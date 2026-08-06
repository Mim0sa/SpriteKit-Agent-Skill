# Scene Architecture

- Introduce named layers such as background, world, UI, and debug when the scene needs independent ordering, transforms, or visibility control. Keep simple scenes simple.
- Add scene-space HUD elements as children of `SKCameraNode` when they must remain fixed during camera movement or zoom.
- Set `scaleMode` intentionally based on whether the game uses a fixed logical canvas or a scene that resizes with the view.
- Use `didMove(to:)` for setup (physics, assets, camera). Use `willMove(from:)` for teardown (save state, stop audio).
- Retain an old scene only as part of an intentional, bounded cache or navigation design. Accidental retention is a memory issue, but a strong reference alone is not a leak.
- Implement `didChangeSize(_:)` when the selected scale mode or resizable window can change `scene.size`.
- Use `SKTransition` when a visual transition is desired; immediate scene changes are valid when the design calls for them.
- `SKScene` is a subclass of `SKEffectNode` — applying effects to the entire scene is expensive. Prefer a specific layer node, and enable `shouldRasterize` only while the filtered content changes infrequently.
- Avoid unbounded per-frame node and action allocation. Event-driven spawning from `update(_:)` is valid; pool only when profiling shows allocation or loading cost.
- Derive layout from `scene.size`, safe-area information, or a documented logical canvas instead of scattering unexplained screen-size constants.
- Use `SKSceneDelegate` when shared frame-cycle logic benefits from composition; subclassing `SKScene` remains valid.
- Set `anchorPoint` to control where the scene's `(0, 0)` maps within the view. The default `(0, 0)` places it at bottom-left; `(0.5, 0.5)` centers it. When a camera is active, `anchorPoint` does not determine visible content.

## Layered Scene Setup

```swift
class GameScene: SKScene {
    let backgroundLayer = SKNode()
    let worldLayer = SKNode()
    let uiLayer = SKNode()
    var worldCamera: SKCameraNode!

    override func didMove(to view: SKView) {
        backgroundLayer.zPosition = -100
        worldLayer.zPosition = 0
        uiLayer.zPosition = 100
        [backgroundLayer, worldLayer, uiLayer].forEach { addChild($0) }

        worldCamera = SKCameraNode()
        addChild(worldCamera)  // Camera must be a direct child of the scene
        self.camera = worldCamera

        // UI pinned to camera, not scene
        let hud = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 40))
        hud.position = CGPoint(x: -size.width / 2 + 120, y: size.height / 2 - 40)
        worldCamera.addChild(hud)
    }
}
```

## Scene Transition

```swift
// Correct: let old scene deallocate
func goToNextLevel(_ level: Int) {
    let next = GameScene(size: size, level: level)
    next.scaleMode = .aspectFill
    view?.presentScene(next, transition: SKTransition.fade(withDuration: 0.5))
}

// Potentially wrong when this grows without a cache policy.
var previousScene: GameScene?
func switchScene() {
    previousScene = skView.scene as? GameScene  // Intentional retention needs a lifetime policy.
    skView.presentScene(newScene)
}
```

## Full-Scene Effect — Prefer Layer Scoping

```swift
// Wrong: expensive full-scene blur
scene.filter = CIFilter(name: "CIGaussianBlur")!
scene.shouldEnableEffects = true

// Correct: scope to a layer, cache with rasterize
let blurLayer = SKEffectNode()
blurLayer.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 5])
blurLayer.shouldRasterize = true
backgroundLayer.addChild(blurLayer)
```

## Smooth Camera with Bounds

```swift
override func update(_ currentTime: TimeInterval) {
    let lerpFactor: CGFloat = 0.1
    worldCamera.position.x += (player.position.x - worldCamera.position.x) * lerpFactor
    worldCamera.position.y += (player.position.y - worldCamera.position.y) * lerpFactor

    // Clamp to world bounds
    worldCamera.position.x = min(max(worldCamera.position.x, worldBounds.minX), worldBounds.maxX)
    worldCamera.position.y = min(max(worldCamera.position.y, worldBounds.minY), worldBounds.maxY)
}
```

## SKSceneDelegate — Shared Logic Across Scenes

```swift
class GameSceneDelegate: NSObject, SKSceneDelegate {
    func update(_ currentTime: TimeInterval, for scene: SKScene) { /* frame logic */ }
    func didSimulatePhysics(for scene: SKScene) { /* deferred removals */ }
}

// scene.delegate is weak — owner must retain the delegate
var sharedDelegate = GameSceneDelegate()
scene.delegate = sharedDelegate
```
