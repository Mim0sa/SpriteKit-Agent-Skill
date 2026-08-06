import SpriteKit

final class Enemy: SKSpriteNode {
    func moveForward() {
        run(.moveBy(x: 20, y: 0, duration: 0.2)) {
            self.recordMove()
        }
    }

    func startTurning() {
        run(.repeatForever(.run {
            self.turnAround()
        }), withKey: "turn")
    }

    private func recordMove() {}
    private func turnAround() {}
}
