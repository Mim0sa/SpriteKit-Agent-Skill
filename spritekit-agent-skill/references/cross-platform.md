# Cross-Platform Development

- Never use SpriteKit in a native visionOS app — it is only supported in iPad/iPhone compatibility mode on visionOS. Use RealityKit for native visionOS targets.
- On watchOS, display SpriteKit content using `WKInterfaceSKScene` (available watchOS 3.0+) — there is no `SKView` on watchOS.
- Use `#if os(iOS)`, `#if os(macOS)`, `#if os(tvOS)` for all platform-specific branches. Never use `UIDevice.current.userInterfaceIdiom` for compile-time platform differences.
- Abstract all input handling behind a shared protocol so game logic contains no platform conditionals (see `input-handling.md`).
- On tvOS, never use touch-based interaction — all navigation must go through the focus engine or a `GCController`.
- Handle the tvOS Siri Remote menu button explicitly via `UITapGestureRecognizer` with `allowedPressTypes = [.menu]` — unhandled menu presses cause the app to exit.
- On macOS, hide the cursor on scene entry (`NSCursor.hide()`) and restore it in `willMove(from:)` without exception.
- Position iOS HUD elements using `view.safeAreaInsets` — never use hardcoded offsets that break on notch/Dynamic Island devices.
- Use `#if targetEnvironment(simulator)` to disable Metal shaders, accelerometer, and other features that fail in the simulator.

## Platform Detection

```swift
#if os(iOS)
    // Touch, safe area, UIDevice orientation
#elseif os(macOS)
    // Mouse, keyboard, NSCursor
#elseif os(tvOS)
    // Focus engine, Siri Remote, GCController required
#elseif os(visionOS)
    // ⚠️ Compatibility mode only — native visionOS must use RealityKit
#endif
```

## tvOS — Menu Button

```swift
#if os(tvOS)
override func didMove(to view: SKView) {
    let menu = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
    menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
    view.addGestureRecognizer(menu)
}
@objc func menuPressed() { togglePause() }
#endif
```

## iOS — Safe Area

```swift
#if os(iOS)
class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = view as! SKView
        let scene = GameScene(size: view.bounds.size)
        scene.safeAreaInsets = view.safeAreaInsets
        skView.presentScene(scene)
    }
}
#endif
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

## visionOS — Use RealityKit Instead

```swift
// ❌ Wrong: SpriteKit in a native visionOS app
SpriteView(scene: GameScene())  // Not supported

// ✅ Correct: RealityKit for native visionOS
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
