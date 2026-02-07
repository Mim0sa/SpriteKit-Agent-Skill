# Asset Management

Texture atlases, asset catalogs, and loading strategies.

---

## Texture Atlases

### Creating Atlases

Xcode automatically compiles texture atlases from folders with `.atlas` extension:

```
Assets/
  Player.atlas/
    player_idle_1.png
    player_idle_2.png
    player_walk_1.png
    player_walk_2.png
```

### Loading from Atlas

```swift
let atlas = SKTextureAtlas(named: "Player")
let idleTexture = atlas.textureNamed("player_idle_1")
```

### Preloading

```swift
// Preload single atlas
SKTextureAtlas.preloadTextureAtlases([atlas]) {
    // Ready to use
}

// Preload multiple with progress
let atlases = ["Player", "Enemies", "Environment"]
SKTextureAtlas.preloadTextureAtlasesNamed(atlases) { progress, error in
    print("Loading: \(Int(progress * 100))%")
}
```

### Individual Texture Preloading

For large individual textures that aren't in atlases:

```swift
// Preload single large texture
let backgroundTexture = SKTexture(imageNamed: "large-background")
backgroundTexture.preload { [weak self] in
    // Texture loaded, safe to use on main thread
    DispatchQueue.main.async {
        self?.background.texture = backgroundTexture
    }
}

// Preload multiple textures
let textures = [
    SKTexture(imageNamed: "background1"),
    SKTexture(imageNamed: "background2"),
    SKTexture(imageNamed: "boss-sprite")
]

SKTexture.preload(textures) {
    // All textures ready
    print("All textures preloaded")
}
```

### Complete Preloading Strategy

```swift
class AssetManager {
    static let shared = AssetManager()

    func preloadLevelAssets(level: Int, completion: @escaping () -> Void) {
        let atlasNames = ["Level\(level)", "Enemies", "UI"]

        // Preload atlases first
        SKTextureAtlas.preloadTextureAtlasesNamed(atlasNames) { [weak self] error, atlases in
            if let error = error {
                print("Atlas loading error: \(error)")
            }

            // Store loaded atlases
            atlases?.forEach { atlas in
                self?.loadedAtlases[atlas.name] = atlas
            }

            // Then preload individual textures if needed
            let individualTextures = self?.getLevelTextures(level: level) ?? []
            SKTexture.preload(individualTextures) {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private var loadedAtlases: [String: SKTextureAtlas] = [:]

    func getLevelTextures(level: Int) -> [SKTexture] {
        // Return level-specific large textures
        return []
    }
}
```

---

## Texture Filtering Modes

**Control how textures are scaled for visual quality.**

### Filtering Mode Options

```swift
// Nearest neighbor (pixel art, sharp edges)
texture.filteringMode = .nearest
// Best for: Pixel art games, retro graphics
// Result: Sharp, blocky scaling (no blur)

// Linear interpolation (smooth scaling, default)
texture.filteringMode = .linear
// Best for: Realistic graphics, photos, smooth sprites
// Result: Smooth, anti-aliased scaling
```

### When to Use Each Mode

| Filtering Mode | Use For | Visual Result | Performance |
|----------------|---------|---------------|-------------|
| `.nearest` | Pixel art, retro games, UI icons | Sharp, crisp pixels | Slightly faster |
| `.linear` | Realistic graphics, photos, smooth sprites | Smooth, anti-aliased | Standard (default) |

### Pixel Art Configuration

```swift
// For pixel art games, use nearest filtering
let pixelArtTexture = SKTexture(imageNamed: "character_8bit")
pixelArtTexture.filteringMode = .nearest

// Apply to all textures in atlas
let pixelAtlas = SKTextureAtlas(named: "PixelArt")
pixelAtlas.textureNames.forEach { name in
    let texture = pixelAtlas.textureNamed(name)
    texture.filteringMode = .nearest
}

// Set default filtering mode for scene
// Note: Individual texture settings override this
class PixelArtScene: SKScene {
    override func didMove(to view: SKView) {
        // This doesn't exist as a scene property, set per-texture instead
        setupPixelArtTextures()
    }

    func setupPixelArtTextures() {
        enumerateChildNodes(withName: "//*") { node, _ in
            if let sprite = node as? SKSpriteNode {
                sprite.texture?.filteringMode = .nearest
            }
        }
    }
}
```

### Realistic Graphics Configuration

```swift
// For smooth, realistic graphics (default)
let realisticTexture = SKTexture(imageNamed: "character_hd")
realisticTexture.filteringMode = .linear  // Default, can omit

// Smooth scaling for UI elements
let buttonTexture = SKTexture(imageNamed: "button")
buttonTexture.filteringMode = .linear
```

### Mixed Filtering in Same Scene

```swift
class MixedStyleScene: SKScene {
    func setupTextures() {
        // Pixel art character
        let pixelCharacter = SKSpriteNode(imageNamed: "pixel_hero")
        pixelCharacter.texture?.filteringMode = .nearest

        // Smooth background
        let background = SKSpriteNode(imageNamed: "hd_background")
        background.texture?.filteringMode = .linear

        // Pixel art UI
        let healthBar = SKSpriteNode(imageNamed: "pixel_health")
        healthBar.texture?.filteringMode = .nearest

        addChild(background)
        addChild(pixelCharacter)
        addChild(healthBar)
    }
}
```

### Performance Considerations

```swift
// Nearest filtering is slightly faster (no interpolation)
// But difference is negligible on modern devices

// Set filtering mode once when loading texture
let texture = SKTexture(imageNamed: "sprite")
texture.filteringMode = .nearest  // Set once

// Avoid changing filtering mode every frame
// Bad:
override func update(_ currentTime: TimeInterval) {
    sprite.texture?.filteringMode = .nearest  // Don't do this!
}

// Good:
override func didMove(to view: SKView) {
    sprite.texture?.filteringMode = .nearest  // Set once
}
```

### Common Pitfalls

```swift
// Problem: Blurry pixel art
let pixelSprite = SKSpriteNode(imageNamed: "8bit_character")
// Default .linear makes pixel art blurry!

// Solution: Use .nearest for pixel art
pixelSprite.texture?.filteringMode = .nearest

// Problem: Jagged smooth graphics
let hdSprite = SKSpriteNode(imageNamed: "hd_character")
hdSprite.texture?.filteringMode = .nearest
// Nearest makes smooth graphics look jagged!

// Solution: Use .linear (or omit, it's default)
hdSprite.texture?.filteringMode = .linear
```

---

## Memory Management

### Purging Unused Textures

```swift
// Clear texture cache when low on memory
SKTexture.purgeTextureCache()

// Release specific atlas
atlas.removeFromParent()
```

### Memory Warnings

```swift
class GameScene: SKScene {
    @objc func handleMemoryWarning() {
        // Release unused textures
        SKTexture.purgeTextureCache()

        // Clear unused atlases
        unusedAtlases.removeAll()
    }
}
```

---

## Checklist

- [ ] Use texture atlases for related images
- [ ] Preload critical atlases before gameplay
- [ ] Preload large individual textures with `SKTexture.preload()`
- [ ] Use background queues for preloading, main queue for UI updates
- [ ] Purge unused textures on memory warnings
- [ ] Monitor texture memory usage
- [ ] Use asset catalogs for non-atlas images
- [ ] Implement progressive loading for large levels
