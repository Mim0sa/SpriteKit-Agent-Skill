# Physics Patterns

Best practices for SKPhysicsBody configuration, collision handling, and simulation optimization.

---

## Physics Body Type Selection

**Choose the simplest shape that fits your needs:**

| Type | Performance | Use Case |
|------|-------------|----------|
| `circleOfRadius` | ⭐⭐⭐ Fastest | Balls, circular objects |
| `rectangleOf` | ⭐⭐⭐ Fast | Boxes, walls, platforms |
| `polygonFrom` | ⭐⭐ Moderate | Custom convex shapes |
| `edgeLoopFrom` | ⭐⭐⭐ Fast | Scene boundaries, static obstacles |
| `edgeChainFrom` | ⭐⭐ Moderate | Ground contours, complex static shapes |
| `init(texture:size:)` | ⭐ Slowest | Pixel-perfect collision (avoid if possible) |

```swift
// Correct: Simple shapes
let ball = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 40))
ball.physicsBody = SKPhysicsBody(circleOfRadius: 20)

let box = SKSpriteNode(color: .blue, size: CGSize(width: 60, height: 40))
box.physicsBody = SKPhysicsBody(rectangleOf: box.size)

// Avoid: Complex texture-based physics unless necessary
let complex = SKSpriteNode(imageNamed: "irregular-shape")
complex.physicsBody = SKPhysicsBody(texture: complex.texture!, size: complex.size)  // Slow!
```

### ⚠️ Edge-Based Physics Bodies Limitation

**Important:** Edge-based physics bodies (`edgeLoopFrom`, `edgeChainFrom`) **never interact with other edge-based physics bodies**. They cannot collide or contact each other, even if you reposition the nodes.

```swift
// Problem: Edge-based bodies don't collide with each other
let ground = SKPhysicsBody(edgeChainFrom: groundPath)      // Edge-based
let platform = SKPhysicsBody(edgeLoopFrom: platformRect)   // Edge-based
// These will NOT collide with each other!

// Solution 1: Use thin rectangles instead of edges for walls that need to collide
func createThinWall(from start: CGPoint, to end: CGPoint) -> SKSpriteNode {
    let thickness: CGFloat = 2.0
    let length = hypot(end.x - start.x, end.y - start.y)
    let angle = atan2(end.y - start.y, end.x - start.x)

    let wall = SKSpriteNode(color: .brown, size: CGSize(width: length, height: thickness))
    wall.position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    wall.zRotation = angle

    // Use rectangle physics body instead of edge
    wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
    wall.physicsBody?.isDynamic = false
    return wall
}

// Solution 2: Use raycasting for edge-edge collision detection
func checkEdgeCollision(from start: CGPoint, to end: CGPoint) -> Bool {
    if let body = physicsWorld.body(alongRayStart: start, end: end) {
        return body.categoryBitMask == PhysicsCategory.wall
    }
    return false
}
```

---

## Physics Category Setup

**Use a centralized category definition:**

> **⚠️ Important:** Each scene can have up to **32 categories** (bits 0-31). Plan your architecture accordingly.

```swift
struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32     = 0b00000001  // 1
    static let enemy: UInt32      = 0b00000010  // 2
    static let projectile: UInt32 = 0b00000100  // 4
    static let obstacle: UInt32   = 0b00001000  // 8
    static let powerUp: UInt32    = 0b00010000  // 16
    static let boundary: UInt32   = 0b00100000  // 32
    // ... maximum 32 categories (up to 0b10000000_00000000_00000000_00000000)

    // Combinations
    static let all: UInt32 = UInt32.max
}

// Strategy for more than 32 object types:
// Use broader categories and differentiate by node properties
struct ExtendedCategories {
    // Group by function rather than specific type
    static let character: UInt32 = 0b00000001   // All characters (player + enemies)
    static let hazard: UInt32    = 0b00000010   // All hazards (spikes, pits, enemies)
    static let pickup: UInt32    = 0b00000100   // All pickups (coins, powerups, keys)

    // Then use node names or userData to identify specific types
    func handleContact(_ node: SKNode) {
        if node.name?.hasPrefix("enemy_") == true {
            // Handle specific enemy type
        }
    }
}
```

**Configure all three bitmasks:**

```swift
// What am I?
body.categoryBitMask = PhysicsCategory.player

// What do I collide with physically? (bounce off)
body.collisionBitMask = PhysicsCategory.obstacle | PhysicsCategory.boundary

// What contacts do I want to be notified about? (overlap detection)
body.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.powerUp
```

---

## Collision Detection

### Contact Delegate Setup

```swift
class GameScene: SKScene, SKPhysicsContactDelegate {

    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)

        // Check collision types
        if bodyA.categoryBitMask == PhysicsCategory.player &&
           bodyB.categoryBitMask == PhysicsCategory.enemy {
            handlePlayerEnemyCollision(player: bodyA.node, enemy: bodyB.node)
        }
        else if bodyA.categoryBitMask == PhysicsCategory.enemy &&
                bodyB.categoryBitMask == PhysicsCategory.player {
            handlePlayerEnemyCollision(player: bodyB.node, enemy: bodyA.node)
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        // Handle contact ending (e.g., leaving ground)
    }
}
```

### Collision Helper Methods

```swift
extension GameScene {
    func handleCollisionBetween(
        _ bodyA: SKPhysicsBody,
        _ bodyB: SKPhysicsBody,
        categories: (UInt32, UInt32),
        handler: (SKNode, SKNode) -> Void
    ) -> Bool {
        let (catA, catB) = categories
        let matches = (bodyA.categoryBitMask == catA && bodyB.categoryBitMask == catB) ||
                      (bodyA.categoryBitMask == catB && bodyB.categoryBitMask == catA)

        if matches {
            handler(bodyA.node!, bodyB.node!)
            return true
        }
        return false
    }

    // Usage in didBegin
    func didBegin(_ contact: SKPhysicsContact) {
        _ = handleCollisionBetween(
            contact.bodyA,
            contact.bodyB,
            categories: (PhysicsCategory.player, PhysicsCategory.enemy)
        ) { player, enemy in
            self.playerHitEnemy(player: player, enemy: enemy)
        }
    }
}
```

---

## Physics Simulation Optimization

### Static vs Dynamic Bodies

```swift
// Static objects (walls, platforms) - most efficient
let wall = SKSpriteNode(color: .gray, size: CGSize(width: 100, height: 20))
wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
wall.physicsBody?.isDynamic = false  // Won't move, better performance
wall.physicsBody?.categoryBitMask = PhysicsCategory.obstacle

// Kinematic objects (moving platforms, elevators) - controlled by code
let platform = SKSpriteNode(color: .brown, size: CGSize(width: 100, height: 20))
platform.physicsBody = SKPhysicsBody(rectangleOf: platform.size)
platform.physicsBody?.isDynamic = false
platform.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
// Position controlled by SKAction or manual updates

// Dynamic objects (player, enemies) - full physics simulation
let player = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
player.physicsBody?.isDynamic = true  // Full physics
player.physicsBody?.allowsRotation = false  // Usually don't want player to rotate
```

### Physics Body Properties

```swift
// Common property configurations

// Player
player.physicsBody?.mass = 1.0
player.physicsBody?.restitution = 0.0      // No bounce
player.physicsBody?.friction = 0.3
player.physicsBody?.linearDamping = 0.1    // Air resistance
player.physicsBody?.angularDamping = 0.1
player.physicsBody?.allowsRotation = false // Keep upright

// Bouncy ball
ball.physicsBody?.restitution = 0.8        // High bounce
ball.physicsBody?.friction = 0.1
ball.physicsBody?.mass = 0.5

// Heavy obstacle
obstacle.physicsBody?.mass = 10.0          // Hard to push
obstacle.physicsBody?.isDynamic = true     // But can be moved with enough force
```

### Deferred Node Removal

```swift
class GameScene: SKScene, SKPhysicsContactDelegate {
    private var nodesToRemove: [SKNode] = []

    func didBegin(_ contact: SKPhysicsContact) {
        // Mark for removal during contact
        if shouldRemove(bodyB.node) {
            bodyB.node?.markForRemoval()
        }
    }

    override func didSimulatePhysics() {
        // Safe to remove after physics simulation
        nodesToRemove.forEach { node in
            node.physicsBody = nil
            node.removeFromParent()
        }
        nodesToRemove.removeAll()
    }
}

extension SKNode {
    func markForRemoval() {
        if let scene = self.scene as? GameScene {
            scene.nodesToRemove.append(self)
        }
    }
}
```

---

## Physics Fields (SKFieldNode)

**Use physics fields for generalized force effects instead of manual force calculations.**

Physics fields apply forces to physics bodies within their region of influence. They're ideal for effects like gravity wells, magnetic attraction, drag, and vortex forces.

**Availability:** iOS 8.0+, macOS 10.10+, tvOS 9.0+, watchOS 1.0+, visionOS 1.0+

### Field Types

```swift
// Radial gravity (pulls toward center)
let gravityField = SKFieldNode.radialGravityField()
gravityField.strength = 5.0
gravityField.position = CGPoint(x: 400, y: 300)
addChild(gravityField)

// Linear gravity (constant direction)
let linearGravity = SKFieldNode.linearGravityField(withVector: vector_float3(0, -9.8, 0))
linearGravity.strength = 1.0
addChild(linearGravity)

// Magnetic field (attracts/repels based on charge)
let magneticField = SKFieldNode.magneticField()
magneticField.strength = 10.0
addChild(magneticField)

// Drag field (slows down objects)
let dragField = SKFieldNode.dragField()
dragField.strength = 0.5
addChild(dragField)

// Vortex field (circular motion)
let vortexField = SKFieldNode.vortexField()
vortexField.strength = 2.0
addChild(vortexField)

// Noise field (random forces)
let noiseField = SKFieldNode.noiseField(withSmoothness: 0.5, animationSpeed: 1.0)
noiseField.strength = 1.0
addChild(noiseField)

// Turbulence field (chaotic motion)
let turbulenceField = SKFieldNode.turbulenceField(withSmoothness: 0.5, animationSpeed: 1.0)
turbulenceField.strength = 1.0
addChild(turbulenceField)

// Velocity field (pushes in specific direction)
let velocityField = SKFieldNode.velocityField(withVector: vector_float3(10, 0, 0))
velocityField.strength = 1.0
addChild(velocityField)

// Electric field (like magnetic but different falloff)
let electricField = SKFieldNode.electricField()
electricField.strength = 5.0
addChild(electricField)

// Spring field (oscillating force)
let springField = SKFieldNode.springField()
springField.strength = 1.0
addChild(springField)

// Custom field (define your own force function)
let customField = SKFieldNode.customField { (position, velocity, mass, charge, deltaTime) -> vector_float3 in
    // Return force vector based on parameters
    return vector_float3(0, sin(Float(position.x) * 0.1) * 10, 0)
}
customField.strength = 1.0
addChild(customField)
```

### Field Categories and Masks

**Control which physics bodies are affected by fields.**

```swift
struct FieldCategory {
    static let gravity: UInt32    = 0b00000001  // 1
    static let wind: UInt32       = 0b00000010  // 2
    static let magnetic: UInt32   = 0b00000100  // 4
    static let drag: UInt32       = 0b00001000  // 8
}

// Configure field
let gravityField = SKFieldNode.radialGravityField()
gravityField.categoryBitMask = FieldCategory.gravity
gravityField.strength = 5.0
addChild(gravityField)

// Configure physics body to respond to specific fields
player.physicsBody?.fieldBitMask = FieldCategory.gravity | FieldCategory.drag
// Player affected by gravity and drag, but not wind or magnetic

enemy.physicsBody?.fieldBitMask = FieldCategory.gravity | FieldCategory.wind
// Enemy affected by gravity and wind

projectile.physicsBody?.fieldBitMask = 0
// Projectile not affected by any fields
```

### Field Regions

**Limit the area where a field has effect.**

```swift
// Circular region
let gravityField = SKFieldNode.radialGravityField()
gravityField.region = SKRegion(radius: 200)  // Only affects bodies within 200 points
gravityField.position = CGPoint(x: 400, y: 300)
addChild(gravityField)

// Rectangular region
let windField = SKFieldNode.velocityField(withVector: vector_float3(50, 0, 0))
windField.region = SKRegion(size: CGSize(width: 300, height: 600))
addChild(windField)

// Infinite region (default)
let dragField = SKFieldNode.dragField()
dragField.region = SKRegion()  // Affects entire scene
addChild(dragField)

// Path-based region
let path = CGMutablePath()
path.addEllipse(in: CGRect(x: -100, y: -100, width: 200, height: 200))
let customRegion = SKRegion(path: path)
let customField = SKFieldNode.radialGravityField()
customField.region = customRegion
addChild(customField)
```

### Field Strength and Falloff

**Control how field strength changes with distance.**

```swift
let gravityField = SKFieldNode.radialGravityField()
gravityField.strength = 10.0  // Base strength

// Falloff determines how quickly strength decreases with distance
gravityField.falloff = 2.0    // Default: inverse square (1/r²)
gravityField.falloff = 1.0    // Linear falloff (1/r)
gravityField.falloff = 0.0    // No falloff (constant strength)
gravityField.falloff = 3.0    // Faster falloff (1/r³)

// Minimum radius (field has no effect closer than this)
gravityField.minimumRadius = 50.0

addChild(gravityField)
```

### Practical Field Examples

#### Black Hole (Strong Radial Gravity)

```swift
func createBlackHole(at position: CGPoint) -> SKNode {
    let blackHole = SKSpriteNode(imageNamed: "blackhole")
    blackHole.position = position

    let gravityField = SKFieldNode.radialGravityField()
    gravityField.strength = 20.0
    gravityField.falloff = 2.0
    gravityField.region = SKRegion(radius: 400)
    gravityField.categoryBitMask = FieldCategory.gravity

    blackHole.addChild(gravityField)
    return blackHole
}
```

#### Wind Zone (Velocity Field)

```swift
func createWindZone(rect: CGRect, direction: CGVector) -> SKFieldNode {
    let windField = SKFieldNode.velocityField(
        withVector: vector_float3(Float(direction.dx), Float(direction.dy), 0)
    )
    windField.strength = 1.0
    windField.region = SKRegion(size: rect.size)
    windField.position = CGPoint(x: rect.midX, y: rect.midY)
    windField.categoryBitMask = FieldCategory.wind

    return windField
}
```

#### Force Field Shield (Repelling Field)

```swift
func activateShield(on ship: SKSpriteNode, duration: TimeInterval) {
    // Negative strength = repulsion
    let shieldField = SKFieldNode.radialGravityField()
    shieldField.strength = -15.0  // Negative = repel
    shieldField.falloff = 3.0     // Fast falloff
    shieldField.region = SKRegion(radius: 100)
    shieldField.categoryBitMask = FieldCategory.magnetic

    ship.addChild(shieldField)

    // Animate shield weakening and removal
    let fadeOut = SKAction.customAction(withDuration: duration) { node, elapsedTime in
        let progress = elapsedTime / CGFloat(duration)
        if let field = node as? SKFieldNode {
            field.strength = -15.0 * (1.0 - progress)
        }
    }
    let remove = SKAction.removeFromParent()
    shieldField.run(SKAction.sequence([fadeOut, remove]))
}
```

#### Underwater Drag

```swift
func createWaterZone(rect: CGRect) -> SKNode {
    let waterZone = SKNode()
    waterZone.position = CGPoint(x: rect.midX, y: rect.midY)

    // Drag field slows objects
    let dragField = SKFieldNode.dragField()
    dragField.strength = 2.0  // Higher = more drag
    dragField.region = SKRegion(size: rect.size)
    dragField.categoryBitMask = FieldCategory.drag

    waterZone.addChild(dragField)
    return waterZone
}
```

#### Tornado (Vortex + Upward Force)

```swift
func createTornado(at position: CGPoint) -> SKNode {
    let tornado = SKNode()
    tornado.position = position

    // Vortex for circular motion
    let vortexField = SKFieldNode.vortexField()
    vortexField.strength = 5.0
    vortexField.region = SKRegion(radius: 150)
    vortexField.categoryBitMask = FieldCategory.wind

    // Linear gravity for upward pull
    let liftField = SKFieldNode.linearGravityField(withVector: vector_float3(0, 10, 0))
    liftField.strength = 1.0
    liftField.region = SKRegion(radius: 150)
    liftField.categoryBitMask = FieldCategory.wind

    tornado.addChild(vortexField)
    tornado.addChild(liftField)

    return tornado
}
```

### Field Performance Considerations

```swift
// Good: Limited region
let field = SKFieldNode.radialGravityField()
field.region = SKRegion(radius: 300)  // Only calculates for nearby bodies

// Avoid: Infinite region with many bodies
let field = SKFieldNode.radialGravityField()
field.region = SKRegion()  // Affects ALL bodies in scene (expensive!)

// Good: Use categories to limit affected bodies
field.categoryBitMask = FieldCategory.gravity
player.physicsBody?.fieldBitMask = FieldCategory.gravity  // Only player affected

// Good: Disable when not needed
field.isEnabled = false  // Temporarily disable field
```

### Animating Fields

```swift
// Pulse effect
let pulseUp = SKAction.customAction(withDuration: 1.0) { node, elapsedTime in
    if let field = node as? SKFieldNode {
        field.strength = 5.0 + sin(elapsedTime * .pi) * 3.0
    }
}
gravityField.run(SKAction.repeatForever(pulseUp))

// Moving field
let moveAction = SKAction.move(by: CGVector(dx: 200, dy: 0), duration: 3.0)
windField.run(SKAction.repeatForever(SKAction.sequence([moveAction, moveAction.reversed()])))

// Rotating field (for directional fields)
let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 5.0)
linearGravityField.run(SKAction.repeatForever(rotateAction))
```

---

## Joints and Constraints

### Common Joint Types

```swift
// Spring joint (elastic connection)
let spring = SKPhysicsJointSpring.joint(
    withBodyA: bodyA,
    bodyB: bodyB,
    anchorA: bodyA.node!.position,
    anchorB: bodyB.node!.position
)
spring.frequency = 4.0  // Oscillation frequency
spring.damping = 0.5    // Damping factor
physicsWorld.add(spring)

// Fixed joint (rigid connection)
let fixed = SKPhysicsJointFixed.joint(
    withBodyA: bodyA,
    bodyB: bodyB,
    anchor: connectionPoint
)
physicsWorld.add(fixed)

// Pin joint (rotation around point)
let pin = SKPhysicsJointPin.joint(
    withBodyA: bodyA,
    bodyB: bodyB,
    anchor: pivotPoint
)
pin.frictionTorque = 0.5  // Rotation resistance
pin.shouldEnableLimits = true
pin.lowerAngleLimit = -.pi / 4
pin.upperAngleLimit = .pi / 4
physicsWorld.add(pin)

// Slider joint (movement along axis)
let slider = SKPhysicsJointSliding.joint(
    withBodyA: bodyA,
    bodyB: bodyB,
    anchor: startPoint,
    axis: CGVector(dx: 1, dy: 0)
)
slider.shouldEnableLimits = true
slider.lowerDistanceLimit = 0
slider.upperDistanceLimit = 200
physicsWorld.add(slider)
```

---

## Raycasting and Queries

### Physics Queries

```swift
// Raycast to find what body is at point
let point = CGPoint(x: 100, y: 200)
if let body = physicsWorld.body(at: point) {
    print("Found body: \(body)")
}

// Raycast along line
let start = CGPoint(x: 0, y: 0)
let end = CGPoint(x: 100, y: 100)
if let body = physicsWorld.body(alongRayStart: start, end: end) {
    print("Hit body along ray")
}

// Query with rectangle
let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
physicsWorld.enumerateBodies(in: rect) { body, stop in
    print("Found body in rectangle: \(body)")
}
```

---

## Common Pitfalls

### Modifying Physics During Simulation

```swift
// Wrong: Direct position changes fight physics
override func update(_ currentTime: TimeInterval) {
    player.position = targetPosition  // Conflicts with physics!
}

// Correct: Use forces and impulses
func jump() {
    player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 10))
}

func move(direction: CGVector) {
    player.physicsBody?.applyForce(direction * moveForce)
}

// Or use velocity for direct control
func updateMovement() {
    let targetVelocityX: CGFloat = inputDirection.x * maxSpeed
    let currentVelocityX = player.physicsBody?.velocity.dx ?? 0
    let diff = targetVelocityX - currentVelocityX

    player.physicsBody?.applyForce(CGVector(dx: diff * acceleration, dy: 0))
}
```

### Physics Body on Removed Node

```swift
// Wrong: Physics body still active after node removal
func destroyEnemy(_ enemy: SKNode) {
    enemy.removeFromParent()
    // Physics body may still exist in simulation!
}

// Correct: Clear physics body first
func destroyEnemy(_ enemy: SKNode) {
    enemy.physicsBody = nil  // Remove physics first
    enemy.removeFromParent()
}
```

### Precise Collision Detection

```swift
// Only enable for fast-moving objects that might tunnel through
let bullet = SKSpriteNode(color: .yellow, size: CGSize(width: 4, height: 4))
bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
bullet.physicsBody?.usesPreciseCollisionDetection = true  // Only for fast objects!

// For normal objects, leave disabled (better performance)
let player = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
player.physicsBody?.usesPreciseCollisionDetection = false  // Default
```

---

## Checklist

- [ ] Use simplest physics shape (circle > rectangle > polygon > texture)
- [ ] Define physics categories in one place (max 32 categories per scene)
- [ ] Configure all three bitmasks (category, collision, contactTest)
- [ ] Set `isDynamic = false` for static objects
- [ ] Disable `allowsRotation` for characters
- [ ] Use deferred removal for nodes destroyed by collisions
- [ ] Apply forces/impulses instead of setting position directly
- [ ] Clear physics body before removing node
- [ ] Enable `usesPreciseCollisionDetection` only for fast objects
- [ ] Use joints for connected physics objects
- [ ] Remember edge-based bodies don't collide with each other
