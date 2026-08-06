# Cross-Platform Development

- SpriteKit APIs are available in the visionOS SDK, but Apple advises against using SpriteKit in apps created specifically for visionOS. Prefer RealityKit or SwiftUI for native visionOS experiences; do not describe SpriteKit as unavailable or limited to compatibility mode.
- On watchOS, display SpriteKit content using `WKInterfaceSKScene` — there is no `SKView` on watchOS.
- Use `#if os(iOS)`, `#if os(macOS)`, `#if os(tvOS)`, `#if os(watchOS)`, and `#if os(visionOS)` when APIs differ at compile time. Use runtime traits or idiom checks for behavior differences within a shared platform build.
- Abstract input behind a shared protocol when the game targets multiple input models; a single-platform game does not need this layer by default.
- On tvOS, support focus, remote presses, or `GCController` input as appropriate to the interaction; do not assume touch events exist.
- Preserve the expected system behavior of the tvOS Menu/Back control. Intercept it only for a documented navigation or pause behavior, not merely to prevent leaving the app.
- On macOS, hide the cursor on scene entry (`NSCursor.hide()`) and restore it in `willMove(from:)` for action games where the cursor is not needed.
- Position iOS HUD elements using `view.safeAreaInsets` — `SKScene` has no built-in safe area property; pass insets via a custom property on your scene subclass and update it in `viewSafeAreaInsetsDidChange()`.
- Simulator supports Metal. Query required capabilities and condition only unsupported features; use `#if targetEnvironment(simulator)` for APIs such as motion sensors that genuinely need a simulator fallback. Validate rendering performance on hardware.

## Platform Detection

```swift
#if os(iOS)
    // Touch, safe area, UIDevice orientation
#elseif os(macOS)
    // Mouse, keyboard, NSCursor
#elseif os(tvOS)
    // Focus, remote presses, or GCController, according to the interaction
#elseif os(watchOS)
    // WKInterfaceSKScene and watch-specific interaction
#elseif os(visionOS)
    // SpriteKit symbols are available, but prefer RealityKit or SwiftUI for
    // an experience created specifically for visionOS.
#endif
```

## tvOS — Optional Menu/Back Handling

```swift
#if os(tvOS)
private var menuRecognizer: UITapGestureRecognizer?

override func didMove(to view: SKView) {
    super.didMove(to: view)
    guard menuRecognizer == nil else { return }

    let menu = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
    menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
    view.addGestureRecognizer(menu)
    menuRecognizer = menu
}

override func willMove(from view: SKView) {
    if let menuRecognizer {
        view.removeGestureRecognizer(menuRecognizer)
        self.menuRecognizer = nil
    }
    super.willMove(from: view)
}

@objc private func menuPressed() {
    if isPaused {
        navigateBack()
    } else {
        isPaused = true
    }
}
#endif
```

Only install this recognizer when pausing is part of the app's navigation design. The example uses the first press to pause and a subsequent press to navigate back; adapt `navigateBack()` to the app's navigation owner so the control still exits according to platform conventions.

## iOS — Safe Area

`SKScene` has no `safeAreaInsets` property. Pass insets via a custom property, updated from `viewSafeAreaInsetsDidChange()`.

```swift
class GameScene: SKScene {
    var safeAreaInsets: UIEdgeInsets = .zero
}

class GameViewController: UIViewController {
    var gameScene: GameScene?

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        gameScene?.safeAreaInsets = view.safeAreaInsets
    }
}
```

## macOS — Cursor Management

```swift
#if os(macOS)
class GameScene: SKScene {
    override func didMove(to view: SKView) { NSCursor.hide() }
    override func willMove(from view: SKView) { NSCursor.unhide() }
}
#endif
```

## visionOS — Follow Native Platform Guidance

```swift
// SpriteView is available in the SDK, but do not choose this architecture for
// an app or experience created specifically for visionOS.
// SpriteView(scene: GameScene())

// Preferred for a native visionOS experience.
import RealityKit
struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "GameScene", in: realityKitContentBundle) {
                content.add(scene)
            }
        }
    }
}
```
