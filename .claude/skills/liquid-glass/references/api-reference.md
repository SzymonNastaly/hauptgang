# Liquid Glass API Reference

Complete API documentation for iOS 26 Liquid Glass SwiftUI implementation.

## Table of Contents

- [Core API](#core-api)
- [Glass Variants](#glass-variants)
- [Button Styles](#button-styles)
- [Tinting](#tinting)
- [Shapes](#shapes)
- [GlassEffectContainer](#glasseffectcontainer)
- [Glass Effect Union](#glass-effect-union)
- [Morphing Transitions](#morphing-transitions)
- [Navigation Components](#navigation-components)
- [Toolbar Grouping](#toolbar-grouping)
- [Sheets and Modals](#sheets-and-modals)
- [Scroll Edge Effects](#scroll-edge-effects)
- [Background Extension](#background-extension)
- [Concentric Shapes](#concentric-shapes)
- [Accessibility](#accessibility)
- [Text and Icons](#text-and-icons)
- [Platform Differences](#platform-differences)
- [Opting Out](#opting-out)
- [References](#references)

## Core API

### Basic Glass Effect Signature

```swift
func glassEffect<S: Shape>(
    _ glass: Glass = .regular,
    in shape: S = DefaultGlassEffectShape,
    isEnabled: Bool = true
) -> some View
```

### Basic Usage Examples

```swift
// Simple glass button
Button("Action") { }
    .padding()
    .glassEffect()

// Glass with specific shape
Button("Action") { }
    .padding()
    .glassEffect(.regular, in: .capsule)

// Clear variant for media-heavy backgrounds
Button("Play") { }
    .padding()
    .glassEffect(.clear, in: .circle)
```

## Glass Variants

| Variant | Use Case | Transparency |
|---------|----------|--------------|
| `.regular` | Default UI elements (toolbars, controls) | Medium |
| `.clear` | Media-rich backgrounds | High |
| `.identity` | Conditional disable (accessibility) | None |

## Button Styles

### SwiftUI Button Styles (Preferred)

```swift
Button("Primary") { }
    .buttonStyle(.glass)

Button("Prominent") { }
    .buttonStyle(.glassProminent)

// With tint
Button("Tinted") { }
    .buttonStyle(.glass(.blue))
```

### UIKit Button Configurations

```swift
button.configuration = .glass()
button.configuration = .prominentGlass()
button.configuration = .clearGlass()
button.configuration = .prominentClearGlass()
```

## Tinting

Apply color tints sparingly (CTAs only):

```swift
// Solid tint
.glassEffect(.regular.tint(.blue))

// Semi-transparent tint
.glassEffect(.regular.tint(.purple.opacity(0.6)))

// Chained with interactive
.glassEffect(.regular.tint(.orange).interactive())
```

## Shapes

Available shape options:

```swift
.glassEffect(.regular, in: .capsule)       // Default
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
.glassEffect(.regular, in: .ellipse)
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))
```

## GlassEffectContainer

Combines multiple glass elements with shared sampling region and enables morphing transitions.

```swift
GlassEffectContainer {
    HStack(spacing: 20) {
        Button(action: {}) {
            Image(systemName: "pencil")
        }
        .frame(width: 44, height: 44)
        .glassEffect(.regular.interactive())

        Button(action: {}) {
            Image(systemName: "trash")
        }
        .frame(width: 44, height: 44)
        .glassEffect(.regular.interactive())
    }
}

// With spacing control (affects morphing threshold)
GlassEffectContainer(spacing: 40.0) {
    // content
}
```

**Important:** Glass cannot sample other glass. Containers provide unified sampling regions for multi-element compositions.

## Glass Effect Union

Combine multiple separate views into a single unified glass effect:

```swift
@Namespace private var namespace

GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        ForEach(items.indices, id: \.self) { index in
            Image(systemName: items[index])
                .frame(width: 80, height: 80)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectUnion(id: index < 2 ? "group1" : "group2", in: namespace)
        }
    }
}
```

This groups items 0-1 into one glass surface and items 2+ into another.

## Morphing Transitions

Create fluid animations between glass elements using `glassEffectID`:

```swift
struct MorphingToolbar: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 30) {
            Button(isExpanded ? "Collapse" : "Expand") {
                withAnimation(.bouncy) {
                    isExpanded.toggle()
                }
            }
            .padding()
            .glassEffect()
            .glassEffectID("toggle", in: namespace)

            if isExpanded {
                Button("Edit") { }
                    .padding()
                    .glassEffect()
                    .glassEffectID("edit", in: namespace)

                Button("Share") { }
                    .padding()
                    .glassEffect()
                    .glassEffectID("share", in: namespace)
            }
        }
    }
}
```

### Requirements for Morphing

1. Elements within same `GlassEffectContainer`
2. Each view tagged with `glassEffectID`
3. Conditional visibility triggering animation
4. Animation applied to state changes

## Navigation Components

Standard navigation automatically adopts Liquid Glass. Avoid custom backgrounds.

### NavigationStack

```swift
NavigationStack {
    List { /* content */ }
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { }
            }
        }
}
```

### TabView

```swift
// Basic tab bar with automatic glass
TabView {
    Tab("Home", systemImage: "house") { HomeView() }
    Tab("Search", systemImage: "magnifyingglass", role: .search) { SearchView() }
}

// Minimizable tab bar
TabView { /* tabs */ }
    .tabBarMinimizeBehavior(.onScrollDown)

// Sidebar adaptable
TabView { /* tabs */ }
    .tabViewStyle(.sidebarAdaptable)
```

## Toolbar Grouping

Separate toolbar items into logical groups using fixed spacers:

```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        Button("Undo", systemImage: "arrow.uturn.backward") { }
        Button("Redo", systemImage: "arrow.uturn.forward") { }

        ToolbarSpacer(.fixed) // Creates visual separation

        Button("Markup", systemImage: "pencil.tip") { }
        Button("More", systemImage: "ellipsis") { }
    }
}
```

## Sheets and Modals

Sheets automatically adopt Liquid Glass. Half sheets are inset:

```swift
.sheet(isPresented: $showSheet) {
    ContentView()
        .presentationDetents([.medium, .large])
    // Half sheets (.medium) are inset with glass background
    // Full height transitions to more opaque
}
```

## Scroll Edge Effects

Scroll edge effects help maintain legibility when content scrolls beneath glass controls.

### Scroll Edge Effect Style

```swift
// API signature
func scrollEdgeEffectStyle(
    _ style: ScrollEdgeEffectStyle?,
    for edges: Edge.Set
) -> some View

// Usage examples
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item)
        }
    }
}
.scrollEdgeEffectStyle(.hard, for: .all)

// Apply to specific edges
.scrollEdgeEffectStyle(.soft, for: .top)
.scrollEdgeEffectStyle(.hard, for: .bottom)
```

### ScrollEdgeEffectStyle Options

| Style | Description |
|-------|-------------|
| `.automatic` | System default behavior |
| `.soft` | Subtle gradient effect |
| `.hard` | More prominent edge treatment |

### Hiding Scroll Edge Effects

```swift
// Hide scroll edge effects entirely
ScrollView {
    // content
}
.scrollEdgeEffectHidden(true, for: .all)

// Hide for specific edges
.scrollEdgeEffectHidden(true, for: .top)
```

### Custom Safe Area Bars

Register custom views as bars that participate in scroll edge effects:

```swift
ScrollView {
    // content
}
.safeAreaBar(edge: .bottom, alignment: .center, spacing: 8) {
    HStack {
        Button("Action") { }
            .glassEffect()
    }
}
```

## Background Extension

Extend backgrounds under sidebars/inspectors:

```swift
NavigationSplitView {
    SidebarView()
} detail: {
    DetailView()
        .backgroundExtensionEffect() // Mirrors content under sidebar
}
```

### Extending Horizontal Scroll Under Sidebar

```swift
ScrollView(.horizontal) {
    LazyHStack {
        ForEach(items) { item in
            ItemCard(item)
        }
    }
}
.scrollExtensionMode(.underSidebar)
```

## Concentric Shapes

Align corner radii with containers:

```swift
// SwiftUI
RoundedRectangle(cornerRadius: .containerConcentric)

// Or using rect
.clipShape(.rect(corners: .all, isUniform: true))

// UIKit
view.cornerConfiguration = UICornerConfiguration(...)
```

## Accessibility

Glass effects automatically adapt to accessibility settings:

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    Button("Action") { }
        .padding()
        .glassEffect(reduceTransparency ? .identity : .regular)
}
```

### Automatic Adaptations

- **Reduce Transparency:** Increases frosting
- **Increase Contrast:** Stark colors/borders
- **Reduce Motion:** Tones down animations
- **Tinted Mode** (Settings > Display > Liquid Glass): User-controlled opacity

## Text and Icons

```swift
// Text on glass - automatically gets vibrant treatment
Text("Glass Label")
    .font(.headline)
    .foregroundStyle(.white)
    .padding()
    .glassEffect()

// Icon button
Button(action: {}) {
    Image(systemName: "heart.fill")
        .font(.title)
        .foregroundStyle(.white)
}
.frame(width: 60, height: 60)
.glassEffect(.regular.interactive())

// Label
Label("Settings", systemImage: "gear")
    .labelStyle(.iconOnly)
    .padding()
    .glassEffect()
```

## Platform Differences

| Platform | Support |
|----------|---------|
| **iOS/iPadOS** | Full glass effects with morphing |
| **macOS (Tahoe)** | NSGlassEffectView, NSToolbar glass |
| **watchOS** | Minimal changes, use standard toolbar APIs |
| **tvOS** | Glass on focus, requires focus APIs |

## Opting Out

To keep pre-Liquid Glass appearance while building with iOS 26 SDK:

```xml
<!-- Info.plist -->
<key>UIDesignRequiresCompatibility</key>
<true/>
```

## References

- [Apple: Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple Design Gallery](https://developer.apple.com/design/new-design-gallery/)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
