# Node Management

- Define node names as constants (enum or struct), never as inline string literals.
- Keep direct references to frequently accessed nodes (player, camera, HUD) — avoid `childNode(withName:)` in hot paths.
- Never use recursive name searches (`"//name"` prefix in `childNode(withName:)` / `enumerateChildNodes`) in hot paths — always search a specific layer instead.
- Use `[weak self]` in every `SKAction.run` block — omitting it always creates a retain cycle.
- Clear `physicsBody = nil` and call `removeAllActions()` before calling `removeFromParent()`.
- Use a `nodesToRemove: [SKNode]` array for deferred removal — process it in `didSimulatePhysics()`, never inside contact callbacks.
- Declare delegates `weak` — a strong delegate between scene and game controller creates a retain cycle.
- Implement `deinit` cleanup: `removeAllActions()`, then recurse over children to nil their physics bodies.
- Use object pooling for bullets, particles, and any objects spawned and destroyed frequently.
- Cull off-screen nodes by setting `isPaused = true` and `isHidden = true`; restore when they re-enter the viewport.
- Prefer subclassing `SKSpriteNode` for entities with complex state; use `userData` only for simple, transient properties.

## Node Naming

```swift
enum NodeName {
    static let player = "player"
    static let enemy = "enemy"
    static let bullet = "bullet"
}

// Lookup: search specific layer, not the whole tree
let enemy = worldLayer.childNode(withName: NodeName.enemy)
```

## Object Pooling

```swift
class NodePool<T: SKNode> {
    private var available: [T] = []
    private let create: () -> T

    init(create: @escaping () -> T, initialCapacity: Int = 20) {
        self.create = create
        (0..<initialCapacity).forEach { _ in available.append(create()) }
    }

    func acquire() -> T {
        let node = available.isEmpty ? create() : available.removeLast()
        node.isHidden = false
        return node
    }

    func release(_ node: T) {
        node.removeFromParent()
        node.removeAllActions()   // Stop any running actions before pooling
        node.isHidden = true
        node.physicsBody?.velocity = .zero
        node.physicsBody?.angularVelocity = 0
        available.append(node)
    }
}
```

## Deferred Removal

```swift
class GameScene: SKScene, SKPhysicsContactDelegate {
    private var nodesToRemove: [SKNode] = []

    func didBegin(_ contact: SKPhysicsContact) {
        // Mark only — never remove here
        guard let node = contact.bodyB.node else { return }
        nodesToRemove.append(node)
    }

    override func didSimulatePhysics() {
        nodesToRemove.forEach {
            $0.physicsBody = nil
            $0.removeAllActions()
            $0.removeFromParent()
        }
        nodesToRemove.removeAll()
    }
}
```

## Retain Cycle in Action Block

```swift
// Wrong: strong capture with repeatForever = retain cycle
SKAction.repeatForever(
    SKAction.run { self.flipDirection() }
)

// Correct
SKAction.repeatForever(
    SKAction.run { [weak self] in self?.flipDirection() }
)
```

## Off-Screen Culling

```swift
func cullOffscreenNodes() {
    guard let camera = camera else { return }
    let cullRect = CGRect(
        origin: CGPoint(x: camera.position.x - size.width / 2 - 100,
                        y: camera.position.y - size.height / 2 - 100),
        size: CGSize(width: size.width + 200, height: size.height + 200)
    )
    // Enumerate direct children of known layers — avoid recursive name searches
    worldLayer.children.forEach { node in
        let visible = cullRect.intersects(node.calculateAccumulatedFrame())
        node.isPaused = !visible
        node.isHidden = !visible
    }
}
```

## Proper Cleanup

```swift
class GameScene: SKScene {
    deinit {
        removeAllActions()
        // Recursive search acceptable here — deinit requires exhaustive cleanup
        enumerateChildNodes(withName: "//.+") { node, _ in
            node.removeAllActions()
            node.physicsBody = nil
        }
        removeAllChildren()
    }
}
```
