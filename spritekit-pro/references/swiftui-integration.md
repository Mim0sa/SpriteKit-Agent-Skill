# SwiftUI Integration

- Use `SpriteView` to embed SpriteKit in SwiftUI — prefer it over `UIViewControllerRepresentable`; it handles the `SKView` lifecycle automatically.
- Never create the `SKScene` inline as a computed `var` on a `View` — it re-creates the scene on every render pass. Store it in `@State` or a separate stored property.
- Pass shared state via `@Observable`. Never expose game state through global singletons.
- Hold a `weak` reference to shared state objects inside `SKScene` — a strong reference creates a retain cycle between the scene and the SwiftUI state.
- Update SwiftUI state from SpriteKit callbacks directly — `SKScene` callbacks run on the main thread; no dispatch required unless you forked work to a background queue.
- Pause/resume the scene in response to SwiftUI lifecycle events (`.onChange(of: scenePhase)`).

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
@Observable
class GameState {
    var score: Int = 0
    var lives: Int = 3
}

struct GameView: View {
    @State private var gameState = GameState()
    // Scene held in @State — created once, not re-created on every render pass
    @State private var scene: GameScene = GameScene.make()

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
            VStack {
                Text("Score: \(gameState.score)").font(.title).foregroundStyle(.white)
                Spacer()
            }.padding()
        }
        .ignoresSafeArea()
        .onAppear { scene.gameState = gameState }  // Wire state after scene is stable
    }
}

class GameScene: SKScene {
    weak var gameState: GameState?  // weak — avoids retain cycle

    static func make() -> GameScene {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFill
        return scene
    }

    func playerScored(_ points: Int) {
        gameState?.score += points  // Mutates @Observable on main thread
    }
}
```

## State Sharing — ObservableObject (iOS 13+)

```swift
class GameState: ObservableObject {
    @Published var score: Int = 0
}

struct GameView: View {
    @StateObject private var gameState = GameState()
    var body: some View {
        SpriteView(scene: GameScene.make(state: gameState))
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
