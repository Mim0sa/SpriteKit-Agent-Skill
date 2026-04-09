# Tile Map Patterns

- Use Xcode's SpriteKit Scene Editor to design tile maps visually; generate them programmatically only for procedural content.
- Always load tile textures from a texture atlas — tiles from the same atlas batch into one draw call. Individual textures multiply draw calls proportionally.
- Use power-of-2 tile sizes (32, 64, 128) for optimal GPU texture performance. Avoid 48×48 or 100×100.
- Enable `tileMap.enableAutomapping = true` when using adjacency rule tile groups — without it, adjacent tiles will not update automatically.
- Never create one `SKPhysicsBody` per tile — combine adjacent solid tiles into a single rectangle body to minimize physics overhead.
- For large worlds, split the map into chunk nodes and load/unload chunks based on camera proximity.
- `SKTileMapNode` defaults to `anchorPoint = (0.5, 0.5)` like all `SKNode` subclasses — its bottom-left corner is at `(-width/2, -height/2)` in parent coordinates. Explicitly set the anchor point when you need a different origin.
- Avoid `SKTileMapNode` for fewer than ~20 tiles — individual `SKSpriteNode` instances are simpler and equally performant at that scale.

## Tile Map Size Guidelines

| Device | Recommended visible tiles | Notes |
|--------|--------------------------|-------|
| iPhone (modern) | 1000–2000 | Use chunk culling for larger maps |
| iPad (modern) | 2000–4000 | |
| Apple TV | 1500–3000 | |
| Older devices | 500–1000 | |

## Programmatic Creation

```swift
// 1. Textures from atlas (required for draw call batching)
let atlas = SKTextureAtlas(named: "TileAtlas")
let grassDef = SKTileDefinition(texture: atlas.textureNamed("grass"))
let dirtDef  = SKTileDefinition(texture: atlas.textureNamed("dirt"))

// 2. Groups
let grassGroup = SKTileGroup(tileDefinition: grassDef)
let dirtGroup  = SKTileGroup(tileDefinition: dirtDef)

// 3. Tile set + map
let tileSet = SKTileSet(tileGroups: [grassGroup, dirtGroup])
let tileMap = SKTileMapNode(tileSet: tileSet, columns: 30, rows: 20,
                            tileSize: CGSize(width: 64, height: 64))
tileMap.fill(with: grassGroup)
addChild(tileMap)
```

## Optimized Physics (Combine Adjacent Tiles)

```swift
// Wrong: one body per tile → hundreds/thousands of physics bodies
for column in 0..<tileMap.numberOfColumns {
    for row in 0..<tileMap.numberOfRows {
        if tileMap.tileGroup(atColumn: column, row: row) == solidGroup {
            let node = SKNode()
            node.physicsBody = SKPhysicsBody(rectangleOf: tileMap.tileSize)  // Expensive!
            tileMap.addChild(node)
        }
    }
}

// Correct: merge horizontal runs into single bodies
func buildOptimizedPhysics() {
    var processed = Set<String>()
    for column in 0..<tileMap.numberOfColumns {
        for row in 0..<tileMap.numberOfRows {
            let key = "\(column),\(row)"
            guard !processed.contains(key),
                  tileMap.tileGroup(atColumn: column, row: row) == solidGroup else { continue }
            var width = 1
            while column + width < tileMap.numberOfColumns &&
                  tileMap.tileGroup(atColumn: column + width, row: row) == solidGroup {
                processed.insert("\(column + width),\(row)")
                width += 1
            }
            let ts = tileMap.tileSize
            let bodySize = CGSize(width: ts.width * CGFloat(width), height: ts.height)
            let center = tileMap.centerOfTile(atColumn: column, row: row)
            let origin = CGPoint(x: center.x + ts.width * CGFloat(width - 1) / 2, y: center.y)
            let node = SKNode()
            node.position = origin
            node.physicsBody = SKPhysicsBody(rectangleOf: bodySize)
            node.physicsBody?.isDynamic = false
            node.physicsBody?.categoryBitMask = PhysicsCategory.ground
            tileMap.addChild(node)
            processed.insert(key)
        }
    }
}
```

## Chunk Loading for Large Maps

```swift
class LargeMapScene: SKScene {
    let chunkSize = 20
    var loadedChunks: [String: SKTileMapNode] = [:]

    func updateChunks(around camera: CGPoint) {
        let cx = Int(camera.x / (CGFloat(chunkSize) * tileSize.width))
        let cy = Int(camera.y / (CGFloat(chunkSize) * tileSize.height))
        for dx in -1...1 {
            for dy in -1...1 {
                let key = "\(cx+dx),\(cy+dy)"
                if loadedChunks[key] == nil { loadedChunks[key] = loadChunk(cx+dx, cy+dy) }
            }
        }
        loadedChunks = loadedChunks.filter { key, chunk in
            let parts = key.split(separator: ",").compactMap { Int($0) }
            let dist = max(abs(parts[0] - cx), abs(parts[1] - cy))
            if dist > 2 { chunk.removeFromParent(); return false }
            return true
        }
    }
}
```

## Adjacency Auto-Tiling

```swift
// Enable before setting any tiles with adjacency rules
tileMap.enableAutomapping = true
tileMap.setTileGroup(platformGroup, forColumn: 5, row: 3)
// Neighboring tiles update their edge/corner variants automatically
```
