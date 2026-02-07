# Tile Map Patterns

Best practices for SKTileMapNode configuration, tile set organization, and performance optimization for tile-based games.

---

## Overview

**SKTileMapNode** is a two-dimensional array of images designed for efficient rendering of tile-based levels and maps. It's ideal for platformers, RPGs, puzzle games, and any game with grid-based layouts.

**Key Benefits:**
- Efficient rendering of large tile grids
- Automatic batching of tiles from the same atlas
- Built-in support for adjacency rules and auto-tiling
- Integration with physics bodies
- Support for parallax scrolling via multiple layers

**Availability:** iOS 10.0+, macOS 10.12+, tvOS 10.0+, watchOS 3.0+, visionOS 1.0+

---

## Creating Tile Maps

### Method 1: Xcode Scene Editor (Recommended)

**Use Xcode's SpriteKit Scene Editor for visual tile map design.**

The Scene Editor provides:
- Visual tile painting interface
- Automatic tile set management
- Built-in adjacency rule configuration
- Real-time preview

```swift
// Load a tile map created in Scene Editor
guard let tileMap = childNode(withName: "//TileMap") as? SKTileMapNode else {
    fatalError("TileMap node not found")
}

// Tile map is ready to use
addChild(tileMap)
```

### Method 2: Programmatic Creation

**Create tile maps in code for procedurally generated levels.**

```swift
// Step 1: Create tile definitions
let grassTexture = SKTexture(imageNamed: "grass")
let grassDefinition = SKTileDefinition(texture: grassTexture)

let dirtTexture = SKTexture(imageNamed: "dirt")
let dirtDefinition = SKTileDefinition(texture: dirtTexture)

// Step 2: Create tile groups
let grassGroup = SKTileGroup(tileDefinition: grassDefinition)
let dirtGroup = SKTileGroup(tileDefinition: dirtDefinition)

// Step 3: Create tile set
let tileSet = SKTileSet(tileGroups: [grassGroup, dirtGroup])

// Step 4: Create tile map node
let tileMap = SKTileMapNode(
    tileSet: tileSet,
    columns: 20,
    rows: 15,
    tileSize: CGSize(width: 32, height: 32)
)

// Step 5: Fill with tiles
tileMap.fill(with: grassGroup)

addChild(tileMap)
```

---

## Tile Set Organization

### Single Tile Groups

**Use for uniform terrain types.**

```swift
let waterTexture = SKTexture(imageNamed: "water")
let waterDefinition = SKTileDefinition(texture: waterTexture)
let waterGroup = SKTileGroup(tileDefinition: waterDefinition)

// Fill entire map with water
tileMap.fill(with: waterGroup)
```

### Heterogeneous Tile Groups with Random Placement

**Use for natural-looking terrain variation.**

```swift
// Create multiple tile definitions
let grass1 = SKTileDefinition(texture: SKTexture(imageNamed: "grass1"))
grass1.placementWeight = 5  // More common

let grass2 = SKTileDefinition(texture: SKTexture(imageNamed: "grass2"))
grass2.placementWeight = 3

let grass3 = SKTileDefinition(texture: SKTexture(imageNamed: "grass3"))
grass3.placementWeight = 2  // Less common

// Create rule for random placement
let grassRule = SKTileGroupRule(
    adjacency: .adjacencyAll,
    tileDefinitions: [grass1, grass2, grass3]
)

let grassGroup = SKTileGroup(rules: [grassRule])

// Fill will randomly distribute tiles based on placement weights
tileMap.fill(with: grassGroup)
```

**Placement weights** control the probability of each tile appearing:
- Total weight = 5 + 3 + 2 = 10
- grass1: 50% chance (5/10)
- grass2: 30% chance (3/10)
- grass3: 20% chance (2/10)

### Adjacency-Based Tile Groups (Auto-Tiling)

**Use for automatic edge and corner tiles.**

Adjacency rules automatically select the correct tile based on neighboring tiles. This is essential for platforms, walls, and terrain edges.

```swift
// Define tiles for each adjacency pattern
let centerTile = SKTileDefinition(texture: SKTexture(imageNamed: "platform_center"))
let topEdgeTile = SKTileDefinition(texture: SKTexture(imageNamed: "platform_top"))
let bottomEdgeTile = SKTileDefinition(texture: SKTexture(imageNamed: "platform_bottom"))
let leftEdgeTile = SKTileDefinition(texture: SKTexture(imageNamed: "platform_left"))
let rightEdgeTile = SKTileDefinition(texture: SKTexture(imageNamed: "platform_right"))
let topLeftCorner = SKTileDefinition(texture: SKTexture(imageNamed: "platform_top_left"))
let topRightCorner = SKTileDefinition(texture: SKTexture(imageNamed: "platform_top_right"))
let bottomLeftCorner = SKTileDefinition(texture: SKTexture(imageNamed: "platform_bottom_left"))
let bottomRightCorner = SKTileDefinition(texture: SKTexture(imageNamed: "platform_bottom_right"))

// Create rules for each adjacency pattern
let centerRule = SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [centerTile])
let topEdgeRule = SKTileGroupRule(adjacency: .adjacencyUpEdge, tileDefinitions: [topEdgeTile])
let bottomEdgeRule = SKTileGroupRule(adjacency: .adjacencyDownEdge, tileDefinitions: [bottomEdgeTile])
let leftEdgeRule = SKTileGroupRule(adjacency: .adjacencyLeftEdge, tileDefinitions: [leftEdgeTile])
let rightEdgeRule = SKTileGroupRule(adjacency: .adjacencyRightEdge, tileDefinitions: [rightEdgeTile])
let topLeftRule = SKTileGroupRule(adjacency: .adjacencyUpperLeft, tileDefinitions: [topLeftCorner])
let topRightRule = SKTileGroupRule(adjacency: .adjacencyUpperRight, tileDefinitions: [topRightCorner])
let bottomLeftRule = SKTileGroupRule(adjacency: .adjacencyLowerLeft, tileDefinitions: [bottomLeftCorner])
let bottomRightRule = SKTileGroupRule(adjacency: .adjacencyLowerRight, tileDefinitions: [bottomRightCorner])

// Create tile group with all rules
let platformGroup = SKTileGroup(rules: [
    centerRule, topEdgeRule, bottomEdgeRule, leftEdgeRule, rightEdgeRule,
    topLeftRule, topRightRule, bottomLeftRule, bottomRightRule
])

// Enable auto-mapping
tileMap.enableAutomapping = true

// When you set a tile, adjacent tiles update automatically
tileMap.setTileGroup(platformGroup, forColumn: 5, row: 5)
```

**Adjacency Types:**
- `.adjacencyAll` - Surrounded by tiles on all sides (center)
- `.adjacencyUpEdge` - Tiles below, empty above
- `.adjacencyDownEdge` - Tiles above, empty below
- `.adjacencyLeftEdge` - Tiles right, empty left
- `.adjacencyRightEdge` - Tiles left, empty right
- `.adjacencyUpperLeft` - Corner tile (top-left)
- `.adjacencyUpperRight` - Corner tile (top-right)
- `.adjacencyLowerLeft` - Corner tile (bottom-left)
- `.adjacencyLowerRight` - Corner tile (bottom-right)

---

## Setting Individual Tiles

### Basic Tile Placement

```swift
// Set a single tile
tileMap.setTileGroup(grassGroup, forColumn: 10, row: 5)

// Remove a tile
tileMap.setTileGroup(nil, forColumn: 10, row: 5)

// Set with specific tile definition (for heterogeneous groups)
tileMap.setTileGroup(grassGroup, andTileDefinition: grass1, forColumn: 10, row: 5)
```

### Querying Tiles

```swift
// Get tile group at position
if let group = tileMap.tileGroup(atColumn: 10, row: 5) {
    print("Tile group found")
}

// Get tile definition at position
if let definition = tileMap.tileDefinition(atColumn: 10, row: 5) {
    print("Tile definition found")
}

// Convert world position to tile coordinates
let tileColumn = tileMap.tileColumnIndex(fromPosition: touchLocation)
let tileRow = tileMap.tileRowIndex(fromPosition: touchLocation)

// Convert tile coordinates to world position
let tileCenter = tileMap.centerOfTile(atColumn: 10, row: 5)
```

---

## Physics Integration

### Generating Physics Bodies from Tiles

**Automatically create physics bodies for solid tiles.**

```swift
// Option 1: Generate physics body for entire tile map
tileMap.physicsBody = SKPhysicsBody(rectangleOf: tileMap.mapSize)
tileMap.physicsBody?.isDynamic = false
tileMap.physicsBody?.categoryBitMask = PhysicsCategory.ground

// Option 2: Generate physics bodies for individual tiles
func addPhysicsToTiles() {
    for column in 0..<tileMap.numberOfColumns {
        for row in 0..<tileMap.numberOfRows {
            guard let tileGroup = tileMap.tileGroup(atColumn: column, row: row) else {
                continue
            }

            // Only add physics to solid tiles
            if tileGroup == solidTileGroup {
                let tileCenter = tileMap.centerOfTile(atColumn: column, row: row)
                let tileSize = tileMap.tileSize

                let tileNode = SKNode()
                tileNode.position = tileCenter
                tileNode.physicsBody = SKPhysicsBody(rectangleOf: tileSize)
                tileNode.physicsBody?.isDynamic = false
                tileNode.physicsBody?.categoryBitMask = PhysicsCategory.ground

                tileMap.addChild(tileNode)
            }
        }
    }
}
```

### Optimized Physics for Tile Maps

**Combine adjacent tiles into larger physics bodies for better performance.**

```swift
func createOptimizedPhysics() {
    var processedTiles = Set<String>()

    for column in 0..<tileMap.numberOfColumns {
        for row in 0..<tileMap.numberOfRows {
            let key = "\(column),\(row)"
            if processedTiles.contains(key) { continue }

            guard tileMap.tileGroup(atColumn: column, row: row) == solidTileGroup else {
                continue
            }

            // Find horizontal run of solid tiles
            var width = 1
            while column + width < tileMap.numberOfColumns &&
                  tileMap.tileGroup(atColumn: column + width, row: row) == solidTileGroup {
                processedTiles.insert("\(column + width),\(row)")
                width += 1
            }

            // Create single physics body for the run
            let tileSize = tileMap.tileSize
            let bodySize = CGSize(width: tileSize.width * CGFloat(width), height: tileSize.height)
            let startCenter = tileMap.centerOfTile(atColumn: column, row: row)
            let bodyCenter = CGPoint(
                x: startCenter.x + (tileSize.width * CGFloat(width - 1)) / 2,
                y: startCenter.y
            )

            let physicsNode = SKNode()
            physicsNode.position = bodyCenter
            physicsNode.physicsBody = SKPhysicsBody(rectangleOf: bodySize)
            physicsNode.physicsBody?.isDynamic = false
            physicsNode.physicsBody?.categoryBitMask = PhysicsCategory.ground

            tileMap.addChild(physicsNode)
            processedTiles.insert(key)
        }
    }
}
```

---

## Performance Optimization

### Texture Atlas Usage

**Always use texture atlases for tile textures.**

```swift
// Correct: Load tiles from atlas
let tileAtlas = SKTextureAtlas(named: "TileAtlas")
let grassTexture = tileAtlas.textureNamed("grass")
let dirtTexture = tileAtlas.textureNamed("dirt")

// Preload atlas before creating tile map
SKTextureAtlas.preloadTextureAtlases([tileAtlas]) { [weak self] in
    self?.createTileMap()
}
```

**Why:** Tiles from the same atlas are batched into a single draw call, dramatically improving performance.

### Tile Map Size Guidelines

| Device | Recommended Max Tiles | Notes |
|--------|----------------------|-------|
| iPhone (modern) | 1000-2000 visible | Use culling for larger maps |
| iPad (modern) | 2000-4000 visible | Higher resolution allows more |
| Apple TV | 1500-3000 visible | TV viewing distance consideration |
| Older devices | 500-1000 visible | Reduce tile count or size |

### Culling Off-Screen Tiles

**For very large maps, use multiple smaller tile map nodes.**

```swift
class LargeMapScene: SKScene {
    let chunkSize = 20  // 20x20 tiles per chunk
    var visibleChunks: [String: SKTileMapNode] = [:]

    func updateVisibleChunks(cameraPosition: CGPoint) {
        let chunkX = Int(cameraPosition.x / (CGFloat(chunkSize) * tileSize.width))
        let chunkY = Int(cameraPosition.y / (CGFloat(chunkSize) * tileSize.height))

        // Load chunks around camera
        for dx in -1...1 {
            for dy in -1...1 {
                let key = "\(chunkX + dx),\(chunkY + dy)"
                if visibleChunks[key] == nil {
                    visibleChunks[key] = loadChunk(x: chunkX + dx, y: chunkY + dy)
                }
            }
        }

        // Unload distant chunks
        visibleChunks = visibleChunks.filter { key, chunk in
            let components = key.split(separator: ",")
            let x = Int(components[0])!
            let y = Int(components[1])!
            let distance = max(abs(x - chunkX), abs(y - chunkY))

            if distance > 2 {
                chunk.removeFromParent()
                return false
            }
            return true
        }
    }

    func loadChunk(x: Int, y: Int) -> SKTileMapNode {
        let chunk = SKTileMapNode(
            tileSet: tileSet,
            columns: chunkSize,
            rows: chunkSize,
            tileSize: tileSize
        )
        chunk.position = CGPoint(
            x: CGFloat(x * chunkSize) * tileSize.width,
            y: CGFloat(y * chunkSize) * tileSize.height
        )
        // Fill chunk with procedural or loaded data
        fillChunk(chunk, x: x, y: y)
        addChild(chunk)
        return chunk
    }
}
```

### Tile Size Recommendations

```swift
// Correct: Power-of-2 sizes for optimal GPU performance
let tileSize = CGSize(width: 32, height: 32)   // Good
let tileSize = CGSize(width: 64, height: 64)   // Good
let tileSize = CGSize(width: 128, height: 128) // Good for large tiles

// Avoid: Non-power-of-2 sizes
let tileSize = CGSize(width: 48, height: 48)   // Suboptimal
let tileSize = CGSize(width: 100, height: 100) // Suboptimal
```

---

## Parallax Scrolling

**Use multiple tile map layers for depth.**

```swift
class ParallaxScene: SKScene {
    let backgroundLayer = SKNode()
    let midgroundLayer = SKNode()
    let foregroundLayer = SKNode()

    var backgroundTileMap: SKTileMapNode!
    var midgroundTileMap: SKTileMapNode!
    var foregroundTileMap: SKTileMapNode!

    override func didMove(to view: SKView) {
        setupLayers()
        setupTileMaps()
    }

    func setupLayers() {
        backgroundLayer.zPosition = -100
        midgroundLayer.zPosition = 0
        foregroundLayer.zPosition = 100

        addChild(backgroundLayer)
        addChild(midgroundLayer)
        addChild(foregroundLayer)
    }

    func setupTileMaps() {
        // Background (slowest parallax)
        backgroundTileMap = createTileMap(named: "Background")
        backgroundLayer.addChild(backgroundTileMap)

        // Midground (medium parallax)
        midgroundTileMap = createTileMap(named: "Midground")
        midgroundLayer.addChild(midgroundTileMap)

        // Foreground (no parallax, moves with camera)
        foregroundTileMap = createTileMap(named: "Foreground")
        foregroundLayer.addChild(foregroundTileMap)
    }

    func updateParallax(cameraPosition: CGPoint) {
        // Background moves slowest (0.2x camera speed)
        backgroundLayer.position = CGPoint(
            x: -cameraPosition.x * 0.2,
            y: -cameraPosition.y * 0.2
        )

        // Midground moves at medium speed (0.5x camera speed)
        midgroundLayer.position = CGPoint(
            x: -cameraPosition.x * 0.5,
            y: -cameraPosition.y * 0.5
        )

        // Foreground moves with camera (1.0x camera speed)
        foregroundLayer.position = CGPoint(
            x: -cameraPosition.x,
            y: -cameraPosition.y
        )
    }
}
```

---

## Dynamic Tile Manipulation

### Procedural Generation

```swift
func generateProceduralMap() {
    for column in 0..<tileMap.numberOfColumns {
        for row in 0..<tileMap.numberOfRows {
            // Use noise or algorithm to determine tile type
            let noiseValue = perlinNoise(x: column, y: row)

            let tileGroup: SKTileGroup
            if noiseValue > 0.6 {
                tileGroup = mountainGroup
            } else if noiseValue > 0.3 {
                tileGroup = grassGroup
            } else {
                tileGroup = waterGroup
            }

            tileMap.setTileGroup(tileGroup, forColumn: column, row: row)
        }
    }
}
```

### Runtime Tile Modification

```swift
// Destroy tile on collision
func didBegin(_ contact: SKPhysicsContact) {
    let tileColumn = tileMap.tileColumnIndex(fromPosition: contact.contactPoint)
    let tileRow = tileMap.tileRowIndex(fromPosition: contact.contactPoint)

    // Check if tile is destructible
    if tileMap.tileGroup(atColumn: tileColumn, row: tileRow) == destructibleGroup {
        // Remove tile
        tileMap.setTileGroup(nil, forColumn: tileColumn, row: tileRow)

        // Add particle effect
        let explosion = SKEmitterNode(fileNamed: "TileExplosion")!
        explosion.position = tileMap.centerOfTile(atColumn: tileColumn, row: tileRow)
        addChild(explosion)
    }
}
```

---

## Common Patterns

### Tile-Based Collision Detection

```swift
func isTileSolid(at position: CGPoint) -> Bool {
    let column = tileMap.tileColumnIndex(fromPosition: position)
    let row = tileMap.tileRowIndex(fromPosition: position)

    guard column >= 0 && column < tileMap.numberOfColumns &&
          row >= 0 && row < tileMap.numberOfRows else {
        return false
    }

    return tileMap.tileGroup(atColumn: column, row: row) == solidTileGroup
}

func getTileType(at position: CGPoint) -> TileType {
    let column = tileMap.tileColumnIndex(fromPosition: position)
    let row = tileMap.tileRowIndex(fromPosition: position)

    guard let group = tileMap.tileGroup(atColumn: column, row: row) else {
        return .empty
    }

    switch group {
    case grassGroup: return .grass
    case waterGroup: return .water
    case lavaGroup: return .lava
    default: return .unknown
    }
}
```

### Tile-Based Pathfinding Integration

```swift
func buildPathfindingGrid() -> [[Bool]] {
    var grid = Array(repeating: Array(repeating: false, count: tileMap.numberOfColumns),
                     count: tileMap.numberOfRows)

    for row in 0..<tileMap.numberOfRows {
        for column in 0..<tileMap.numberOfColumns {
            // Mark walkable tiles as true
            let group = tileMap.tileGroup(atColumn: column, row: row)
            grid[row][column] = (group == grassGroup || group == dirtGroup)
        }
    }

    return grid
}
```

---

## Common Pitfalls

### Pitfall 1: Not Using Texture Atlases

```swift
// Problem: Individual textures cause many draw calls
let grass = SKTexture(imageNamed: "grass.png")  // Separate texture
let dirt = SKTexture(imageNamed: "dirt.png")    // Separate texture
// Result: 2 draw calls per frame

// Solution: Use texture atlas
let atlas = SKTextureAtlas(named: "TileAtlas")
let grass = atlas.textureNamed("grass")
let dirt = atlas.textureNamed("dirt")
// Result: 1 draw call per frame
```

### Pitfall 2: Creating Too Many Physics Bodies

```swift
// Problem: Individual physics body per tile
for column in 0..<tileMap.numberOfColumns {
    for row in 0..<tileMap.numberOfRows {
        // Creates 100s or 1000s of physics bodies!
        let body = SKPhysicsBody(rectangleOf: tileSize)
        // ...
    }
}

// Solution: Combine adjacent tiles or use edge-based bodies
// See "Optimized Physics for Tile Maps" section above
```

### Pitfall 3: Forgetting Anchor Point

```swift
// Problem: Tile map positioned incorrectly
let tileMap = SKTileMapNode(...)
tileMap.position = .zero
// Tile map's bottom-left is at origin by default

// Solution: Set anchor point for centered positioning
tileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
tileMap.position = .zero
// Now tile map is centered at origin
```

### Pitfall 4: Not Enabling Automapping

```swift
// Problem: Adjacency rules don't work
let platformGroup = SKTileGroup(rules: [/* adjacency rules */])
tileMap.setTileGroup(platformGroup, forColumn: 5, row: 5)
// Adjacent tiles don't update automatically

// Solution: Enable automapping
tileMap.enableAutomapping = true
tileMap.setTileGroup(platformGroup, forColumn: 5, row: 5)
// Adjacent tiles now update based on rules
```

---

## Summary

**Key Principles:**
1. **Use Texture Atlases** - Essential for performance
2. **Choose the Right Creation Method** - Scene Editor for static, code for procedural
3. **Optimize Physics** - Combine adjacent tiles, use edge bodies
4. **Implement Culling** - For large maps, load/unload chunks
5. **Leverage Adjacency Rules** - Automatic edge and corner tiles
6. **Use Appropriate Tile Sizes** - Power-of-2 dimensions (32, 64, 128)

**When to Use SKTileMapNode:**
- ✅ Platformer levels
- ✅ RPG overworld maps
- ✅ Puzzle game grids
- ✅ Tile-based strategy games
- ✅ Procedurally generated dungeons

**When NOT to Use SKTileMapNode:**
- ❌ Small numbers of tiles (< 20) - use individual SKSpriteNodes
- ❌ Non-grid-based layouts - use regular nodes
- ❌ Highly dynamic content - consider particle systems or custom rendering
