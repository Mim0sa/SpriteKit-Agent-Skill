# Rendering Pipeline

- SpriteKit uses Metal as its rendering backend on all platforms (iOS 12+ / macOS 10.14+). SKShader source is GLSL-compatible syntax but compiled to Metal Shading Language (MSL) at runtime.
- Update shader uniforms from `update(_:)` — never create new `SKShader` instances per frame.
- Use `SKRenderer` only when mixing SpriteKit content into an existing Metal render loop; for pure SpriteKit apps, use `SKView`.
- Cache complex static node hierarchies with `view?.texture(from:)` and replace the node tree with a single `SKSpriteNode` using the cached texture.
- Set `shouldRasterize = true` on `SKEffectNode` whenever the filtered content does not change every frame — this caches the filter output to a bitmap.
- Use `SKLightNode` with normal-map textures for dynamic lighting. Bake lighting into textures for static scenes — runtime lighting is expensive.
- Configure `renderer.ignoresSiblingOrder = true` and `renderer.shouldCullNonVisibleNodes = true` when using `SKRenderer`.

## Available Shader Variables

| Variable | Type | Description |
|----------|------|-------------|
| `v_tex_coord` | `vec2` | Texture UV coordinates |
| `u_texture` | `sampler2D` | Node's texture |
| `v_color_mix` | `vec4` | Color blend factor |
| `u_sprite_size` | `vec2` | Sprite size in points |
| `u_path_length` | `float` | Path length (SKShapeNode) |

## Shader with Uniform

```swift
let shader = SKShader(source: """
    uniform float u_time;
    void main() {
        vec4 color = texture2D(u_texture, v_tex_coord);
        float pulse = sin(u_time * 5.0) * 0.5 + 0.5;
        gl_FragColor = vec4(color.rgb * pulse, color.a);
    }
""")
let timeUniform = SKUniform(name: "u_time", float: 0)
shader.addUniform(timeUniform)
sprite.shader = shader

// Update in update(_:), not per event
override func update(_ currentTime: TimeInterval) {
    timeUniform.floatValue = Float(currentTime)
}
```

## Caching Complex Node Trees

```swift
// Render once, use as static sprite
let complexNode = SKNode()
// ... add many children ...
if let texture = view?.texture(from: complexNode) {
    complexNode.removeFromParent()
    let cached = SKSpriteNode(texture: texture)
    addChild(cached)
}

// Alternatively, rasterize in place
let effectNode = SKEffectNode()
effectNode.shouldRasterize = true  // Re-renders only when content changes
addChild(effectNode)
```

## SKRenderer Setup (Metal Integration)

```swift
import Metal
import SpriteKit

class MetalGameRenderer {
    let renderer: SKRenderer
    let scene: SKScene

    init(device: MTLDevice) {
        renderer = SKRenderer(device: device)
        renderer.ignoresSiblingOrder = true
        renderer.shouldCullNonVisibleNodes = true
        scene = GameScene(size: CGSize(width: 1024, height: 768))
        renderer.scene = scene
    }

    func draw(in view: MTKView, commandBuffer: MTLCommandBuffer) {
        renderer.update(atTime: CACurrentMediaTime())
        guard let rpd = view.currentRenderPassDescriptor else { return }
        let viewport = CGRect(origin: .zero, size: view.drawableSize)
        renderer.render(withViewport: viewport,
                        commandBuffer: commandBuffer,
                        renderPassDescriptor: rpd)
    }
}
```

## Dynamic Lighting

```swift
func setupLighting() {
    let sprite = SKSpriteNode(imageNamed: "character")
    sprite.normalTexture = SKTexture(imageNamed: "character_normal")  // Required for lighting
    sprite.lightingBitMask = 1
    sprite.shadowCastBitMask = 1

    let light = SKLightNode()
    light.categoryBitMask = 1
    light.falloff = 1.5
    light.ambientColor = UIColor(white: 0.2, alpha: 1)
    light.lightColor = .white
    light.shadowColor = UIColor(white: 0, alpha: 0.6)
    addChild(light)
    addChild(sprite)
}
```
