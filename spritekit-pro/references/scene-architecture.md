# Scene Architecture

- Always organize scenes into named layers: background, world, UI, debug. Assign explicit `zPosition` values to each.
- Add UI elements as children of `SKCameraNode`, not the scene, so they stay fixed on screen during camera movement.
- Set `scaleMode` on every scene — prefer `.aspectFill` for most games; never leave it at the default without intention.
- Use `didMove(to:)` for setup (physics, assets, camera). Use `willMove(from:)` for teardown (save state, stop audio).
- Never keep a strong reference to the old scene after calling `presentScene(_:)` — let it deallocate automatically.
- Implement `didChangeSize(_:)` to handle orientation and layout changes.
- Use `SKTransition` for all scene changes to avoid visual cuts.
- `SKScene` is a subclass of `SKEffectNode` — applying effects to the entire scene is expensive. Apply effects to specific layer nodes instead, and set `shouldRasterize = true` to cache the output.
- Never create or add nodes inside `update(_:)` — use object pooling instead.
- Size nodes relative to `scene.size`, not hardcoded values.
- Use `SKSceneDelegate` instead of subclassing `SKScene` when multiple scenes share the same frame-cycle logic — set `scene.delegate` and implement the `SKSceneDelegate` protocol methods (`update(_:for:)`, `didSimulatePhysics(for:)`, etc.).
- Set `anchorPoint` to control where the scene's `(0, 0)` maps within the view — `(0.5, 0.5)` centers it (default), `(0, 0)` places it at bottom-left. When a camera is active, `anchorPoint` has no effect on visible content.

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

// Wrong: retains old scene (memory leak)
var previousScene: GameScene?
func switchScene() {
    previousScene = skView.scene as? GameScene  // leak
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
// Use a delegate when multiple scenes share the same frame-cycle logic
class GameSceneDelegate: NSObject, SKSceneDelegate {
    private var lastUpdateTime: TimeInterval = 0

    func update(_ currentTime: TimeInterval, for scene: SKScene) {
        let rawDelta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        guard let gameScene = scene as? GameScene else { return }
        gameScene.entityManager.update(deltaTime: min(rawDelta, 1.0 / 20.0))
    }

    func didSimulatePhysics(for scene: SKScene) {
        guard let gameScene = scene as? GameScene else { return }
        gameScene.processDeferredRemovals()
    }
}

// In view controller — hold a strong reference, then assign to scene.delegate
class GameViewController: UIViewController {
    var gameDelegate: GameSceneDelegate?  // Strong reference — delegate is weak on SKScene

    override func viewDidLoad() {
        super.viewDidLoad()
        let scene = GameScene(size: view.bounds.size)
        gameDelegate = GameSceneDelegate()
        scene.delegate = gameDelegate
        (view as? SKView)?.presentScene(scene)
    }
}
```
