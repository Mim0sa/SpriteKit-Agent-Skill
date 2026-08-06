# Node Management

- Define frequently queried node names as constants so lookups and `.sks` names stay consistent.
- Keep direct references to frequently accessed nodes (player, camera, HUD) — avoid `childNode(withName:)` in hot paths.
- Avoid recursive name searches (`"//name"` prefix in `childNode(withName:)` / `enumerateChildNodes`) in measured hot paths; search a known subtree or retain the node instead.
- Break a repeating or long-lived node-action-closure ownership cycle with `[weak self]` or guaranteed action cancellation at the node's ownership boundary. Treat a finite strong capture as temporary only when the action is guaranteed to complete or be canceled while the node remains reachable; a detached node's paused action can otherwise retain the cycle indefinitely.
- Before pooling or retaining a removed node for reuse, stop actions and reset mutable physics state. A node that is simply removed and released does not require manual teardown of every property.
- Queue identified nodes for deferred removal and process them in `didSimulatePhysics()`; contact body ordering is not a gameplay identity, so select the target from either body by category or entity.
- Declare custom delegate properties `weak` when the delegate or its owner already retains the delegating object.
- Release view-bound or external resources in `willMove(from:)`. Reserve destructive node-tree cleanup for a permanent ownership boundary where the scene is guaranteed not to be reused; `deinit` is suitable for diagnostics, not for breaking a cycle that prevents `deinit` from running.
- Use object pooling for frequently spawned nodes only when allocation or asset loading is a measured cost.
- For off-screen nodes with active actions or custom updates, pause or remove them when gameplay semantics allow it. Hiding alone does not remove node-tree traversal cost.
- Subclass `SKSpriteNode` when an entity needs node-specific behavior; use composition when logic should remain independent of rendering.

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
class GameScene: SKScene {
    private var nodesToRemove = Set<SKNode>()

    func didBegin(_ contact: SKPhysicsContact) {
        let enemyBody: SKPhysicsBody?
        if (contact.bodyA.categoryBitMask & PhysicsCategory.enemy) != 0 {
            enemyBody = contact.bodyA
        } else if (contact.bodyB.categoryBitMask & PhysicsCategory.enemy) != 0 {
            enemyBody = contact.bodyB
        } else {
            enemyBody = nil
        }

        guard let enemy = enemyBody?.node else { return }
        nodesToRemove.insert(enemy)
    }

    override func didSimulatePhysics() {
        nodesToRemove.forEach { $0.removeFromParent() }
        nodesToRemove.removeAll(keepingCapacity: true)
    }
}
```

Declare `SKPhysicsContactDelegate` conformance using the platform- and compiler-appropriate form shown in `physics-patterns.md`. If removed nodes enter a pool, perform that pool's documented action and physics reset instead of the simple `removeFromParent()` above.

## Retain Cycle in Action Block

```swift
// Wrong when this node owns the repeating action: node -> action -> closure -> node
run(SKAction.repeatForever(
    SKAction.run { self.flipDirection() }
))

// Break the cycle for a repeating action.
run(SKAction.repeatForever(
    SKAction.run { [weak self] in self?.flipDirection() }
))

// Also valid when the owner guarantees stopTurning() at the lifecycle boundary.
run(SKAction.repeatForever(
    SKAction.run { self.flipDirection() }
), withKey: "turn")

func stopTurning() {
    removeAction(forKey: "turn")
}
```

## Off-Screen Culling

```swift
// Add only nodes whose actions and visibility may safely pause off-screen.
private let offscreenPausableLayer = SKNode()
// Add offscreenPausableLayer to worldLayer during scene setup.

func cullOffscreenNodes() {
    guard let view else { return }
    let viewCorners = [
        CGPoint(x: view.bounds.minX, y: view.bounds.minY),
        CGPoint(x: view.bounds.maxX, y: view.bounds.minY),
        CGPoint(x: view.bounds.maxX, y: view.bounds.maxY),
        CGPoint(x: view.bounds.minX, y: view.bounds.maxY)
    ]
    let worldCorners = viewCorners.map {
        offscreenPausableLayer.convert(convertPoint(fromView: $0), from: self)
    }
    let xValues = worldCorners.map(\.x)
    let yValues = worldCorners.map(\.y)
    let margin: CGFloat = 100
    let cullRect = CGRect(
        x: xValues.min()! - margin,
        y: yValues.min()! - margin,
        width: xValues.max()! - xValues.min()! + margin * 2,
        height: yValues.max()! - yValues.min()! + margin * 2
    )
    // Direct children have frames in offscreenPausableLayer's coordinate space.
    offscreenPausableLayer.children.forEach { node in
        let visible = cullRect.intersects(node.calculateAccumulatedFrame())
        node.isPaused = !visible
        node.isHidden = !visible
    }
}
```

Keep authoritative entities, physics-driven nodes, and anything that must continue simulating outside `offscreenPausableLayer`. Use render-only culling when visibility should change without changing action state.

## Scene Exit and Permanent Disposal

```swift
class GameScene: SKScene {
    override func willMove(from view: SKView) {
        // Stop view-bound services or named loops that didMove(to:) can restart.
        removeAction(forKey: "scene-only-loop")
        super.willMove(from: view)
    }

    // Call only when the scene owner has decided this scene will never be reused.
    func discardPermanently() {
        stopActionsRecursively(in: self)
        removeAllChildren()
    }

    private func stopActionsRecursively(in node: SKNode) {
        node.removeAllActions()
        node.children.forEach { stopActionsRecursively(in: $0) }
    }
}
```

Do not clear the node tree from `willMove(from:)` when the scene can be cached or presented again.
