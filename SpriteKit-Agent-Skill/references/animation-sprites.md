# Animation and Sprites

Best practices for sprite animation, texture atlases, and SKAction patterns.

---

## Texture Atlases

**Always use texture atlases for related sprites.**

```swift
// Correct: Using texture atlas
let atlas = SKTextureAtlas(named: "Player")
let walkFrames = (1...8).map { atlas.textureNamed("player_walk_\($0)") }
let idleFrames = (1...4).map { atlas.textureNamed("player_idle_\($0)") }

// Preload before scene appears
SKTextureAtlas.preloadTextureAtlases([atlas]) {
    // Ready to use
}
```

**Benefits of atlases:**
- Reduced draw calls (better performance)
- Automatic texture packing
- Platform-specific compression
- Dynamic loading/unloading

---

## Sprite Animation

### Frame-based Animation

```swift
class Player: SKSpriteNode {
    private var walkTextures: [SKTexture] = []
    private var idleTextures: [SKTexture] = []

    func setupAnimations() {
        let atlas = SKTextureAtlas(named: "Player")

        walkTextures = (1...8).map { atlas.textureNamed("walk_\($0)") }
        idleTextures = (1...4).map { atlas.textureNamed("idle_\($0)") }

        // Preload textures
        SKTexture.preload(walkTextures + idleTextures) {
            print("Animations ready")
        }
    }

    func playWalkAnimation() {
        let walkAction = SKAction.animate(with: walkTextures, timePerFrame: 0.1)
        run(SKAction.repeatForever(walkAction), withKey: "walk")
    }

    func playIdleAnimation() {
        let idleAction = SKAction.animate(with: idleTextures, timePerFrame: 0.2)
        run(SKAction.repeatForever(idleAction), withKey: "idle")
    }

    func stopAnimation() {
        removeAction(forKey: "walk")
        removeAction(forKey: "idle")
    }
}
```

### State-based Animation System

```swift
enum AnimationState: String, CaseIterable {
    case idle, walk, jump, attack, hurt

    var timePerFrame: TimeInterval {
        switch self {
        case .idle: return 0.2
        case .walk: return 0.1
        case .jump: return 0.15
        case .attack: return 0.08
        case .hurt: return 0.1
        }
    }

    var shouldRepeat: Bool {
        switch self {
        case .idle, .walk: return true
        case .jump, .attack, .hurt: return false
        }
    }
}

class AnimatedSprite: SKSpriteNode {
    private var textures: [AnimationState: [SKTexture]] = [:]
    private var currentState: AnimationState = .idle

    func loadAnimations(from atlas: SKTextureAtlas) {
        for state in AnimationState.allCases {
            var frameIndex = 1
            var stateTextures: [SKTexture] = []

            while atlas.textureNames.contains("\(state.rawValue)_\(frameIndex)") {
                stateTextures.append(atlas.textureNamed("\(state.rawValue)_\(frameIndex)"))
                frameIndex += 1
            }

            textures[state] = stateTextures
        }
    }

    func transition(to state: AnimationState) {
        guard state != currentState,
              let stateTextures = textures[state],
              !stateTextures.isEmpty else { return }

        currentState = state

        removeAction(forKey: "animation")

        let animation = SKAction.animate(with: stateTextures, timePerFrame: state.timePerFrame)

        if state.shouldRepeat {
            run(SKAction.repeatForever(animation), withKey: "animation")
        } else {
            run(animation, withKey: "animation")
        }
    }
}
```

---

## SKAction Best Practices

### Action Groups and Sequences

```swift
// Sequence: Actions run one after another
let moveUp = SKAction.moveBy(x: 0, y: 100, duration: 0.5)
let wait = SKAction.wait(forDuration: 0.2)
let moveDown = SKAction.moveBy(x: 0, y: -100, duration: 0.5)

let jumpSequence = SKAction.sequence([moveUp, wait, moveDown])
player.run(jumpSequence)

// Group: Actions run simultaneously
let moveRight = SKAction.moveBy(x: 100, y: 0, duration: 1)
let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 1)
let fadeIn = SKAction.fadeIn(withDuration: 1)

let combinedAction = SKAction.group([moveRight, rotate, fadeIn])
player.run(combinedAction)
```

### Reusable Actions

```swift
// Create actions once, reuse multiple times
class GameScene: SKScene {
    static let enemyMoveAction: SKAction = {
        let moveLeft = SKAction.moveBy(x: -100, y: 0, duration: 2)
        let moveRight = SKAction.moveBy(x: 100, y: 0, duration: 2)
        return SKAction.repeatForever(
            SKAction.sequence([moveLeft, moveRight])
        )
    }()

    func spawnEnemy() {
        let enemy = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 40))
        enemy.run(GameScene.enemyMoveAction)  // Reuse same action
        addChild(enemy)
    }
}
```

### Action Completion Callbacks

```swift
// Correct: Weak self in completion
let moveAction = SKAction.move(to: targetPosition, duration: 1)
let completionAction = SKAction.run { [weak self] in
    self?.animationDidComplete()
}

let sequence = SKAction.sequence([moveAction, completionAction])
run(sequence)

// Or use completion closure
run(moveAction) { [weak self] in
    self?.animationDidComplete()
}
```

---

## Sprite Positioning and Anchors

### Understanding Anchor Points

```swift
// Anchor point (0.5, 0.5) - center (default)
let centeredSprite = SKSpriteNode(color: .blue, size: CGSize(width: 100, height: 100))
centeredSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
// Position refers to center of sprite

// Anchor point (0, 0) - bottom-left
let anchoredSprite = SKSpriteNode(color: .red, size: CGSize(width: 100, height: 100))
anchoredSprite.anchorPoint = CGPoint(x: 0, y: 0)
// Position refers to bottom-left corner

// Useful for UI elements
let healthBar = SKSpriteNode(color: .green, size: CGSize(width: 200, height: 20))
healthBar.anchorPoint = CGPoint(x: 0, y: 0.5)  // Left-center
healthBar.position = CGPoint(x: 20, y: 100)
```

---

## Common Pitfalls

### Creating Actions in Update

```swift
// Wrong: Creating new actions every frame
override func update(_ currentTime: TimeInterval) {
    let pulse = SKAction.sequence([
        SKAction.scale(to: 1.2, duration: 0.5),
        SKAction.scale(to: 1.0, duration: 0.5)
    ])
    run(pulse)  // Creates new action every frame!
}

// Correct: Create once, run when needed
let pulseAction = SKAction.sequence([
    SKAction.scale(to: 1.2, duration: 0.5),
    SKAction.scale(to: 1.0, duration: 0.5)
])

func startPulsing() {
    run(SKAction.repeatForever(pulseAction), withKey: "pulse")
}

func stopPulsing() {
    removeAction(forKey: "pulse")
}
```

### Strong Reference in Action Blocks

```swift
// Wrong: Retain cycle
let repeatingAction = SKAction.repeatForever(
    SKAction.sequence([
        SKAction.wait(forDuration: 1),
        SKAction.run { self.spawnEnemy() }  // Retain cycle!
    ])
)
run(repeatingAction)

// Correct: Weak reference
let safeAction = SKAction.repeatForever(
    SKAction.sequence([
        SKAction.wait(forDuration: 1),
        SKAction.run { [weak self] in self?.spawnEnemy() }
    ])
)
run(safeAction)
```

---

## Checklist

- [ ] Use texture atlases for related sprites
- [ ] Preload textures before scene appears
- [ ] Create reusable actions as static constants
- [ ] Use [weak self] in action completion blocks
- [ ] Remove actions with specific keys to stop them
- [ ] Don't create actions in update loops
- [ ] Choose appropriate anchor points for positioning
- [ ] Use state-based animation system for complex characters
- [ ] Preload animation textures to avoid stuttering
