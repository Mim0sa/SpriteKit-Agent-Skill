# SwiftUI Integration

- Use `SpriteView` for embedding SpriteKit scenes in SwiftUI — it handles the `SKView` lifecycle automatically.
- Never create the `SKScene` inline as a computed `var` on the `View` struct — it re-creates the scene on every render pass. Use `@State` or a separate stored property.
- Pass shared state via `@Observable` (iOS 17+) or `ObservableObject` (iOS 13+). Never expose game state through global singletons.
- Hold a `weak` reference to shared state objects inside `SKScene` — a strong reference creates a retain cycle between the scene and the SwiftUI state.
- Update SwiftUI state from SpriteKit only on the main actor — `SKScene` callbacks run on the main thread, but confirm this when using async dispatch.
- Use `UIViewControllerRepresentable` only when you need `SKView` configuration not exposed by `SpriteView` (e.g. custom `preferredFramesPerSecond`).
- Pause/resume the scene in response to SwiftUI lifecycle events (`onAppear`/`onDisappear` or `.onChange(of: scenePhase)`).

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
