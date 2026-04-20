---
name: spritekit-pro
description: Reviews, writes, and optimizes SpriteKit game code for correctness, modern API usage, performance, and cross-platform compatibility. Use when reading, writing, or reviewing SpriteKit projects. Trigger whenever the user mentions SpriteKit, SKScene, SKNode, SKPhysicsBody, SKAction, SKEmitterNode, SKTileMapNode, GameplayKit (GKEntity, GKStateMachine, GKAgent, etc.), or any SpriteKit/GameplayKit class — even if the request is a simple question about game code, a bug fix, or adding a feature to an existing SpriteKit project.
license: MIT
metadata:
  version: "0.3"
---

Review SpriteKit code for correctness, modern API usage, performance, and cross-platform compatibility. Report only genuine problems — do not nitpick or invent issues.

Review process:

1. Validate scene hierarchy and lifecycle using `references/scene-architecture.md`.
2. Check node lifecycle, memory management, and pooling using `references/node-management.md`.
3. Verify physics body configuration, collision setup, and simulation correctness using `references/physics-patterns.md`.
4. Validate texture atlases, animation state machines, and action usage using `references/animation-sprites.md`.
5. Check asset loading strategy, texture filtering, and memory cleanup using `references/asset-management.md`.
6. Ensure the game loop and frame cycle methods are used correctly using `references/game-loop-patterns.md`.
7. Audit rendering performance — draw calls, node count, culling, shaders using `references/performance-optimization.md`.
8. Validate particle system configuration and optimization using `references/particle-systems.md`.
9. Check input handling for target platforms using `references/input-handling.md`.
10. Validate audio setup and spatial audio configuration using `references/audio-integration.md`.
11. Check cross-platform compatibility and visionOS restrictions using `references/cross-platform.md`.
12. If tile maps are present, validate tile set and physics setup using `references/tilemap-patterns.md`.
13. If shaders or Metal integration are present, validate using `references/rendering-pipeline.md`.
14. If SwiftUI integration is present, validate state sharing and lifecycle using `references/swiftui-integration.md`.
15. If GameplayKit is used, first check the index at `references/gameplaykit-integration.md`, then validate using the relevant sub-files: `references/gameplaykit-ecs.md`, `references/gameplaykit-state-machines.md`, `references/gameplaykit-pathfinding.md`, `references/gameplaykit-agents.md`, `references/gameplaykit-randomization.md`, `references/gameplaykit-rules.md`, `references/gameplaykit-spatial.md`.

If doing a partial review, load only the relevant reference files.


## Core Instructions

- Apple unified platform versioning at 26 — target `iOS 26 / macOS 26 / tvOS 26 / watchOS 26` for new projects (Xcode 26, Swift 6.3).
- SpriteKit is not supported in native visionOS apps — it only runs in iPhone/iPad compatibility mode. Recommend RealityKit for native visionOS targets.
- Do not introduce third-party game frameworks without asking first.
- Prefer `@Observable` over `ObservableObject` for SwiftUI state sharing.


## Output Format

Organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated (e.g., "Defer node removal to `didSimulatePhysics()`").
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.

Example output:

### GameScene.swift

**Line 42: Defer node removal to `didSimulatePhysics()` — removing during contact callbacks causes undefined behavior.**

```swift
// Before
func didBegin(_ contact: SKPhysicsContact) {
    contact.bodyB.node?.removeFromParent()
}

// After
func didBegin(_ contact: SKPhysicsContact) {
    nodesToRemove.append(contact.bodyB.node)
}

override func didSimulatePhysics() {
    nodesToRemove.forEach { $0.physicsBody = nil; $0.removeFromParent() }
    nodesToRemove.removeAll()
}
```

**Line 78: Use `[weak self]` in `SKAction.run` block — strong capture with `repeatForever` creates a retain cycle.**

```swift
// Before
run(SKAction.repeatForever(
    SKAction.run { self.spawnEnemy() }
))

// After
run(SKAction.repeatForever(
    SKAction.run { [weak self] in self?.spawnEnemy() }
))
```

### Summary

1. **Crash risk (high):** Node removal during contact callback on line 42.
2. **Memory leak (high):** Strong self capture in repeating action on line 78.

End of example.


## References

- `references/scene-architecture.md` — Scene lifecycle, layered node hierarchy, camera control, scene transitions.
- `references/node-management.md` — Node lifecycle, memory management, object pooling, culling.
- `references/physics-patterns.md` — Physics body types, category bitmasks, collision handling, fields, joints.
- `references/animation-sprites.md` — Texture atlases, frame animation, SKAction patterns, anchor points.
- `references/asset-management.md` — Atlas loading, texture filtering modes, memory cleanup strategy.
- `references/game-loop-patterns.md` — Frame cycle methods, delta time, fixed timestep, component systems.
- `references/performance-optimization.md` — Draw call reduction, node culling, SKView debug options, profiling.
- `references/particle-systems.md` — SKEmitterNode configuration, particle count limits, emitter pooling.
- `references/input-handling.md` — Touch (iOS), mouse (macOS), game controller (tvOS), unified abstraction.
- `references/audio-integration.md` — SKAudioNode, positional audio, spatial listener, AVAudioEngine.
- `references/cross-platform.md` — Platform detection, screen adaptation, visionOS restrictions.
- `references/tilemap-patterns.md` — SKTileMapNode creation, adjacency rules, physics generation, chunking.
- `references/rendering-pipeline.md` — SKShader (GLSL→Metal), SKRenderer, offscreen rendering, lighting.
- `references/swiftui-integration.md` — SpriteView, @Observable state sharing, UIViewControllerRepresentable.
- `references/gameplaykit-integration.md` — Index file; cross-cutting rules, GKScene/.sks integration.
- `references/gameplaykit-ecs.md` — GKEntity/GKComponent/GKComponentSystem, EntityManager, factory pattern.
- `references/gameplaykit-state-machines.md` — GKStateMachine/GKState, per-entity and scene-level FSM, lifecycle hooks.
- `references/gameplaykit-pathfinding.md` — GKObstacleGraph, GKMeshGraph, GKGridGraph, obstacle generation from SKNode.
- `references/gameplaykit-agents.md` — GKAgent2D, GKGoal, GKBehavior, GKAgentDelegate, flocking.
- `references/gameplaykit-randomization.md` — GKRandomSource, GKRandomDistribution, GKPerlinNoiseSource, GKNoiseMap.
- `references/gameplaykit-rules.md` — GKRuleSystem, GKRule, fuzzy logic, GKDecisionTree.
- `references/gameplaykit-spatial.md` — GKQuadtree/GKOctree/GKRTree for region and proximity queries.
