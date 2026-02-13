# Architecture

Hauptgang is a recipe manager with a Rails API backend, a SwiftUI iOS app, and RevenueCat for subscriptions.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Rails 8.1, Ruby 3.4.7, SQLite (multi-DB) |
| Infrastructure | Solid Queue, Solid Cache, Solid Cable — all SQLite-backed |
| iOS | SwiftUI, Swift 5.9, iOS 18+, strict concurrency |
| Billing | RevenueCat (iOS SDK + server webhook) |
| AI | OpenRouter LLM for recipe extraction |
| Deployment | Kamal + Docker on Hetzner VPS |

## How It Works

The Rails backend serves a JSON API at `/api/v1/`. The iOS app is the primary client. There is also a lightweight web interface using Hotwire, but the mobile app drives most of the design.

### Authentication

Users sign up or log in with email and password. Rails returns a Bearer token (90-day expiry) that iOS stores in the Keychain. The Keychain uses a shared access group so the share extension can read the same token. Every API request carries this token in the `Authorization` header.

### Recipes

The central model. A recipe has a name, ingredients (JSON array), instructions (JSON array), optional cover image, and tags. Recipes belong to a user and track an `import_status` (pending, completed, or failed).

There are three ways to create a recipe — import from URL, paste text, or snap a photo. All three follow the same async pattern: the API accepts the request, creates a pending recipe, enqueues a background job, and returns HTTP 202. The iOS app polls every 3 seconds until the recipe completes or fails.

**URL import** fetches the webpage and tries JSON-LD (schema.org) extraction first. If that fails, it sends the page content to an LLM. **Text and image extraction** go straight to the LLM. Cover images are downloaded and converted to WebP thumbnails via libvips.

Free users can import 15 recipes per month. Pro users have no limit. The server enforces this with a row lock on the user to prevent race conditions.

### Shopping List

Users can add ingredients from recipes to a shopping list or create items manually. The shopping list is offline-first: each item gets a client-generated UUID (`client_id`), and the app tracks local changes until it can sync them with the server via batch upsert. The server deduplicates by `client_id`. Checked items auto-delete after one hour.

### Tags

Recipes can have tags. Tags have a name and a slug. The relationship goes through a `recipe_tags` join table.

## iOS App

### State and Navigation

`AuthManager` and `SubscriptionManager` are `ObservableObject`s injected via `.environmentObject()`. `RecipeViewModel` uses the newer `@Observable` macro with `@State` in views.

`APIClient` is an actor-based singleton that handles token injection, snake_case/camelCase conversion, and typed error responses.

### Offline-First Sync

Recipes sync in two phases. First, the list endpoint loads summaries into SwiftData. Then a background task fetches full details via cursor-based batch pagination (`/recipes/batch`). The cursor persists in UserDefaults per user, so the app picks up where it left off.

The shopping list syncs similarly — local changes accumulate with a `pendingCreate`/`pendingUpdate` state and flush to the server on the next sync. Server wins for already-synced items; client wins for pending changes.

### Local Search

The app maintains a per-user FTS5 search index (via GRDB) alongside the SwiftData store. It indexes recipe names, ingredients, and instructions with BM25 ranking and prefix matching. The index rebuilds automatically if its schema version changes or if corruption is detected. If FTS5 is unavailable, the app falls back to client-side fuzzy matching.

### Share Extension

`ImportRecipeExtension` appears in the iOS share sheet. It reads the auth token from the shared Keychain, extracts a URL or image from the share context, and calls the same import API. It then opens the main app via the `hauptgang://` URL scheme. The extension shares source files (APIClient, KeychainService, Constants, etc.) with the main target.

## RevenueCat Integration

A single entitlement — `"Hauptgang Pro"` — gates premium features (currently just unlimited imports).

**iOS side:** On login, the app calls `Purchases.shared.logIn("\(user.id)")` to link the RevenueCat customer with the Rails user ID. `SubscriptionManager` checks entitlement status and exposes an `isPro` flag. When a free user hits the import limit (HTTP 403), the app presents a RevenueCatUI paywall.

**Server side:** After a purchase (or renewal, cancellation, or billing change), RevenueCat sends a webhook to `/api/v1/webhooks/revenuecat`. Rails verifies the `Authorization` header against `ENV["REVENUECAT_WEBHOOK_SECRET"]` using constant-time comparison, then checks whether the `"Hauptgang Pro"` entitlement is active based on `expires_date`. It updates the user's `pro` boolean accordingly. For unknown user IDs, the webhook returns 200 to stop RevenueCat from retrying.

This is entitlement-based, not event-type-based — the same logic handles renewals, expirations, and refunds uniformly.

## Deployment

The app runs on a Hetzner VPS behind Kamal. The Docker image uses Thruster as a reverse proxy in front of Puma. SSL comes from Let's Encrypt via `cook.hauptgang.app`.

SQLite databases and Active Storage uploads live in a persistent Docker volume (`hauptgang_storage`). Production file uploads go to Hetzner Object Storage (S3-compatible). Solid Queue runs inside the Puma process rather than as a separate worker.
