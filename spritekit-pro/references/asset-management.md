# Asset Management

- Group related sprites in texture atlases when it improves loading and batching. Verify `showsDrawCount`; textures from one atlas can still require separate drawing passes because of ordering, overlap, blend mode, shaders, crops, or effects.
- Preload atlases with `SKTextureAtlas.preloadTextureAtlasesNamed(_:withCompletionHandler:)` from a loading scene before gameplay begins. In Swift concurrency contexts, use the async variant `SKTextureAtlas.preloadTextureAtlasesNamed(_:) async throws -> [SKTextureAtlas]`.
- Preload large individual textures with `SKTexture.preload(_:withCompletionHandler:)` — loading on first use causes frame drops.
- Always call completion handlers on the main thread after background preloading finishes.
- Set texture filtering mode once when loading: use `.nearest` for pixel art, `.linear` (default) for smooth/HD art. Never change it per frame.
- Release scene-specific texture and atlas references when they are no longer needed and memory measurements show that reclaiming them matters. Textures remain resident while referenced, but shared assets should not be purged solely because a scene changes.
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
