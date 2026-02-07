# Audio Integration

SKAudioNode and AVAudioEngine usage patterns.

---

## SKAudioNode Basics

### Simple Audio Playback

```swift
class GameScene: SKScene {
    var backgroundMusic: SKAudioNode!
    var soundEffect: SKAudioNode!

    override func didMove(to view: SKView) {
        // Background music
        if let url = Bundle.main.url(forResource: "background", withExtension: "mp3") {
            backgroundMusic = SKAudioNode(url: url)
            backgroundMusic.autoplayLooped = true
            backgroundMusic.isPositional = false
            addChild(backgroundMusic)
        }
    }

    func playSoundEffect(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }

        let sound = SKAudioNode(url: url)
        sound.autoplayLooped = false
        addChild(sound)

        // Remove after playing
        let wait = SKAction.wait(forDuration: 2.0)
        let remove = SKAction.removeFromParent()
        sound.run(SKAction.sequence([wait, remove]))
    }
}
```

### Positional Audio

```swift
func createPositionalSound(at position: CGPoint) {
    guard let url = Bundle.main.url(forResource: "explosion", withExtension: "wav") else { return }

    let sound = SKAudioNode(url: url)
    sound.position = position
    sound.isPositional = true  // 3D audio effect

    // Configure attenuation
    sound.avAudioNode?.environmentalNode?.distanceAttenuationParameters.distanceAttenuationModel = .exponential

    addChild(sound)
}
```

---

## Spatial Audio with Scene Listener

Set up positional audio with a listener node for true 3D sound:

```swift
class SpatialAudioScene: SKScene {
    func setupSpatialAudio() {
        // Set the listener - usually the player character
        let playerNode = SKNode()
        playerNode.position = CGPoint(x: 0, y: 0)
        addChild(playerNode)
        self.listener = playerNode  // Scene's listener property

        // Create enemy with positional audio
        let enemy = SKSpriteNode(imageNamed: "enemy")
        enemy.position = CGPoint(x: 200, y: 0)

        // Add humming sound to enemy
        let audioNode = SKAudioNode(fileNamed: "enemy-hum.wav")
        audioNode.isPositional = true
        audioNode.autoplayLooped = true
        enemy.addChild(audioNode)

        addChild(enemy)

        // As enemy moves, audio panning and volume adjust automatically
        // based on distance from listener (player)
    }

    override func update(_ currentTime: TimeInterval) {
        // Update listener position to follow player
        listener?.position = player.position
    }
}
```

### Audio Engine Configuration

Access the scene's AVAudioEngine for advanced configuration:

```swift
class CustomAudioEnvironment: SKScene {
    func configureAudioEnvironment() {
        guard let audioEngine = self.audioEngine else { return }

        // Add environmental reverb
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 20

        audioEngine.attach(reverb)

        // Connect main mixer through reverb
        audioEngine.connect(audioEngine.mainMixerNode, to: reverb, format: nil)
        audioEngine.connect(reverb, to: audioEngine.outputNode, format: nil)
    }
}
```

---

## Volume and Control

### Audio Management

```swift
class AudioManager {
    static let shared = AudioManager()

    var musicVolume: Float = 0.5 {
        didSet {
            backgroundMusic?.run(SKAction.changeVolume(to: musicVolume, duration: 0.5))
        }
    }

    var sfxVolume: Float = 0.7

    private var backgroundMusic: SKAudioNode?

    func playMusic(named name: String) {
        backgroundMusic?.removeFromParent()

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }

        let music = SKAudioNode(url: url)
        music.autoplayLooped = true
        music.isPositional = false

        // Fade in
        music.run(SKAction.changeVolume(to: musicVolume, duration: 1.0))

        // Store reference
        backgroundMusic = music
    }

    func stopMusic() {
        guard let music = backgroundMusic else { return }

        // Fade out
        let fadeOut = SKAction.changeVolume(to: 0, duration: 1.0)
        let stop = SKAction.removeFromParent()
        music.run(SKAction.sequence([fadeOut, stop]))
    }
}
```

---

## AVAudioEngine (Advanced)

### Custom Audio Processing

```swift
import AVFoundation

class AdvancedAudioScene: SKScene {
    var audioEngine: AVAudioEngine!
    var musicPlayer: AVAudioPlayerNode!
    var reverb: AVAudioUnitReverb!

    override func didMove(to view: SKView) {
        setupAudioEngine()
    }

    func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        musicPlayer = AVAudioPlayerNode()
        reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = 30

        // Connect nodes
        audioEngine.attach(musicPlayer)
        audioEngine.attach(reverb)

        audioEngine.connect(musicPlayer, to: reverb, format: nil)
        audioEngine.connect(reverb, to: audioEngine.mainMixerNode, format: nil)

        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func playEffectWithReverb(url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else { return }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: reverb, format: file.processingFormat)

        player.scheduleFile(file, at: nil)
        player.play()
    }
}
```

---

## Checklist

- [ ] Use SKAudioNode for simple audio needs
- [ ] Set isPositional for 3D audio effects
- [ ] Set scene `listener` for spatial audio reference point
- [ ] Remove one-shot audio nodes after playback
- [ ] Implement volume controls
- [ ] Fade audio in/out for smooth transitions
- [ ] Use AVAudioEngine for advanced processing
- [ ] Handle audio interruptions properly
- [ ] Update listener position to follow player for dynamic spatial audio
