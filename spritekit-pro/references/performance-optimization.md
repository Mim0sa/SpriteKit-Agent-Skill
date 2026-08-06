# Performance Optimization

- Enable SKView debug overlays in `#if DEBUG` blocks only — never ship with `showsFPS`, `showsNodeCount`, or `showsDrawCount` enabled.
- Set `view.ignoresSiblingOrder = true` when z-ordering is managed exclusively via `zPosition` — this allows SpriteKit to batch nodes by texture regardless of tree order.
- Establish node, draw-call, frame-time, memory, and physics budgets on the minimum supported device. Do not use a universal node-count threshold as a correctness rule.
- Avoid repeated `SKAction` or node allocation in a measured hot path; event-driven allocation from `update(_:)` can be valid.
- Use `shouldCullNonVisibleNodes` for render culling when appropriate. Remove or pool distant nodes when traversal or simulation remains expensive, but only if they are disposable or an authoritative world model can restore them; `isHidden` alone does not remove traversal cost.
- Measure physics cost with the actual mix of bodies, contacts, joints, fields, and precise collision detection instead of enforcing a universal body-count limit.
- Reuse immutable `SKAction` instances when the same action is executed frequently and measurements show repeated construction in a hot path.
- Use `shouldRasterize = true` on `SKEffectNode` layers that are static or change infrequently — caches filtered output to a bitmap.
- Group compatible nodes when draw-count measurements show batching opportunities. Texture, z-order, overlap, blend mode, shader, crop, and effect state all affect batching.
- Release texture and atlas references when memory measurements show scene-specific assets should be reclaimed.
- Choose particle blend mode by visual semantics: `.add` for luminous accumulation and `.alpha` for opacity-bearing effects. Measure either mode when fill rate is a concern.
- Lower `preferredFramesPerSecond` only when the product's motion and input requirements permit it, and verify the battery or performance benefit.
- Replace frequently changing or numerous `SKShapeNode` instances with pre-rendered textures only when profiling identifies shape tessellation or drawing as a bottleneck.

## Debug Overlays (DEBUG only)

```swift
class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let view = self.view as? SKView else { return }
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        view.showsDrawCount = true
        view.showsPhysics = true
        #endif
        view.ignoresSiblingOrder = true
        view.presentScene(GameScene(size: view.bounds.size))
    }
}
```

## Debug Property Reference

| Property | Shows | Use For |
|----------|-------|---------|
| `showsFPS` | Frame rate | Monitoring performance |
| `showsNodeCount` | Active nodes | Detecting node leaks |
| `showsDrawCount` | Draw calls | Optimizing batching |
| `showsPhysics` | Physics body outlines | Debugging collisions |
| `showsFields` | Physics field regions | Debugging force fields |
| `showsQuadCount` | Rendered rectangles | Tracking submitted sprite geometry |

## Performance Evidence

| Signal | Use |
|--------|-----|
| Frame time and FPS | Confirm the user-visible performance problem |
| `showsDrawCount` / `showsQuadCount` | Find batching and rendered-geometry opportunities; neither directly measures overdraw |
| `showsNodeCount` | Detect unexpected growth; not a universal capacity limit |
| `showsPhysics` plus contact/body metrics | Correlate physics complexity with frame spikes |
| Memory on the minimum supported device | Set scene-specific texture and pooling budgets |

## Recycling Disposable Off-Screen Nodes

```swift
override func update(_ currentTime: TimeInterval) {
    guard let view else { return }
    let viewCorners = [
        CGPoint(x: view.bounds.minX, y: view.bounds.minY),
        CGPoint(x: view.bounds.maxX, y: view.bounds.minY),
        CGPoint(x: view.bounds.maxX, y: view.bounds.maxY),
        CGPoint(x: view.bounds.minX, y: view.bounds.maxY)
    ]
    let worldCorners = viewCorners.map {
        worldLayer.convert(convertPoint(fromView: $0), from: self)
    }
    let xValues = worldCorners.map(\.x)
    let yValues = worldCorners.map(\.y)
    let margin: CGFloat = 100
    let cullRect = CGRect(
        x: xValues.min()! - margin,
        y: yValues.min()! - margin,
        width: xValues.max()! - xValues.min()! + margin * 2,
        height: yValues.max()! - yValues.min()! + margin * 2
    )
    let disposableNodes = worldLayer.children.filter {
        $0.userData?["discardWhenOffscreen"] as? Bool == true
    }

    disposableNodes.forEach { node in
        guard !cullRect.intersects(node.calculateAccumulatedFrame()) else { return }
        recycle(node) // Stops activity, removes the node, and returns it to its pool.
    }
}
```

Converting all four view corners makes the axis-aligned culling rectangle conservative under camera zoom and rotation and under transforms on `worldLayer`. Keep persistent level state outside the rendered node tree and restore it through a chunk or world manager. Never remove arbitrary world children merely because the camera cannot currently see them.

## Texture Batching

```swift
// These nodes can batch when render state and ordering are compatible.
let texture = atlas.textureNamed("enemy_basic")
for _ in 0..<20 {
    worldLayer.addChild(SKSpriteNode(texture: texture))
}

// Different textures may require additional passes; verify with showsDrawCount.
worldLayer.addChild(SKSpriteNode(imageNamed: "enemy_a"))
worldLayer.addChild(SKSpriteNode(imageNamed: "enemy_b"))
```

## Rasterizing Static Effect Layers

```swift
let complexUI = SKEffectNode()
complexUI.filter = CIFilter(name: "CIGaussianBlur")
complexUI.shouldRasterize = true  // Cached to bitmap; re-renders only on change
```
