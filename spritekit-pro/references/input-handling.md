# Input Handling

- Always implement `touchesCancelled(_:with:)` on iOS — forward it to `touchesEnded` to prevent stuck input states.
- Enable `view.isMultipleTouchEnabled = true` explicitly if the game requires multi-touch; it is disabled by default.
- Abstract platform input behind a protocol so game logic does not contain `#if os()` branching.
- For tvOS, handle the Siri Remote menu button via `UITapGestureRecognizer` with `allowedPressTypes = [.menu]`.
- For macOS, implement `mouseMoved` only when hover/aim feedback is required — it fires constantly and adds cost.
- For macOS keyboard input, override `keyDown(with:)` and `keyUp(with:)` on `SKScene` — call `super` for unhandled keys to avoid swallowing system shortcuts.
- Use `gesture recognizers` added to the `SKView` for complex gestures (pinch, pan, double-tap) rather than reimplementing them from raw touch events.
- Convert gesture recognizer coordinates with `convertPoint(fromView:)` before using them in scene space.
- Bind game controller handlers with `[weak self]` — `GCController` holds strong references to closures.
- Poll `GCController.controllers()` in `didMove(to:)` to handle controllers already connected before the scene loads.

## Touch (iOS)

```swift
class GameScene: SKScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleInput(at: touch.location(in: self))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleInputMoved(to: touch.location(in: self))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleInputEnded()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)  // Always forward
    }
}
```

## Mouse (macOS)

```swift
#if os(macOS)
extension GameScene {
    override func mouseDown(with event: NSEvent) {
        handleInput(at: event.location(in: self))
    }
    override func mouseDragged(with event: NSEvent) {
        handleInputMoved(to: event.location(in: self))
    }
    override func mouseUp(with event: NSEvent) {
        handleInputEnded()
    }
}
#endif
```

## Cross-Platform Abstraction

```swift
protocol InputHandlerDelegate: AnyObject {
    func inputBegan(at point: CGPoint)
    func inputMoved(to point: CGPoint)
    func inputEnded()
}

class GameScene: SKScene, InputHandlerDelegate {
    func inputBegan(at point: CGPoint) { /* shared logic */ }
    func inputMoved(to point: CGPoint) { /* shared logic */ }
    func inputEnded() { /* shared logic */ }

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let loc = touches.first?.location(in: self) { inputBegan(at: loc) }
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        inputBegan(at: event.location(in: self))
    }
    #endif
}
```

## Game Controller (tvOS / iOS)

```swift
import GameController

class GameScene: SKScene {
    override func didMove(to view: SKView) {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerConnected(_:)),
                                               name: .GCControllerDidConnect, object: nil)
        GCController.controllers().forEach { registerController($0) }
    }

    @objc func controllerConnected(_ note: Notification) {
        if let c = note.object as? GCController { registerController(c) }
    }

    func registerController(_ controller: GCController) {
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.handleStick(x: x, y: y)
        }
        controller.extendedGamepad?.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.handleJump() }
        }
    }
}
```

## Gesture Recognizer (iOS)

```swift
class GameScene: SKScene {
    override func didMove(to view: SKView) {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scenePoint = convertPoint(fromView: gesture.location(in: view))
        zoom(to: gesture.scale, anchor: scenePoint)
        gesture.scale = 1  // Reset delta
    }
}
```
