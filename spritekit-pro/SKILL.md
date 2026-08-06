---
name: spritekit-pro
description: Reviews, explains, writes, debugs, and optimizes SpriteKit code for correctness, modern API usage, performance, and cross-platform compatibility. Use whenever a task mentions SpriteKit or SpriteKit types such as SKScene, SKNode, SKSpriteNode, SKPhysicsBody, SKAction, SKEmitterNode, SKTileMapNode, SKShader, SKView, or SpriteView, including focused questions and small fixes. Also use for GameplayKit types such as GKEntity, GKComponent, GKStateMachine, or GKAgent when the surrounding project uses SpriteKit. Do not use for GameplayKit projects without SpriteKit or for general Swift questions.
license: MIT
metadata:
  version: "0.4"
---

Determine the task mode before loading references:

- **Explain:** Answer the question directly. Load only the references needed for the concepts involved.
- **Implement or fix:** Inspect the affected code, load only the references for the domains being changed, make the requested change, and verify it in proportion to risk.
- **Optimize:** Establish the reported or measured bottleneck first. Treat numeric budgets as starting points, not universal correctness limits.
- **Review:** Report only concrete issues supported by code evidence. Do not turn preferences or unmeasured performance concerns into violations.
- **Comprehensive audit:** Follow the ordered review process below and load every reference relevant to code that is actually present.

For partial tasks, select the relevant references first and skip unrelated domains. For a comprehensive audit, first inventory the frameworks, node types, callbacks, and platform-specific code that are actually present. Then follow this order, loading a reference only when its condition applies:

1. If scenes or scene transitions are present, validate hierarchy and lifecycle using `references/scene-architecture.md`.
2. If nodes are created, retained, removed, pooled, or culled, use `references/node-management.md`.
3. If physics bodies, contacts, fields, or joints are present, use `references/physics-patterns.md`.
4. If textures, sprite animation, or actions are present, use `references/animation-sprites.md`.
5. If assets, atlases, or texture loading are present, use `references/asset-management.md`.
6. If frame-cycle callbacks or time-based updates are present, use `references/game-loop-patterns.md`.
7. Audit rendering performance using `references/performance-optimization.md` when code or measurements indicate a rendering concern.
8. Validate particle configuration using `references/particle-systems.md` when emitters are present.
9. If touch, mouse, keyboard, gesture, remote, or controller input is present, use `references/input-handling.md`.
10. If SpriteKit or AVFoundation audio is present, use `references/audio-integration.md`.
11. If the project is multi-platform, contains platform conditionals, or targets visionOS, use `references/cross-platform.md`.
12. If tile maps are present, use `references/tilemap-patterns.md`.
13. If shaders or custom Metal integration are present, use `references/rendering-pipeline.md`.
14. If SwiftUI integration is present, use `references/swiftui-integration.md`.
15. If GameplayKit is integrated with SpriteKit, start with `references/gameplaykit-integration.md`, then load only the relevant specialized files: `references/gameplaykit-ecs.md`, `references/gameplaykit-state-machines.md`, `references/gameplaykit-pathfinding.md`, `references/gameplaykit-agents.md`, `references/gameplaykit-randomization.md`, `references/gameplaykit-rules.md`, or `references/gameplaykit-spatial.md`.

## Core Instructions

- Respect the project's existing deployment targets, Swift language mode, and supported devices. Do not raise them unless the user asks. When creating a project with no stated requirements, use iOS 18+ / macOS 15+ as the baseline and call out the assumption.
- SpriteKit APIs are available in the visionOS SDK, but Apple advises against using SpriteKit in apps created specifically for visionOS. Recommend RealityKit or SwiftUI for native visionOS experiences, and distinguish this platform guidance from API unavailability and from iPhone or iPad compatibility apps.
- Do not introduce third-party game frameworks without asking first.
- Prefer `@Observable` over `ObservableObject` when the deployment target supports Observation, while preserving compatibility with the project's target.
- Distinguish **correctness requirements**, **conditional patterns**, and **performance heuristics**. Report a violation only when its preconditions are present.
- Require evidence for performance findings: measurements, debug counters, a demonstrated hot path, or an obviously unbounded operation. Do not report device-count budgets as hard limits.
- Preserve intentional architecture. Recommend patterns such as layers, pooling, ECS, or state machines only when they solve a demonstrated need; do not impose them universally.
- Report only genuine problems. Do not nitpick, invent retain cycles, or label deliberate object retention as a leak without tracing the complete ownership cycle.

## Output Format

Match the output to the task mode:

- **Explain:** Give a direct answer, followed by the smallest useful example or caveat.
- **Implement or fix:** Lead with the completed outcome. Summarize changed files, important design decisions, and verification performed.
- **Optimize:** State the observed bottleneck and evidence, then recommend changes in impact order. Separate measured findings from hypotheses.
- **Review:** Organize findings by file. For each issue, state the relevant line, severity, violated correctness requirement or applicable condition, evidence, and a concise fix. Show before/after code only when it materially clarifies the change. Skip files with no issues and end with a prioritized summary.

If there are no genuine review findings, say so explicitly and mention any verification gaps. Never force review formatting onto an explanation or implementation task.

## References

- `references/scene-architecture.md` — Scene lifecycle, optional layer organization, camera control, scene transitions.
- `references/node-management.md` — Node lifecycle, ownership, cleanup, pooling, culling.
- `references/physics-patterns.md` — Physics body types, category bitmasks, collision handling, fields, joints.
- `references/animation-sprites.md` — Texture atlases, frame animation, action reuse, animation state.
- `references/asset-management.md` — Atlas loading, texture filtering modes, memory cleanup strategy.
- `references/game-loop-patterns.md` — Frame-cycle methods, delta time, fixed-step game logic, component updates.
- `references/performance-optimization.md` — Draw-call measurement, node traversal, culling, effect caching.
- `references/particle-systems.md` — Emitter lifetime, coordinate space, pooling, blend-mode selection.
- `references/input-handling.md` — Touch, mouse, keyboard, controllers, gestures, unified abstraction.
- `references/audio-integration.md` — SKAudioNode, positional audio, spatial listener, AVAudioEngine.
- `references/cross-platform.md` — Platform detection, safe areas, input differences, visionOS guidance.
- `references/tilemap-patterns.md` — SKTileMapNode creation, adjacency rules, physics generation, chunking.
- `references/rendering-pipeline.md` — SKShader, SKRenderer, offscreen rendering, effects, lighting.
- `references/swiftui-integration.md` — SpriteView, stable scene identity, Observation, lifecycle.
- `references/gameplaykit-integration.md` — Index and cross-cutting GameplayKit/SpriteKit integration rules.
- `references/gameplaykit-ecs.md` — GKEntity, GKComponent, GKComponentSystem, optional entity management.
- `references/gameplaykit-state-machines.md` — GKStateMachine, GKState, transition and lifecycle hooks.
- `references/gameplaykit-pathfinding.md` — GKObstacleGraph, GKMeshGraph, GKGridGraph, SpriteKit obstacles.
- `references/gameplaykit-agents.md` — GKAgent2D, GKGoal, GKBehavior, GKAgentDelegate.
- `references/gameplaykit-randomization.md` — GKRandomSource, distributions, procedural noise.
- `references/gameplaykit-rules.md` — GKRuleSystem, GKRule, fuzzy logic, GKDecisionTree.
- `references/gameplaykit-spatial.md` — GKQuadtree, GKOctree, and GKRTree spatial queries.
