---
name: liquid-glass
description: iOS 26 Liquid Glass SwiftUI reference for implementing Apple's dynamic material system. Use when building iOS 26+ UI with glass effects, morphing transitions, navigation bars, toolbars, or sheets. Triggers on requests mentioning "liquid glass," "glass effect," "iOS 26 design," "glassEffect modifier," or modernizing iOS UI to the new design language.
---

# iOS 26 Liquid Glass SwiftUI Reference

Reference for implementing Liquid Glass effects in SwiftUI for iOS 26+.

## What is Liquid Glass?

Apple's dynamic material system (WWDC 2025) featuring real-time light bending, specular highlights, adaptive shadows, and interactive behaviors.

**Key Principle:** Liquid Glass is EXCLUSIVELY for the navigation layer floating above content. Never apply to content itself (lists, tables, media).

## Quick Start

```swift
// Simple glass button
Button("Action") { }
    .padding()
    .glassEffect()

// With shape
Button("Action") { }
    .padding()
    .glassEffect(.regular, in: .capsule)

// Interactive (touch feedback)
Button("Tap") { }
    .glassEffect(.regular.interactive())

// Button styles (preferred for buttons)
Button("Primary") { }
    .buttonStyle(.glass)

Button("Prominent") { }
    .buttonStyle(.glassProminent)
```

## Availability Gate (Required)

Always provide fallback UI for earlier iOS versions:

```swift
if #available(iOS 26, *) {
    content.glassEffect(.regular, in: .rect(cornerRadius: 16))
} else {
    content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

Reusable pattern:

```swift
extension View {
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
```

## Glass Variants

| Variant | Use Case |
|---------|----------|
| `.regular` | Default UI elements (toolbars, controls) |
| `.clear` | Media-rich backgrounds (higher transparency) |
| `.identity` | Conditional disable (accessibility) |

## GlassEffectContainer (Multiple Elements)

Wrap multiple glass elements for unified sampling and morphing:

```swift
GlassEffectContainer {
    HStack(spacing: 20) {
        Button(action: {}) { Image(systemName: "pencil") }
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())

        Button(action: {}) { Image(systemName: "trash") }
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())
    }
}
```

**Rule:** Glass cannot sample other glass. Always use containers for multi-element compositions.

## Morphing Transitions

Use `glassEffectID` with `@Namespace` for fluid animations:

```swift
@Namespace private var namespace

GlassEffectContainer(spacing: 30) {
    Button(isExpanded ? "Collapse" : "Expand") {
        withAnimation(.bouncy) { isExpanded.toggle() }
    }
    .padding()
    .glassEffect()
    .glassEffectID("toggle", in: namespace)

    if isExpanded {
        Button("Edit") { }
            .padding()
            .glassEffect()
            .glassEffectID("edit", in: namespace)
    }
}
```

## Modifier Order

Apply `glassEffect()` LAST, after all layout/appearance modifiers:

```swift
Text("Label")
    .font(.headline)           // 1. Typography
    .foregroundStyle(.white)   // 2. Color
    .padding()                 // 3. Layout
    .frame(width: 100)         // 4. Size
    .glassEffect()             // 5. Glass effect LAST
```

## Best Practices

**DO:**
- Use standard SwiftUI components (automatic glass adoption)
- Apply glass to navigation/control layer only
- Use `GlassEffectContainer` for multiple glass elements
- Gate with `#available(iOS 26, *)` with fallback UI
- Use `.interactive()` for touch-responsive controls
- Test with Reduce Transparency and Reduce Motion settings

**DON'T:**
- Apply glass to content (lists, tables, media, images)
- Layer glass on top of other glass
- Use custom backgrounds on navigation bars/toolbars
- Apply tints for decoration (only for meaningful CTAs)
- Apply `glassEffect()` before layout modifiers

## Review Checklist

- [ ] `#available(iOS 26, *)` with fallback UI
- [ ] Multiple glass views in `GlassEffectContainer`
- [ ] `glassEffect` after layout/appearance modifiers
- [ ] `.interactive()` only where interaction exists
- [ ] `glassEffectID` with `@Namespace` for morphing
- [ ] Works with Reduce Transparency/Motion

## Detailed Reference

For complete API documentation including:
- All modifier signatures and options
- Tinting and shapes
- Navigation components (TabView, toolbars, sheets)
- Scroll edge effects
- Accessibility adaptations
- Platform differences

See [references/api-reference.md](references/api-reference.md)
