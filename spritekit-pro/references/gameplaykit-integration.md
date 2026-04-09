# GameplayKit Integration

- Use `GKEntity` + `GKComponent` to separate game logic from visual representation — `SpriteComponent` holds the `SKSpriteNode`; other components hold behavior.
- Always use a central `EntityManager` to add, update, and deferred-remove entities — never mutate the entity set during its own iteration.
- Hold a `weak` reference to the target entity in `ChaseComponent` and similar AI components — a strong reference prevents deallocation when the target is removed.
- Update all entities from the scene's `update(_:)` by calling `entityManager.update(deltaTime:)` — do not scatter `entity.update` calls across the scene.
- Use `GKStateMachine` for entities with distinct behavioral states (Idle, Chase, Attack, Dead) — boolean flags become unmanageable past 2–3 states.
- Throttle AI pathfinding updates — update every 0.3–0.5 seconds rather than every frame.
- Clean up entity sprites in `EntityManager.remove(_:)` — call `spriteComponent.node.removeFromParent()` before removing the entity from the set.
- Prefer `GKComponent` over direct subclassing of `SKNode` for game logic — it keeps logic portable and testable outside of SpriteKit.

## Core Component Trio

```swift
import GameplayKit

// 1. Visual
class SpriteComponent: GKComponent {
    let node: SKSpriteNode
    init(texture: SKTexture, size: CGSize) {
        node = SKSpriteNode(texture: texture, size: size)
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func willRemoveFromEntity() { node.removeFromParent() }
}

// 2. Physics
class PhysicsComponent: GKComponent {
    let body: SKPhysicsBody
    init(body: SKPhysicsBody) { self.body = body; super.init() }
    required init?(coder: NSCoder) { fatalError() }
    override func didAddToEntity() {
        entity?.component(ofType: SpriteComponent.self)?.node.physicsBody = body
    }
}

// 3. AI Movement (throttled)
class ChaseComponent: GKComponent {
    weak var target: GKEntity?
    var speed: CGFloat = 150
    private var timer: TimeInterval = 0
    private let interval: TimeInterval = 0.4  // Throttle

    init(target: GKEntity) { self.target = target; super.init() }
    required init?(coder: NSCoder) { fatalError() }

    override func update(deltaTime seconds: TimeInterval) {
        timer += seconds
        guard timer >= interval else { return }
        timer = 0

        guard let myNode = entity?.component(ofType: SpriteComponent.self)?.node,
              let targetNode = target?.component(ofType: SpriteComponent.self)?.node else { return }
        let dx = targetNode.position.x - myNode.position.x
        let dy = targetNode.position.y - myNode.position.y
        let dist = hypot(dx, dy)
        guard dist > 0, dist < 600 else { return }
        entity?.component(ofType: PhysicsComponent.self)?.body.velocity =
            CGVector(dx: dx / dist * speed, dy: dy / dist * speed)
    }
}
```

## Entity Manager

```swift
class EntityManager {
    var entities = Set<GKEntity>()
    private var toRemove = Set<GKEntity>()
    weak var scene: SKScene?

    func add(_ entity: GKEntity) {
        entities.insert(entity)
        if let node = entity.component(ofType: SpriteComponent.self)?.node {
            scene?.addChild(node)
        }
    }

    func remove(_ entity: GKEntity) { toRemove.insert(entity) }

    func update(deltaTime: TimeInterval) {
        entities.forEach { $0.update(deltaTime: deltaTime) }
        toRemove.forEach { entity in
            entity.component(ofType: SpriteComponent.self)?.node.removeFromParent()
            entities.remove(entity)
        }
        toRemove.removeAll()
    }
}
```

## State Machine

```swift
class EnemyIdleState: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == EnemyChaseState.self
    }
    override func update(deltaTime seconds: TimeInterval) {
        // After idle period, transition
        stateMachine?.enter(EnemyChaseState.self)
    }
}

class EnemyChaseState: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == EnemyIdleState.self || stateClass == EnemyDeadState.self
    }
    override func didEnter(from previousState: GKState?) {
        // Activate chase component, change tint
    }
}

// Setup
let sm = GKStateMachine(states: [EnemyIdleState(), EnemyChaseState(), EnemyDeadState()])
sm.enter(EnemyIdleState.self)
```

## Scene Integration

```swift
class GameScene: SKScene {
    var entityManager: EntityManager!

    override func didMove(to view: SKView) {
        entityManager = EntityManager(scene: self)
        spawnPlayer()
        spawnEnemies(count: 5)
    }

    private var lastUpdateTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        let dt = min(rawDelta, 1.0 / 20.0)
        lastUpdateTime = currentTime
        entityManager.update(deltaTime: dt)
    }
}
```
