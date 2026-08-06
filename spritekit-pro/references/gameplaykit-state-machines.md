# GameplayKit — State Machines

- Use `GKStateMachine` when mutually exclusive modes have meaningful transition rules or entry/exit behavior; a small enum can be sufficient for simple state.
- Override `isValidNextState(_:)` when transitions are restricted. The default accepts transitions, so do not require an override for an intentionally unrestricted state.
- Use `didEnter(from:)` for side effects that happen once on entry (play animation, change tint, enable component) — not in `update(deltaTime:)`.
- Use `willExit(to:)` for cleanup that depends on the *next* state (e.g., stop a looping action only when transitioning to Dead, not Idle).
- Call `stateMachine.update(deltaTime:)` from the entity's or scene's `update(_:)` — the machine forwards the call to `currentState.update(deltaTime:)`.
- Use `canEnterState(_:)` before attempting a transition in response to external events (e.g., damage received) — avoids silent no-ops that are hard to debug.
- Keep `GKState` ownership explicit. Use a weak reference when the owner retains the state machine and the states would otherwise retain the owner; a strong reference is valid without a cycle.
- A top-level `GKStateMachine` can model game flow such as Menu → Playing → Paused → GameOver when transition hooks simplify system coordination.

## State Subclass Template

```swift
class EnemyChaseState: GKState {
    // Weak reference avoids retain cycle with the owning entity
    private weak var enemy: EnemyEntity?

    init(enemy: EnemyEntity) { self.enemy = enemy; super.init() }

    // Declare which transitions are legal FROM this state
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == EnemyFleeState.self || stateClass == EnemyDeadState.self
    }

    // One-shot setup on entry
    override func didEnter(from previousState: GKState?) {
        enemy?.sprite.color = .red
        enemy?.chaseComponent?.isEnabled = true
    }

    // Per-frame logic
    override func update(deltaTime seconds: TimeInterval) {
        guard let enemy else { return }
        if enemy.healthComponent.isDead {
            stateMachine?.enter(EnemyDeadState.self)
        }
    }

    // Cleanup on exit — knows the next state
    override func willExit(to nextState: GKState) {
        enemy?.chaseComponent?.isEnabled = false
        if nextState is EnemyDeadState {
            enemy?.sprite.color = .gray
        }
    }
}
```

## Wiring a State Machine on an Entity

```swift
class EnemyEntity: GKEntity {
    lazy var stateMachine = GKStateMachine(states: [
        EnemyIdleState(enemy: self),
        EnemyChaseState(enemy: self),
        EnemyDeadState(enemy: self),
    ])

    override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)
        stateMachine.update(deltaTime: seconds)    // forwards to currentState
    }
}

// Terminal state — no valid transitions out
class EnemyDeadState: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { false }
}
```

## Game UI State Machine

```swift
// Top-level scene state — controls which systems are active
class GameScene: SKScene {
    var uiStateMachine: GKStateMachine!

    override func didMove(to view: SKView) {
        uiStateMachine = GKStateMachine(states: [
            MenuState(scene: self),
            PlayingState(scene: self),
            PausedState(scene: self),
            GameOverState(scene: self)
        ])
        uiStateMachine.enter(MenuState.self)
    }

    override func update(_ currentTime: TimeInterval) {
        // Only update gameplay systems when in PlayingState
        if uiStateMachine.currentState is PlayingState {
            entityManager.update(deltaTime: computeDelta(currentTime))
        }
    }
}

class PausedState: GKState {
    private weak var scene: GameScene?

    init(scene: GameScene) { self.scene = scene; super.init() }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PlayingState.self   // Can only resume
    }

    override func didEnter(from previousState: GKState?) {
        scene?.physicsWorld.speed = 0     // Halt physics
        scene?.showPauseOverlay()
    }

    override func willExit(to nextState: GKState) {
        scene?.physicsWorld.speed = 1
        scene?.hidePauseOverlay()
    }
}
```

## Checking State Before Transitions

```swift
// Safe external event handling
func playerAttacked(enemy: EnemyEntity) {
    guard enemy.stateMachine.canEnterState(EnemyFleeState.self) else { return }
    enemy.stateMachine.enter(EnemyFleeState.self)
}

// Inspecting current state
if entity.stateMachine.currentState is EnemyDeadState {
    entityManager.remove(entity)
}
```
