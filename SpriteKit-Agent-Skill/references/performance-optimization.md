# Performance Optimization

Best practices for rendering optimization, node culling, and profiling in SpriteKit.

---

## SKView Debug and Performance Options

**Use SKView configuration properties for debugging and optimization.**

### Debug Visualization

```swift
class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else { return }

        // Debug overlays (disable in production)
        #if DEBUG
        view.showsFPS = true              // Frame rate display
        view.showsNodeCount = true        // Active node count
        view.showsDrawCount = true        // Draw call count
        view.showsPhysics = true          // Physics body outlines
        view.showsFields = true           // Physics field visualization
        view.showsQuadCount = true        // Quad count (sprite batches)
        #endif

        // Present scene
        let scene = GameScene(size: view.bounds.size)
        view.presentScene(scene)
    }
}
```

**Debug Properties:**

| Property | Shows | Performance Impact | Use For |
|----------|-------|-------------------|---------|
| `showsFPS` | Frame rate (FPS) | Minimal | Monitoring performance |
| `showsNodeCount` | Total active nodes | Minimal | Detecting node leaks |
| `showsDrawCount` | Number of draw calls | Minimal | Optimizing batching |
| `showsPhysics` | Physics body shapes | Moderate | Debugging collisions |
| `showsFields` | Physics field regions | Moderate | Debugging forces |
| `showsQuadCount` | Sprite batch count | Minimal | Optimizing rendering |

### Frame Rate Configuration

```swift
// Set preferred frame rate
view.preferredFramesPerSecond = 60  // Default on modern devices

// For battery-conscious apps
view.preferredFramesPerSecond = 30  // Lower frame rate

// For ProMotion displays (iPad Pro, iPhone 13 Pro+)
view.preferredFramesPerSecond = 120 // Smooth 120Hz

// Adaptive frame rate
if UIDevice.current.batteryState == .unplugged {
    view.preferredFramesPerSecond = 30
} else {
    view.preferredFramesPerSecond = 60
}
```

**Frame Rate Guidelines:**

| Device/Scenario | Recommended FPS | Notes |
|-----------------|----------------|-------|
| Modern iPhone/iPad | 60 | Standard smooth gameplay |
| ProMotion devices | 120 | Ultra-smooth (battery intensive) |
| Battery saving mode | 30 | Acceptable for turn-based games |
| Apple TV | 60 | TV standard |
| Older devices | 30-60 | Test and adjust |

### Rendering Optimization Options

```swift
// Ignore sibling order for better batching
view.ignoresSiblingOrder = true
// Nodes with same texture batch together regardless of z-order
// ⚠️ Only enable if you don't rely on sibling order for rendering

// Automatic culling of off-screen nodes
view.shouldCullNonVisibleNodes = true
// SpriteKit automatically skips rendering nodes outside viewport
// ⚠️ May have overhead for scenes with many nodes

// Asynchronous texture loading
view.allowsTransparency = false
// Opaque view = faster compositing
// Only set to false if scene has no transparency
```

**Optimization Property Trade-offs:**

| Property | Benefit | Cost | When to Use |
|----------|---------|------|-------------|
| `ignoresSiblingOrder = true` | Better batching, fewer draw calls | Loses z-order control | When z-position is sufficient |
| `shouldCullNonVisibleNodes = true` | Skips off-screen rendering | Culling calculation overhead | Large scenes with camera |
| `allowsTransparency = false` | Faster compositing | No scene transparency | Opaque backgrounds only |

### Performance Monitoring in Code

```swift
class GameScene: SKScene {
    var lastUpdateTime: TimeInterval = 0
    var frameCount = 0
    var fpsLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        // Custom FPS counter
        fpsLabel = SKLabelNode(text: "FPS: 60")
        fpsLabel.position = CGPoint(x: 50, y: size.height - 30)
        fpsLabel.fontSize = 14
        fpsLabel.fontColor = .yellow
        addChild(fpsLabel)
    }

    override func update(_ currentTime: TimeInterval) {
        // Calculate FPS
        if lastUpdateTime > 0 {
            let deltaTime = currentTime - lastUpdateTime
            let fps = 1.0 / deltaTime
            frameCount += 1

            // Update label every 30 frames
            if frameCount % 30 == 0 {
                fpsLabel.text = String(format: "FPS: %.1f", fps)
            }
        }
        lastUpdateTime = currentTime
    }

    func logPerformanceMetrics() {
        #if DEBUG
        print("=== Performance Metrics ===")
        print("Node count: \(nodeCount)")
        print("Physics bodies: \(physicsWorld.bodies.count)")

        if let view = view {
            print("Draw count: \(view.showsDrawCount ? "enabled" : "disabled")")
            print("FPS: \(view.preferredFramesPerSecond)")
        }
        #endif
    }
}
```

### Profiling with Instruments

**Use Xcode Instruments for deep performance analysis:**

1. **Time Profiler** - Identify CPU bottlenecks
   - Look for expensive `update(_:)` calls
   - Check physics simulation time
   - Identify slow action evaluations

2. **Allocations** - Track memory usage
   - Monitor texture memory
   - Detect node leaks
   - Check for retain cycles

3. **Metal System Trace** - GPU performance
   - Analyze draw calls
   - Check texture bandwidth
   - Identify shader bottlenecks

```swift
// Add signposts for Instruments profiling
import os.signpost

let performanceLog = OSLog(subsystem: "com.yourapp.game", category: "Performance")

override func update(_ currentTime: TimeInterval) {
    os_signpost(.begin, log: performanceLog, name: "Game Update")

    // Your update logic
    updatePlayer()
    updateEnemies()
    updatePhysics()

    os_signpost(.end, log: performanceLog, name: "Game Update")
}
```

---

## Node Count Management

**Limit total node count for optimal performance.**

| Device | Recommended Max Nodes | Critical Threshold |
|--------|----------------------|-------------------|
| iPhone (modern) | 300-500 | 1000+ |
| iPad (modern) | 500-800 | 1500+ |
| Apple TV | 400-600 | 1200+ |
| Older devices | 200-300 | 500+ |

```swift
class GameScene: SKScene {
    var nodeCount: Int {
        var count = 0
        enumerateChildNodes(withName: "//.") { _, _ in
            count += 1
            return nil
        }
        return count
    }

    func logNodeCount() {
        print("Active nodes: \(nodeCount)")
        // Monitor during development
    }
}
```

---

## Node Culling

**Pause and hide off-screen nodes.**

```swift
class GameScene: SKScene {
    var visibleRect: CGRect {
        guard let camera = camera else { return frame }
        let halfSize = CGSize(width: size.width / 2, height: size.height / 2)
        return CGRect(
            origin: CGPoint(x: camera.position.x - halfSize.width,
                           y: camera.position.y - halfSize.height),
            size: size
        )
    }

    func cullOffscreenNodes() {
        let padding: CGFloat = 200
        let cullRect = visibleRect.insetBy(dx: -padding, dy: -padding)

        worldLayer.enumerateChildNodes(withName: "//.") { node, _ in
            let nodeFrame = node.calculateAccumulatedFrame()

            if cullRect.intersects(nodeFrame) {
                // Node is visible
                if node.isPaused {
                    node.isPaused = false
                    node.isHidden = false
                }
            } else {
                // Node is off-screen
                node.isPaused = true
                node.isHidden = true
                node.physicsBody?.isResting = true
            }
            return nil
        }
    }
}
```

---

## Texture Optimization

### Texture Atlas Usage

```swift
// Correct: Atlas reduces draw calls
let atlas = SKTextureAtlas(named: "GameSprites")

// Load related textures together
let playerTextures = [
    atlas.textureNamed("player_idle"),
    atlas.textureNamed("player_walk"),
    atlas.textureNamed("player_jump")
]
```

### Texture Size Guidelines

| Use Case | Max Size | Notes |
|----------|----------|-------|
| Character sprites | 128x128 - 256x256 | Power of 2 preferred |
| Background tiles | 512x512 - 1024x1024 | Repeatable patterns |
| Full backgrounds | Device screen size | Consider parallax layers |
| UI elements | Actual display size | Avoid upscaling |

### Memory Management

```swift
// Purge unused textures
SKTexture.purgeTextureCache()

// Release atlas when switching scenes
atlas.removeFromParent()

// Monitor texture memory
func reportTextureMemory() {
    // Check for memory warnings and adjust accordingly
}
```

---

## Draw Call Reduction

**Batch nodes with same texture.**

```swift
// Correct: Nodes with same texture batch together
let atlas = SKTextureAtlas(named: "Enemies")
let enemyTexture = atlas.textureNamed("enemy_basic")

for i in 0..<10 {
    let enemy = SKSpriteNode(texture: enemyTexture)
    // Same texture = batched draw call
    worldLayer.addChild(enemy)
}

// Avoid: Mixing textures frequently
// Each texture change = new draw call
```

**Use `shouldRasterize` for static complex nodes:**

```swift
let complexUI = SKNode()
// Add many static UI elements...

// Cache as bitmap once static
complexUI.shouldRasterize = true
```

---

## Physics Optimization

### Physics Body Guidelines

```swift
// Use simple shapes
let circle = SKPhysicsBody(circleOfRadius: 20)     // Fast
let rect = SKPhysicsBody(rectangleOf: size)        // Fast
let polygon = SKPhysicsBody(polygonFrom: points)   // Moderate
let texture = SKPhysicsBody(texture: tex, size: s) // Slow - avoid

// Limit physics body count
// Max 100-200 active physics bodies recommended
```

### Physics Simulation Steps

```swift
// Adjust simulation speed if needed
physicsWorld.speed = 1.0  // Normal

// Reduce for slow-motion effects
physicsWorld.speed = 0.5

// Increase for faster simulation
physicsWorld.speed = 2.0
```

---

## Action Optimization

**Reuse actions, don't create in loops.**

```swift
// Correct: Static reusable actions
class GameScene: SKScene {
    static let standardMove = SKAction.moveBy(x: 100, y: 0, duration: 1)
    static let standardFade = SKAction.fadeOut(withDuration: 0.5)
}

// Avoid: Creating actions in update
override func update(_ currentTime: TimeInterval) {
    // Never create actions here
}
```

---

## Profiling Techniques

### Built-in Debug Options

```swift
class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as? SKView {
            // Show FPS and node count
            view.showsFPS = true
            view.showsNodeCount = true

            // Show physics outlines
            view.showsPhysics = true

            // Show draw count (draw calls)
            view.showsDrawCount = true

            // Show quad count (visible sprites)
            view.showsQuadCount = true
        }
    }
}
```

### Frame Time Monitoring

```swift
class GameScene: SKScene {
    var lastUpdateTime: TimeInterval = 0
    var frameTimeAccumulator: TimeInterval = 0
    var frameCount = 0

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        frameTimeAccumulator += deltaTime
        frameCount += 1

        // Log every 60 frames
        if frameCount >= 60 {
            let averageFrameTime = frameTimeAccumulator / Double(frameCount)
            let fps = 1.0 / averageFrameTime
            print("Avg FPS: \(Int(fps)), Frame time: \(averageFrameTime * 1000)ms")

            frameCount = 0
            frameTimeAccumulator = 0
        }
    }
}
```

---

## Checklist

- [ ] Keep node count under 500 (mobile) or 800 (tablet)
- [ ] Implement off-screen node culling
- [ ] Use texture atlases to reduce draw calls
- [ ] Use simple physics shapes (circle > rectangle > polygon)
- [ ] Limit active physics bodies to 100-200
- [ ] Reuse actions instead of creating new ones
- [ ] Enable debug overlays during development
- [ ] Profile frame time regularly
- [ ] Clear unused textures when switching scenes
- [ ] Use `isPaused` for off-screen scenes
