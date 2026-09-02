# NSTouchBar in a SwiftUI macOS App

This reference records the working integration pattern used by Adel Intelligence and the reasons behind it. Touch Bar is an AppKit API, so the implementation has three boundaries: SwiftUI state, an AppKit delegate, and the `NSWindow` that owns the bar.

## 1. Bridge from SwiftUI to the window

SwiftUI views do not own an `NSWindow` value. Embed a transparent `NSViewRepresentable` near the root view and report its `window` asynchronously:

```swift
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            callback(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            callback(nsView?.window)
        }
    }
}
```

The callback can run more than once. Reconfigure the existing window safely rather than assuming `makeNSView` is a one-time lifecycle event. Keep the accessor’s callback lightweight.

## 2. Define stable identifiers

Use reverse-DNS identifiers owned by the app. These are persistence/API identifiers, not display strings:

```swift
extension NSTouchBarItem.Identifier {
    static let newChat = Self("com.example.app.new-chat")
    static let toggleSidebar = Self("com.example.app.toggle-sidebar")
}
```

Every identifier in `defaultItemIdentifiers` must be handled by `touchBar(_:makeItemForIdentifier:)`, unless it is a system item that AppKit knows how to create. Keep flexible-space identifiers explicit when layout spacing matters.

## 3. Implement the delegate

An AppKit delegate is the most reliable way to create custom SwiftUI-app controls:

```swift
@MainActor
final class TouchBarDelegate: NSObject, NSTouchBarDelegate {
    var newChatAction: (() -> Void)?

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == .newChat else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "",
            target: self,
            action: #selector(newChatPressed)
        )
        button.image = NSImage(
            systemSymbolName: "square.and.pencil",
            accessibilityDescription: "New Chat"
        )
        item.view = button
        return item
    }

    @objc private func newChatPressed() {
        newChatAction?()
    }
}
```

The selector must be exposed to Objective-C with `@objc`. Use one selector per action or a carefully scoped selector dispatch; do not depend on SwiftUI environment lookup from the delegate.

For text controls, a titled button is often more discoverable than an icon-only control. For icon-only buttons, set both the image accessibility description and any appropriate item/view accessibility metadata.

## 4. Configure and retain the bar

The root SwiftUI view should retain the delegate and configure it after the window accessor resolves:

```swift
@State private var touchBarDelegate = TouchBarDelegate()

var body: some View {
    ContentView()
        .background(WindowAccessor { window in
            let touchBar = NSTouchBar()
            touchBar.delegate = touchBarDelegate
            touchBar.defaultItemIdentifiers = [
                .toggleSidebar,
                .newChat,
                .flexibleSpace
            ]
            touchBarDelegate.newChatAction = {
                chatViewModel.create(model: Defaults[.defaultModel])
            }
            window?.touchBar = touchBar
        })
}
```

The actual project uses separate left/right flexible-space items and closure properties for each action. That makes the intended visual order obvious and keeps model/environment access in `AppView` rather than in the delegate.

Because the accessor updates asynchronously, the closure may be called while app state is changing. Guard optional windows and avoid inserting duplicate model data from setup callbacks.

## 5. Connect state and focus

Use an observable object for behavior that needs to cross the AppKit/SwiftUI boundary:

```swift
@Observable
final class FocusManager {
    var shouldFocusTextField = false
    var shouldToggleInspector = false
}
```

The Touch Bar action toggles a state value; the focused SwiftUI control observes that value and performs focus. This keeps the delegate independent from the view hierarchy. For visibility changes, mutate `window.touchBar?.defaultItemIdentifiers` in response to an observed state change. Clearing the identifiers removes the app’s default Touch Bar items while the field is focused; restoring the array brings them back.

Do not use `NSApplication.shared.windows.first` as a general window-selection strategy in a multi-window app. Store or resolve the specific window that owns the bar, otherwise focus changes in one window can mutate another window’s Touch Bar.

## 6. Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Nothing appears | `window.touchBar` was never assigned, or setup ran before the view had a window | Use `WindowAccessor`; assign after attachment; verify the scene/window is the one being displayed. |
| Buttons appear but do nothing | Selector is not `@objc`, target is not retained, or the closure is nil | Use `@objc` selectors, retain the delegate in SwiftUI state, and assign action closures during setup. |
| An item is blank | Its identifier is listed but not handled by the delegate | Add a switch case and return an item, or remove the identifier. |
| Controls duplicate or stale state appears | Setup assumes the accessor runs once | Make setup idempotent and update the existing bar’s identifiers instead of creating model objects in every callback. |
| Focus action cannot find the text field | AppKit delegate is trying to reach SwiftUI directly | Toggle shared observable focus state and let the SwiftUI field react. |
| Other Macs regress | Code assumes Touch Bar hardware | Keep the feature optional and preserve menu, toolbar, keyboard, and accessibility paths. |

## 7. Testing limits

Touch Bar behavior is hardware-dependent and is not covered by ordinary SwiftUI previews. A successful Xcode build validates API integration only. Manual testing must include a physical Touch Bar Mac when available; if it is unavailable, validate the delegate’s identifier coverage, selector wiring, and no-hardware app behavior through code review and build checks, and record hardware validation as pending.
