# Game Loop Patterns

Update patterns, fixed timestep, and component systems.

---

## Update Loop

### Basic Update

```swift
class GameScene: SKScene {
    var lastUpdateTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Update game logic
        updatePlayer(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime)
    }
}
```

### Fixed Timestep

```swift
class GameScene: SKScene {
    let fixedTimeStep: TimeInterval = 1.0 / 60.0
    var accumulator: TimeInterval = 0
    var lastTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let deltaTime = currentTime - lastTime
        lastTime = currentTime

        accumulator += deltaTime

        while accumulator >= fixedTimeStep {
            fixedUpdate(deltaTime: fixedTimeStep)
            accumulator -= fixedTimeStep
        }

        // Interpolate visual update
        let alpha = accumulator / fixedTimeStep
        renderUpdate(interpolation: alpha)
    }

    func fixedUpdate(deltaTime: TimeInterval) {
        // Physics and game logic at fixed rate
    }

    func renderUpdate(interpolation: CGFloat) {
        // Visual interpolation
    }
}
```

---

## Complete Frame Cycle

SpriteKit's frame update follows a specific sequence. Override these methods to hook into different stages:

```swift
class CompleteFrameCycle: SKScene {

    // 1. FIRST: Update game logic and input processing
    override func update(_ currentTime: TimeInterval) {
        // Called every frame
        // Process input, AI, game logic here
        processInput()
        updateAI(deltaTime: deltaTime)
        updateGameLogic()
    }

    // 2. Actions are evaluated (SKAction processing)
    override func didEvaluateActions() {
        // Called after all SKActions have been processed
        // Good place to check action completion states
        checkAnimationStates()
    }

    // 3. Physics simulation completes
    override func didSimulatePhysics() {
        // Called after physics simulation
        // Safe to remove nodes marked during contact callbacks
        processPendingRemovals()

        // Update positions based on physics results
        updateCameraPosition()
    }

    // 4. Constraints are applied (SKConstraint)
    override func didApplyConstraints() {
        // Called after SKConstraints are applied
        // Use for post-constraint adjustments
        // For example: Keep UI elements within bounds after camera constraints
    }

    // 5. LAST: Frame completes
    override func didFinishUpdate() {
        // Called after all frame processing is complete
        // Use for debugging, metrics, final cleanup
        // ⚠️ Do not modify node state here - may affect next frame
        updatePerformanceMetrics()
        logFrameData()
    }
}
```

### Frame Cycle Usage Guidelines

| Method | Use For | Avoid |
|--------|---------|-------|
| `update(_:)` | Game logic, input, AI | Physics modifications |
| `didEvaluateActions()` | Action state checks | Heavy computation |
| `didSimulatePhysics()` | Node removal, physics responses | Modifying physics bodies |
| `didApplyConstraints()` | Post-constraint adjustments | Adding new constraints |
| `didFinishUpdate()` | Metrics, debugging | Node state changes |

---

## Component System

### Component Pattern

```swift
protocol Component {
    var entity: SKNode? { get set }
    func update(deltaTime: TimeInterval)
}

class Entity: SKNode {
    var components: [Component] = []

    func addComponent(_ component: Component) {
        component.entity = self
        components.append(component)
    }

    func update(deltaTime: TimeInterval) {
        components.forEach { $0.update(deltaTime: deltaTime) }
    }
}
```

---

## Checklist

- [ ] Use delta time for frame-rate independent movement
- [ ] Consider fixed timestep for physics
- [ ] Use component pattern for complex entities
- [ ] Separate visual and logic updates
- [ ] Choose appropriate frame cycle method for your logic
- [ ] Process node removals in `didSimulatePhysics()`
- [ ] Avoid modifying nodes in `didFinishUpdate()`
