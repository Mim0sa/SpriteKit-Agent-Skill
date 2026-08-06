# Animation and Sprites

- Group related sprites in a texture atlas when it improves loading and batching. Verify draw count because z-order, overlap, blend mode, shaders, and effects can still split drawing passes.
- Preload atlases with `SKTextureAtlas.preloadTextureAtlases(_:withCompletionHandler:)` before the scene appears. Never load textures for the first time inside `update(_:)`.
- Reuse immutable actions that are executed frequently. Avoid reconstructing identical actions in measured hot paths.
- Break a repeating or long-lived node-action-closure ownership cycle with `[weak self]` or guaranteed action cancellation at the node's ownership boundary. A finite action may capture its owner strongly only when it is guaranteed to run to completion or be canceled while the node is still reachable; detaching a node pauses its actions and can otherwise make the cycle persistent.
- Stop a specific action with `removeAction(forKey:)` rather than `removeAllActions()`, which also cancels unrelated actions.
- Use an enum or state machine when an entity has multiple mutually exclusive animations and transition rules.
- Set anchor points intentionally — default `(0.5, 0.5)` is correct for physics bodies; `(0, 0.5)` is useful for health bars.
- Use `SKAction.sequence` for serial actions and `SKAction.group` for parallel actions.
- Pass completion logic to `run(_:completion:)` or chain with `SKAction.sequence` — do not use `DispatchQueue.asyncAfter` for action sequencing.

## Texture Atlas Loading

```swift
// An atlas centralizes loading and may improve batching; verify draw count.
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
func animateWhileLifetimeIsGuaranteed() {
    let move = SKAction.move(to: targetPos, duration: 1)
    let callback = SKAction.run { self.animationComplete() }
    run(SKAction.sequence([move, callback]))
}

func animateWhenNodeMayDetach() {
    let move = SKAction.move(to: targetPos, duration: 1)
    run(move) { [weak self] in self?.animationComplete() }
}

func animateWithExplicitCancellationBoundary() {
    let move = SKAction.move(to: targetPos, duration: 1)
    let callback = SKAction.run { self.animationComplete() }
    run(SKAction.sequence([move, callback]), withKey: "move-and-callback")
}

// The external lifecycle owner calls this before detaching the node.
func prepareForRemoval() {
    removeAction(forKey: "move-and-callback")
}
```
