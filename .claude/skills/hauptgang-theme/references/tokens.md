# Hauptgang Design Tokens

Complete reference for all design tokens in light and dark mode.

## Table of Contents
- [Light Mode Colors](#light-mode-colors)
- [Dark Mode Colors](#dark-mode-colors)
- [Typography](#typography)
- [Shadows](#shadows)
- [Border Radius](#border-radius)
- [Tailwind Custom Properties](#tailwind-custom-properties)

---

## Light Mode Colors

### Brand Colors (from Tailwind config)
| Token | HEX | RGB | OKLCH | CSS Variable |
|-------|-----|-----|-------|--------------|
| Primary | `#8B5E34` | `rgb(139, 94, 52)` | `oklch(48.5% 0.078 56)` | `--color-brand-primary` |
| Primary Dark | `#6B4826` | `rgb(107, 72, 38)` | `oklch(37.5% 0.078 56)` | `--color-brand-primary-dark` |
| Primary Light | `#A57A52` | `rgb(165, 122, 82)` | `oklch(59.2% 0.071 56)` | `--color-brand-primary-light` |

### Surface Colors (from Tailwind config)
| Token | HEX | RGB | OKLCH | CSS Variable |
|-------|-----|-----|-------|--------------|
| Base (background) | `#FDFBF7` | `rgb(253, 251, 247)` | `oklch(99.2% 0.009 85)` | `--color-surface-base` |
| Raised | `#F5F2EA` | `rgb(245, 242, 234)` | `oklch(96.3% 0.013 85)` | `--color-surface-raised` |
| Overlay (card) | `#FFFFFF` | `rgb(255, 255, 255)` | `oklch(100% 0 0)` | `--color-surface-overlay` |

### Border Colors (from Tailwind config)
| Token | HEX | RGB | OKLCH | CSS Variable |
|-------|-----|-----|-------|--------------|
| Subtle | `#E5E0D5` | `rgb(229, 224, 213)` | `oklch(90.8% 0.014 85)` | `--color-border-subtle` |
| Medium | `#D5CABF` | `rgb(213, 202, 191)` | `oklch(83.5% 0.018 70)` | `--color-border-medium` |

### Text Colors (from Tailwind config)
| Token | HEX | RGB | OKLCH | CSS Variable |
|-------|-----|-----|-------|--------------|
| Primary | `#1F1F1F` | `rgb(31, 31, 31)` | `oklch(16.5% 0 0)` | `--color-text-primary` |
| Secondary | `#6B6B6B` | `rgb(107, 107, 107)` | `oklch(50.5% 0 0)` | `--color-text-secondary` |
| Tertiary | `#9B9B9B` | `rgb(155, 155, 155)` | `oklch(67.5% 0 0)` | `--color-text-tertiary` |

### Semantic Colors (deduced)
| Token | HEX | RGB | OKLCH | Notes |
|-------|-----|-----|-------|-------|
| Destructive | `#DC2626` | `rgb(220, 38, 38)` | `oklch(55.5% 0.226 27)` | red-600 |
| Destructive Foreground | `#FFFFFF` | `rgb(255, 255, 255)` | `oklch(100% 0 0)` | white |

---

## Dark Mode Colors

### Brand Colors (from view classes)
| Token | Tailwind | HEX | RGB | OKLCH |
|-------|----------|-----|-----|-------|
| Primary | `amber-700` | `#B45309` | `rgb(180, 83, 9)` | `oklch(50.5% 0.155 48)` |
| Primary Hover | `amber-800` | `#92400E` | `rgb(146, 64, 14)` | `oklch(44.5% 0.135 52)` |
| Accent/Links | `amber-500` | `#F59E0B` | `rgb(245, 158, 11)` | `oklch(79.5% 0.165 75)` |
| Focus Ring | `amber-600` | `#D97706` | `rgb(217, 119, 6)` | `oklch(63.5% 0.155 55)` |

### Surface Colors (from view classes)
| Token | Tailwind | HEX | RGB | OKLCH |
|-------|----------|-----|-----|-------|
| Background | `gray-950` | `#030712` | `rgb(3, 7, 18)` | `oklch(7.5% 0.023 264)` |
| Raised/Sidebar | `gray-900` | `#111827` | `rgb(17, 24, 39)` | `oklch(15.8% 0.023 264)` |
| Card/Overlay | `gray-800` | `#1F2937` | `rgb(31, 41, 55)` | `oklch(24.7% 0.020 264)` |

### Border Colors (from view classes)
| Token | Tailwind | HEX | RGB | OKLCH |
|-------|----------|-----|-----|-------|
| Subtle | `gray-700` | `#374151` | `rgb(55, 65, 81)` | `oklch(33.5% 0.018 264)` |
| Medium | `gray-800` | `#1F2937` | `rgb(31, 41, 55)` | `oklch(24.7% 0.020 264)` |

### Text Colors (from view classes)
| Token | Tailwind | HEX | RGB | OKLCH |
|-------|----------|-----|-----|-------|
| Primary | `gray-100` | `#F3F4F6` | `rgb(243, 244, 246)` | `oklch(96.7% 0.003 264)` |
| Secondary | `gray-400` | `#9CA3AF` | `rgb(156, 163, 175)` | `oklch(71.0% 0.014 264)` |
| Tertiary | `gray-500` | `#6B7280` | `rgb(107, 114, 128)` | `oklch(53.5% 0.014 264)` |

### Semantic Colors (from view classes)
| Token | Tailwind | HEX | RGB | OKLCH |
|-------|----------|-----|-----|-------|
| Destructive BG | `red-900/20` | `rgba(127,29,29,0.2)` | - | - |
| Destructive Border | `red-800` | `#991B1B` | `rgb(153, 27, 27)` | `oklch(40.5% 0.165 27)` |
| Destructive Text | `red-200` | `#FECACA` | `rgb(254, 202, 202)` | `oklch(88.5% 0.048 17)` |

---

## Typography

### Font Families (from Tailwind config)
| Token | Value | CSS Variable |
|-------|-------|--------------|
| Sans (body) | `"Lato", ui-sans-serif, system-ui, sans-serif` | `--font-sans` |
| Serif (headings) | `"Merriweather", ui-serif, Georgia, serif` | `--font-serif` |

### Available Weights
| Font | Weights |
|------|---------|
| Lato | 300 (Light), 400 (Regular), 700 (Bold) |
| Merriweather | 400 (Regular), 700 (Bold) |

### Font Files
Located in `app/assets/fonts/`:
- Lato: Regular, Italic, Bold, BoldItalic, Light, LightItalic
- Merriweather: Regular, Italic, Bold, BoldItalic (24pt variant)

---

## Shadows

### Tailwind Defaults (most used in codebase)
| Class | Value | Usage Count |
|-------|-------|-------------|
| `shadow-sm` | `0 1px 2px 0 rgb(0 0 0 / 0.05)` | 10 |
| `shadow-lg` | `0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)` | 5 |
| `shadow-md` | `0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)` | 1 |

---

## Border Radius

### Tailwind Defaults (usage in codebase)
| Class | Value | Usage Count |
|-------|-------|-------------|
| `rounded-lg` | `0.5rem` (8px) | 14 |
| `rounded-full` | `9999px` | 13 |
| `rounded-md` | `0.375rem` (6px) | 10 |
| `rounded-sm` | `0.125rem` (2px) | 6 |
| `rounded-xl` | `0.75rem` (12px) | 4 |

## Tailwind Custom Properties

Defined in `app/assets/tailwind/application.css`:

```css
@theme {
  /* Font Families */
  --font-sans: "Lato", ui-sans-serif, system-ui, sans-serif;
  --font-serif: "Merriweather", ui-serif, Georgia, serif;

  /* Brand Colors */
  --color-brand-primary: #8B5E34;
  --color-brand-primary-dark: #6B4826;
  --color-brand-primary-light: #A57A52;

  /* Surface/Background Colors */
  --color-surface-base: #FDFBF7;
  --color-surface-raised: #F5F2EA;
  --color-surface-overlay: #FFFFFF;

  /* Border Colors */
  --color-border-subtle: #E5E0D5;
  --color-border-medium: #D5CABF;

  /* Text Colors */
  --color-text-primary: #1F1F1F;
  --color-text-secondary: #6B6B6B;
  --color-text-tertiary: #9B9B9B;
}
```
