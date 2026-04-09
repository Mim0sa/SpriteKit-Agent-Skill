---
name: spritekit-pro
description: Reviews, writes, and optimizes SpriteKit game code for correctness, modern API usage, performance, and cross-platform compatibility. Use when reading, writing, or reviewing SpriteKit projects.
license: MIT
metadata:
  version: "0.1"
---

Review SpriteKit code for correctness, modern API usage, performance, and cross-platform compatibility. Report only genuine problems — do not nitpick or invent issues.

Review process:

1. Validate scene hierarchy and lifecycle using `references/scene-architecture.md`.
1. Check node lifecycle, memory management, and pooling using `references/node-management.md`.
1. Verify physics body configuration, collision setup, and simulation correctness using `references/physics-patterns.md`.
1. Validate texture atlases, animation state machines, and action usage using `references/animation-sprites.md`.
1. Check asset loading strategy, texture filtering, and memory cleanup using `references/asset-management.md`.
1. Ensure the game loop and frame cycle methods are used correctly using `references/game-loop-patterns.md`.
1. Audit rendering performance — draw calls, node count, culling, shaders using `references/performance-optimization.md`.
1. Validate particle system configuration and optimization using `references/particle-systems.md`.
1. Check input handling for target platforms using `references/input-handling.md`.
1. Validate audio setup and spatial audio configuration using `references/audio-integration.md`.
1. Check cross-platform compatibility and visionOS restrictions using `references/cross-platform.md`.
1. If tile maps are present, validate tile set and physics setup using `references/tilemap-patterns.md`.
1. If shaders or Metal integration are present, validate using `references/rendering-pipeline.md`.
1. If SwiftUI integration is present, validate state sharing and lifecycle using `references/swiftui-integration.md`.
1. If GameplayKit is used, validate entity-component architecture using `references/gameplaykit-integration.md`.

If doing a partial review, load only the relevant reference files.


## Core Instructions

- SpriteKit minimum supported versions: iOS 7 / macOS 10.9 / tvOS 9 / watchOS 3.
- SpriteKit renders via Metal on all platforms — GLSL shader syntax is supported but compiled to MSL at runtime.
- Do not introduce third-party game frameworks without asking first.
- SpriteKit is not supported in native visionOS apps; always recommend RealityKit for native visionOS targets.
- Prefer `@Observable` (iOS 17+) over `ObservableObject` for SwiftUI state sharing.
- Use `[weak self]` in all `SKAction.run` blocks without exception.
- Never remove nodes directly inside `didBegin(_:)` — always defer to `didSimulatePhysics()`.


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
- `references/gameplaykit-integration.md` — GKEntity/GKComponent, EntityManager, GKStateMachine.
