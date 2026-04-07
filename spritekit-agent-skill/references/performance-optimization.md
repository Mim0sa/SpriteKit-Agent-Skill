# Performance Optimization

- Enable SKView debug overlays in `#if DEBUG` blocks only — never ship with `showsFPS`, `showsNodeCount`, or `showsDrawCount` enabled.
- Set `view.ignoresSiblingOrder = true` when z-ordering is managed exclusively via `zPosition` — this allows SpriteKit to batch nodes by texture regardless of tree order.
- Keep active node count below 500 on iPhone, 800 on iPad. Flag scenes that consistently exceed these limits.
- Avoid creating `SKAction` instances or allocating nodes inside `update(_:)`.
- Implement off-screen culling: set `isPaused = true` and `isHidden = true` on nodes outside the viewport. Restore them when they re-enter.
- Limit active physics bodies to 100–200. Static bodies (`isDynamic = false`) are nearly free; dynamic bodies are the budget concern.
- Reuse `SKAction` instances as `static let` constants rather than recreating them per spawn.
- Use `shouldRasterize = true` on `SKEffectNode` layers that are static or change infrequently — caches filtered output to a bitmap.
- Batch draw calls by grouping nodes that share the same texture together in the node tree.
- Use `SKTexture.purgeTextureCache()` when switching major scenes to reclaim GPU memory.
- Prefer `additive` blend mode over `alpha` for particles — additive is faster and avoids overdraw cost.
- Call `view.preferredFramesPerSecond = 30` for turn-based or low-action games to save battery.

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
| `showsQuadCount` | Sprite batch count | Validating atlas batching |

## Node Count Thresholds

| Device | Target | Critical |
|--------|--------|----------|
| iPhone (modern) | < 500 | > 1000 |
| iPad (modern) | < 800 | > 1500 |
| Apple TV | < 600 | > 1200 |
| Older devices | < 300 | > 500 |

## Off-Screen Culling

```swift
override func update(_ currentTime: TimeInterval) {
    guard let camera = camera else { return }
    let cullRect = CGRect(
        x: camera.position.x - size.width / 2 - 100,
        y: camera.position.y - size.height / 2 - 100,
        width: size.width + 200, height: size.height + 200
    )
    worldLayer.enumerateChildNodes(withName: "//.*") { node, _ in
        let visible = cullRect.intersects(node.calculateAccumulatedFrame())
        node.isPaused = !visible
        node.isHidden = !visible
    }
}
```

## Texture Batching

```swift
// Correct: same texture = one draw call for all instances
let texture = atlas.textureNamed("enemy_basic")
for _ in 0..<20 {
    let enemy = SKSpriteNode(texture: texture)
    worldLayer.addChild(enemy)
}

// Wrong: each unique texture is a separate draw call
worldLayer.addChild(SKSpriteNode(imageNamed: "enemy_a"))
worldLayer.addChild(SKSpriteNode(imageNamed: "enemy_b"))
// Two draw calls instead of one
```

## Rasterizing Static Effect Layers

```swift
let complexUI = SKEffectNode()
complexUI.filter = CIFilter(name: "CIGaussianBlur")
complexUI.shouldRasterize = true  // Cached to bitmap; re-renders only on change
```
