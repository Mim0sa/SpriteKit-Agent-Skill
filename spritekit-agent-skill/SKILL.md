---
name: spritekit-agent-skill
description: Write, review, or improve SpriteKit game code following best practices for scene architecture, physics patterns, performance optimization, texture atlases, memory management, and cross-platform development. Use when building new game features, optimizing rendering performance, implementing physics systems, managing node lifecycles, or integrating SpriteKit with SwiftUI.
---

# SpriteKit Agent Skill

Expert guidance for SpriteKit framework game development — modern APIs, scene architecture, physics patterns, performance optimization, and cross-platform development.

---

## Workflow Decision Tree

### What are you working on?

**Building a new feature**
→ Check [Quick Reference Tables](#quick-reference-tables) → Follow [Core Guidelines](#core-guidelines)

**Code Review & Optimization**
→ Start with [Review Checklists](#review-checklists) → Dive into relevant references

**Performance issues**
→ Go to [Performance Checklist](#performance-checklist) → See `performance-optimization.md`

**Cross-platform compatibility**
→ Review [Cross-Platform Guidelines](#cross-platform-guidelines) → See `cross-platform.md`

---

## Core Guidelines

### Scene Architecture

**Always use a layered node hierarchy.**

Organize your scene into logical layers (background, world, UI, debug) with explicit z-positioning. This simplifies camera control, pause behavior, and rendering order.

**Why**: Layered architecture makes batch operations trivial (like pausing game but not UI) and prevents depth sorting issues.

See `references/scene-architecture.md` for complete implementation patterns.

### Node Lifecycle Management

**Always mark nodes for removal instead of immediate removal during physics/contact callbacks.**

Removing nodes during physics simulation can cause crashes or undefined behavior. Use a deferred removal pattern with a `nodesToRemove` array processed in `update(_:)`.

See `references/node-management.md` for lifecycle patterns and object pooling.

### Physics Body Best Practices

**Use simple physics shapes and enable precise collision only when necessary.**

- Prefer `circleOfRadius` and `rectangleOf` over texture-based physics bodies
- Only enable `usesPreciseCollisionDetection` for fast-moving objects
- Each scene has a maximum of **32 physics categories** (bits 0-31)
- Edge-based physics bodies **never collide with other edge bodies**

**Use physics categories with bitmask operations.**

Define categories as powers of 2 and use bitwise operations for collision filtering. Avoid string-based collision detection.

**Use physics fields for generalized force effects.**

Instead of manually calculating forces every frame, use `SKFieldNode` for effects like gravity wells, magnetic attraction, drag, and vortex forces.

See `references/physics-patterns.md` for complete physics configuration patterns.

### Texture and Animation

**Always use texture atlases for related sprites.**

Texture atlases reduce draw calls and improve performance. Preload critical atlases before the scene appears to avoid frame drops.

**Preload critical textures before the scene appears.**

Use `SKTextureAtlas.preloadTextureAtlases(_:withCompletionHandler:)` to load assets asynchronously.

See `references/animation-sprites.md` for animation patterns and `references/asset-management.md` for loading strategies.

### Memory Management

**Avoid retain cycles with action blocks.**

Always use `[weak self]` in `SKAction.run` blocks, especially with `repeatForever` actions.

**Remove strong references in deinit.**

Use `weak` for delegates and clean up resources in `deinit` to prevent memory leaks.

See `references/node-management.md` for memory management patterns.

---

## Quick Reference Tables

### Node Type Selection

| Node Type | Use When | Avoid When |
|-----------|----------|------------|
| `SKSpriteNode` | Displaying images or colored rectangles | Complex vector graphics (use `SKShapeNode`) |
| `SKTileMapNode` | Tile-based levels and maps (platformers, RPGs) | Small numbers of tiles (use `SKSpriteNode` instead) |
| `SKShapeNode` | Dynamic vector shapes, debug overlays | Static images (use `SKSpriteNode` for performance) |
| `SKLabelNode` | Static text display | Frequently updating text (batch updates or use `SKSpriteNode` for numbers) |
| `SKEmitterNode` | Particle effects (fire, smoke, magic) | Simple repeated animations (use `SKAction`) |
| `SKFieldNode` | Physics fields (gravity wells, wind, drag) | Simple one-time forces (use `applyForce` instead) |
| `SKVideoNode` | Playing video in scene | Just audio (use `SKAudioNode`) |
| `SKCropNode` | Masking content | Complex multi-layer masks (performance cost) |
| `SKLightNode` | Dynamic lighting effects | Static lighting (bake into textures) |

### Physics Body Type Selection

| Type | Use When | Performance |
|------|----------|-------------|
| `circleOfRadius` | Circular objects | Fastest |
| `rectangleOf` | Boxes, walls | Fast |
| `polygonFrom` | Custom shapes (convex only) | Moderate |
| `edgeLoopFrom` | Scene boundaries, static obstacles | Fast (static only) |
| `init(texture:size:)` | Pixel-perfect collision | Slowest - avoid if possible |

### Action Type Selection

| Action | Use For | Alternative |
|--------|---------|-------------|
| `move(to:duration:)` | Simple position changes | Direct position manipulation for instant changes |
| `animate(with:timePerFrame:)` | Frame-based sprite animation | `SKAnimatedSprite` or shader-based animation |
| `repeatForever` | Continuous animations | Consider pausing when off-screen |
| `sequence` | Chained actions | `group` for parallel actions |
| `run(_:)` | Custom code execution | Override `update(_:)` for frame-by-frame logic |
| `wait(forDuration:)` | Timing delays | `Timer` or `DispatchQueue` for non-node timing |

### Frame Cycle Order

Understanding the frame cycle is critical for correct game logic:

1. `update(_:)` - Main game logic
2. `didEvaluateActions()` - After SKActions execute
3. `didSimulatePhysics()` - After physics simulation
4. `didApplyConstraints()` - After constraints applied
5. `didFinishUpdate()` - Final frame cleanup

See `references/game-loop-patterns.md` for detailed patterns.

### SKView Debug Options

| Property | Shows | Performance Impact | Use For |
|----------|-------|-------------------|---------|
| `showsFPS` | Frame rate (FPS) | Minimal | Monitoring performance |
| `showsNodeCount` | Total active nodes | Minimal | Detecting node leaks |
| `showsDrawCount` | Number of draw calls | Minimal | Optimizing batching |
| `showsPhysics` | Physics body shapes | Moderate | Debugging collisions |
| `showsFields` | Physics field regions | Moderate | Debugging forces |
| `showsQuadCount` | Sprite batch count | Minimal | Optimizing rendering |

**Enable in debug builds only:**
```swift
#if DEBUG
view.showsFPS = true
view.showsNodeCount = true
view.showsDrawCount = true
#endif
```

See `references/performance-optimization.md` for detailed debugging and profiling.

---

## Review Checklists

### Scene Setup Checklist

- [ ] Uses layered node architecture (world/UI/background)
- [ ] Sets `scaleMode` appropriately for the project
- [ ] Configures physics world gravity and speed
- [ ] Sets physics contact delegate
- [ ] Preloads critical texture atlases
- [ ] Configures camera node properly

### Physics Checklist

- [ ] Uses `categoryBitMask` for all physics bodies
- [ ] Configures `contactTestBitMask` correctly (only what's needed)
- [ ] Configures `collisionBitMask` correctly
- [ ] Uses simple shapes (circle/rectangle) when possible
- [ ] Enables `usesPreciseCollisionDetection` only for fast objects
- [ ] Defers node removal during contact callbacks
- [ ] Sets `isDynamic` to false for static objects
- [ ] Aware of 32-category limit per scene
- [ ] Aware that edge bodies don't collide with each other

### Performance Checklist

- [ ] Uses texture atlases instead of individual textures
- [ ] Implements node culling (pauses/removes off-screen nodes)
- [ ] Limits total node count (aim for < 500 active nodes)
- [ ] Avoids creating nodes in `update(_:)`
- [ ] Uses `isPaused` for backgrounded/invisible scenes
- [ ] Implements object pooling for frequently spawned objects
- [ ] Avoids complex shaders on many nodes
- [ ] Avoids full-scene effects (use layer effects instead)

### Memory Checklist

- [ ] Uses `[weak self]` in action blocks
- [ ] Removes unused textures with `SKTexture` purge
- [ ] Implements proper `deinit` cleanup
- [ ] Avoids retain cycles between nodes and physics bodies
- [ ] Releases unused atlases when switching scenes

### Cross-Platform Checklist

- [ ] Handles touch (iOS) vs mouse (macOS) input
- [ ] Supports GCController for tvOS
- [ ] Adapts to different screen sizes
- [ ] Handles different aspect ratios gracefully
- [ ] Uses `#if os()` for platform-specific code
- [ ] Tests on target platforms

---

## Cross-Platform Guidelines

### Input Handling Abstraction

**Use a unified input handler for all platforms.**

Create a protocol-based input system that abstracts touch, mouse, and game controller input into a common interface.

See `references/input-handling.md` for complete implementation patterns.

### Platform-Specific Considerations

Each platform has unique input methods and behaviors:

- **tvOS**: Focus-based navigation (not touch)
- **macOS**: Mouse/trackpad with multiple click types
- **visionOS**: Compatibility mode only (see `cross-platform.md` for important restrictions)

See `references/cross-platform.md` for detailed platform adaptation patterns.

---

## SwiftUI Integration

### Basic SpriteView Usage

Use `SpriteView` to embed SpriteKit scenes in SwiftUI:

```swift
import SwiftUI
import SpriteKit

struct GameContainerView: View {
    var scene: SKScene {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFill
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
```

### State Sharing Between SwiftUI and SpriteKit

Use observation frameworks to share state between SwiftUI and SpriteKit:

- **iOS 17+**: Use `@Observable` macro for modern, efficient observation
- **iOS 13+**: Use `ObservableObject` protocol with `@Published` properties

Pass the observable object to the scene and update it from game logic.

See `references/swiftui-integration.md` for complete integration patterns.

---

## Common Pitfalls

### Retain Cycles with Actions

**Problem**: Using `self` in `SKAction.run` blocks creates retain cycles.

**Solution**: Always use `[weak self]` in action blocks, especially with `repeatForever`.

### Physics Body After Node Removal

**Problem**: Accessing physics body properties after removing a node causes undefined behavior.

**Solution**: Set `physicsBody = nil` before removing nodes, or use deferred removal.

### Modifying Physics During Simulation

**Problem**: Directly setting position on nodes with physics bodies fights the physics simulation.

**Solution**: Use physics forces, velocity, or impulses instead of direct position manipulation.

### Full-Scene Effects

**Problem**: `SKScene` is a subclass of `SKEffectNode`. Applying effects to the entire scene is expensive.

**Solution**: Apply effects to specific layers only, not the entire scene. Use `shouldRasterize = true` to cache filtered output.

See individual reference documents for detailed anti-patterns and solutions.

---

## References

- `references/scene-architecture.md` - Scene lifecycle, node hierarchy, camera control
- `references/node-management.md` - Node lifecycle, memory management, object pooling
- `references/physics-patterns.md` - Physics body configuration, collision handling, fields, joints
- `references/animation-sprites.md` - Sprite animation, texture atlases, actions
- `references/particle-systems.md` - SKEmitterNode configuration and optimization
- `references/tilemap-patterns.md` - SKTileMapNode for tile-based games and levels
- `references/performance-optimization.md` - Rendering optimization, node culling, profiling, SKView debugging
- `references/input-handling.md` - Touch, mouse, and game controller handling
- `references/audio-integration.md` - SKAudioNode and AVAudioEngine usage
- `references/cross-platform.md` - iOS/macOS/tvOS/visionOS adaptation
- `references/rendering-pipeline.md` - Custom shaders (Metal-based), offscreen rendering, SKRenderer
- `references/asset-management.md` - Texture atlases, asset catalogs, loading strategies, filtering modes
- `references/game-loop-patterns.md` - Update patterns, fixed timestep, component systems
- `references/swiftui-integration.md` - SpriteView, state sharing, mixed UI
- `references/gameplaykit-integration.md` - GameplayKit entity-component system integration

---

## Summary

**Key Principles:**
1. **Layered Architecture** - Organize nodes into logical layers
2. **Physics Discipline** - Use categories, simple shapes, defer removals
3. **Performance Awareness** - Atlases, culling, pooling, batching
4. **Memory Safety** - Weak references, proper cleanup
5. **Cross-Platform** - Abstract inputs, handle platform differences
