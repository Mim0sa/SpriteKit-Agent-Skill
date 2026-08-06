# Game Loop Patterns

- Compute variable-step `deltaTime` from the `currentTime` parameter in `update(_:)`; do not assume a fixed display frame rate.
- Guard against first-frame and resume spikes. Choose the maximum accepted delta from gameplay requirements instead of treating `1.0 / 20.0` as universal.
- Place game logic in `update(_:)` and defer contact-triggered removals until after physics. Use `didFinishUpdate()` for final values that must be rendered in the current frame; actions, physics, and constraints changed there take effect in later update phases.
- Use fixed-step accumulation for custom deterministic game logic when needed. It does not make SpriteKit's internally stepped physics simulation deterministic for networking or replays.
- Never place heavy computation (sorting large arrays, pathfinding) directly in `update(_:)` — batch or throttle it.
- If the project uses GameplayKit entities, update them from one documented point in the frame cycle to avoid duplicate updates.

## Frame Cycle Reference

| Method | Use For | Avoid |
|--------|---------|-------|
| `update(_:)` | Input, AI, game logic | Direct physics modifications |
| `didEvaluateActions()` | Checking action completion states | Heavy computation |
| `didSimulatePhysics()` | Deferred node removal, camera update | Adding new physics bodies |
| `didApplyConstraints()` | Post-constraint adjustments | New constraints |
| `didFinishUpdate()` | Final presentation adjustments, metrics | Expecting newly added actions, physics, or constraints to run in the same frame |

## Basic Delta Time

```swift
class GameScene: SKScene {
    var lastUpdateTime: TimeInterval = 0
    let maximumDelta: TimeInterval = 0.05

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        let deltaTime = min(rawDelta, maximumDelta)
        lastUpdateTime = currentTime

        updatePlayer(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime)
    }
}
```

## Fixed Timestep

```swift
class GameScene: SKScene {
    let fixedStep: TimeInterval = 1.0 / 60.0
    var accumulator: TimeInterval = 0
    var lastTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        accumulator += min(currentTime - lastTime, 0.1)
        lastTime = currentTime

        while accumulator >= fixedStep {
            fixedUpdate(dt: fixedStep)
            accumulator -= fixedStep
        }
    }

    func fixedUpdate(dt: TimeInterval) {
        // Fixed-step custom simulation or game logic here.
        // SpriteKit advances physics separately in its frame cycle.
    }
}
```

## Component System Integration

```swift
class GameScene: SKScene {
    var entityManager: EntityManager!

    override func update(_ currentTime: TimeInterval) {
        // ... delta time calculation ...
        entityManager.update(deltaTime: deltaTime)
    }
}

class EntityManager {
    var entities: Set<GKEntity> = []

    func update(deltaTime: TimeInterval) {
        entities.forEach { $0.update(deltaTime: deltaTime) }
    }
}
```
