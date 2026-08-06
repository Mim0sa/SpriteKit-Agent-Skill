# Physics Patterns

- Use the simplest physics shape that fits: `circleOfRadius` > `rectangleOf` > `polygonFrom` > `init(texture:size:)`. Texture-based physics is the slowest — avoid unless pixel-perfect collision is required.
- Define all physics categories in one place as a struct with `UInt32` bit constants. Each scene supports a maximum of **32 categories** (bits 0–31).
- Treat `categoryBitMask` as a set of memberships. Test a category with `(body.categoryBitMask & category) != 0` when a body may carry multiple bits; use equality only when the project enforces exactly one category per body.
- Set `categoryBitMask`, `collisionBitMask`, and `contactTestBitMask` intentionally when their defaults do not express the design. `collisionBitMask` controls physical response; `contactTestBitMask` controls contact callbacks.
- Only add categories to `contactTestBitMask` that you actually handle in `didBegin(_:)` — unused contact pairs waste CPU.
- Set `isDynamic = false` for bodies that must not move under forces or collisions, such as fixed walls and terrain.
- Set `allowsRotation = false` for player and humanoid characters unless spinning is intentional.
- Enable `usesPreciseCollisionDetection` only for fast-moving objects that could tunnel through thin bodies (e.g. bullets). Leave it off everywhere else.
- Avoid setting `position` directly on a node with an active physics body during gameplay — use `applyForce`, `applyImpulse`, or `velocity`. Direct position assignment is acceptable for one-time teleports or respawns.
- Edge-based bodies (`edgeLoopFrom`, `edgeChainFrom`) **never collide with other edge-based bodies**. Use thin rectangle bodies when two static surfaces must interact.
- Clear or reset `physicsBody` before pooling a node when the pooled instance should stop participating in physics or will be reconfigured. Removing and releasing a node does not require this as a universal cleanup step.
- Defer all node removal triggered by contacts to `didSimulatePhysics()`.
- Use `SKFieldNode` instead of per-frame manual force calculations for gravity wells, drag zones, and wind.
- Assign `fieldBitMask` to physics bodies to control which fields affect them.
- Always add joints through `physicsWorld.add(_:)` after both bodies are in the scene.
- Tune physics feel with `linearDamping` (friction-like deceleration, 0–1), `angularDamping` (rotational friction, 0–1), and `restitution` (bounciness, 0 = no bounce, 1 = perfect elastic). Set these once during body configuration, not per frame.
- Set `friction` on physics bodies for surface interaction (e.g., ice = 0.1, rubber = 0.8). Default is 0.2.

## Category Bitmask Setup

```swift
struct PhysicsCategory {
    static let none:       UInt32 = 0
    static let player:     UInt32 = 0b00000001
    static let enemy:      UInt32 = 0b00000010
    static let projectile: UInt32 = 0b00000100
    static let obstacle:   UInt32 = 0b00001000
    static let powerUp:    UInt32 = 0b00010000
    static let boundary:   UInt32 = 0b00100000
    // Max 32 total (up to bit 31)
}

// Set each mask explicitly when this body relies on non-default behavior.
body.categoryBitMask     = PhysicsCategory.player
body.collisionBitMask    = PhysicsCategory.obstacle | PhysicsCategory.boundary
body.contactTestBitMask  = PhysicsCategory.enemy | PhysicsCategory.powerUp
```

## Body Shape Selection

| Type | Performance | Use Case |
|------|-------------|----------|
| `circleOfRadius` | Fastest | Balls, characters |
| `rectangleOf` | Fast | Boxes, walls, platforms |
| `polygonFrom` | Moderate | Custom convex shapes only |
| `edgeLoopFrom` | Fast (static only) | Scene boundaries |
| `edgeChainFrom` | Moderate (static only) | Terrain contours |
| `init(texture:size:)` | Slowest | Avoid unless necessary |

## Edge-Based Body Limitation

```swift
// These two bodies will NEVER collide with each other
let ground = SKPhysicsBody(edgeChainFrom: groundPath)
let wall   = SKPhysicsBody(edgeLoopFrom: wallRect)

// Fix: use a thin rectangle body for walls that must collide with ground
let wall = SKNode()
wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: 200))
wall.physicsBody?.isDynamic = false
```

## Correct Force Application

```swift
// Wrong: fights physics simulation
override func update(_ currentTime: TimeInterval) {
    player.position = targetPosition
}

// Correct: work with the simulation
func jump() {
    player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 500))
}

func move(direction: CGFloat) {
    let targetVx = direction * maxSpeed
    let diff = targetVx - (player.physicsBody?.velocity.dx ?? 0)
    player.physicsBody?.applyForce(CGVector(dx: diff * 10, dy: 0))
}
```

## Physics Field — Gravity Well

```swift
let blackHole = SKNode()
blackHole.position = CGPoint(x: 400, y: 300)

let field = SKFieldNode.radialGravityField()
field.strength = 20.0
field.falloff = 2.0
field.region = SKRegion(radius: 300)
field.categoryBitMask = FieldCategory.gravity

blackHole.addChild(field)
addChild(blackHole)

// Only player is affected, not projectiles
player.physicsBody?.fieldBitMask = FieldCategory.gravity
projectile.physicsBody?.fieldBitMask = 0
```

## Contact Delegate

Select the conformance form from both the target platform and compiler. On iOS, macOS, tvOS, and visionOS, Swift 6.2+ supports a global-actor-isolated conformance; Swift 6.0 and 6.1 require `@preconcurrency` when the main-actor-isolated scene satisfies the nonisolated delegate requirements. SpriteKit nodes are not main-actor-isolated on watchOS, so use an ordinary conformance there and configure the delegate without `SKView`. Older compilers can also use an ordinary conformance. Do not raise the deployment target or Swift language mode solely to copy a newer form.

```swift
class GameScene: SKScene {
    #if !os(watchOS)
    override func didMove(to view: SKView) {
        configurePhysics()
    }
    #endif

    // On watchOS, call this before presenting the scene through WKInterfaceSKScene.
    func configurePhysics() {
        physicsWorld.contactDelegate = self
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let (a, b) = (contact.bodyA, contact.bodyB)
        guard let nodeA = a.node, let nodeB = b.node else { return }

        let aIsPlayer = (a.categoryBitMask & PhysicsCategory.player) != 0
        let aIsEnemy = (a.categoryBitMask & PhysicsCategory.enemy) != 0
        let bIsPlayer = (b.categoryBitMask & PhysicsCategory.player) != 0
        let bIsEnemy = (b.categoryBitMask & PhysicsCategory.enemy) != 0
        let player: SKNode
        let enemy: SKNode
        if aIsPlayer && bIsEnemy {
            (player, enemy) = (nodeA, nodeB)
        } else if bIsPlayer && aIsEnemy {
            (player, enemy) = (nodeB, nodeA)
        } else {
            return
        }

        handlePlayerHitEnemy(player: player, enemy: enemy)
    }
}

#if os(watchOS)
extension GameScene: SKPhysicsContactDelegate {}
#elseif compiler(>=6.2)
extension GameScene: @MainActor SKPhysicsContactDelegate {}
#elseif compiler(>=6.0)
extension GameScene: @preconcurrency SKPhysicsContactDelegate {}
#else
extension GameScene: SKPhysicsContactDelegate {}
#endif
```

## Physics Feel Tuning

```swift
// Player — responsive, no bounce, moderate air friction
player.physicsBody?.linearDamping = 0.1
player.physicsBody?.angularDamping = 0.5
player.physicsBody?.restitution = 0
player.physicsBody?.friction = 0.4

// Bouncy ball — high restitution, low friction
ball.physicsBody?.restitution = 0.9
ball.physicsBody?.friction = 0.05
ball.physicsBody?.linearDamping = 0.02

// Ice surface — very low friction
ground.physicsBody?.friction = 0.05
```
