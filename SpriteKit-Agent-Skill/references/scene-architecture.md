# Scene Architecture

Guidance for structuring SKScene hierarchies, camera control, and scene transitions.

---

## Layered Node Architecture

**Always organize your scene into logical layers.**

```swift
class GameScene: SKScene {
    // MARK: - Layers
    let backgroundLayer = SKNode()
    let worldLayer = SKNode()      // Game world (scrolled by camera)
    let uiLayer = SKNode()         // UI elements (fixed to screen)
    let debugLayer = SKNode()      // Debug overlays

    // MARK: - Camera
    var worldCamera: SKCameraNode!

    override func didMove(to view: SKView) {
        setupLayers()
        setupCamera()
    }

    private func setupLayers() {
        // Add in render order (back to front)
        addChild(backgroundLayer)
        addChild(worldLayer)
        addChild(uiLayer)
        addChild(debugLayer)

        // Layers don't participate in physics
        backgroundLayer.zPosition = -100
        worldLayer.zPosition = 0
        uiLayer.zPosition = 100
        debugLayer.zPosition = 1000
    }

    private func setupCamera() {
        worldCamera = SKCameraNode()
        worldLayer.addChild(worldCamera)
        self.camera = worldCamera
    }
}
```

**Why layers matter:**
- **Camera control**: Only worldLayer moves with camera; UI stays fixed
- **Pausing**: Can pause game world while keeping UI responsive
- **Rendering order**: Explicit z-ordering prevents depth issues
- **Batch operations**: Easy to hide/show entire categories

---

## Scene Lifecycle

### Proper Initialization

```swift
class GameScene: SKScene {

    // Correct: Custom initializer for dependency injection
    convenience init(size: CGSize, levelData: LevelData) {
        self.init(size: size)
        self.levelData = levelData
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        // Called when scene becomes active in a view
        // Setup physics, load assets, start music
        setupPhysics()
        loadAssets()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)

        // Called before scene is removed from view
        // Clean up, save state, stop audio
        saveGameState()
        stopAudio()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        // Handle orientation/size changes
        adjustLayoutForNewSize()
    }
}
```

### Scene Transition Patterns

**Use SKTransition for visual scene changes:**

```swift
// Correct: Proper scene transition
func transitionToLevel(_ level: Int) {
    let newScene = GameScene(size: currentSize, level: level)
    newScene.scaleMode = .aspectFill

    let transition = SKTransition.fade(withDuration: 0.5)
    view?.presentScene(newScene, transition: transition)
}
```

**Avoid holding references to old scenes:**

```swift
// Wrong: Memory leak
class GameViewController: UIViewController {
    var oldScene: GameScene?  // Don't keep references

    func switchScene() {
        oldScene = skView.scene as? GameScene  // Memory leak!
        skView.presentScene(newScene)
    }
}

// Correct: Let the old scene deallocate
func switchScene() {
    skView.presentScene(newScene, transition: transition)
    // Old scene will be deallocated automatically
}
```

---

## Camera Control

### Basic Camera Following

```swift
class GameScene: SKScene {
    var worldCamera: SKCameraNode!
    var player: SKNode!

    override func didMove(to view: SKView) {
        worldCamera = SKCameraNode()
        worldLayer.addChild(worldCamera)
        self.camera = worldCamera
    }

    override func update(_ currentTime: TimeInterval) {
        // Simple follow
        worldCamera.position = player.position
    }
}
```

### Smooth Camera with Bounds

```swift
class GameScene: SKScene {
    let worldBounds: CGRect
    var cameraTarget: CGPoint = .zero

    override func update(_ currentTime: TimeInterval) {
        // Smooth lerp to target
        let lerpFactor: CGFloat = 0.1
        let diff = CGPoint(
            x: cameraTarget.x - worldCamera.position.x,
            y: cameraTarget.y - worldCamera.position.y
        )

        worldCamera.position.x += diff.x * lerpFactor
        worldCamera.position.y += diff.y * lerpFactor

        // Clamp to world bounds
        clampCameraToBounds()
    }

    private func clampCameraToBounds() {
        let x = min(max(worldCamera.position.x, worldBounds.minX), worldBounds.maxX)
        let y = min(max(worldCamera.position.y, worldBounds.minY), worldBounds.maxY)
        worldCamera.position = CGPoint(x: x, y: y)
    }
}
```

### Camera with UI Constraints

```swift
class GameScene: SKScene {
    override func didMove(to view: SKView) {
        // UI elements should be children of the camera
        // so they move with the camera (stay fixed on screen)

        let healthBar = SKSpriteNode(color: .green, size: CGSize(width: 200, height: 20))
        healthBar.position = CGPoint(x: -size.width/2 + 120, y: size.height/2 - 40)
        healthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        worldCamera.addChild(healthBar)
    }
}
```

---

## World Bounds and Constraints

### Defining World Boundaries

```swift
class GameScene: SKScene {
    func setupWorldBounds(size: CGSize) {
        // Create edge loop for world boundary
        let bounds = CGRect(origin: .zero, size: size)
        let boundaryBody = SKPhysicsBody(edgeLoopFrom: bounds)
        boundaryBody.isDynamic = false
        boundaryBody.categoryBitMask = PhysicsCategory.boundary
        boundaryBody.contactTestBitMask = PhysicsCategory.player
        boundaryBody.collisionBitMask = PhysicsCategory.player | PhysicsCategory.enemy

        // Create invisible node to hold the physics body
        let boundaryNode = SKNode()
        boundaryNode.physicsBody = boundaryBody
        worldLayer.addChild(boundaryNode)
    }
}
```

---

## Scene Composition Best Practices

### Use SKReferenceNode for Reusable Components

```swift
class GameScene: SKScene {
    func loadLevelFromFile() {
        // Load a pre-designed scene from .sks file
        if let levelScene = SKScene(fileNamed: "Level1") {
            let referenceNode = SKReferenceNode(url: levelScene.url!)
            worldLayer.addChild(referenceNode)
        }
    }
}
```

### Scene Loading with Progress

```swift
class LoadingScene: SKScene {
    func loadGameAssets() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Load textures
            let atlases = ["Player", "Enemies", "Environment"]
            SKTextureAtlas.preloadTextureAtlasesNamed(atlases) { progress, error in
                DispatchQueue.main.async {
                    self.loadingBar.setProgress(progress)

                    if progress >= 1.0 {
                        self.transitionToGame()
                    }
                }
            }
        }
    }
}
```

---

## Common Pitfalls

### Don't Add Children in update()

```swift
// Wrong: Creating nodes every frame
override func update(_ currentTime: TimeInterval) {
    let particle = SKEmitterNode(fileNamed: "Spark")
    addChild(particle)  // Memory leak!
}

// Correct: Use object pooling
override func update(_ currentTime: TimeInterval) {
    if shouldSpawnParticle {
        particlePool.spawnParticle(at: position)
    }
}
```

### SKScene as SKEffectNode - Performance Warning

> **Note:** `SKScene` is a subclass of `SKEffectNode`. Applying effects to the entire scene can be **expensive**.

```swift
// ⚠️ Expensive: Full-screen effects
class ExpensiveScene: SKScene {
    func applyFullScreenBlur() {
        // This affects the entire scene - performance impact!
        self.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 10])
        self.shouldEnableEffects = true

        // Mitigate with rasterization
        self.shouldRasterize = true  // Caches the filtered output
    }
}

// ✅ Better: Apply effects to specific layers only
class OptimizedScene: SKScene {
    func applyLayeredBlur() {
        let blurLayer = SKEffectNode()
        blurLayer.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 5])
        blurLayer.shouldRasterize = true

        // Only add content that needs blurring
        backgroundLayer.addChild(blurLayer)
    }
}
```

### Proper Scene Scaling

```swift
// Choose appropriate scale mode for your game
enum SKSceneScaleMode {
    case fill          // Stretches to fill (distorts aspect ratio)
    case aspectFill    // Fills while preserving aspect (may crop)
    case aspectFit     // Fits while preserving aspect (may letterbox)
    case resizeFill    // Scene resizes to match view
}

// For most games
scene.scaleMode = .aspectFill
```

### Scene Size Consistency

```swift
// Wrong: Hardcoding sizes
let player = SKSpriteNode(size: CGSize(width: 50, height: 50))

// Correct: Size relative to scene
let playerSize = CGSize(width: scene.size.width * 0.05,
                        height: scene.size.width * 0.05)
let player = SKSpriteNode(size: playerSize)
```

---

## Checklist

- [ ] Uses layered node architecture
- [ ] Camera properly configured with constraints
- [ ] Scene lifecycle methods implemented correctly
- [ ] No retained references to old scenes
- [ ] World boundaries properly defined
- [ ] Scale mode chosen appropriately
- [ ] No node creation in update()
- [ ] Smooth camera transitions with clamping
- [ ] Avoid full-scene effects (use layer effects instead)
