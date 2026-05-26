---
name: swiftui
description: SwiftUI development expert. Use when user asks about building, modifying, or troubleshooting SwiftUI views, layouts, state management, toolbars, navigation, or animations in iOS applications. Fully integrated with iOS 26 Liquid Glass design paradigms.
---

# SwiftUI Development Guide

This skill provides comprehensive guidelines and best practices for building modern, responsive, and accessible user interfaces with SwiftUI, targeting iOS 14 through iOS 26.

## SwiftUI Layout & View Hierarchy

1. **Hierarchy Strategy**: Keep view declarations clean by extracting subviews into dedicated structural components or computed properties.
2. **State Management**:
   - Use `@State` only for private, view-local state.
   - Use `@Binding` to pass read-write access down to child views.
   - Use `@StateObject` (iOS 14+) or `@Observable` (iOS 17+) for managing reference-type data sources.
3. **GeometryReader**: Use sparingly; rely on flexible layout containers (`HStack`, `VStack`, `ZStack`, `LazyVGrid`, `LazyHGrid`) and frame modifiers before using explicit geometries.

---

## SwiftUI Toolbars

Apple SwiftUI Toolbars (`.toolbar`) are the primary container for navigation-related and context-driven action items.

### 1. Basic Structure and Placements
Items are added using the `.toolbar(content:)` modifier on the view contained within a `NavigationStack`.
```swift
NavigationStack {
    List(items) { item in
        Text(item.name)
    }
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { /* Action */ }
        }
    }
}
```

Key placements (`ToolbarItemPlacement`):
- `.navigationBarLeading` / `.topBarLeading`: Secondary actions on the leading edge.
- `.navigationBarTrailing` / `.topBarTrailing`: Primary action or utility menus.
- `.principal`: Center of the navigation bar (e.g., custom title or segmented picker).
- `.bottomBar`: Bottom navigation or action area (ideal for toolgroups).
- `.keyboard`: Accessory toolbar floating above the keyboard.

### 2. Grouping and Spacing
Use `ToolbarItemGroup` to group multiple related items on the same side or bar:
```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        Button(action: share) { Image(systemName: "square.and.arrow.up") }
        ToolbarSpacer(.flexible) // Dynamic spacing
        Button(action: delete) { Image(systemName: "trash") }
    }
}
```

### 3. Customizable Toolbars (iOS 16+)
Allow users to personalize their workspace with customizable toolbars by specifying a stable identifier:
```swift
.toolbar(id: "editor-actions") {
    ToolbarItem(id: "markup", placement: .secondaryAction, allowsUserCustomization: true) {
        Toggle("Markup", isOn: $isMarkupEnabled)
    }
}
```

### 4. Search and Behavior (iOS 17+)
Search fields can be tightly integrated with the toolbar layout:
```swift
.searchable(text: $searchText)
.searchToolbarBehavior(.automatic)
```

---

## SwiftUI Navigation Bars

Navigation Bars display page headers and navigation actions, working in tandem with `NavigationStack` or `NavigationSplitView`.

### 1. Title and Customization
Configure navigation titles using `.navigationTitle(_:)` and configure the title display mode:
```swift
NavigationStack {
    ContentView()
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.inline) // Or .large
}
```

### 2. Glass and Background Customization
In iOS 26, Navigation Bars automatically adopt the Liquid Glass material. You can explicitly set or customize it using the `.toolbarBackground` modifier:
```swift
ContentView()
    .toolbarBackground(.glass, for: .navigationBar) // Explicit Liquid Glass styling
```
You can control the visibility of the navigation bar background:
```swift
ContentView()
    .toolbarBackground(.hidden, for: .navigationBar) // Hide standard background
```

### 3. Hiding the Navigation Bar
To hide the navigation bar completely:
```swift
ContentView()
    .navigationBarHidden(true)
```

### 4. Scale Application Custom Navigation Paradigm
In the Scale application, standard navigation bars are hidden to support fully customized, modern layouts:
```swift
// Hide default system navigation bars inside child views
ContentView()
    .toolbar(.hidden, for: .navigationBar)
```
Instead of standard navigation bars, Scale uses a **Custom Accessory Header** (e.g., `topAccessoryRow` in `RootView`) and custom floating toolbars styled with Liquid Glass modifiers:
```swift
// Custom floating bottom toolbar using Liquid Glass container
.safeAreaInset(edge: .bottom) {
    GlassEffectContainer(spacing: 40) {
        HStack(spacing: 10) {
            tabPill
            Spacer()
            logButton
        }
    }
}
```

---

## Modern iOS Design & Liquid Glass

In modern iOS versions (iOS 26+), toolbars, tab bars, and interactive navigation elements transition to **Liquid Glass** treatment. 

> [!IMPORTANT]
> When designing navigation layers, floating action groups, or advanced toolbars on iOS 26, you MUST consult and apply the **Liquid Glass** design system.
> Refer to the detailed **Liquid Glass Skill** at [liquid-glass/SKILL.md](file:///Users/jonathangroberg/repos/Scale/Skills/liquid-glass/SKILL.md) for API usage, morphing animations, and HIG compliance rules.

### Basic Liquid Glass Bridge
```swift
// Upgrade standard buttons in toolbars or control panels to use liquid glass effects
Button("Create", systemImage: "plus") {
    // Action
}
.buttonStyle(.glass) // Renders with smooth liquid glass background
```

For grouping tool actions with liquid morphing, wrap your control layout in a container:
```swift
GlassEffectContainer {
    HStack {
        Button("Undo", systemImage: "arrow.uturn.backward") { }
        Button("Redo", systemImage: "arrow.uturn.forward") { }
    }
}
```

---

## Reference Resources
- [Apple Developer Documentation: SwiftUI Toolbars](https://developer.apple.com/documentation/SwiftUI/Toolbars)
- [Apple Developer Documentation: View/toolbar(content:)](https://developer.apple.com/documentation/swiftui/view/toolbar(content:))
- [Liquid Glass Skill Specification](file:///Users/jonathangroberg/repos/Scale/Skills/liquid-glass/SKILL.md)
