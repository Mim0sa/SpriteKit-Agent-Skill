# SwiftUI Integration

SpriteView, state sharing, and mixed UI patterns.

---

## Basic SpriteView

### Simple Integration

```swift
import SwiftUI
import SpriteKit

struct GameView: View {
    var scene: SKScene {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .aspectFill
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
```

### SpriteView Options

```swift
SpriteView(scene: scene, options: [
    .allowsTransparency,
    .ignoresSiblingOrder
])
.frame(width: 300, height: 300)
```

---

## State Sharing

### @Observable Pattern (iOS 17+)

Modern observation using the `@Observable` macro - more efficient and simpler syntax:

```swift
@Observable
class GameState {
    var score: Int = 0
    var isPaused: Bool = false
}

struct GameContainerView: View {
    @State private var gameState = GameState()

    var body: some View {
        ZStack {
            SpriteView(scene: GameScene(state: gameState))

            VStack {
                Text("Score: \(gameState.score)")
                    .font(.title)
                Spacer()
            }
        }
    }
}

class GameScene: SKScene {
    weak var gameState: GameState?

    convenience init(state: GameState) {
        self.init(size: CGSize(width: 1024, height: 768))
        self.gameState = state
    }

    func updateScore(_ points: Int) {
        gameState?.score += points
    }
}
```

### ObservableObject Pattern (iOS 13+)

Traditional observation using `ObservableObject` protocol and `@Published` properties:

```swift
class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var isPaused: Bool = false
}

struct GameContainerView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            SpriteView(scene: GameScene(state: gameState))

            VStack {
                Text("Score: \(gameState.score)")
                    .font(.title)
                Spacer()
            }
        }
    }
}

class GameScene: SKScene {
    weak var gameState: GameState?

    convenience init(state: GameState) {
        self.init(size: CGSize(width: 1024, height: 768))
        self.gameState = state
    }

    func updateScore(_ points: Int) {
        gameState?.score += points
    }
}
```

---

## UIViewControllerRepresentable

### Custom SpriteKit View Controller

```swift
struct SpriteKitContainer: UIViewControllerRepresentable {
    let scene: SKScene

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let skView = SKView()
        skView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(skView)

        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            skView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            skView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor)
        ])

        skView.presentScene(scene)
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
```

---

## Checklist

- [ ] Use SpriteView for simple integration
- [ ] Share state via `@Observable` (iOS 17+) or `ObservableObject` (iOS 13+)
- [ ] Use weak references to avoid retain cycles
- [ ] Handle lifecycle properly (pause/resume)
- [ ] Use UIViewControllerRepresentable for custom setups
