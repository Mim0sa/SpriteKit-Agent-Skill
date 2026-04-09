# Particle Systems

- Use `SKEmitterNode(fileNamed:)` over programmatic creation for effects designed in Xcode's particle editor.
- Set `targetNode = scene` (or the world layer) on emitters attached to moving nodes — this causes particles to persist in world space after the emitter moves.
- Always set `numParticlesToEmit` for one-shot effects (explosions, impacts) so the emitter stops automatically.
- Use `additive` blend mode (`particleBlendMode = .add`) instead of `alpha` — faster rendering and produces correct glow/fire look.
- Disable unused particle properties (`particleRotationSpeed = 0`, `fieldBitMask = 0`) — unused channels still incur evaluation cost.
- Use small, simple particle textures (< 64×64) — large textures multiply GPU texture bandwidth.
- Remove emitters after one-shot effects complete; do not leave dead emitters in the node tree.
- Pool frequently reused emitters with `resetSimulation()` on release — recreating from file on every spawn is expensive.
- Keep total live particles below 1000–2000 on iPhone, 3000–5000 on Apple TV.

## Particle Count Limits

| Device | Max Concurrent Particles | Max Emitters |
|--------|--------------------------|--------------|
| iPhone | 1000–2000 | 5–10 |
| iPad | 2000–4000 | 10–15 |
| Apple TV | 3000–5000 | 10–20 |

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
emitter.particleBlendMode = .add    // Faster, no overdraw depth sorting

// Use only when true transparency/overlap is required
emitter.particleBlendMode = .alpha
```
