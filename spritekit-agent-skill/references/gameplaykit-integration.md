# GameplayKit Integration

Integrating GameplayKit's entity-component system with SpriteKit.

---

## Overview

GameplayKit provides a robust entity-component architecture that pairs well with SpriteKit's visual nodes. This separation allows:
- **Clean separation** of game logic from visual representation
- **Reusable components** across different entity types
- **Data-driven design** for easier balancing and modification
- **Better testability** of game logic

---

## Basic Entity-Component Setup

### Sprite Component

Connects the GameplayKit entity to the SpriteKit node tree:

```swift
import GameplayKit
import SpriteKit

class SpriteComponent: GKComponent {
    let node: SKSpriteNode

    init(texture: SKTexture, size: CGSize? = nil) {
        self.node = SKSpriteNode(texture: texture, size: size)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willRemoveFromEntity() {
        // Clean up when component is removed
        node.removeFromParent()
    }
}
```

### Physics Component

Manages physics body and collision:

```swift
class PhysicsComponent: GKComponent {
    var physicsBody: SKPhysicsBody
    var previousPosition: CGPoint = .zero

    init(physicsBody: SKPhysicsBody) {
        self.physicsBody = physicsBody
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didAddToEntity() {
        // Connect physics body to the sprite node
        if let spriteComponent = entity?.component(ofType: SpriteComponent.self) {
            spriteComponent.node.physicsBody = physicsBody
        }
    }

    override func update(deltaTime seconds: TimeInterval) {
        // Store previous position for interpolation or rollback
        previousPosition = physicsBody.node?.position ?? .zero
    }
}
```

### Movement Component

Handles AI and movement logic:

```swift
class MovementComponent: GKComponent {
    var velocity: CGVector = .zero
    var maxSpeed: CGFloat = 200.0
    var acceleration: CGFloat = 500.0

    override func update(deltaTime seconds: TimeInterval) {
        guard let spriteComponent = entity?.component(ofType: SpriteComponent.self) else { return }

        // Apply velocity
        let dx = velocity.dx * CGFloat(seconds)
        let dy = velocity.dy * CGFloat(seconds)
        spriteComponent.node.position.x += dx
        spriteComponent.node.position.y += dy
    }

    func moveTowards(target: CGPoint) {
        guard let spriteComponent = entity?.component(ofType: SpriteComponent.self) else { return }
        let currentPos = spriteComponent.node.position

        let dx = target.x - currentPos.x
        let dy = target.y - currentPos.y
        let distance = hypot(dx, dy)

        if distance > 0 {
            let normalizedX = dx / distance
            let normalizedY = dy / distance

            velocity.dx = normalizedX * maxSpeed
            velocity.dy = normalizedY * maxSpeed
        }
    }

    func stop() {
        velocity = .zero
    }
}
```

---

## Entity Management

### Entity Manager

Centralized system for creating, tracking, and removing entities:

```swift
class EntityManager {
    var entities: Set<GKEntity> = []
    var toRemove: Set<GKEntity> = []
    weak var scene: SKScene?

    init(scene: SKScene) {
        self.scene = scene
    }

    func add(entity: GKEntity) {
        entities.insert(entity)

        // Add sprite to scene if entity has sprite component
        if let spriteComponent = entity.component(ofType: SpriteComponent.self) {
            scene?.addChild(spriteComponent.node)
        }
    }

    func remove(entity: GKEntity) {
        toRemove.insert(entity)
    }

    func update(deltaTime: TimeInterval) {
        // Update all entities
        for entity in entities {
            entity.update(deltaTime: deltaTime)
        }

        // Remove marked entities
        for entity in toRemove {
            if let spriteComponent = entity.component(ofType: SpriteComponent.self) {
                spriteComponent.node.removeFromParent()
            }
            entities.remove(entity)
        }
        toRemove.removeAll()
    }

    // Helper methods for entity queries
    func entitiesWithComponents<T: GKComponent>(_ componentType: T.Type) -> [GKEntity] {
        return entities.filter { $0.component(ofType: T.self) != nil }
    }

    func playerEntity() -> GKEntity? {
        return entities.first { $0.component(ofType: PlayerComponent.self) != nil }
    }
}
```

---

## Creating Game Entities

### Player Entity

```swift
func createPlayer(at position: CGPoint, entityManager: EntityManager) -> GKEntity {
    let player = GKEntity()

    // Visual component
    let spriteComponent = SpriteComponent(texture: SKTexture(imageNamed: "player"))
    spriteComponent.node.position = position
    spriteComponent.node.zPosition = 10
    player.addComponent(spriteComponent)

    // Physics component
    let physicsBody = SKPhysicsBody(circleOfRadius: 20)
    physicsBody.categoryBitMask = PhysicsCategory.player
    physicsBody.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.powerUp
    physicsBody.collisionBitMask = PhysicsCategory.obstacle
    physicsBody.allowsRotation = false
    let physicsComponent = PhysicsComponent(physicsBody: physicsBody)
    player.addComponent(physicsComponent)

    // Movement component
    let movementComponent = MovementComponent()
    movementComponent.maxSpeed = 300.0
    player.addComponent(movementComponent)

    // Player-specific component (for tagging)
    player.addComponent(PlayerComponent())

    entityManager.add(entity: player)
    return player
}
```

### Enemy Entity

```swift
func createEnemy(at position: CGPoint, target: GKEntity, entityManager: EntityManager) -> GKEntity {
    let enemy = GKEntity()

    // Visual
    let spriteComponent = SpriteComponent(texture: SKTexture(imageNamed: "enemy"))
    spriteComponent.node.position = position
    spriteComponent.node.zPosition = 5
    enemy.addComponent(spriteComponent)

    // Physics
    let physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 40))
    physicsBody.categoryBitMask = PhysicsCategory.enemy
    let physicsComponent = PhysicsComponent(physicsBody: physicsBody)
    enemy.addComponent(physicsComponent)

    // AI Movement - follows target
    let chaseComponent = ChaseComponent(targetEntity: target)
    chaseComponent.maxSpeed = 150.0
    enemy.addComponent(chaseComponent)

    // Health
    let healthComponent = HealthComponent(maxHealth: 100)
    enemy.addComponent(healthComponent)

    entityManager.add(entity: enemy)
    return enemy
}
```

---

## Advanced Components

### Health Component

```swift
class HealthComponent: GKComponent {
    var maxHealth: Int
    var currentHealth: Int

    var isDead: Bool { currentHealth <= 0 }
    var healthPercentage: CGFloat {
        return CGFloat(currentHealth) / CGFloat(maxHealth)
    }

    init(maxHealth: Int) {
        self.maxHealth = maxHealth
        self.currentHealth = maxHealth
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func takeDamage(_ amount: Int) {
        currentHealth -= amount
        if currentHealth < 0 { currentHealth = 0 }

        // Update visual if entity has sprite
        if let spriteComponent = entity?.component(ofType: SpriteComponent.self) {
            let flashAction = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
            ])
            spriteComponent.node.run(flashAction)
        }
    }

    func heal(_ amount: Int) {
        currentHealth += amount
        if currentHealth > maxHealth { currentHealth = maxHealth }
    }
}
```

### AI Chase Component

```swift
class ChaseComponent: GKComponent {
    weak var targetEntity: GKEntity?
    var maxSpeed: CGFloat = 100.0
    var updateInterval: TimeInterval = 0.5
    var timeSinceLastUpdate: TimeInterval = 0

    init(targetEntity: GKEntity?) {
        self.targetEntity = targetEntity
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(deltaTime seconds: TimeInterval) {
        timeSinceLastUpdate += seconds

        // Update pathfinding periodically, not every frame
        guard timeSinceLastUpdate >= updateInterval else { return }
        timeSinceLastUpdate = 0

        guard let targetEntity = targetEntity,
              let targetSprite = targetEntity.component(ofType: SpriteComponent.self)?.node,
              let mySprite = entity?.component(ofType: SpriteComponent.self)?.node else { return }

        let targetPos = targetSprite.position
        let myPos = mySprite.position

        // Simple movement towards target
        let dx = targetPos.x - myPos.x
        let dy = targetPos.y - myPos.y
        let distance = hypot(dx, dy)

        if distance > 0 && distance < 500 {  // Only chase if within range
            let normalizedX = dx / distance
            let normalizedY = dy / distance

            // Apply velocity through physics if available
            if let physicsComponent = entity?.component(ofType: PhysicsComponent.self) {
                physicsComponent.physicsBody.velocity = CGVector(
                    dx: normalizedX * maxSpeed,
                    dy: normalizedY * maxSpeed
                )
            }
        }
    }
}
```

---

## State Machines (GKStateMachine)

### Enemy States

```swift
import GameplayKit

class EnemyState: GKState {
    weak var entity: GKEntity?

    init(entity: GKEntity) {
        self.entity = entity
        super.init()
    }
}

class IdleState: EnemyState {
    var idleTime: TimeInterval = 0
    let maxIdleTime: TimeInterval = 2.0

    override func update(deltaTime seconds: TimeInterval) {
        idleTime += seconds

        // Transition to chase if idle too long
        if idleTime >= maxIdleTime {
            stateMachine?.enter(ChaseState.self)
        }
    }

    override func didEnter(from previousState: GKState?) {
        idleTime = 0
        // Stop movement
        if let physics = entity?.component(ofType: PhysicsComponent.self) {
            physics.physicsBody.velocity = .zero
        }
    }
}

class ChaseState: EnemyState {
    override func update(deltaTime seconds: TimeInterval) {
        // Chase logic handled by ChaseComponent
        // This state just ensures the component is active
    }

    override func didEnter(from previousState: GKState?) {
        // Visual indicator - turn red when chasing
        if let sprite = entity?.component(ofType: SpriteComponent.self) {
            sprite.node.color = .red
            sprite.node.colorBlendFactor = 0.3
        }
    }

    override func willExit(to nextState: GKState) {
        // Reset visual
        if let sprite = entity?.component(ofType: SpriteComponent.self) {
            sprite.node.colorBlendFactor = 0
        }
    }
}

// Setup state machine for enemy
func setupEnemyAI(enemy: GKEntity, target: GKEntity) {
    let stateMachine = GKStateMachine(states: [
        IdleState(entity: enemy),
        ChaseState(entity: enemy)
    ])

    // Store state machine in a custom component
    let stateComponent = StateMachineComponent(stateMachine: stateMachine)
    enemy.addComponent(stateComponent)

    stateMachine.enter(IdleState.self)
}

class StateMachineComponent: GKComponent {
    let stateMachine: GKStateMachine

    init(stateMachine: GKStateMachine) {
        self.stateMachine = stateMachine
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(deltaTime seconds: TimeInterval) {
        stateMachine.update(deltaTime: seconds)
    }
}
```

---

## Integration with Scene

### Complete Scene Example

```swift
class GameplayKitScene: SKScene, SKPhysicsContactDelegate {
    var entityManager: EntityManager!
    var player: GKEntity!
    var lastUpdateTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        entityManager = EntityManager(scene: self)
        physicsWorld.contactDelegate = self

        // Create player
        player = createPlayer(at: CGPoint(x: 0, y: 0), entityManager: entityManager)

        // Create enemies
        for i in 0..<5 {
            let position = CGPoint(x: CGFloat.random(in: -300...300),
                                 y: CGFloat.random(in: -300...300))
            createEnemy(at: position, target: player, entityManager: entityManager)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Update all entities through manager
        entityManager.update(deltaTime: deltaTime)
    }

    // Handle physics contacts between entities
    func didBegin(_ contact: SKPhysicsContact) {
        // Find entities from physics bodies
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB

        // Check for player-enemy collision
        if isPlayerEnemyCollision(bodyA, bodyB) {
            handlePlayerEnemyCollision(bodyA: bodyA, bodyB: bodyB)
        }
    }

    private func isPlayerEnemyCollision(_ bodyA: SKPhysicsBody, _ bodyB: SKPhysicsBody) -> Bool {
        let playerEnemy = (bodyA.categoryBitMask == PhysicsCategory.player &&
                          bodyB.categoryBitMask == PhysicsCategory.enemy)
        let enemyPlayer = (bodyA.categoryBitMask == PhysicsCategory.enemy &&
                          bodyB.categoryBitMask == PhysicsCategory.player)
        return playerEnemy || enemyPlayer
    }

    private func handlePlayerEnemyCollision(bodyA: SKPhysicsBody, bodyB: SKPhysicsBody) {
        // Apply damage through component system
        let enemyBody = bodyA.categoryBitMask == PhysicsCategory.enemy ? bodyA : bodyB
        let enemyNode = enemyBody.node

        // Find entity and apply damage
        for entity in entityManager.entities {
            if let spriteComponent = entity.component(ofType: SpriteComponent.self),
               spriteComponent.node == enemyNode,
               let healthComponent = entity.component(ofType: HealthComponent.self) {
                healthComponent.takeDamage(20)

                if healthComponent.isDead {
                    entityManager.remove(entity: entity)
                }
            }
        }
    }
}
```

---

## Checklist

- [ ] Use SpriteComponent for visual representation
- [ ] Use PhysicsComponent for physics bodies
- [ ] Create EntityManager to handle entity lifecycle
- [ ] Separate game logic into focused components
- [ ] Use GKStateMachine for complex entity behaviors
- [ ] Query entities by component type when needed
- [ ] Clean up entities properly to avoid memory leaks
- [ ] Keep components independent and reusable
