---
name: hauptgang-theme
description: Design system tokens for the Hauptgang app. Use when styling UI components, creating new screens, or needing color/typography/spacing values. Provides light mode and dark mode tokens including colors, fonts, shadows, and border radius.
---

# Hauptgang Design System

Single source of truth for styling UI in the Hauptgang app.

## Quick Reference

### Brand Colors
- **Primary**: `#8B5E34` (warm brown) → dark: `amber-700` (`#B45309`)
- **Primary Light**: `#A57A52` → dark: `amber-500` (`#F59E0B`)
- **Primary Dark**: `#6B4826` → dark: `amber-800` (`#92400E`)

### Typography
- **Sans (body)**: `"Lato", ui-sans-serif, system-ui, sans-serif`
- **Serif (headings)**: `"Merriweather", ui-serif, Georgia, serif`

### Core Surfaces
| Token | Light | Dark |
|-------|-------|------|
| Background | `#FDFBF7` | `gray-950` (`#030712`) |
| Card/Overlay | `#FFFFFF` | `gray-800` (`#1F2937`) |
| Raised/Sidebar | `#F5F2EA` | `gray-900` (`#111827`) |

### Borders & Radius
- **Border subtle**: `#E5E0D5` → dark: `gray-700` (`#374151`)
- **Border medium**: `#D5CABF` → dark: `gray-800` (`#1F2937`)
- **Radius**: `rounded-md` (0.375rem) most common, `rounded-lg` for cards

### Shadows
Use `shadow-sm` (most common), `shadow-lg` for elevated elements.

## Usage Patterns

### Tailwind Classes (Rails app)
```erb
<!-- Light/dark adaptive button -->
<button class="bg-brand-primary dark:bg-amber-700 hover:bg-brand-primary-dark dark:hover:bg-amber-800 text-white">

<!-- Card -->
<div class="bg-surface-overlay dark:bg-gray-800 border border-border-subtle dark:border-gray-700 rounded-lg shadow-sm">

<!-- Text hierarchy -->
<h1 class="text-text-primary dark:text-gray-100 font-serif">
<p class="text-text-secondary dark:text-gray-400">
<span class="text-text-tertiary dark:text-gray-500">
```

### Focus States
```erb
focus:border-brand-primary dark:focus:border-amber-600 focus:ring-1 focus:ring-brand-primary dark:focus:ring-amber-600
```

## Complete Token Reference

For full token list with all values in HEX, RGB, and OKLCH formats, plus Tailwind custom properties, see [references/tokens.md](references/tokens.md).
