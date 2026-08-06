# SwiftUI Integration

- Use `SpriteView` for standard SwiftUI embedding. Use `UIViewRepresentable` or `UIViewControllerRepresentable` when the feature requires direct `SKView` configuration that `SpriteView` does not expose.
- Never create the `SKScene` inline as a computed `var` on a `View` — it re-creates the scene on every render pass. Store it in `@State` or a separate stored property.
- Pass shared state via `@Observable` when Observation is available; avoid global singletons.
- Give shared state one clear owner. `SKScene` may hold it strongly unless the state also retains the scene; use `weak` only when it breaks a demonstrated ownership cycle.
- Update SwiftUI state from SpriteKit callbacks directly — `SKScene` callbacks run on the main thread; no dispatch required unless you forked work to a background queue.
- Pause/resume gameplay in response to SwiftUI lifecycle events when background simulation is not intended.

## Stable Scene Creation

```swift
// Wrong: scene re-created on every SwiftUI render pass
struct GameView: View {
    var scene: SKScene {  // Computed property = new scene every time
        let s = GameScene(size: CGSize(width: 1024, height: 768))
        s.scaleMode = .aspectFill
        return s
    }
    var body: some View { SpriteView(scene: scene) }
}

// Correct: scene held in @State
struct GameView: View {
    @State private var scene = GameScene.make()
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
extension GameScene {
    static func make() -> GameScene {
        let s = GameScene(size: CGSize(width: 1024, height: 768))
        s.scaleMode = .aspectFill
        return s
    }
}
```

## State Sharing — @Observable (iOS 17+)

```swift
import Observation

@MainActor
@Observable
class GameState {
    var score: Int = 0
    var lives: Int = 3
}

@MainActor
struct GameView: View {
    @State private var gameState: GameState
    @State private var scene: GameScene

    init() {
        let state = GameState()
        _gameState = State(initialValue: state)
        _scene = State(initialValue: GameScene.make(state: state))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
            VStack {
                Text("Score: \(gameState.score)").font(.title).foregroundStyle(.white)
                Spacer()
            }.padding()
        }
        .ignoresSafeArea()
    }
}

class GameScene: SKScene {
    // Strong is correct here because GameState does not retain GameScene.
    var gameState: GameState?

    static func make(state: GameState) -> GameScene {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFill
        scene.gameState = state
        return scene
    }

    func playerScored(_ points: Int) {
        gameState?.score += points  // Mutates @Observable on main thread
    }
}
```

## State Sharing — ObservableObject (iOS 14+)

```swift
class GameState: ObservableObject {
    @Published var score: Int = 0
}

@MainActor
struct GameView: View {
    @StateObject private var gameState: GameState
    @State private var scene: GameScene

    init() {
        let state = GameState()
        let scene = GameScene.make()
        scene.gameState = state
        _gameState = StateObject(wrappedValue: state)
        _scene = State(initialValue: scene)
    }

    var body: some View {
        SpriteView(scene: scene)
    }
}
```

## Lifecycle — Pause on Background

```swift
struct GameView: View {
    @State private var scene = GameScene.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onChange(of: scenePhase) { _, phase in
                scene.isPaused = (phase != .active)
            }
    }
}
```
