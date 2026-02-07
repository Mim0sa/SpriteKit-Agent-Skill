# Rendering Pipeline

Custom shaders, offscreen rendering, and effects.

---

## Custom Shaders

> **⚠️ Important:** Modern SpriteKit uses **Metal** as its rendering backend (since iOS 12/macOS 10.14). While shader syntax remains GLSL-compatible for ease of use, SpriteKit automatically translates your shaders to Metal Shading Language (MSL) at runtime.

### SKShader Basics

```swift
// Create shader from string
// Note: SpriteKit uses GLSL-compatible syntax but renders via Metal
let shaderSource = """
    void main() {
        vec2 uv = v_tex_coord;
        vec4 color = texture2D(u_texture, uv);

        // Invert colors
        gl_FragColor = vec4(1.0 - color.rgb, color.a);
    }
"""

let shader = SKShader(source: shaderSource)
sprite.shader = shader
```

**Available SpriteKit Shader Variables:**
- `v_tex_coord` - Texture coordinates (vec2)
- `u_texture` - The node's texture (sampler2D)
- `v_color_mix` - Color blend factor (vec4)
- `u_path_length` - Path length for SKShapeNode (float)
- `u_sprite_size` - Sprite size in points (vec2)

### Shader with Uniforms

```swift
let pulseShader = SKShader(source: """
    uniform float u_time;

    void main() {
        vec2 uv = v_tex_coord;
        float pulse = sin(u_time * 5.0) * 0.5 + 0.5;
        vec4 color = texture2D(u_texture, uv);
        gl_FragColor = vec4(color.rgb * pulse, color.a);
    }
""")

// Add uniform
let timeUniform = SKUniform(name: "u_time", float: 0)
pulseShader.addUniform(timeUniform)

// Update in update loop
override func update(_ currentTime: TimeInterval) {
    timeUniform.floatValue = Float(currentTime)
}
```

---

## SKRenderer - Metal Integration

Use `SKRenderer` to mix SpriteKit content with custom Metal rendering. This is useful when:
- You have an existing Metal app and want to add SpriteKit content
- You need precise control over render order (z-position)
- You want to apply custom Metal shaders as post-processing

### Basic SKRenderer Setup

```swift
import Metal
import SpriteKit

class MetalSpriteKitMixer {
    var renderer: SKRenderer!
    var scene: SKScene!
    var device: MTLDevice!

    func setup(device: MTLDevice) {
        self.device = device
        renderer = SKRenderer(device: device)

        scene = GameScene(size: CGSize(width: 1024, height: 768))
        renderer.scene = scene
    }

    func update(atTime time: TimeInterval) {
        // Drive the scene's update cycle
        renderer.update(atTime: time)
    }

    func render(in view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        let viewport = CGRect(
            x: 0, y: 0,
            width: view.drawableSize.width,
            height: view.drawableSize.height
        )

        // Render SpriteKit scene into Metal command buffer
        renderer.render(
            withViewport: viewport,
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor
        )
    }
}
```

### Rendering SpriteKit Between Metal Passes

```swift
func renderMixedContent(view: MTKView, commandQueue: MTLCommandQueue) {
    guard let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

    // 1. First render your custom Metal content
    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    // ... custom Metal rendering ...
    encoder?.endEncoding()

    // 2. Render SpriteKit content on top
    let viewport = CGRect(origin: .zero, size: view.drawableSize)
    renderer.render(
        withViewport: viewport,
        commandBuffer: commandBuffer,
        renderPassDescriptor: renderPassDescriptor
    )

    // 3. Continue with more Metal rendering if needed
    let finalEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    // ... final Metal pass ...
    finalEncoder?.endEncoding()

    commandBuffer.present(view.currentDrawable!)
    commandBuffer.commit()
}
```

### SKRenderer Performance Options

```swift
// Configure performance settings
renderer.ignoresSiblingOrder = true        // Optimize draw order
renderer.shouldCullNonVisibleNodes = true  // Automatically cull off-screen nodes

// Debug visualization
renderer.showsNodeCount = true
renderer.showsDrawCount = true
renderer.showsQuadCount = true
renderer.showsPhysics = true
renderer.showsFields = true
```

---

## Offscreen Rendering

### SKRenderTexture

```swift
func createSnapshot() -> SKTexture {
    let renderTexture = SKRenderTexture(size: size)
    renderTexture.render(self)
    return renderTexture.texture
}
```

### Caching Complex Nodes

```swift
let complexNode = SKNode()
// Add many children...

// Render to texture once
let texture = view?.texture(from: complexNode)
let cachedSprite = SKSpriteNode(texture: texture)

// Use cached sprite instead of complex node
addChild(cachedSprite)
```

---

## Lighting Effects

### SKLightNode

```swift
func setupLighting() {
    // Normal map for lighting
    let sprite = SKSpriteNode(imageNamed: "character")
    sprite.normalTexture = SKTexture(imageNamed: "character_normal")

    // Light source
    let light = SKLightNode()
    light.categoryBitMask = 1
    light.falloff = 1.0
    light.ambientColor = .darkGray
    light.lightColor = .white
    light.shadowColor = .black.withAlphaComponent(0.5)

    addChild(light)

    // Sprite responds to light
    sprite.lightingBitMask = 1
    sprite.shadowCastBitMask = 1
}
```

---

## Checklist

- [ ] Use shaders for custom effects
- [ ] Cache offscreen rendered content
- [ ] Update shader uniforms efficiently
- [ ] Use normal maps for lighting
- [ ] Test shader performance on target devices
- [ ] Use SKRenderer for mixing SpriteKit with Metal
- [ ] Configure `ignoresSiblingOrder` and `shouldCullNonVisibleNodes` for SKRenderer
