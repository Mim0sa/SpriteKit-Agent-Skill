# Audio Integration

- Use `SKAudioNode` for all in-game audio — it integrates with SpriteKit's scene graph and lifecycle automatically.
- Set `isPositional = false` for background music and ambient loops; use `isPositional = true` only for sounds attached to game objects.
- Set `scene.listener` to the player node to enable automatic 3D panning and attenuation for all positional audio. SpriteKit tracks the listener node's position automatically — do not manually sync it in `update(_:)`.
- Remove one-shot sound nodes from the parent after playback — orphaned `SKAudioNode` instances leak memory.
- Use `SKAction.changeVolume(to:duration:)` to fade music in and out — never jump volume abruptly.
- Use `AVAudioEngine` directly when you need effects chains (reverb, EQ, compression) beyond what `SKAudioNode` exposes.
- Prefer `.wav` for short sound effects (lower decode latency) and `.mp3` or `.m4a` for background music (better compression).

## Background Music

```swift
class GameScene: SKScene {
    private var music: SKAudioNode?

    func playMusic(named name: String) {
        music?.removeFromParent()
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        let node = SKAudioNode(url: url)
        node.autoplayLooped = true
        node.isPositional = false
        node.run(SKAction.changeVolume(to: 0.5, duration: 0))
        addChild(node)
        music = node
    }

    func stopMusic() {
        let fade = SKAction.changeVolume(to: 0, duration: 1.0)
        let remove = SKAction.removeFromParent()
        music?.run(SKAction.sequence([fade, remove]))
        music = nil
    }
}
```

## One-Shot Sound Effect

```swift
func playSFX(named name: String) {
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
    let sfx = SKAudioNode(url: url)
    sfx.autoplayLooped = false
    sfx.isPositional = false
    addChild(sfx)

    // Auto-remove after playback (use actual duration if known)
    sfx.run(SKAction.sequence([
        SKAction.wait(forDuration: 2.0),
        SKAction.removeFromParent()
    ]))
}
```

## Positional Audio with Listener

```swift
class GameScene: SKScene {
    var player: SKSpriteNode!

    override func didMove(to view: SKView) {
        self.listener = player  // Scene automatically pans audio relative to this node

        let enemy = SKSpriteNode(imageNamed: "enemy")
        enemy.position = CGPoint(x: 400, y: 0)

        let hum = SKAudioNode(fileNamed: "enemy_hum.wav")
        hum.isPositional = true
        hum.autoplayLooped = true
        enemy.addChild(hum)
        worldLayer.addChild(enemy)
    }

    // No update() needed — SpriteKit tracks the listener node's position automatically
}
```

## AVAudioEngine (Advanced Effects)

```swift
class GameScene: SKScene {
    override func didMove(to view: SKView) {
        let engine = self.audioEngine  // Non-optional — always present on SKScene
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 25
        engine.attach(reverb)
        // Disconnect the existing mainMixerNode → outputNode path before inserting reverb
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(engine.mainMixerNode, to: reverb, format: nil)
        engine.connect(reverb, to: engine.outputNode, format: nil)
    }
}
```
