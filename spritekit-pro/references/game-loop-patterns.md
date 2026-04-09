# Game Loop Patterns

- Always compute `deltaTime` from the `currentTime` parameter in `update(_:)` — never use a hardcoded time step for movement or animation.
- Guard against abnormally large delta values on first frame or after backgrounding: clamp delta to a max of `1.0 / 20.0`.
- Place game logic (input, AI, state) in `update(_:)`. Place node removal in `didSimulatePhysics()`. Use `didFinishUpdate()` for metrics only — do not modify node state there.
- Use fixed-timestep accumulation when physics determinism is required (e.g. network multiplayer, replays).
- Never place heavy computation (sorting large arrays, pathfinding) directly in `update(_:)` — batch or throttle it.
- Use a component system for entities with multiple behaviors; call `entity.update(deltaTime:)` from the scene's `update(_:)`.

## Frame Cycle Reference

| Method | Use For | Avoid |
|--------|---------|-------|
| `update(_:)` | Input, AI, game logic | Direct physics modifications |
| `didEvaluateActions()` | Checking action completion states | Heavy computation |
| `didSimulatePhysics()` | Deferred node removal, camera update | Adding new physics bodies |
| `didApplyConstraints()` | Post-constraint adjustments | New constraints |
| `didFinishUpdate()` | Metrics, debug logging | Any node state changes |

## Basic Delta Time

```swift
class GameScene: SKScene {
    var lastUpdateTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        let deltaTime = min(rawDelta, 1.0 / 20.0)  // Clamp spike on resume
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
        // Deterministic physics-tick logic here
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
