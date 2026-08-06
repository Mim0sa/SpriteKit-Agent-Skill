import SpriteKit

enum PhysicsCategory {
    static let player: UInt32 = 1 << 0
    static let enemy: UInt32 = 1 << 1
    static let airborne: UInt32 = 1 << 2
}

final class GameScene: SKScene {
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard contact.bodyB.categoryBitMask == PhysicsCategory.enemy else { return }
        contact.bodyB.node?.removeFromParent()
    }
}

#if compiler(>=6.2)
extension GameScene: @MainActor SKPhysicsContactDelegate {}
#elseif compiler(>=6.0)
extension GameScene: @preconcurrency SKPhysicsContactDelegate {}
#else
extension GameScene: SKPhysicsContactDelegate {}
#endif
