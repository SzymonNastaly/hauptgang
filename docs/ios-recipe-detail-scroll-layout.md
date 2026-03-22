# iOS recipe detail: scroll width and hero image

## Problem

On the recipe detail screen (`RecipeDetailView`), ingredients and steps could appear shifted or clipped horizontally. The scroll view’s content was sometimes **wider than the screen**.

## Cause

The hero used `CachedRecipeImage` / `Image` from a decoded **`UIImage`**. Even with `.resizable()` and `.aspectRatio(contentMode: .fill)`, that subtree could still contribute a **very large layout width** (linked to pixel dimensions). A vertical `ScrollView` sizes its document from its children, so an oversized hero **widened the entire scroll content**.

Recipe data (e.g. servings-only metadata) was unrelated; large or high-resolution cover images made the issue more likely.

## Fix (in `RecipeDetailView`)

1. **Hero** — Same approach as `RecipeCardView`: a **`Color.clear`** view gets an explicit `frame(height:)` and `frame(maxWidth: .infinity)`. The image is drawn in **`.background { … }`** and **`.clipped()`**. The clear layer defines geometry; the image fills that rect visually without driving stack width from intrinsic image size.

2. **Scroll root** — The outer `VStack` inside the `ScrollView` uses **`.frame(maxWidth: .infinity)`** so the column tracks the viewport width the scroll view proposes.

3. **Ingredients and steps** — `Text` in `HStack` rows uses **`.frame(maxWidth: .infinity, alignment: .leading)`** (and leading multiline alignment) so very long unbroken strings wrap instead of stretching row width.

## Reference

Introduced in commit `5eb1a89` (*Fix recipe detail horizontal layout with hero image sizing*).
