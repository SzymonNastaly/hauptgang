---
title: Implement Failed Recipe Import Handling with Auto-Cleanup
type: feat
date: 2026-01-30
---

# Implement Failed Recipe Import Handling with Auto-Cleanup

## Overview

When recipe imports fail (unsupported website, no recipe data, timeout, etc.), the recipe currently remains in the user's list with "Importing..." indefinitely. This feature adds automatic failed recipe handling that shows clear error messages to users and automatically cleans up failed imports after ensuring users had a chance to see them.

**Solution**: Display failed recipes as error banners at the top of the recipe list, include the domain name that failed, and auto-delete after the first fetch + 1 minute buffer.

## Problem Statement

**Current Behavior:**
- Failed imports show "Importing..." forever
- No visibility into failures or reasons
- No way to clean up failed recipes
- Clutters the recipe list

**Impact on Users:**
- Confusion about import status
- No feedback on which sites work/don't work
- Manual cleanup burden (requires database access)
- Poor user experience

## Proposed Solution

### High-Level Approach

**Backend (Rails):**
1. Add `error_message` (TEXT) and `failed_recipe_fetched_at` (TIMESTAMP) columns
2. Store user-friendly error messages when imports fail (include domain)
3. Track first fetch time of failed recipes
4. Auto-delete failed recipes after 1+ minute post-fetch

**Frontend (iOS):**
1. Receive failed recipes with error messages from API
2. Filter recipes into failed and successful groups
3. Display failed recipes as error banners at top of list
4. Display successful recipes as normal cards below
5. Banners disappear automatically when backend deletes recipes

### Timing Logic

```
1. Import fails
   → Recipe created: status=failed, fetched_at=nil, error_message="Import from example.com failed..."

2. iOS polls (GET /recipes)
   → Backend: fetched_at=nil? Set to now
   → iOS: Shows error banner

3. User sees error for 1+ minute
   → iOS continues normal polling

4. iOS polls again (after 1+ minute)
   → Backend: fetched_at < 1.minute.ago? Delete recipe
   → iOS: Error banner disappears
```

## Technical Approach

### Backend Implementation

#### 1. Database Migration

**File**: `db/migrate/TIMESTAMP_add_error_fields_to_recipes.rb`

```ruby
class AddErrorFieldsToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :error_message, :text, null: true
    add_column :recipes, :failed_recipe_fetched_at, :datetime, null: true
  end
end
```

**Rationale:**
- `:text` for potentially long error strings (domain + message)
- `:datetime` for timestamp tracking
- `null: true` since only failed recipes need these fields

#### 2. Error Message Generation in RecipeImportJob

**File**: `app/jobs/recipe_import_job.rb` (modify lines 13-18)

**Current Code:**
```ruby
if result.success?
  recipe.update!(result.recipe_attributes.merge(import_status: :completed))
else
  recipe.update!(import_status: :failed)
  Rails.logger.error "[RecipeImportJob] Import failed for recipe #{recipe_id}: #{result.error}"
end
```

**New Code:**
```ruby
if result.success?
  recipe.update!(result.recipe_attributes.merge(import_status: :completed))
else
  error_message = build_error_message(source_url, result.error_code)
  recipe.update!(
    import_status: :failed,
    error_message: error_message
  )
  Rails.logger.error "[RecipeImportJob] Import failed for recipe #{recipe_id}: #{result.error}"
end
```

**Add Helper Method:**
```ruby
private

def build_error_message(url, error_code)
  domain = extract_domain(url)

  # Generic message covers all failure types
  # (no JSON-LD, LLM timeout, fetch errors, etc.)
  "Import from #{domain} failed - page is not supported or doesn't contain a recipe"
end

def extract_domain(url)
  return "unknown source" if url.blank?

  uri = URI.parse(url)
  uri.host || "unknown source"
rescue URI::InvalidURIError
  "unknown source"
end
```

**Also Update RecipeTextExtractJob** (lines 17-18):
```ruby
else
  error_message = "Import failed - text doesn't contain a recipe"
  recipe.update!(
    import_status: :failed,
    error_message: error_message
  )
end
```

#### 3. Controller Changes for Fetch Tracking & Cleanup

**File**: `app/controllers/api/v1/recipes_controller.rb`

**Modify `index` action** (after line 7):
```ruby
def index
  recipes = current_user.recipes.with_attached_cover_image.includes(:tags)
  recipes = recipes.favorited if params[:favorites] == "true"
  recipes = recipes.order(updated_at: :desc)

  # Track first fetch of failed recipes (before rendering)
  track_failed_recipe_fetches(recipes)

  render json: recipes.map { |recipe| recipe_list_json(recipe) }
end
```

**Add Helper Methods:**
```ruby
private

def track_failed_recipe_fetches(recipes)
  # Find failed recipes that haven't been fetched yet
  unfetched_failed = recipes.select do |recipe|
    recipe.failed? && recipe.failed_recipe_fetched_at.nil?
  end

  # Mark them as fetched now
  unfetched_failed.each do |recipe|
    recipe.update_column(:failed_recipe_fetched_at, Time.current)
  end
end
```

**Add `after_action` hook** (after line 3):
```ruby
after_action :cleanup_old_failed_recipes, only: [:index]

private

def cleanup_old_failed_recipes
  # Delete failed recipes that were fetched more than 1 minute ago
  current_user.recipes
    .where(import_status: :failed)
    .where("failed_recipe_fetched_at < ?", 1.minute.ago)
    .destroy_all
end
```

**Update `recipe_list_json` helper** (line 70):
```ruby
def recipe_list_json(recipe)
  {
    id: recipe.id,
    name: recipe.name,
    prep_time: recipe.prep_time,
    cook_time: recipe.cook_time,
    favorite: recipe.favorite,
    cover_image_url: cover_image_url(recipe, :thumbnail),
    import_status: recipe.import_status,
    error_message: recipe.error_message,  # ← NEW: nil for non-failed recipes
    updated_at: recipe.updated_at
  }
end
```

**Why `after_action`?**
- Runs after response is rendered and sent to client
- Doesn't slow down API response time
- Failed recipes are already in the response if they shouldn't be deleted yet

**Why 1 minute buffer?**
- Prevents deletion from rapid refreshes (iOS polls every 3 seconds during imports)
- Handles app backgrounding/foregrounding
- Accounts for multiple devices with slight time skew
- Ensures error message is delivered to at least one device

#### 4. Data Migration for Existing Failed Recipes

**File**: `db/migrate/TIMESTAMP_backfill_failed_recipe_errors.rb`

```ruby
class BackfillFailedRecipeErrors < ActiveRecord::Migration[8.1]
  def up
    # Option 1: Delete existing failed recipes immediately (clean slate)
    Recipe.where(import_status: :failed).destroy_all

    # Option 2: Backfill with generic message (preserve data)
    # Recipe.where(import_status: :failed).update_all(
    #   error_message: "Import failed - page is not supported",
    #   failed_recipe_fetched_at: Time.current
    # )
  end

  def down
    # No-op: Can't restore deleted recipes
  end
end
```

**Recommendation**: Use Option 1 (delete) for clean slate. Existing failed recipes are stuck in bad state anyway.

### iOS Implementation

#### 1. Update Recipe Model

**File**: `hauptgang-ios/Hauptgang/Models/Recipe.swift`

**Modify `RecipeListItem`** (after line 13):
```swift
struct RecipeListItem: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let prepTime: Int?
    let cookTime: Int?
    let favorite: Bool
    let coverImageUrl: String?
    let importStatus: String?
    let errorMessage: String?  // ← NEW: Error text for failed imports
    let updatedAt: Date
}
```

**Coding Keys** (add if needed):
```swift
enum CodingKeys: String, CodingKey {
    case id, name, prepTime, cookTime, favorite, coverImageUrl
    case importStatus, errorMessage, updatedAt
}
```

#### 2. Update Persistence Model

**File**: `hauptgang-ios/Hauptgang/Models/PersistedRecipe.swift`

**Add field** (after line 15):
```swift
@Model
final class PersistedRecipe {
    @Attribute(.unique) var id: Int
    var name: String
    var prepTime: Int?
    var cookTime: Int?
    var favorite: Bool
    var coverImageUrl: String?
    var importStatus: String?
    var errorMessage: String?  // ← NEW: Store error from API
    var updatedAt: Date
    var lastFetchedAt: Date

    // ... rest of fields
}
```

**Update Convenience Initializer** (line 100):
```swift
convenience init(from listItem: RecipeListItem) {
    self.init(
        id: listItem.id,
        name: listItem.name,
        prepTime: listItem.prepTime,
        cookTime: listItem.cookTime,
        favorite: listItem.favorite,
        coverImageUrl: listItem.coverImageUrl,
        importStatus: listItem.importStatus,
        errorMessage: listItem.errorMessage,  // ← NEW
        updatedAt: listItem.updatedAt
    )
}
```

**Update `update(from:)` Method** (line 136):
```swift
func update(from listItem: RecipeListItem) {
    name = listItem.name
    prepTime = listItem.prepTime
    cookTime = listItem.cookTime
    favorite = listItem.favorite
    coverImageUrl = listItem.coverImageUrl
    importStatus = listItem.importStatus
    errorMessage = listItem.errorMessage  // ← NEW
    updatedAt = listItem.updatedAt
    lastFetchedAt = Date()
}
```

#### 3. Create ErrorBannerView Component

**File**: `hauptgang-ios/Hauptgang/Views/ErrorBannerView.swift` (NEW FILE)

```swift
import SwiftUI

struct ErrorBannerView: View {
    let recipe: PersistedRecipe

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 24)

            // Error message text
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let errorMessage = recipe.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                } else {
                    // Fallback for recipes without error_message
                    Text("Import failed - page is not supported")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.hauptgangError)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Preview
#Preview("Single Error") {
    ErrorBannerView(recipe: {
        let recipe = PersistedRecipe(
            id: 1,
            name: "Importing...",
            favorite: false,
            updatedAt: Date()
        )
        recipe.importStatus = "failed"
        recipe.errorMessage = "Import from allrecipes.com failed - page is not supported or doesn't contain a recipe"
        return recipe
    }())
    .padding()
}

#Preview("Multiple Errors") {
    VStack(spacing: Theme.Spacing.sm) {
        ErrorBannerView(recipe: {
            let recipe = PersistedRecipe(id: 1, name: "Test", favorite: false, updatedAt: Date())
            recipe.importStatus = "failed"
            recipe.errorMessage = "Import from allrecipes.com failed - page is not supported or doesn't contain a recipe"
            return recipe
        }())

        ErrorBannerView(recipe: {
            let recipe = PersistedRecipe(id: 2, name: "Test", favorite: false, updatedAt: Date())
            recipe.importStatus = "failed"
            recipe.errorMessage = "Import from epicurious.com failed - page is not supported or doesn't contain a recipe"
            return recipe
        }())
    }
    .padding()
}
```

**Design Rationale:**
- **Icon**: `exclamationmark.triangle.fill` (standard warning icon)
- **Color**: `.hauptgangError` (red #DC2626 from theme)
- **Layout**: Horizontal with icon on left, text on right
- **Styling**: Rounded corners, shadow, padding matching theme constants
- **No dismiss button**: Auto-disappears after 1 minute (backend-driven)

#### 4. Update RecipesView Layout

**File**: `hauptgang-ios/Hauptgang/Views/RecipesView.swift`

**Modify `recipeListView`** (replace lines 51-88):
```swift
private var recipeListView: some View {
    ScrollView {
        VStack(spacing: Theme.Spacing.sm) {
            // Global error message (API failures)
            if let error = recipeViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.hauptgangError)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            // Failed recipe error banners (NEW)
            ForEach(recipeViewModel.failedRecipes) { recipe in
                ErrorBannerView(recipe: recipe)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            // Successful recipe cards
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(recipeViewModel.successfulRecipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.top, Theme.Spacing.sm)
    }
    .refreshable {
        await recipeViewModel.refreshRecipes()
    }
}
```

**Key Changes:**
- Split recipes into `failedRecipes` and `successfulRecipes` (computed properties)
- Display error banners at top of list
- Successful recipes below as normal cards
- Removed card overlay logic for failed recipes (now using banners)

#### 5. Update RecipeViewModel

**File**: `hauptgang-ios/Hauptgang/ViewModels/RecipeViewModel.swift`

**Add Computed Properties** (after line 15):
```swift
var failedRecipes: [PersistedRecipe] {
    recipes.filter { $0.importStatus == "failed" }
}

var successfulRecipes: [PersistedRecipe] {
    recipes.filter { $0.importStatus != "failed" }
}
```

**No polling changes needed** - Polling already checks only `"pending"` status (line 14), so failed recipes won't trigger continuous polling.

#### 6. Update RecipeCardView (Optional Cleanup)

**File**: `hauptgang-ios/Hauptgang/Views/RecipeCardView.swift`

**Remove failed overlay** (lines 137-158):
```swift
// Delete the "failed" case from importStatusOverlay method
// Only keep "pending" case, remove entire failed block
```

**Rationale**: Failed recipes now display as banners, not cards. Pending recipes still need the spinner overlay.

## Acceptance Criteria

### Functional Requirements

- [ ] Failed recipes display as error banners at top of recipe list
- [ ] Error messages include domain name that failed (e.g., "Import from allrecipes.com failed...")
- [ ] Multiple failures display as stacked banners (one per failure)
- [ ] Error banners auto-disappear after ~1 minute
- [ ] No failed recipes accumulate long-term in the database
- [ ] Text-based imports show "Import failed - text doesn't contain a recipe"
- [ ] Successful recipes display as normal cards below error banners

### Non-Functional Requirements

- [ ] No premature deletion from rapid refreshes (polling every 3 seconds)
- [ ] Works correctly across multiple devices with time skew
- [ ] Backend cleanup doesn't slow down API response time (`after_action`)
- [ ] iOS UI handles 5+ concurrent failures gracefully (scrolling, spacing)
- [ ] Existing failed recipes cleaned up via data migration

### Quality Gates

- [ ] Backend tests verify error message storage and domain extraction
- [ ] Backend tests verify 1-minute deletion timing
- [ ] Backend tests verify first-fetch tracking
- [ ] iOS previews show single and multiple error banners
- [ ] Manual testing with unsupported domains (e.g., example.com)
- [ ] Manual testing with multiple concurrent failures

## Technical Considerations

### Race Condition Prevention

**Problem**: Device A fetches at T+0, Device B fetches at T+30s. If we delete immediately, Device B might never see the error.

**Solution**: 1-minute buffer ensures all devices have multiple polling cycles to fetch the failed recipe before deletion.

**Edge Case - Clock Skew**: What if devices have slightly different system times?
- Server time (`Time.current`) is source of truth
- Buffer is generous enough (60 seconds) to handle skew
- Polling continues regardless of client time

### Performance Considerations

**Database Queries:**
- `track_failed_recipe_fetches`: In-memory filtering, single UPDATE per unfetched recipe
- `cleanup_old_failed_recipes`: Single DELETE query with WHERE clause, runs after response
- No N+1 queries (already using `includes(:tags)`)

**API Response Size:**
- Failed recipes included in normal response (adds ~100 bytes per failure)
- Typical case: 0-2 failed recipes at a time
- Edge case: 10+ failures → ~1KB extra (acceptable)

**iOS Memory:**
- Failed recipes stored in SwiftData temporarily
- Auto-deleted by backend, so iOS cache stays clean
- No memory leak risk

### Security Considerations

**No vulnerabilities identified:**
- Error messages don't expose internal paths or stack traces
- Domain extraction uses `URI.parse` with rescue (safe)
- User-scoped queries prevent cross-user data leaks (`current_user.recipes`)
- No user input in error messages (domain comes from source_url)

### Alternative Approaches Considered

**Time-Based Auto-Delete (5 minutes)**
- ❌ Less reliable - might delete before user sees it
- ❌ Arbitrary timeout (5 min too long? too short?)
- ❌ Doesn't adapt to user behavior

**User-Dismissed Errors (Manual deletion)**
- ❌ Adds friction - requires user action
- ❌ More complex iOS UI (dismiss buttons)
- ❌ Failed imports accumulate if ignored

**Immediate Deletion (No user visibility)**
- ❌ Mystery failures ("I tried importing but nothing happened")
- ❌ No feedback loop for reporting issues

## Dependencies & Risks

### Dependencies

**No external dependencies** - Uses existing gems and frameworks:
- Rails 8.1 (already on project)
- SQLite (already configured)
- iOS 17+ SwiftUI (already minimum version)

### Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Users don't notice 1-minute banners | Low | Medium | Banners at top of list are prominent; 1 minute is reasonable viewing time |
| Clock skew causes premature deletion | Low | Low | 1-minute buffer handles typical skew; server time is source of truth |
| Too many concurrent failures clutter UI | Low | Medium | Stack banners vertically; ScrollView handles overflow gracefully |
| Existing failed recipes cause confusion | Low | Low | Data migration deletes them before feature launch |
| Backend deletion runs too frequently | Low | Low | Only runs on index action; WHERE clause is indexed |

## Testing Strategy

### Backend Tests

**File**: `test/jobs/recipe_import_job_test.rb`

```ruby
test "stores error message on import failure" do
  recipe = recipes(:pending_import)

  # Mock failure
  RecipeImporter.any_instance.stubs(:import).returns(
    RecipeImportJob::Result.new(
      success?: false,
      error: "No recipe found",
      error_code: :no_recipe_found
    )
  )

  RecipeImportJob.perform_now(users(:one).id, recipe.id, "https://example.com/recipe")

  recipe.reload
  assert_equal "failed", recipe.import_status
  assert_includes recipe.error_message, "example.com"
  assert_includes recipe.error_message, "not supported"
end

test "handles text imports with appropriate error message" do
  recipe = recipes(:pending_text_import)

  RecipeTextExtractJob.expects(:perform_later)
    .never  # Simulate immediate failure

  # Perform job with text that can't be parsed
  RecipeTextExtractJob.perform_now(users(:one).id, recipe.id, "random text")

  recipe.reload
  assert_equal "failed", recipe.import_status
  assert_equal "Import failed - text doesn't contain a recipe", recipe.error_message
end
```

**File**: `test/controllers/api/v1/recipes_controller_test.rb`

```ruby
test "tracks first fetch of failed recipes" do
  recipe = recipes(:failed_import)
  assert_nil recipe.failed_recipe_fetched_at

  get api_v1_recipes_path, headers: authenticated_headers

  recipe.reload
  assert_not_nil recipe.failed_recipe_fetched_at
  assert_in_delta Time.current, recipe.failed_recipe_fetched_at, 2.seconds
end

test "deletes failed recipes after 1 minute" do
  recipe = recipes(:failed_import)
  recipe.update!(failed_recipe_fetched_at: 2.minutes.ago)

  assert_difference "Recipe.count", -1 do
    get api_v1_recipes_path, headers: authenticated_headers
  end

  assert_raises(ActiveRecord::RecordNotFound) { recipe.reload }
end

test "does not delete recently fetched failed recipes" do
  recipe = recipes(:failed_import)
  recipe.update!(failed_recipe_fetched_at: 30.seconds.ago)

  assert_no_difference "Recipe.count" do
    get api_v1_recipes_path, headers: authenticated_headers
  end

  assert_nothing_raised { recipe.reload }
end

test "includes error_message in recipe list JSON" do
  recipe = recipes(:failed_import)
  recipe.update!(error_message: "Import from test.com failed")

  get api_v1_recipes_path, headers: authenticated_headers

  json = JSON.parse(response.body)
  failed_recipe = json.find { |r| r["id"] == recipe.id }

  assert_equal "Import from test.com failed", failed_recipe["error_message"]
  assert_equal "failed", failed_recipe["import_status"]
end
```

### iOS Tests

**File**: `hauptgang-ios/HauptgangTests/ViewModels/RecipeViewModelTests.swift`

```swift
func testFailedRecipesFilteredCorrectly() {
    // Create test recipes
    let failed1 = PersistedRecipe(id: 1, name: "Test 1", favorite: false, updatedAt: Date())
    failed1.importStatus = "failed"

    let failed2 = PersistedRecipe(id: 2, name: "Test 2", favorite: false, updatedAt: Date())
    failed2.importStatus = "failed"

    let successful = PersistedRecipe(id: 3, name: "Test 3", favorite: false, updatedAt: Date())
    successful.importStatus = "completed"

    viewModel.recipes = [failed1, failed2, successful]

    XCTAssertEqual(viewModel.failedRecipes.count, 2)
    XCTAssertEqual(viewModel.successfulRecipes.count, 1)
}

func testPollingDoesNotTriggerForFailedRecipes() {
    let failedRecipe = PersistedRecipe(id: 1, name: "Test", favorite: false, updatedAt: Date())
    failedRecipe.importStatus = "failed"

    viewModel.recipes = [failedRecipe]

    XCTAssertFalse(viewModel.hasPendingImports)
}
```

### Manual Testing Checklist

- [ ] **Test 1**: Import from unsupported domain (example.com)
  - Verify error banner appears
  - Verify domain name shown in message
  - Verify banner disappears after ~1 minute

- [ ] **Test 2**: Import 3 recipes simultaneously, all fail
  - Verify 3 stacked banners appear
  - Verify UI scrolls correctly
  - Verify all disappear after ~1 minute

- [ ] **Test 3**: Rapid refreshing during banner display
  - Pull to refresh 5 times in 10 seconds
  - Verify banner doesn't disappear prematurely

- [ ] **Test 4**: App backgrounding during banner display
  - Trigger failed import
  - Background app for 30 seconds
  - Foreground app
  - Verify banner still visible

- [ ] **Test 5**: Multiple devices
  - Device A: Trigger failed import
  - Device A: See error banner
  - Device B: Open app
  - Device B: Should see error banner
  - Wait 1 minute
  - Both devices: Banner should disappear

- [ ] **Test 6**: Text import failure
  - Import from text: "random words no recipe"
  - Verify message: "Import failed - text doesn't contain a recipe"

## Implementation Checklist

### Backend Tasks

- [x] Create migration: Add `error_message` and `failed_recipe_fetched_at` columns
- [x] Run migration: `bin/rails db:migrate`
- [x] Update `RecipeImportJob`: Add `build_error_message` and `extract_domain` methods
- [x] Update `RecipeImportJob`: Store error message on failure
- [x] Update `RecipeTextExtractJob`: Store error message on text import failure
- [x] Update `RecipesController#index`: Add `track_failed_recipe_fetches` call
- [x] Update `RecipesController`: Add `after_action :cleanup_old_failed_recipes`
- [x] Update `RecipesController#recipe_list_json`: Include `error_message` field
- [x] Create data migration: Clean up existing failed recipes
- [x] Write backend tests for error message storage
- [x] Write backend tests for fetch tracking
- [x] Write backend tests for cleanup timing
- [ ] Run `bin/rubocop -a` to fix style issues
- [ ] Run `bin/ci` to verify all checks pass

### iOS Tasks

- [x] Update `Recipe.swift`: Add `errorMessage: String?` to `RecipeListItem`
- [x] Update `PersistedRecipe.swift`: Add `errorMessage` field
- [x] Update `PersistedRecipe.swift`: Update convenience initializers
- [x] Update `PersistedRecipe.swift`: Update `update(from:)` method
- [ ] Create `ErrorBannerView.swift`: Implement banner component
- [ ] Add SwiftUI previews to `ErrorBannerView.swift` (single + multiple errors)
- [ ] Update `RecipesView.swift`: Add failed recipe banners to layout
- [ ] Update `RecipeViewModel.swift`: Add `failedRecipes` computed property
- [ ] Update `RecipeViewModel.swift`: Add `successfulRecipes` computed property
- [ ] Update `RecipeCardView.swift`: Remove failed overlay case (optional cleanup)
- [ ] Write iOS tests for recipe filtering
- [ ] Write iOS tests for polling behavior with failed recipes
- [ ] Run `bin/ios-test` to verify tests pass
- [ ] Manual testing: Follow checklist above

### Deployment Tasks

- [ ] Merge to main branch
- [ ] Deploy backend changes
- [ ] Verify data migration ran successfully (check logs)
- [ ] Submit iOS app update to App Store
- [ ] Monitor for errors in production logs
- [ ] Verify failed recipes are being cleaned up (check database)

## Future Considerations

### Potential Enhancements

1. **Detailed Error Messages** (Low Priority)
   - Map specific error codes to different messages
   - Example: "Connection timeout - try again later" vs "Site doesn't support recipe imports"
   - Trade-off: More complexity vs slightly more helpful

2. **Fallback Cleanup** (Medium Priority)
   - Add 7-day max age for failed recipes regardless of fetch status
   - Handles edge case: user never opens app after import fails
   - Implementation: Add WHERE clause `OR created_at < 7.days.ago`

3. **Analytics** (Low Priority)
   - Track which domains fail most often
   - Helps prioritize adding support for popular sites
   - Implementation: Log domain on failure with counter

4. **User Reporting** (Low Priority)
   - "Report this site" button on error banners
   - Collects domains users want supported
   - Implementation: New endpoint to store domain requests

### Extensibility

**If we add more import sources later** (PDF, email, etc.):
- Error message pattern supports any source type
- Domain extraction can be generalized to "source identifier"
- Banner UI scales to different error types

**If we add localization later:**
- Error messages should move to i18n files
- Domain name remains dynamic (not translated)
- Example: `I18n.t('recipe_import.failed', domain: domain)`

## References & Research

### Internal References

**Backend Files:**
- `app/models/recipe.rb:3` - Enum definition
- `app/jobs/recipe_import_job.rb:17` - Current failure handling
- `app/controllers/api/v1/recipes_controller.rb:62-73` - List JSON response
- `db/migrate/20260127105314_add_import_status_to_recipes.rb` - Migration pattern

**iOS Files:**
- `hauptgang-ios/Hauptgang/Models/Recipe.swift:13` - RecipeListItem structure
- `hauptgang-ios/Hauptgang/Views/RecipesView.swift:54-60` - Error display pattern
- `hauptgang-ios/Hauptgang/Views/RecipeCardView.swift:137-158` - Failed overlay pattern
- `hauptgang-ios/Hauptgang/ViewModels/RecipeViewModel.swift:14` - Polling logic

### Design Documents

- [Brainstorm Document](../brainstorms/2026-01-30-failed-recipe-import-handling-brainstorm.md) - Full exploration of alternatives and decisions

### Key Patterns Used

- **Rails `after_action`**: Post-response cleanup without slowing down API
- **SwiftUI `@Observable`**: Reactive state management with computed properties
- **Time-based auto-delete**: Prevents race conditions from multiple devices
- **Error banners at top**: More prominent than inline card overlays
