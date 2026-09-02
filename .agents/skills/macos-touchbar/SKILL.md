---
name: macos-touchbar
description: "Build, review, and debug NSTouchBar support in native SwiftUI macOS apps by bridging AppKit delegates, window attachment, action routing, and state-driven visibility."
---

# macOS Touch Bar

Use this skill when a native macOS SwiftUI app needs Touch Bar controls or when existing Touch Bar support is not appearing, responding, or staying synchronized with app state. Read [references/implementation.md](references/implementation.md) for the detailed pattern and project-specific lessons.

## Core workflow

1. Locate the `NSWindow` that owns the SwiftUI scene. SwiftUI does not expose a reliable `NSWindow` binding directly; use a small `NSViewRepresentable` window accessor and schedule the callback on the main queue after the view is attached.
2. Create an `NSObject` conforming to `NSTouchBarDelegate`. Keep stable `NSTouchBarItem.Identifier` values in one namespace, and return one item for every identifier placed in `defaultItemIdentifiers`.
3. Build custom items with `NSCustomTouchBarItem` and an `NSButton`. Give icon-only controls an `accessibilityDescription`; use SF Symbols where possible.
4. Route button selectors through closures owned by the SwiftUI layer. The delegate should describe/control AppKit items, while the view owns app behavior such as creating chats, toggling split-view state, and focusing fields.
5. Retain the delegate for as long as the window uses the bar. In SwiftUI, `@State` is appropriate for the delegate reference; assigning a temporary local delegate risks callbacks after deallocation.
6. Attach the configured bar with `window.touchBar = touchBar` and make setup idempotent because a representable’s `updateNSView` can run repeatedly.
7. Update `defaultItemIdentifiers` from observable SwiftUI state when the UI should change. For example, hide navigation controls while the message field is focused and restore them when focus ends.

## Review rules

- Keep all AppKit and window mutations on the main actor.
- Do not put business logic in `NSTouchBarDelegate`; route to view models or shared observable state.
- Do not rely on `focusTextFieldGroup` or other identifiers that are never returned by the delegate; unused identifiers create misleading maintenance paths.
- Prefer a real `NSButton` target/action pair over trying to make a SwiftUI `Button` the Touch Bar item view.
- Avoid assuming every Mac has a Touch Bar. The build must work without hardware, and manual verification must be done on a Touch Bar Mac or a suitable test environment.
- Treat Touch Bar behavior as progressive enhancement: keyboard shortcuts and ordinary toolbar/menu actions remain the primary accessible path.

## Validation

After changes, build the macOS target, then manually verify the bar on a Touch Bar Mac:

- the bar appears after the window is fully created;
- every visible item has the intended icon/title and accessibility label;
- each selector invokes the expected app action exactly once;
- focus-driven visibility updates when focus changes;
- reopening windows does not lose the delegate or duplicate controls;
- the app remains usable on a Mac without a Touch Bar.
