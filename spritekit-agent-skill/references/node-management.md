# Node Management

Best practices for SKNode lifecycle, memory management, and object pooling.

---

## Node Naming and Lookup

**Use consistent naming conventions for node lookup.**

```swift
// Correct: Type-safe node names
enum NodeName {
    static let player = "player"
    static let enemy = "enemy"
    static let projectile = "projectile"
    static let collectable = "collectable"
}

// Usage
player.name = NodeName.player

// Lookup
if let player = scene.childNode(withName: NodeName.player) {
    // Found player
}
```

**Avoid expensive recursive searches:**

```swift
// Wrong: Searches entire hierarchy
let enemy = scene.childNode(withName: "//enemy")  // Recursive search

// Correct: Search specific layer
let enemy = worldLayer.childNode(withName: NodeName.enemy)

// Better: Keep direct references
class GameScene: SKScene {
    var player: SKSpriteNode!
    var enemies: [SKSpriteNode] = []
}
```

---

## Object Pooling

**Use object pooling for frequently spawned/despawned objects.**

```swift
class NodePool<T: SKNode> {
    private var available: [T] = []
    private var inUse: Set<T> = []
    private let create: () -> T

    init(create: @escaping () -> T, initialCapacity: Int = 10) {
        self.create = create
        // Pre-warm pool
        for _ in 0..<initialCapacity {
            available.append(create())
        }
    }

    func acquire() -> T {
        let node: T
        if available.isEmpty {
            node = create()
        } else {
            node = available.removeLast()
        }
        inUse.insert(node)
        node.isHidden = false
        return node
    }

    func release(_ node: T) {
        guard inUse.contains(node) else { return }
        inUse.remove(node)
        node.removeFromParent()
        node.isHidden = true
        // Reset state
        node.physicsBody?.velocity = .zero
        node.physicsBody?.angularVelocity = 0
        available.append(node)
    }

    func releaseAll() {
        inUse.forEach { release($0) }
    }
}

// Usage
class GameScene: SKScene {
    lazy var bulletPool: NodePool<SKSpriteNode> = {
        NodePool(create: {
            let bullet = SKSpriteNode(color: .yellow, size: CGSize(width: 8, height: 8))
            bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
            return bullet
        }, initialCapacity: 50)
    }()

    func fireBullet(from position: CGPoint, direction: CGVector) {
        let bullet = bulletPool.acquire()
        bullet.position = position
        bullet.physicsBody?.velocity = direction
        worldLayer.addChild(bullet)
    }

    func bulletHitTarget(_ bullet: SKSpriteNode) {
        bulletPool.release(bullet)
    }
}
```

---

## Memory Management

### Avoid Retain Cycles

**Common retain cycle patterns:**

```swift
// Wrong: Strong reference in action block
class Enemy: SKSpriteNode {
    func startPatrol() {
        let action = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 100, y: 0, duration: 1),
                SKAction.run { self.flipDirection() },  // Retain cycle!
                SKAction.moveBy(x: -100, y: 0, duration: 1)
            ])
        )
        run(action)
    }
}

// Correct: Use weak self
func startPatrol() {
    let action = SKAction.repeatForever(
        SKAction.sequence([
            SKAction.moveBy(x: 100, y: 0, duration: 1),
            SKAction.run { [weak self] in self?.flipDirection() },
            SKAction.moveBy(x: -100, y: 0, duration: 1)
        ])
    )
    run(action)
}
```

### Proper Cleanup

```swift
class GameScene: SKScene {
    deinit {
        // Clean up actions
        removeAllActions()

        // Clean up children
        enumerateChildNodes(withName: "//.*") { node, _ in
            node.removeAllActions()
            node.physicsBody = nil
        }
        removeAllChildren()

        // Release pools
        bulletPool.releaseAll()
    }
}
```

### Weak References for Delegates

```swift
// Correct: Weak delegate
protocol GameSceneDelegate: AnyObject {
    func sceneDidFinish(_ scene: GameScene)
}

class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?  // Always weak
}

// Wrong: Strong delegate creates cycle
class BadScene: SKScene {
    var gameDelegate: GameSceneDelegate?  // Memory leak!
}
```

---

## Node State Management

### Using UserData vs Subclassing

**UserData for simple state:**

```swift
// Good for simple properties
enemy.userData = NSMutableDictionary()
enemy.userData?["health"] = 100
enemy.userData?["speed"] = 5.0
```

**Subclass for complex state:**

```swift
// Better for complex objects with behavior
class Enemy: SKSpriteNode {
    var health: Int = 100
    var speed: CGFloat = 5.0
    var behavior: EnemyBehavior

    init(behavior: EnemyBehavior) {
        self.behavior = behavior
        super.init(texture: nil, color: .red, size: CGSize(width: 40, height: 40))
    }

    func update(deltaTime: TimeInterval) {
        behavior.update(enemy: self, deltaTime: deltaTime)
    }
}
```

---

## Component Pattern

**For complex games, consider a component system:**

```swift
protocol Component {
    var entity: SKNode? { get set }
    func update(deltaTime: TimeInterval)
}

class MovementComponent: Component {
    weak var entity: SKNode?
    var velocity: CGVector = .zero
    var speed: CGFloat = 100

    func update(deltaTime: TimeInterval) {
        guard let entity = entity else { return }
        let dx = velocity.dx * speed * CGFloat(deltaTime)
        let dy = velocity.dy * speed * CGFloat(deltaTime)
        entity.position.x += dx
        entity.position.y += dy
    }
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

// Usage
let enemy = Entity()
enemy.addComponent(MovementComponent())
```

---

## Node Visibility and Culling

**Cull off-screen nodes for performance:**

```swift
class GameScene: SKScene {
    var visibleRect: CGRect {
        let size = self.size
        let origin = CGPoint(
            x: camera!.position.x - size.width / 2,
            y: camera!.position.y - size.height / 2
        )
        return CGRect(origin: origin, size: size)
    }

    func cullOffscreenNodes() {
        let padding: CGFloat = 100
        let cullRect = visibleRect.insetBy(dx: -padding, dy: -padding)

        worldLayer.enumerateChildNodes(withName: "//.*") { node, _ in
            let nodeRect = node.calculateAccumulatedFrame()
            let isVisible = cullRect.intersects(nodeRect)

            if !isVisible && node.name != NodeName.player {
                node.isPaused = true
                node.isHidden = true
                node.physicsBody?.isResting = true
            } else {
                node.isPaused = false
                node.isHidden = false
            }
            return nil
        }
    }
}
```

---

## Common Pitfalls

### Removing Nodes During Iteration

```swift
// Wrong: Modifying collection during enumeration
worldLayer.enumerateChildNodes(withName: NodeName.enemy) { node, _ in
    if node.position.y < -100 {
        node.removeFromParent()  // May cause crash!
    }
    return nil
}

// Correct: Collect then remove
var nodesToRemove: [SKNode] = []
worldLayer.enumerateChildNodes(withName: NodeName.enemy) { node, _ in
    if node.position.y < -100 {
        nodesToRemove.append(node)
    }
    return nil
}
nodesToRemove.forEach { $0.removeFromParent() }
```

### Physics Body After Removal

```swift
// Wrong: Physics body still exists after removal
func destroyEnemy(_ enemy: SKNode) {
    enemy.removeFromParent()
    // Physics body may still be in simulation!
}

// Correct: Clear physics before removal
func destroyEnemy(_ enemy: SKNode) {
    enemy.physicsBody = nil
    enemy.removeAllActions()
    enemy.removeFromParent()
}
```

---

## Checklist

- [ ] Use type-safe node naming (enum or constants)
- [ ] Keep direct references to important nodes
- [ ] Implement object pooling for frequently spawned objects
- [ ] Use [weak self] in all action blocks
- [ ] Clear physics bodies before node removal
- [ ] Implement proper deinit cleanup
- [ ] Use weak references for all delegates
- [ ] Implement off-screen culling for performance
- [ ] Don't modify node hierarchy during enumeration
- [ ] Consider component pattern for complex entities
