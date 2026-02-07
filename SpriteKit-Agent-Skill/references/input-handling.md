# Input Handling

Touch, mouse, and game controller handling in SpriteKit.

---

## Touch Input (iOS)

### Basic Touch Handling

```swift
class GameScene: SKScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        if node.name == "button" {
            handleButtonPress()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)

        let translation = CGPoint(
            x: location.x - previousLocation.x,
            y: location.y - previousLocation.y
        )

        // Handle drag
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle touch end
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Always handle cancellation
        touchesEnded(touches, with: event)
    }
}
```

### Multi-Touch Support

```swift
class GameScene: SKScene {
    var activeTouches: [UITouch: SKNode] = [:]

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let node = atPoint(location)
            activeTouches[touch] = node
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }
    }
}
```

---

## Mouse Input (macOS)

### Mouse Event Handling

```swift
#if os(macOS)
import AppKit

class GameScene: SKScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        // Handle click
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        // Handle drag
    }

    override func mouseUp(with event: NSEvent) {
        // Handle release
    }

    override func rightMouseDown(with event: NSEvent) {
        // Handle right click
    }

    override func scrollWheel(with event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        // Handle zoom/scroll
    }

    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        // Handle hover
    }
}
#endif
```

---

## Game Controller (tvOS, iOS)

### Controller Setup

```swift
import GameController

class GameScene: SKScene {

    override func didMove(to view: SKView) {
        setupGameControllers()
    }

    func setupGameControllers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Check for already connected controllers
        for controller in GCController.controllers() {
            registerController(controller)
        }
    }

    @objc func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        registerController(controller)
    }

    func registerController(_ controller: GCController) {
        // Extended gamepad (modern controllers)
        if let gamepad = controller.extendedGamepad {
            gamepad.leftThumbstick.valueChangedHandler = { [weak self] x, y in
                self?.handleLeftStick(x: x, y: y)
            }

            gamepad.rightThumbstick.valueChangedHandler = { [weak self] x, y in
                self?.handleRightStick(x: x, y: y)
            }

            gamepad.buttonA.pressedChangedHandler = { [weak self] button, value, pressed in
                if pressed { self?.handleButtonA() }
            }
        }

        // Micro gamepad (Siri Remote)
        if let microGamepad = controller.microGamepad {
            microGamepad.dpad.valueChangedHandler = { [weak self] x, y in
                self?.handleDPad(x: x, y: y)
            }

            microGamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.handleSelect() }
            }
        }
    }
}
```

---

## Unified Input Handler

### Cross-Platform Input Abstraction

```swift
protocol InputHandlerDelegate: AnyObject {
    func inputMoved(to point: CGPoint)
    func inputBegan(at point: CGPoint)
    func inputEnded(at point: CGPoint)
    func inputCancelled()
}

#if os(iOS) || os(tvOS)
class InputHandler {
    weak var delegate: InputHandlerDelegate?

    func handleTouchesBegan(_ touches: Set<UITouch>, in view: SKView) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: view)
        delegate?.inputBegan(at: location)
    }

    func handleTouchesMoved(_ touches: Set<UITouch>, in view: SKView) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: view)
        delegate?.inputMoved(to: location)
    }

    func handleTouchesEnded(_ touches: Set<UITouch>, in view: SKView) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: view)
        delegate?.inputEnded(at: location)
    }
}
#elseif os(macOS)
class InputHandler {
    weak var delegate: InputHandlerDelegate?

    func handleMouseDown(at point: CGPoint) {
        delegate?.inputBegan(at: point)
    }

    func handleMouseDragged(at point: CGPoint) {
        delegate?.inputMoved(to: point)
    }

    func handleMouseUp(at point: CGPoint) {
        delegate?.inputEnded(at: point)
    }
}
#endif
```

---

## Gesture Recognizers

### UIGestureRecognizer Integration (iOS)

```swift
class GameScene: SKScene {

    override func didMove(to view: SKView) {
        setupGestureRecognizers()
    }

    func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 2
        view?.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view?.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        view?.addGestureRecognizer(pinchGesture)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let sceneLocation = convertPoint(fromView: location)
        // Handle double tap
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        // Handle pan
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = gesture.scale
        // Handle zoom
    }
}
```

---

## Checklist

- [ ] Handle touchesCancelled properly
- [ ] Support multi-touch if needed
- [ ] Implement mouse support for macOS
- [ ] Support game controllers for tvOS
- [ ] Create unified input abstraction
- [ ] Use gesture recognizers for complex gestures
- [ ] Test on all target input methods
