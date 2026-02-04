# Failed Recipe Import Handling - Brainstorm

**Date:** 2026-01-30
**Status:** Ready for Planning

## Problem Statement

When recipe imports fail (unsupported website, no recipe data found, timeout, etc.), the recipe remains in the user's list with the name "Importing..." indefinitely. Users have no visibility into:
- Whether the import failed
- Why it failed
- Which URL caused the failure
- How to clean up failed imports

This creates a poor user experience and clutters the recipe list.

## What We're Building

An automatic failed recipe handling system that:
1. **Shows clear error messages** to users when imports fail, including the domain name
2. **Displays errors prominently** as banners at the top of the recipe list
3. **Automatically cleans up** failed recipes after ensuring the user had a chance to see them
4. **Handles multiple failures** gracefully (multiple error banners if needed)

## Why This Approach

**Selected: Auto-Delete After First Fetch + Time Buffer**

We chose this approach because it balances three key concerns:

1. **User Awareness**: Users must see what went wrong and which URL failed
2. **Automatic Cleanup**: No manual deletion required, keeps UI clean
3. **Safety**: Prevents premature deletion from race conditions or rapid refreshes

### How It Works

**Backend (Rails):**
- Add `error_message` TEXT and `failed_recipe_fetched_at` TIMESTAMP columns to recipes table
- When `RecipeImportJob` fails:
  - Set `import_status: :failed`
  - Store user-friendly error: "Import from {domain} failed - page is not supported or doesn't contain a recipe"
  - Leave `failed_recipe_fetched_at` as NULL
- On `GET /recipes` (in controller):
  - If failed recipe has `fetched_at = nil`, set it to `Time.current` (first fetch)
  - If failed recipe has `fetched_at` older than 1 minute, delete it (using `after_action`)
- Return failed recipes in normal JSON response with error message

**Frontend (iOS):**
- Receive all recipes including failed ones from API
- Filter recipes into two groups:
  - `failedRecipes`: where `importStatus == "failed"`
  - `successfulRecipes`: all others
- Display failed recipes as error banners at **top** of list
- Display successful recipes as normal cards below banners
- Each error banner shows the recipe's `errorMessage` field
- Multiple failed imports → Multiple banners (one per failure)

### Timing Logic

1. Import fails → Recipe created with status `failed`, `fetched_at = nil`
2. iOS polls (GET /recipes) → Backend sees `fetched_at = nil`, sets to now
3. iOS shows error banner(s) for at least 1 minute
4. iOS polls again after 1+ minute → Backend deletes recipe, returns updated list
5. Error banner(s) disappear from UI

## Key Decisions

### 1. Error Message Format
**Decision:** "Import from {domain} failed - page is not supported or doesn't contain a recipe"

**Rationale:**
- Includes domain so user knows which URL failed
- Generic enough to cover all failure types (no JSON-LD, LLM timeout, fetch errors)
- Friendly and non-technical language

**Edge case:** Text imports (no URL) → Show "Import failed - text doesn't contain a recipe"

### 2. Display Location
**Decision:** Error banners at top of recipe list (not integrated into recipe cards)

**Rationale:**
- More prominent and noticeable
- Clearly separates temporary errors from permanent recipes
- Easy to understand multiple failures
- Doesn't clutter main recipe grid/list

### 3. Deletion Timing
**Decision:** Delete after first fetch + 1 minute minimum

**Rationale:**
- **First fetch tracking**: Ensures error was delivered to at least one device
- **1 minute buffer**: Handles rapid refreshes, app backgrounding, multiple devices
- Prevents deletion from:
  - Polling every 3 seconds during import
  - User quickly opening/closing app
  - Multiple devices fetching simultaneously

### 4. Error Message Storage
**Decision:** Add `error_message` column instead of just using enum status

**Rationale:**
- Backend already generates detailed error codes (`:no_json_ld`, `:timeout`, etc.)
- Can map error codes to user-friendly messages
- Includes dynamic content (domain name)
- Future-proof for localization or more detailed errors

## Alternatives Considered

### Time-Based Auto-Delete (5 minutes)
**Why not chosen:**
- Less reliable - might delete before user sees it
- Arbitrary timeout (5 min too long? too short?)
- Doesn't adapt to user behavior (e.g., user opens app after 10 minutes)

### User-Dismissed Errors (Manual deletion)
**Why not chosen:**
- Adds friction - requires user action
- More complex iOS UI (dismiss buttons)
- Failed imports accumulate if user ignores them
- Breaks the "automatic cleanup" goal

### Immediate Deletion (No user visibility)
**Why not chosen:**
- Users don't learn which sites work/don't work
- Mystery failures ("I tried importing but nothing happened")
- No feedback loop for reporting issues

## Open Questions

### Technical Details
1. **Error code mapping:** How should we map backend error codes to user messages?
   - Option A: All failures show same generic message (simpler)
   - Option B: Different messages for timeout vs no-recipe vs fetch-failed (more helpful)

2. **Domain extraction:** Should we extract domain in backend or iOS?
   - Recommendation: Backend (in `RecipeImportJob`) - keeps logic centralized

3. **Migration strategy:** What happens to existing failed recipes with no error message?
   - Recommendation: Backfill with generic "Import failed" or delete immediately

4. **Polling optimization:** Should we stop polling when only failed recipes remain?
   - Current: Polls until no "pending" recipes
   - With this change: Failed recipes aren't pending, so polling already stops correctly

### iOS Implementation
5. **Banner styling:** Should banners be dismissible, or just show info?
   - Recommendation: Info-only (auto-disappears after 1 min)

6. **Multiple failures UI:** Stack banners vertically, or show count?
   - Option A: Stack all banners (clear but takes space)
   - Option B: Single banner "3 imports failed" with expansion (compact)
   - Recommendation: Start with Option A (simpler)

7. **Error icon:** What SF Symbol to use for error banners?
   - Recommendation: `exclamationmark.triangle.fill` (standard warning icon)

### Edge Cases
8. **User never opens app:** If failed recipe created but user doesn't open app for days?
   - Current plan: Recipe stays until fetched once
   - Alternative: Add fallback cleanup (delete after 7 days regardless)

9. **Multiple devices with time skew:** What if device A fetches, device B fetches 30s later?
   - Current plan: First fetch sets timestamp, second device sees existing timestamp
   - Works correctly - buffer time handles this

10. **Concurrent imports failing:** 5 recipes imported simultaneously, all fail?
    - Current plan: 5 error banners shown
    - Need to ensure iOS UI handles this gracefully (scrolling, spacing)

## Success Criteria

We'll know this is working when:
1. ✅ Users see clear error messages when imports fail
2. ✅ Error messages include the domain name that failed
3. ✅ Failed recipes auto-delete after ~1 minute
4. ✅ No failed recipes accumulate in the list long-term
5. ✅ Multiple failures display clearly (stacked banners)
6. ✅ No premature deletion from rapid refreshes
7. ✅ Works correctly across multiple devices

## Files That Will Change

### Backend (Rails)
- `db/migrate/TIMESTAMP_add_error_fields_to_recipes.rb` - New migration
- `app/models/recipe.rb` - Add scopes for deletion logic
- `app/jobs/recipe_import_job.rb` - Store error messages on failure
- `app/controllers/api/v1/recipes_controller.rb` - Track fetch time, delete old failures
- `app/services/recipe_importer.rb` - Maybe refine error messages (optional)

### Frontend (iOS)
- `hauptgang-ios/Hauptgang/Models/Recipe.swift` - Add `errorMessage` field
- `hauptgang-ios/Hauptgang/Views/RecipesView.swift` - Filter and display banners
- `hauptgang-ios/Hauptgang/Views/ErrorBannerView.swift` - **New file** for banner component
- `hauptgang-ios/Hauptgang/ViewModels/RecipeViewModel.swift` - Handle failed recipes in logic

## Next Steps

Ready for `/workflows:plan` to design detailed implementation with:
- Database migration SQL
- Exact error message mapping logic
- iOS banner component design (spacing, colors, SF Symbols)
- Testing strategy for edge cases
- Deployment considerations (existing failed recipes)
