# GameplayKit — Randomization & Procedural Noise

## Randomization

- Prefer `GKRandomSource` subclasses over `arc4random` or `Int.random(in:)` for gameplay randomness — they are seedable, reproducible, and can be serialized for replays.
- Use `GKARC4RandomSource` for most gameplay needs — good balance of speed and randomness; seed it to reproduce a specific session.
- Use `GKMersenneTwisterRandomSource` when high statistical quality is required (procedural generation, simulations) and speed is secondary.
- Use `GKLinearCongruentialRandomSource` only for non-critical, high-frequency decisions where speed matters most — it has noticeable patterns over large samples.
- Wrap any `GKRandomSource` in a `GKGaussianDistribution` for natural-feeling variance (damage spread, spawn timing) — results cluster around the mean.
- Wrap in `GKShuffledDistribution` when you need uniform coverage with no clustering — prevents "lucky streaks" in loot or spawn tables.
- Use `GKRandomDistribution.d6()` / `.d20()` as semantic aliases for die rolls — they communicate intent clearly in gameplay code.
- Store and restore `GKRandomSource` state via `NSCoder` for deterministic replay — the same seed + same sequence = identical game session.
- Never use GameplayKit random sources on the main thread for large batch operations (generating noise maps, shuffling thousands of items) — do this on a background queue and push results to the main thread.

### Source Selection Guide

| Source | Quality | Speed | Use Case |
|--------|---------|-------|----------|
| `GKARC4RandomSource` | Good | Fast | General gameplay, most decisions |
| `GKMersenneTwisterRandomSource` | Best | Slower | World gen, statistical simulations |
| `GKLinearCongruentialRandomSource` | Moderate | Fastest | Particle variation, non-critical high-frequency |

## Randomization Code

```swift
import GameplayKit

// Seeded source — reproducible sessions (replays, level seeds)
// GKMersenneTwisterRandomSource has best statistical quality for procedural generation
let seed: UInt64 = 42
let seededSource = GKMersenneTwisterRandomSource(seed: seed)

// Unseeded source — general gameplay (non-reproducible)
// GKARC4RandomSource is the best default for most in-game decisions
let source = GKARC4RandomSource()

// Uniform die: 1–6
let d6 = GKRandomDistribution.d6()
let roll = d6.nextInt()              // 1...6

// Custom range: 10–50
let dist = GKRandomDistribution(randomSource: seededSource, lowestValue: 10, highestValue: 50)
let value = dist.nextInt()           // 10...50

// Gaussian — clusters around mean
let gaussDist = GKGaussianDistribution(randomSource: seededSource, mean: 25, deviation: 5)
let dmg = gaussDist.nextInt()        // Most values near 25

// Shuffled — no runs of similar values
let shuffled = GKShuffledDistribution(randomSource: source, lowestValue: 1, highestValue: 5)
// Guarantees each value appears before any repeats

// nextBool — 50/50 coin flip
let dropLoot = d6.nextBool()

// nextUniform — 0.0...1.0 Float
let alpha = Float(dist.nextUniform())

// Shuffling arrays
let shuffledDeck = seededSource.arrayByShufflingObjects(in: cardArray) as! [Card]
```

---

## Procedural Noise

- Prefer `GKPerlinNoiseSource` for terrain, clouds, and organic shapes — it resembles natural phenomena and is the most versatile noise type.
- Use `GKRidgedNoiseSource` for mountain ridges and sharp geological features — it amplifies high-frequency detail at peaks.
- Use `GKBillowNoiseSource` for smooth, puffy shapes like clouds or rolling hills — it is Perlin with absolute-value post-processing.
- Use `GKVoronoiNoiseSource` for cell-based patterns: cracked earth, scales, stone textures.
- Always construct the pipeline in order: `GKNoiseSource` → `GKNoise` → `GKNoiseMap` → output — skipping steps wastes computation.
- `GKNoise` operations (add, multiply, clamp, invert) are lazy — computation only happens when `GKNoiseMap` is created; chain them freely.
- Use `GKNoiseMap(noise:size:origin:sampleCount:seamless:)` with `seamless: true` for tileable textures — essential for repeating backgrounds.
- Convert `GKNoiseMap` to `SKTexture` via `SKTexture(noiseMap:)` — generates the texture on the calling thread; do this off the main thread for large maps.
- Use `noiseMap.value(at:)` to read individual noise values as `Float` in `[-1, 1]` for procedural tile selection or height maps.
- Set a fixed `seed` on noise sources for reproducible world generation; use a player-derived value (level number, timestamp) to vary per run.

### Noise Source Quick Reference

| Source | Output Pattern | Typical Use |
|--------|---------------|-------------|
| `GKPerlinNoiseSource` | Smooth fractal | Terrain, clouds, water |
| `GKRidgedNoiseSource` | Sharp ridges | Mountains, cracks |
| `GKBillowNoiseSource` | Smooth bumps | Clouds, dunes |
| `GKVoronoiNoiseSource` | Cell patterns | Stone, scales, cracked mud |
| `GKCylindersNoiseSource` | Concentric cylinders | Wood grain |
| `GKSpheresNoiseSource` | Concentric spheres | Marble |
| `GKCheckerboardNoiseSource` | Checkerboard | Debug / stylized |

## Noise Pipeline Code

```swift
import GameplayKit
import SpriteKit

// 1. Configure noise source
let perlin = GKPerlinNoiseSource(
    frequency: 2.0,          // Scale of features — higher = finer detail
    octaveCount: 6,          // Layers of detail
    persistence: 0.5,        // Amplitude falloff per octave
    lacunarity: 2.0,         // Frequency multiplier per octave
    seed: Int32(42)
)

// 2. Create noise object — apply operations here
let noise = GKNoise(perlin)
noise.clamp(lowerBound: -0.5, upperBound: 0.8)    // Flatten low terrain
noise.remapValues(toTerracesWithPeaks: [-0.5, 0, 0.5, 1.0], terracesInverted: false)

// 3. Sample into a finite map
let noiseMap = GKNoiseMap(
    noise,
    size: SIMD2<Double>(1.0, 1.0),           // Normalized world size
    origin: SIMD2<Double>(0, 0),
    sampleCount: SIMD2<Int32>(256, 256),      // Resolution
    seamless: true                            // Tileable
)

// 4a. Generate SKTexture (off main thread)
DispatchQueue.global(qos: .userInitiated).async {
    let texture = SKTexture(noiseMap: noiseMap)
    DispatchQueue.main.async {
        backgroundNode.texture = texture
    }
}

// 4b. Read values for tile selection
let rawValue = noiseMap.value(at: vector_int2(Int32(x), Int32(y)))  // -1.0...1.0
let tileType: TileType = rawValue < -0.3 ? .water : rawValue < 0.3 ? .grass : .mountain
```

## Combining Noise Sources

```swift
// Layer multiple noise sources to blend terrain types
let baseNoise   = GKNoise(GKPerlinNoiseSource(frequency: 1.5, octaveCount: 4, persistence: 0.5, lacunarity: 2.0, seed: 1))
let detailNoise = GKNoise(GKRidgedNoiseSource(frequency: 3.0, octaveCount: 3, lacunarity: 2.0, seed: 2))
let selectNoise = GKNoise(GKPerlinNoiseSource(frequency: 0.5, octaveCount: 2, persistence: 0.5, lacunarity: 2.0, seed: 3))

// Blend: where selector > 0, use detailNoise; elsewhere use baseNoise
let combined = GKNoise(componentNoises: [baseNoise, detailNoise], selectionNoise: selectNoise)
let finalMap = GKNoiseMap(combined, size: SIMD2(1.0, 1.0), origin: .zero,
                          sampleCount: SIMD2<Int32>(512, 512), seamless: false)
```

## Procedural Tile Map Generation

```swift
// Use noise values to assign tile groups in SKTileMapNode
func populateTileMap(_ tileMap: SKTileMapNode, noiseMap: GKNoiseMap,
                     waterGroup: SKTileGroup, grassGroup: SKTileGroup, rockGroup: SKTileGroup) {
    let cols = tileMap.numberOfColumns
    let rows = tileMap.numberOfRows

    for col in 0..<cols {
        for row in 0..<rows {
            let pos = vector_int2(Int32(col), Int32(row))
            let v   = noiseMap.value(at: pos)  // -1.0...1.0

            let group: SKTileGroup = v < -0.2 ? waterGroup
                                   : v < 0.4  ? grassGroup
                                   :             rockGroup
            tileMap.setTileGroup(group, forColumn: col, row: row)
        }
    }
}
```
