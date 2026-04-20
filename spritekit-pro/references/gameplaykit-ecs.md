# GameplayKit — Entity-Component System

- Use `GKEntity` + `GKComponent` to separate game logic from visual representation — `SpriteComponent` holds the `SKSpriteNode`; behavior components hold logic.
- Never scatter `entity.update(deltaTime:)` calls across the scene — drive all updates from a single `EntityManager.update(deltaTime:)` called in `GameScene.update(_:)`.
- Always use a central `EntityManager` to add, update, and remove entities — never mutate the entity set during its own iteration; buffer removals to a `toRemove` set.
- Hold `weak` references to other entities inside components (e.g., `ChaseComponent.target`) — strong references prevent deallocation when the target is removed.
- Override `willRemoveFromEntity()` in `SpriteComponent` to call `node.removeFromParent()` — this guarantees the visual is cleaned up whenever the component is detached.
- Override `didAddToEntity()` in `PhysicsComponent` to wire `physicsBody` onto the sprite node — avoids ordering bugs when components are added in different sequences.
- Prefer `GKComponent` over subclassing `SKNode` for game logic — logic stays portable and testable outside SpriteKit.
- Use `GKComponentSystem<T>` when you need all components of the same type to update in a strict, deterministic order (e.g., all `MovementComponent` before all `RenderComponent`).
- Cap `deltaTime` passed to `entity.update(deltaTime:)` at `1.0/20.0` — prevents physics tunneling and runaway AI after a frame spike.
- Do not store scene-level references (e.g., `SKCamera`, `HUD nodes`) inside components — pass them via initializer or a shared context object, not as retained properties.
- Use `GKSKNodeComponent` to bind an `SKNode` to a `GKEntity` — it automatically sets `node.entity`, so you can navigate from any `SKNode` hit (e.g., a contact callback's `bodyA.node`) back to its owning entity via `node.entity`. The Xcode SpriteKit scene editor emits `GKSKNodeComponent` automatically when you attach entities/components to nodes in `.sks`.

## Core Component Trio

```swift
import GameplayKit

// 1. Visual — owns the SKSpriteNode
class SpriteComponent: GKComponent {
    let node: SKSpriteNode

    init(texture: SKTexture, size: CGSize) {
        node = SKSpriteNode(texture: texture, size: size)
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func willRemoveFromEntity() {
        node.removeFromParent()      // Always clean up the visual
    }
}

// 2. Physics — wires body onto the sprite after being added
class PhysicsComponent: GKComponent {
    let body: SKPhysicsBody

    init(body: SKPhysicsBody) { self.body = body; super.init() }
    required init?(coder: NSCoder) { fatalError() }

    override func didAddToEntity() {
        entity?.component(ofType: SpriteComponent.self)?.node.physicsBody = body
    }
}

// 3. Health — pure data, no node dependency
class HealthComponent: GKComponent {
    var hp: Int
    let max: Int

    init(hp: Int) { self.hp = hp; self.max = hp; super.init() }
    required init?(coder: NSCoder) { fatalError() }

    var isDead: Bool { hp <= 0 }

    func take(damage: Int) {
        hp = max(0, hp - damage)
    }
}
```

## Entity Factory Pattern

```swift
// Build entities through factory methods, not inline scene setup
enum EntityFactory {
    static func makeEnemy(at position: CGPoint, target: GKEntity, scene: SKScene) -> GKEntity {
        let entity = GKEntity()
        let texture = SKTexture(imageNamed: "enemy")
        let sprite = SpriteComponent(texture: texture, size: CGSize(width: 40, height: 40))
        sprite.node.position = position
        scene.addChild(sprite.node)

        entity.addComponent(sprite)
        entity.addComponent(PhysicsComponent(body: .init(circleOfRadius: 20)))
        entity.addComponent(HealthComponent(hp: 30))
        entity.addComponent(ChaseComponent(target: target, speed: 120))
        return entity
    }
}
```

## Entity Manager

```swift
class EntityManager {
    private(set) var entities = Set<GKEntity>()
    private var toRemove   = Set<GKEntity>()
    weak var scene: SKScene?

    func add(_ entity: GKEntity) {
        entities.insert(entity)
    }

    // Buffer removal — never remove during update iteration
    func remove(_ entity: GKEntity) {
        toRemove.insert(entity)
    }

    func update(deltaTime: TimeInterval) {
        let dt = min(deltaTime, 1.0 / 20.0)         // Cap at 20 fps minimum
        entities.forEach { $0.update(deltaTime: dt) }

        // Flush deferred removals
        for entity in toRemove {
            entity.components.forEach { entity.removeComponent(ofType: type(of: $0)) }
            entities.remove(entity)
        }
        toRemove.removeAll()
    }
}
```

## GKComponentSystem — Ordered Updates

```swift
// All MovementComponents update before any RenderComponent
class GameScene: SKScene {
    let movementSystem = GKComponentSystem(componentClass: MovementComponent.self)
    let renderSystem   = GKComponentSystem(componentClass: RenderComponent.self)

    private var lastUpdateTime: TimeInterval = 0

    func addEntity(_ entity: GKEntity) {
        entityManager.add(entity)
        movementSystem.addComponent(foundIn: entity)
        renderSystem.addComponent(foundIn: entity)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0, 1.0 / 20.0)
        lastUpdateTime = currentTime
        movementSystem.update(deltaTime: dt)   // Movement first
        renderSystem.update(deltaTime: dt)     // Render second
    }
}
```

