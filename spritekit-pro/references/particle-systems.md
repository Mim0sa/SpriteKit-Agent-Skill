# Particle Systems

- Use `SKEmitterNode(fileNamed:)` for effects authored as `.sks` emitter assets; programmatic construction remains valid for generated or data-driven effects.
- Set `targetNode = scene` (or the world layer) on emitters attached to moving nodes — this causes particles to persist in world space after the emitter moves.
- Always set `numParticlesToEmit` for one-shot effects (explosions, impacts) so the emitter stops automatically.
- Use `.add` for luminous effects such as fire, sparks, and glow; retain `.alpha` when particles represent smoke, debris, or other opacity-bearing material.
- Set `fieldBitMask = 0` when the effect must ignore fields. Keep other particle properties simple unless the visual design uses them, and profile before claiming a performance win.
- Keep particle textures no larger than their visual detail requires and include fill-rate cost in performance testing.
- Remove emitters after one-shot effects complete; do not leave dead emitters in the node tree.
- Pool frequently reused emitters when asset decoding or allocation appears in measurements; call `resetSimulation()` before reuse.
- Set emitter and live-particle budgets from measurements on the minimum supported device. Treat sample counts as starting values, not framework limits.

## Particle Budget Signals

| Signal | What to inspect |
|--------|-----------------|
| Frame time while effects overlap | Fill-rate and blending pressure |
| Live particles and emitters | Unexpected accumulation or missing cleanup |
| Texture dimensions | Bandwidth relative to on-screen particle size |
| Minimum-device measurements | The budget to enforce for this project |

## One-Shot Effect (Auto-Remove)

```swift
func spawnExplosion(at position: CGPoint) {
    guard let emitter = SKEmitterNode(fileNamed: "Explosion") else { return }
    emitter.position = position
    emitter.targetNode = self
    emitter.numParticlesToEmit = 80  // Auto-stops after 80 particles
    worldLayer.addChild(emitter)

    // Remove after particles have lived out their lifetime.
    // particleLifetimeRange varies ±half its value, so max lifetime = base + range/2.
    let lifetime = emitter.particleLifetime + emitter.particleLifetimeRange / 2
    emitter.run(SKAction.sequence([
        SKAction.wait(forDuration: TimeInterval(lifetime)),
        SKAction.removeFromParent()
    ]))
}
```

## World-Space Particles on Moving Emitter

```swift
// Attached to ship but particles trail in world space
let thruster = SKEmitterNode(fileNamed: "Thruster")!
thruster.targetNode = worldLayer  // Particles stay in world after ship moves
ship.addChild(thruster)
```

## Emitter Pool

```swift
class EmitterPool {
    private var available: [SKEmitterNode] = []
    private let fileName: String

    init(fileName: String, capacity: Int) {
        self.fileName = fileName
        (0..<capacity).forEach { _ in
            if let e = SKEmitterNode(fileNamed: fileName) { available.append(e) }
        }
    }

    func acquire() -> SKEmitterNode? {
        let emitter = available.popLast() ?? SKEmitterNode(fileNamed: fileName)
        return emitter
    }

    func release(_ emitter: SKEmitterNode) {
        emitter.removeFromParent()
        emitter.resetSimulation()
        available.append(emitter)
    }
}
```

## Additive vs Alpha Blend Mode

```swift
// Preferred for fire, sparks, glow effects
emitter.particleBlendMode = .add

// Appropriate for smoke, dust, debris, and ordinary transparency
emitter.particleBlendMode = .alpha
```
