# GameplayKit Integration

> This file is an index. Detailed rules and code are in the sub-files below.

GameplayKit integrates with SpriteKit through `GKScene`, `GKSKNodeComponent`, and the `GKSceneRootNodeType` protocol. The framework is organized into six areas — each has its own reference file:

- `gameplaykit-ecs.md` — `GKEntity` / `GKComponent` / `GKComponentSystem`, EntityManager, factory pattern.
- `gameplaykit-state-machines.md` — `GKStateMachine` / `GKState`, per-entity and scene-level FSM, state lifecycle hooks.
- `gameplaykit-pathfinding.md` — `GKObstacleGraph`, `GKMeshGraph`, `GKGridGraph`, obstacle generation from SKNode.
- `gameplaykit-agents.md` — `GKAgent2D`, `GKGoal`, `GKBehavior`, `GKAgentDelegate`, flocking, composite behaviors.
- `gameplaykit-randomization.md` — `GKRandomSource` subclasses, `GKRandomDistribution`, procedural noise (`GKPerlinNoiseSource`, `GKNoiseMap`, `SKTexture`).
- `gameplaykit-rules.md` — `GKRuleSystem`, `GKRule`, fuzzy logic grades, `GKDecisionTree`.
- `gameplaykit-spatial.md` — `GKQuadtree` / `GKOctree` / `GKRTree` for fast region and proximity queries.

GameplayKit also ships a strategist family (`GKMinmaxStrategist`, `GKMonteCarloStrategist`) driven by the `GKGameModel` / `GKGameModelPlayer` / `GKGameModelUpdate` protocols — for turn-based AI. This skill does not cover strategists in depth; consult Apple's GameplayKit docs directly if you need them.

## Cross-Cutting Rules

- Import `GameplayKit` at the top of any file that uses GK types — `SpriteKit` does not re-export it.
- GameplayKit is available on iOS 9+ / macOS 10.11+ / tvOS 9+ and to native visionOS apps. SpriteKit APIs are also present in the visionOS SDK, although Apple advises against using SpriteKit in apps created specifically for visionOS.
- When an agent and a physics body share an entity, choose one authoritative movement source and synchronize the other representation.
- Use one documented, seedable randomness pipeline for systems that require reproducibility. Unrelated cosmetic randomness may use a separate source when it does not affect replay state.
- Use `GKScene` to embed GameplayKit entities and graphs directly in `.sks` scene files when using the SpriteKit Scene Editor.

## GKScene / SKS Integration

```swift
// Load a .sks file that has embedded GameplayKit data
if let gkScene = GKScene(fileNamed: "GameScene"),
   let skScene = gkScene.rootNode as? GameScene {

    // Access pre-configured entities from the scene editor
    let entities = gkScene.entities

    // Access graphs built in the scene editor
    if let graph = gkScene.graphs["NavGraph"] as? GKObstacleGraph<GKGraphNode2D> {
        skScene.navGraph = graph
    }

    skView.presentScene(skScene)
}
```
