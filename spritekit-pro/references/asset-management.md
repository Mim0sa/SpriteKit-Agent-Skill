# Asset Management

- Use texture atlases (`.atlas` folders) for all related sprites — tiles and animation frames from the same atlas batch into a single draw call.
- Preload atlases with `SKTextureAtlas.preloadTextureAtlasesNamed(_:withCompletionHandler:)` from a loading scene before gameplay begins. In Swift concurrency contexts, use the async variant `SKTextureAtlas.preloadTextureAtlasesNamed(_:) async throws -> [SKTextureAtlas]`.
- Preload large individual textures with `SKTexture.preload(_:withCompletionHandler:)` — loading on first use causes frame drops.
- Always call completion handlers on the main thread after background preloading finishes.
- Set texture filtering mode once when loading: use `.nearest` for pixel art, `.linear` (default) for smooth/HD art. Never change it per frame.
- Release texture and atlas references when transitioning between major scenes — textures stay in GPU memory until the referencing `SKTexture` object is deallocated. Nil out unused texture/atlas properties to reclaim GPU memory.
- Prefer power-of-2 tile sizes (32, 64, 128) when targeting older devices — modern Apple Silicon handles non-power-of-2 textures efficiently.

## Atlas Preloading Strategy

```swift
class LoadingScene: SKScene {
    func preloadLevel(_ level: Int, completion: @escaping () -> Void) {
        let names = ["Level\(level)", "Enemies", "UI"]
        SKTextureAtlas.preloadTextureAtlasesNamed(names) { error, atlases in
            if let error = error { print("Preload error: \(error)") }
            DispatchQueue.main.async { completion() }
        }
    }
}
```

## Individual Texture Preloading

```swift
let textures = [
    SKTexture(imageNamed: "boss"),
    SKTexture(imageNamed: "background_level3")
]
SKTexture.preload(textures) {
    DispatchQueue.main.async {
        self.transitionToGame()
    }
}
```

## Texture Filtering

```swift
// Pixel art — sharp pixels
let pixelTexture = SKTexture(imageNamed: "hero_8bit")
pixelTexture.filteringMode = .nearest  // Set once on load

// HD / smooth art — anti-aliased (default, can omit)
let hdTexture = SKTexture(imageNamed: "hero_hd")
hdTexture.filteringMode = .linear

// Apply nearest to all sprites in a pixel-art atlas
let atlas = SKTextureAtlas(named: "PixelHero")
atlas.textureNames.forEach { name in
    atlas.textureNamed(name).filteringMode = .nearest
}
```

## Memory Warning Response

```swift
class GameScene: SKScene {
    func handleMemoryWarning() {
        // Release atlas references — textures are freed when no SKTexture references remain
        unusedAtlases.removeAll()
        // Release any cached textures by nil-ing properties that hold them
        cachedTextures = nil
    }
}
```
