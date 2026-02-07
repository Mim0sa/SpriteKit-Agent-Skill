# Cross-Platform Development

iOS/macOS/tvOS adaptation best practices.

> **⚠️ visionOS Important Notice**
> SpriteKit is **not recommended for native visionOS apps**. It should only be used in compatible iPhone or iPad apps running on visionOS. For native visionOS development, use RealityKit instead.
>
> **Supported Platforms:**
> - ✅ iOS (iPhone/iPad)
> - ✅ macOS
> - ✅ tvOS
> - ⚠️ visionOS (Compatible iPhone/iPad apps only)

---

## Platform Detection

### Conditional Compilation

```swift
#if os(iOS)
    // iPhone/iPad specific
    let platform = "iOS"
#elseif os(macOS)
    // Mac specific
    let platform = "macOS"
#elseif os(tvOS)
    // Apple TV specific
    let platform = "tvOS"
#elseif os(visionOS)
    // ⚠️ Warning: SpriteKit is not recommended for native visionOS apps
    // Only use for compatible iPhone/iPad apps running on visionOS
    let platform = "visionOS"
#endif
```

### Target Conditionals

```swift
#if targetEnvironment(macCatalyst)
    // Running on Mac Catalyst
#endif

#if targetEnvironment(simulator)
    // Running in simulator
#endif
```

---

## Screen Size Adaptation

### Device-Specific Layouts

```swift
class GameScene: SKScene {
    func setupLayout() {
        let screenSize = UIScreen.main.bounds.size
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isTV = UIDevice.current.userInterfaceIdiom == .tv

        if isTV {
            // TV: Larger UI, focus-based navigation
            setupTVLayout()
        } else if isPad {
            // iPad: Full feature set
            setupPadLayout()
        } else {
            // iPhone: Compact layout
            setupPhoneLayout()
        }
    }
}
```

### Safe Areas

```swift
#if os(iOS)
import UIKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = view as! SKView
        let scene = GameScene(size: view.bounds.size)

        // Respect safe areas (notch, home indicator)
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        scene.safeArea = safeFrame
    }
}
#endif
```

---

## visionOS Limitations

### What Works (Compatible Mode)

When running an iPhone or iPad app on visionOS:
- SpriteKit renders in a compatibility window
- Touch-based interactions work
- Standard 2D gameplay functions normally

```swift
#if os(visionOS)
// This code only runs in compatibility mode
// It's an iPhone/iPad app running on visionOS
class CompatibilityModeScene: SKScene {
    // Standard SpriteKit code works normally
}
#endif
```

### What Does NOT Work

Native visionOS apps should NOT use:
- `SKView` / `SpriteView` in immersive spaces
- `WKInterfaceSKScene` (watchOS only anyway)
- SpriteKit particle systems in 3D space

### Recommended Alternatives

For native visionOS game development:

```swift
// ❌ Don't do this in native visionOS app
import SpriteKit
let scene = SKScene()

// ✅ Use RealityKit instead
import RealityKit
import RealityKitContent

// Create 2D-style game in 3D space using RealityKit
struct ImmersiveGame: View {
    var body: some View {
        RealityView { content in
            // Load RealityKit content
            if let scene = try? await Entity(named: "GameScene") {
                content.add(scene)
            }
        }
    }
}
```

---

## Platform-Specific Features

### tvOS Focus Engine

```swift
#if os(tvOS)
class TVGameScene: SKScene {

    override func didMove(to view: SKView) {
        // Enable focus-based navigation
        setupFocusNavigation()
    }

    func setupFocusNavigation() {
        // Menu button handling
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
        tapRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view?.addGestureRecognizer(tapRecognizer)
    }

    @objc func menuPressed() {
        // Handle menu button
    }
}
#endif
```

### macOS Cursor

```swift
#if os(macOS)
import AppKit

class MacGameScene: SKScene {

    func hideCursor() {
        NSCursor.hide()
    }

    func showCursor() {
        NSCursor.unhide()
    }

    func setCursorAppearance() {
        NSCursor.crosshair.set()
    }
}
#endif
```

---

## Input Adaptation

### Unified Input Handler

```swift
class GameScene: SKScene {

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleInputBegan(at: touches.first?.location(in: self))
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        handleInputBegan(at: event.location(in: self))
    }
    #endif

    func handleInputBegan(at location: CGPoint?) {
        guard let location = location else { return }
        // Handle input
    }
}
```

---

## Asset Variants

### Device-Specific Assets

```swift
func loadBackground() -> SKTexture {
    #if os(tvOS)
    return SKTexture(imageNamed: "background_tv")
    #elseif os(macOS)
    return SKTexture(imageNamed: "background_mac")
    #else
    return SKTexture(imageNamed: "background_ios")
    #endif
}
```

---

## Checklist

- [ ] Use #if os() for platform-specific code
- [ ] Handle different screen sizes gracefully
- [ ] Support tvOS focus engine
- [ ] Manage macOS cursor visibility
- [ ] Adapt UI for different input methods
- [ ] Test on all target platforms
- [ ] Use platform-specific assets when needed
- [ ] ⚠️ Do NOT use SpriteKit in native visionOS apps (use RealityKit instead)
- [ ] Document visionOS compatibility mode if applicable
