# Animation and Sprites

- Always group related sprites in a texture atlas (`.atlas` folder). Single textures per draw call — individual files multiply draw calls.
- Preload atlases with `SKTextureAtlas.preloadTextureAtlases(_:withCompletionHandler:)` before the scene appears. Never load textures for the first time inside `update(_:)`.
- Create reusable actions as `static let` constants — never create `SKAction` instances inside `update(_:)` or inside loops.
- Use `[weak self]` in all action completion blocks and `SKAction.run` blocks.
- Stop a specific action with `removeAction(forKey:)` rather than `removeAllActions()`, which also cancels unrelated actions.
- Manage animation states with a state machine or enum rather than manually tracking which animation is running.
- Set anchor points intentionally — default `(0.5, 0.5)` is correct for physics bodies; `(0, 0.5)` is useful for health bars.
- Use `SKAction.sequence` for serial actions and `SKAction.group` for parallel actions.
- Pass completion logic to `run(_:completion:)` or chain with `SKAction.sequence` — do not use `DispatchQueue.asyncAfter` for action sequencing.

## Texture Atlas Loading

```swift
// Correct: atlas reduces draw calls; preload before scene appears
let atlas = SKTextureAtlas(named: "Player")
let walkFrames = (1...8).map { atlas.textureNamed("walk_\($0)") }

SKTextureAtlas.preloadTextureAtlases([atlas]) {
    // Safe to use atlas textures now
}
```

## State-Based Animation

```swift
enum AnimationState: String {
    case idle, walk, jump, attack

    var timePerFrame: TimeInterval {
        switch self {
        case .idle: return 0.2; case .walk: return 0.1
        case .jump: return 0.15; case .attack: return 0.08
        }
    }
    var loops: Bool { self == .idle || self == .walk }
}

class AnimatedSprite: SKSpriteNode {
    private var textures: [AnimationState: [SKTexture]] = [:]
    private var currentState: AnimationState = .idle

    func transition(to state: AnimationState) {
        guard state != currentState,
              let frames = textures[state], !frames.isEmpty else { return }
        currentState = state
        removeAction(forKey: "anim")
        let anim = SKAction.animate(with: frames, timePerFrame: state.timePerFrame)
        run(state.loops ? SKAction.repeatForever(anim) : anim, withKey: "anim")
    }
}
```

## Reusable Static Actions

```swift
class GameScene: SKScene {
    // Create once, reuse on all instances
    static let enemyPatrolAction: SKAction = {
        SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 100, y: 0, duration: 2),
            SKAction.moveBy(x: -100, y: 0, duration: 2)
        ]))
    }()

    func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "enemy")
        enemy.run(GameScene.enemyPatrolAction)
        worldLayer.addChild(enemy)
    }
}
```

## Wrong: Creating Actions in update()

```swift
// Wrong: allocates a new action every frame
override func update(_ currentTime: TimeInterval) {
    run(SKAction.sequence([
        SKAction.scale(to: 1.2, duration: 0.3),
        SKAction.scale(to: 1.0, duration: 0.3)
    ]))
}

// Correct: create once, run on event
let pulseAction = SKAction.repeatForever(SKAction.sequence([
    SKAction.scale(to: 1.2, duration: 0.3),
    SKAction.scale(to: 1.0, duration: 0.3)
]))
func startPulse() { run(pulseAction, withKey: "pulse") }
func stopPulse()  { removeAction(forKey: "pulse") }
```

## Completion Chaining

```swift
// Correct: chain with sequence
let move = SKAction.move(to: targetPos, duration: 1)
let callback = SKAction.run { [weak self] in self?.animationComplete() }
run(SKAction.sequence([move, callback]))

// Also correct: completion closure
run(move) { [weak self] in self?.animationComplete() }
```
