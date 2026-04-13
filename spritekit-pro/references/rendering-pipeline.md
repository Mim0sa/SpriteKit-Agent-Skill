# Rendering Pipeline

- SpriteKit uses Metal as its rendering backend on all platforms since iOS 9 / OS X 10.11. SKShader source must be written in the **OpenGL ES 2.0 shading language** — SpriteKit compiles it for the Metal backend internally.
- Update shader uniforms from `update(_:)` — never create new `SKShader` instances per frame.
- Use `SKRenderer` only when mixing SpriteKit content into an existing Metal render loop; for pure SpriteKit apps, use `SKView`.
- Cache complex static node hierarchies with `view?.texture(from:)` and replace the node tree with a single `SKSpriteNode` using the cached texture.
- Set `shouldRasterize = true` on `SKEffectNode` whenever the filtered content does not change every frame — this caches the filter output to a bitmap.
- Use `SKLightNode` with normal-map textures for dynamic lighting. Bake lighting into textures for static scenes — runtime lighting is expensive.
- Configure `renderer.ignoresSiblingOrder = true` and `renderer.shouldCullNonVisibleNodes = true` when using `SKRenderer`.

## Available Shader Variables

SpriteKit automatically declares these symbols in the shader preamble — you do not need to declare them yourself:

| Variable | Type | Description |
|----------|------|-------------|
| `v_tex_coord` | `vec2` | Texture UV coordinates (0–1) |
| `u_texture` | `sampler2D` | Node's current texture |
| `v_color_mix` | `vec4` | Color blend factor from the node's `color`/`colorBlendFactor` |
| `u_time` | `float` | Elapsed time since the scene started (seconds) |
| `u_path_length` | `float` | Total path length (only for `SKShapeNode`) |
| `SKDefaultShading()` | `vec4` | Built-in function that returns the default SpriteKit fragment color — use it to blend custom effects with the standard rendering result |

## Passing Custom Data to Shaders

`u_sprite_size` is **not** a built-in SpriteKit symbol. To access sprite size in a shader, pass it yourself via `SKUniform` (global for all sprites) or `SKAttribute` (per-node values).

```swift
// Via SKUniform — same value for all sprites using this shader
let spriteSize = vector_float2(Float(sprite.frame.size.width),
                               Float(sprite.frame.size.height))
let sizeUniform = SKUniform(name: "u_sprite_size", vectorFloat2: spriteSize)
shader.addUniform(sizeUniform)

// Via SKAttribute — per-node value, no recompilation when changed
let sizeAttribute = SKAttribute(name: "a_sprite_size", type: .vectorFloat2)
shader.attributes = [sizeAttribute]
sprite.setValue(SKAttributeValue(vectorFloat2Value: spriteSize),
                forAttribute: "a_sprite_size")
```

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
