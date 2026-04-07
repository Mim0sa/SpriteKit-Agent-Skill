# Physics Patterns

- Use the simplest physics shape that fits: `circleOfRadius` > `rectangleOf` > `polygonFrom` > `init(texture:size:)`. Texture-based physics is the slowest — avoid unless pixel-perfect collision is required.
- Define all physics categories in one place as a struct with `UInt32` bit constants. Each scene supports a maximum of **32 categories** (bits 0–31).
- Configure all three bitmasks on every physics body: `categoryBitMask`, `collisionBitMask`, `contactTestBitMask`.
- Only add categories to `contactTestBitMask` that you actually handle in `didBegin(_:)` — unused contact pairs waste CPU.
- Set `isDynamic = false` for all static objects (walls, platforms, ground). This is the single biggest physics performance win.
- Set `allowsRotation = false` for player and humanoid characters unless spinning is intentional.
- Enable `usesPreciseCollisionDetection` only for fast-moving objects that could tunnel through thin bodies (e.g. bullets). Leave it off everywhere else.
- Never set `position` directly on a node with an active physics body — use `applyForce`, `applyImpulse`, or `velocity`.
- Edge-based bodies (`edgeLoopFrom`, `edgeChainFrom`) **never collide with other edge-based bodies**. Use thin rectangle bodies when two static surfaces must interact.
- Clear `physicsBody = nil` before removing a node — the physics body otherwise persists in the simulation.
- Defer all node removal triggered by contacts to `didSimulatePhysics()`.
- Use `SKFieldNode` instead of per-frame manual force calculations for gravity wells, drag zones, and wind.
- Assign `fieldBitMask` to physics bodies to control which fields affect them.
- Always add joints through `physicsWorld.add(_:)` after both bodies are in the scene.

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

// All three bitmasks required
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

```swift
class GameScene: SKScene, SKPhysicsContactDelegate {
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let (a, b) = (contact.bodyA, contact.bodyB)
        guard let nodeA = a.node, let nodeB = b.node else { return }

        let isPlayerEnemy =
            (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.enemy) ||
            (a.categoryBitMask == PhysicsCategory.enemy  && b.categoryBitMask == PhysicsCategory.player)

        if isPlayerEnemy {
            let player = a.categoryBitMask == PhysicsCategory.player ? nodeA : nodeB
            let enemy  = a.categoryBitMask == PhysicsCategory.enemy  ? nodeA : nodeB
            handlePlayerHitEnemy(player: player, enemy: enemy)
        }
    }
}
```
