# Meal Planning — Architecture Plan (v1)

## Domain Model

```
MealPlan (per cookbook, per date — lazy-created)
  └── MealPlanEntry (a recipe proposed for that day)
        └── MealPlanVote (a user's "like" on that entry)
```

---

## Rails Backend

### New Tables (one migration)

**`meal_plans`**
| Column | Type | Notes |
|---|---|---|
| `id` | integer | PK |
| `cookbook_id` | integer | FK, not null |
| `date` | date | not null |
| `selected_entry_id` | integer | FK → meal_plan_entries, nullable |
| `selected_by_user_id` | integer | FK → users, nullable |
| `selected_at` | datetime | nullable |
| `created_at` / `updated_at` | datetime | |

Unique index: `[cookbook_id, date]`

**`meal_plan_entries`**
| Column | Type | Notes |
|---|---|---|
| `id` | integer | PK |
| `meal_plan_id` | integer | FK, not null |
| `recipe_id` | integer | FK, not null |
| `proposed_by_user_id` | integer | FK → users, not null |
| `created_at` / `updated_at` | datetime | |

Unique index: `[meal_plan_id, recipe_id]` (same recipe can't be proposed twice for same day)

**`meal_plan_votes`**
| Column | Type | Notes |
|---|---|---|
| `id` | integer | PK |
| `meal_plan_entry_id` | integer | FK, not null |
| `user_id` | integer | FK, not null |
| `created_at` / `updated_at` | datetime | |

Unique index: `[meal_plan_entry_id, user_id]`

### Foreign Key Behavior

- `meal_plan_entries.recipe_id` → **restrict** (can't delete a recipe that's in a plan)
- `meal_plan_entries.proposed_by_user_id` → nullify
- `meal_plan_votes` → cascade on entry delete
- `meal_plans` → cascade on cookbook delete

### Models

```ruby
class MealPlan < ApplicationRecord
  belongs_to :cookbook
  belongs_to :selected_entry, class_name: "MealPlanEntry", optional: true
  belongs_to :selected_by_user, class_name: "User", optional: true
  has_many :entries, class_name: "MealPlanEntry", dependent: :destroy

  validates :date, presence: true
  validates :date, uniqueness: { scope: :cookbook_id }
  validate :selected_entry_belongs_to_self

  def selected?
    selected_entry_id.present?
  end
end

class MealPlanEntry < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :recipe
  belongs_to :proposed_by_user, class_name: "User", optional: true
  has_many :votes, class_name: "MealPlanVote", dependent: :destroy

  validates :recipe_id, uniqueness: { scope: :meal_plan_id }
  validate :recipe_belongs_to_same_cookbook
end

class MealPlanVote < ApplicationRecord
  belongs_to :meal_plan_entry
  belongs_to :user

  validates :user_id, uniqueness: { scope: :meal_plan_entry_id }
end
```

### Authorization Rules

| Action | Who | Precondition |
|---|---|---|
| Add entry | Any cookbook member | Plan not selected |
| Delete entry | Any cookbook member | Plan not selected |
| Vote / unvote | Any cookbook member | Plan not selected |
| Select | Any cookbook member | Plan not already selected |
| Deselect | Any cookbook member | Plan is selected |

### Idempotency & Conflict Rules

- **Add entry** for existing recipe → return existing entry (200)
- **Vote** when already voted → return success (no-op)
- **Unvote** when no vote exists → return success (no-op)
- **Select** when already selected with different entry → return **409 Conflict**
- **Select** when already selected with same entry → return success (no-op)
- All mutations on a selected plan (add/vote/delete entry) → return **422** with clear error

### API Endpoints

```
GET    /api/v1/cookbooks/:cookbook_id/meal_plans?from=DATE&to=DATE

POST   /api/v1/cookbooks/:cookbook_id/meal_plans/:date/entries    → { recipe_id: }
DELETE /api/v1/meal_plan_entries/:id

POST   /api/v1/meal_plan_entries/:id/vote
DELETE /api/v1/meal_plan_entries/:id/vote

PATCH  /api/v1/cookbooks/:cookbook_id/meal_plans/:date/select     → { entry_id: }
DELETE /api/v1/cookbooks/:cookbook_id/meal_plans/:date/select
```

Plans are lazy-created server-side when the first entry is added. The entry-create endpoint uses `:date` in the URL and does find-or-create internally. Select/deselect also use `:date` so the iOS app never needs to know meal_plan IDs.

### JSON Response (GET index)

```json
[
  {
    "date": "2026-03-15",
    "selected_entry_id": null,
    "selected_by_user_id": null,
    "selected_at": null,
    "entries": [
      {
        "id": 10,
        "recipe": { "id": 5, "name": "Pasta", "cover_image_url": "..." },
        "proposed_by": { "id": 1, "email": "alice@example.com" },
        "vote_count": 2,
        "voted_by_current_user": true
      }
    ]
  }
]
```

For dates with no plan, the response simply omits them — iOS fills empty days client-side.

### Integrity Validations

- Entry's recipe must belong to the same cookbook as the meal plan
- Selected entry must belong to that meal plan
- All controller actions verify the current user is a cookbook member (via existing `cookbook_memberships`)

### Recipe Deletion

`dependent: :restrict_with_error` on `Recipe → MealPlanEntry`. A recipe can't be deleted while it's in any meal plan. The user must remove it from the plan first.

### Query Strategy

Eager-load to avoid N+1:
```ruby
meal_plans = cookbook.meal_plans
  .where(date: from..to)
  .includes(entries: [:recipe, :proposed_by_user, :votes])
```

Vote count and `voted_by_current_user` computed in the serializer from preloaded votes.

---

## iOS App

### Offline Support

**Read offline**: Meal plans are cached locally so the user can always see what's planned, even without connectivity.

**Add entries offline**: Users can add recipes to a plan while offline. These entries are stored locally with a `pendingSync` flag and flushed to the server on next connectivity. This follows the same pattern as the shopping list's offline-first sync (client-generated identifiers, pending state, sync on reconnect).

**Online-only actions**: Voting, selecting, and deselecting remain online-only — these are collaborative actions that only make sense with a live server round-trip. The UI disables vote/select buttons when offline.

#### Implementation approach

Local persistence uses **SwiftData** `@Model` classes, consistent with how `PersistedRecipe` and `PersistedShoppingListItem` already work. This means:

1. **`PersistedMealPlanDay`** — SwiftData model caching server state (date, selectedEntryId, selectedByUserId, cookbookId). Updated on each server fetch.
2. **`PersistedMealPlanEntry`** — SwiftData model for each entry (serverId, recipeId, recipeName, coverImageUrl, proposedByEmail, voteCount, votedByCurrentUser, syncState). Entries created offline get `syncState = .pendingCreate` and a nil `serverId`.
3. **Sync flow** — on reconnect, pending entries are posted to the server. Server response replaces the local record with the real server ID and sets `syncState = .synced`. If the server rejects (e.g., plan was already selected), the pending entry is deleted and the user is notified.
4. **Merge** — server wins for votes/selection state. Pending local entries are additive. Conflicts are rare (only if the other user selected while you were offline — the add is rejected with 422 and the pending entry is discarded).
5. **Schema migration** — new SwiftData schema version (V3) adding the two new `@Model` classes.

This is simpler than the shopping list's offline sync because there's no update/delete of pending items — only create. And votes/selection skip offline entirely.

### New Files

| Layer | File | Purpose |
|---|---|---|
| Models | `MealPlan.swift` | Codable structs for API responses: `MealPlanDay`, `MealPlanEntry` |
| Models | `PersistedMealPlan.swift` | SwiftData `@Model` classes: `PersistedMealPlanDay`, `PersistedMealPlanEntry` |
| Services | `MealPlanService.swift` | API calls (fetch, add entry, vote, select) |
| ViewModels | `MealPlanViewModel.swift` | `@Observable`, `@MainActor` — holds 2-day state, merge logic |
| Views | `MealPlanView.swift` | Main screen with today + tomorrow cards |
| Views | `MealPlanDayCard.swift` | Single day: voting state or selected state |
| Views | `MealPlanRecipePicker.swift` | Sheet to pick a recipe from current cookbook |

### Models (Swift)

#### API response models (`MealPlan.swift`)

```swift
struct MealPlanDay: Codable, Identifiable {
    let date: String
    let selectedEntryId: Int?
    let selectedByUserId: Int?
    let entries: [MealPlanEntry]
    var id: String { date }
}

struct MealPlanEntry: Codable, Identifiable {
    let id: Int
    let recipe: MealPlanRecipeSummary
    let proposedBy: MealPlanUser
    let voteCount: Int
    let votedByCurrentUser: Bool
}
```

#### SwiftData models (`PersistedMealPlan.swift`)

```swift
@Model
final class PersistedMealPlanDay {
    @Attribute(.unique) var scopedDate: String  // "\(cookbookId)|\(date)"
    var cookbookId: Int
    var date: String
    var selectedEntryId: Int?
    var selectedByUserId: Int?
}

@Model
final class PersistedMealPlanEntry {
    @Attribute(.unique) var scopedId: String  // "\(cookbookId)|\(date)|\(recipeId)"
    var cookbookId: Int
    var date: String
    var serverId: Int?
    var recipeId: Int
    var recipeName: String
    var recipeCoverImageUrl: String?
    var proposedByEmail: String?
    var voteCount: Int
    var votedByCurrentUser: Bool
    var syncStateRaw: String  // "synced" | "pending_create"
}
```

  to V3, adding these two models to `HauptgangSchemaV3` and updating `HauptgangMigrationPlan`.

### Navigation

New tab in `MainTabView` between Shopping List and Settings:

```swift
SwiftUI.Tab("Meal Plan", systemImage: "calendar", value: Tab.mealPlan) {
    MealPlanView()
}
```

### UX States per Day Card

```
┌─────────────────────────────────────────┐
│  State 1: EMPTY                         │
│  "No meals planned" + [+] button        │
├─────────────────────────────────────────┤
│  State 2: VOTING (multiple entries)     │
│  Recipe cards with vote ♡ + count       │
│  [Select] button on each               │
│  [+] button to add more                │
├─────────────────────────────────────────┤
│  State 3: SELECTED (final pick)         │
│  Single recipe card, prominent          │
│  [Add to Shopping List] button          │
│  [Change] button (owner/selector only)  │
└─────────────────────────────────────────┘
```

### Optimistic UI & Offline Behavior

- **Add entry (online)**: update UI immediately, revert on failure
- **Add entry (offline)**: save as pending entry, show with sync indicator, flush on reconnect
- **Vote toggle**: update UI immediately, revert on failure (disabled when offline)
- **Select / Deselect**: wait for server response, show loading indicator (disabled when offline)

### Add to Shopping List

When a recipe is selected, show an "Add to Shopping List" button. This reuses the existing shopping list service — creates items with `source_recipe_id` set. Same flow as adding from recipe detail.

### Cookbook Awareness

The view model reads the active cookbook from `CookbookViewModel` (same source as shopping list/recipes). On cookbook switch, re-fetch meal plans. Only show the meal plan tab content for the active cookbook.

### Timezone Handling (v1)

iOS sends dates as `yyyy-MM-dd` strings derived from the device's current calendar. No timezone field. This works fine when household members share a timezone.

---

## Future Expansion Path (not built now)

- **Full week/calendar view**: widen date range, swap 2-card layout for scrollable week
- **Multiple meals per day**: add `meal_type` enum to MealPlan (breakfast/lunch/dinner)
- **Cookbook timezone**: add `timezone` to cookbooks table
- **Live updates**: Solid Cable / ActionCable for real-time vote/selection sync
- **Recipe snapshots**: snapshot name/image on entry for history after recipe deletion
