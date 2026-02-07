# Particle Systems

Best practices for SKEmitterNode configuration and optimization.

---

## Emitter Creation

### Programmatic Creation

```swift
func createFireEmitter() -> SKEmitterNode {
    let emitter = SKEmitterNode()

    // Particle texture
    emitter.particleTexture = SKTexture(imageNamed: "spark")

    // Emission rate
    emitter.particleBirthRate = 100
    emitter.numParticlesToEmit = 0  // 0 = infinite

    // Particle lifetime
    emitter.particleLifetime = 1.0
    emitter.particleLifetimeRange = 0.5

    // Position
    emitter.position = CGPoint(x: 0, y: 0)
    emitter.particlePositionRange = CGVector(dx: 20, dy: 0)

    // Movement
    emitter.emissionAngle = .pi / 2  // Up
    emitter.emissionAngleRange = .pi / 8
    emitter.particleSpeed = 100
    emitter.particleSpeedRange = 50

    // Physics
    emitter.xAcceleration = 0
    emitter.yAcceleration = -50  // Gravity

    // Scale
    emitter.particleScale = 1.0
    emitter.particleScaleRange = 0.5
    emitter.particleScaleSpeed = -0.5  // Shrink over time

    // Rotation
    emitter.particleRotation = 0
    emitter.particleRotationRange = .pi
    emitter.particleRotationSpeed = 2.0

    // Color
    emitter.particleColor = .orange
    emitter.particleColorBlendFactor = 1.0
    emitter.particleColorSequence = SKKeyframeSequence(
        keyframeValues: [UIColor.red, UIColor.orange, UIColor.yellow, UIColor.clear],
        times: [0, 0.3, 0.7, 1]
    )

    // Alpha
    emitter.particleAlpha = 1.0
    emitter.particleAlphaRange = 0.2
    emitter.particleAlphaSpeed = -1.0  // Fade out

    // Blend mode
    emitter.particleBlendMode = .add

    return emitter
}
```

### Loading from File

```swift
// Correct: Load pre-configured emitter
if let emitter = SKEmitterNode(fileNamed: "FireParticle") {
    emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
    addChild(emitter)
}

// Target a specific node
emitter.targetNode = self  // Particles render relative to scene
```

---

## Performance Guidelines

### Particle Count Limits

| Device | Max Particles | Max Emitters |
|--------|--------------|--------------|
| iPhone | 1000-2000 | 5-10 |
| iPad | 2000-4000 | 10-15 |
| Apple TV | 3000-5000 | 10-20 |

### Optimization Techniques

```swift
// Limit concurrent particles
emitter.numParticlesToEmit = 100  // Emit only 100 then stop

// Use simple textures
emitter.particleTexture = SKTexture(imageNamed: "simple_circle")  // Small, simple

// Reduce overdraw with additive blending
emitter.particleBlendMode = .add  // Faster than alpha

// Disable unnecessary features
emitter.particleRotationSpeed = 0  // If not needed
emitter.fieldBitMask = 0  // If not using physics fields
```

### Pooling Emitters

```swift
class EmitterPool {
    private var available: [SKEmitterNode] = []
    private let create: () -> SKEmitterNode

    init(create: @escaping () -> SKEmitterNode, capacity: Int) {
        self.create = create
        for _ in 0..<capacity {
            available.append(create())
        }
    }

    func acquire() -> SKEmitterNode {
        return available.popLast() ?? create()
    }

    func release(_ emitter: SKEmitterNode) {
        emitter.removeFromParent()
        emitter.resetSimulation()
        available.append(emitter)
    }
}
```

---

## Common Particle Types

### Explosion Effect

```swift
func createExplosion() -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.particleTexture = SKTexture(imageNamed: "spark")
    emitter.particleBirthRate = 1000
    emitter.numParticlesToEmit = 100  // One-time burst
    emitter.particleLifetime = 0.5
    emitter.particleSpeed = 200
    emitter.particleSpeedRange = 100
    emitter.emissionAngleRange = .pi * 2  // All directions
    emitter.particleScaleSpeed = -2.0
    emitter.particleAlphaSpeed = -2.0
    emitter.particleBlendMode = .add
    return emitter
}
```

### Trail Effect

```swift
func createTrail() -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.particleTexture = SKTexture(imageNamed: "trail")
    emitter.particleBirthRate = 50
    emitter.particleLifetime = 0.5
    emitter.particleSpeed = 0  // Follow emitter position
    emitter.particleScaleSpeed = -0.5
    emitter.particleAlphaSpeed = -1.0
    return emitter
}
```

---

## Checklist

- [ ] Use small, simple particle textures
- [ ] Limit total concurrent particles
- [ ] Set `numParticlesToEmit` for one-shot effects
- [ ] Use additive blending when possible
- [ ] Pool frequently used emitters
- [ ] Set `targetNode` for correct rendering
- [ ] Disable unused features (rotation, fields)
- [ ] Remove emitters when effects complete
