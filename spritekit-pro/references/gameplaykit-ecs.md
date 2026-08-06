# GameplayKit — Entity-Component System

- Use `GKEntity` + `GKComponent` when the project benefits from separating behavior from its SpriteKit representation; do not introduce ECS for a simple node hierarchy without a demonstrated need.
- Give entity updates one documented owner so an entity is not updated twice in a frame. A central manager or ordered component systems are options, not requirements.
- When mutating the entity collection during updates, buffer additions or removals until iteration completes.
- Use `weak` references for non-owning relationships such as a transient chase target. Strong references are valid when the component intentionally owns the related object.
- Remove a sprite in `willRemoveFromEntity()` only when the component owns that node's scene lifetime.
- Wire dependent components in lifecycle hooks or a factory that guarantees ordering; choose one consistent strategy.
- Use components when behavior should be portable or independently testable; node subclasses remain valid for rendering-specific behavior.
- Use `GKComponentSystem<T>` when you need all components of the same type to update in a strict, deterministic order (e.g., all `MovementComponent` before all `RenderComponent`).
- Clamp or reset entity `deltaTime` after a frame spike according to gameplay requirements. This does not control SpriteKit's separate physics step.
- Pass scene services through explicit dependencies or a context object when components need them; avoid hidden global access.
- Use `GKSKNodeComponent` to bind an `SKNode` to a `GKEntity` — it automatically sets `node.entity`, so you can navigate from any `SKNode` hit (e.g., a contact callback's `bodyA.node`) back to its owning entity via `node.entity`. The Xcode SpriteKit scene editor emits `GKSKNodeComponent` automatically when you attach entities/components to nodes in `.sks`.

## Core Component Trio

```swift
import GameplayKit

// 1. Visual — owns the SKSpriteNode and its scene lifetime
class SpriteComponent: GKComponent {
    let node: SKSpriteNode

    init(texture: SKTexture, size: CGSize) {
        node = SKSpriteNode(texture: texture, size: size)
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func willRemoveFromEntity() {
        node.removeFromParent()      // Matches this component's documented ownership.
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
    let maxHP: Int

    init(hp: Int) { self.hp = hp; self.maxHP = hp; super.init() }
    required init?(coder: NSCoder) { fatalError() }

    var isDead: Bool { hp <= 0 }

    func take(damage: Int) {
        hp = Swift.max(0, hp - damage)
    }
}
```

## Entity Factory Pattern

```swift
// A factory is useful when every entity needs the same component wiring.
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
    var maximumDelta: TimeInterval = 0.05

    func add(_ entity: GKEntity) {
        entities.insert(entity)
    }

    // Buffer removal — never remove during update iteration
    func remove(_ entity: GKEntity) {
        toRemove.insert(entity)
    }

    func update(deltaTime: TimeInterval) {
        let dt = min(deltaTime, maximumDelta)
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
    private let maximumDelta: TimeInterval = 0.05  // Chosen for this game's resume behavior.

    func addEntity(_ entity: GKEntity) {
        entityManager.add(entity)
        movementSystem.addComponent(foundIn: entity)
        renderSystem.addComponent(foundIn: entity)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0, maximumDelta)
        lastUpdateTime = currentTime
        movementSystem.update(deltaTime: dt)   // Movement first
        renderSystem.update(deltaTime: dt)     // Render second
    }
}
```
