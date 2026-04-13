# GameplayKit — Agents, Goals, and Behaviors

- Use `GKAgent2D` (not `GKAgent3D`) for SpriteKit — it operates in the same 2D coordinate space.
- Implement `GKAgentDelegate` on the owning component or entity to synchronize the agent's `position`/`rotation` with the `SKSpriteNode` each frame — without it the agent simulates but nothing moves visually.
- Set `agent.maxSpeed` and `agent.maxAcceleration` to match your game's physics feel — these are the primary tuning knobs; `mass` affects how quickly the agent reacts to forces.
- Compose behaviors from multiple `GKGoal` instances with different weights via `GKBehavior(goals:andWeights:)` — weights are relative, not normalized.
- Use `GKCompositeBehavior` when goals need to be grouped and weighted as a unit (e.g., flocking = alignment + cohesion + separation, all weighted together vs. obstacle avoidance).
- Prefer `GKGoal(toAvoid:maxPredictionTime:)` over manual obstacle checks — the agent predicts future collisions and steers away proactively.
- Call `agent.update(deltaTime:)` from your entity's update loop — not directly from the scene, unless agents are managed by a `GKComponentSystem`.
- Separate the `GKAgent2D` from the display node — let the agent compute steering math, then copy `agent.position` into `node.position` in `agentDidUpdate(_:)`.
- Never use `GKAgent2D` with `SKPhysicsBody` directly — the agent moves by manipulating position, conflicting with physics simulation; choose one or the other per entity.

## Basic Agent Setup

```swift
import GameplayKit

class AgentComponent: GKComponent, GKAgentDelegate {
    let agent = GKAgent2D()

    // The node this agent drives
    private weak var node: SKSpriteNode?

    init(node: SKSpriteNode, maxSpeed: Float = 200, maxAcceleration: Float = 80) {
        self.node = node
        super.init()

        agent.delegate = self
        agent.maxSpeed = maxSpeed
        agent.maxAcceleration = maxAcceleration
        agent.mass = 0.1
        agent.radius = Float(node.size.width / 2)

        // Seed initial position from the node
        agent.position = SIMD2<Float>(Float(node.position.x), Float(node.position.y))
    }
    required init?(coder: NSCoder) { fatalError() }

    // Called BEFORE agent simulation — sync current node position into agent
    // Parameter type is GKAgent (base class); cast or use self.agent directly
    func agentWillUpdate(_ agent: GKAgent) {
        guard let node else { return }
        self.agent.position = SIMD2<Float>(Float(node.position.x), Float(node.position.y))
    }

    // Called AFTER agent simulation — write updated agent position back to node
    func agentDidUpdate(_ agent: GKAgent) {
        guard let node else { return }
        node.position = CGPoint(x: CGFloat(self.agent.position.x),
                                y: CGFloat(self.agent.position.y))
        // Optional: rotate node to face direction of travel
        node.zRotation = CGFloat(self.agent.rotation)
    }

    override func update(deltaTime seconds: TimeInterval) {
        agent.update(deltaTime: seconds)
    }
}
```

## Goals and Behaviors

```swift
// Seek — move directly toward a target point
let seekGoal = GKGoal(toSeekAgent: playerAgent)

// Flee — move away from a threat
let fleeGoal = GKGoal(toFleeAgent: playerAgent)

// Wander — random, smooth wandering motion
let wanderGoal = GKGoal(toWander: 50)   // speed parameter

// Follow a path (looping)
let path = GKPath(points: waypoints, radius: 10, cyclical: true)
let followGoal = GKGoal(toFollow: path, maxPredictionTime: 1.0, forward: true)
let stayGoal   = GKGoal(toStayOn: path, maxPredictionTime: 1.0)

// Avoid static obstacles
let obstacles = SKNode.obstacles(fromNodePhysicsBodies: wallNodes)
let avoidGoal = GKGoal(toAvoid: obstacles, maxPredictionTime: 0.5)

// Reach a target speed
let speedGoal = GKGoal(toReachTargetSpeed: 150)

// Compose goals into a behavior with relative weights
let behavior = GKBehavior(goals: [seekGoal, avoidGoal, wanderGoal],
                          andWeights: [1.0, 2.0, 0.3])  // Avoidance strongest
agent.behavior = behavior
```

## Flocking with GKCompositeBehavior

```swift
// Classic Reynolds flocking: separation, alignment, cohesion
func makeFlockBehavior(agents: [GKAgent2D], obstacles: [GKObstacle]) -> GKCompositeBehavior {
    let separation = GKGoal(toSeparateFrom: agents, maxDistance: 30, maxAngle: .pi)
    let alignment  = GKGoal(toAlignWith: agents, maxDistance: 80, maxAngle: .pi / 2)
    let cohesion   = GKGoal(toCohereWith: agents, maxDistance: 100, maxAngle: .pi)
    let avoidance  = GKGoal(toAvoid: obstacles, maxPredictionTime: 0.5)

    let flockBehavior = GKBehavior(goals: [separation, alignment, cohesion],
                                   andWeights: [2.0, 1.0, 1.0])
    let compositeBehavior = GKCompositeBehavior()
    compositeBehavior[flockBehavior] = 1.0
    compositeBehavior[GKBehavior(goal: avoidance, weight: 3.0)] = 1.0
    return compositeBehavior
}
```

## Dynamic Behavior Switching

```swift
// Swap behaviors based on game state — no new agent instance needed
class EnemyAgentComponent: GKComponent {
    let agent = GKAgent2D()
    private let chaseBehavior: GKBehavior
    private let fleeBehavior:  GKBehavior

    init(player: GKAgent2D) {
        chaseBehavior = GKBehavior(goal: GKGoal(toSeekAgent: player), weight: 1.0)
        fleeBehavior  = GKBehavior(goal: GKGoal(toFleeAgent: player), weight: 1.0)
        super.init()
        agent.behavior = chaseBehavior
    }
    required init?(coder: NSCoder) { fatalError() }

    func enterFlee() { agent.behavior = fleeBehavior }
    func enterChase() { agent.behavior = chaseBehavior }
}
```

## GKComponentSystem for Deterministic Agent Updates

```swift
// Ensures all agents update in a single pass — consistent with physics frame
let agentSystem = GKComponentSystem(componentClass: AgentComponent.self)

// Register when adding entities
agentSystem.addComponent(foundIn: entity)

// In scene update — update agents after physics, before rendering
// Store lastUpdateTime as a property and compute delta in update(_:)
override func update(_ currentTime: TimeInterval) {
    let dt = lastUpdateTime > 0 ? min(currentTime - lastUpdateTime, 1.0 / 20.0) : 0
    lastUpdateTime = currentTime
    agentSystem.update(deltaTime: dt)
}
```
