# GameplayKit — Pathfinding

- Choose the graph type by movement style: `GKObstacleGraph` for precise corner-hugging paths, `GKMeshGraph` for smooth open-area movement, `GKGridGraph` for tile/grid games.
- Build obstacle graphs once and cache them — graph construction is expensive; only rebuild when the world geometry changes.
- Always call `connectUsingObstacles(node:)` for temporary start/end nodes, then `remove([startNode, endNode])` after pathfinding — leaving ad-hoc nodes in the graph leaks memory and degrades future searches.
- Set `bufferRadius` on `GKObstacleGraph` equal to the agent's collision radius — prevents characters from clipping through obstacle corners.
- Use `GKPolygonObstacle(points:count:)` for convex collision shapes; never use concave polygons directly — split them into convex parts first. In Swift, prefer the `init(points:)` overload that takes `[SIMD2<Float>]` directly.
- Prefer `GKCircleObstacle(radius:)` for point-like obstacles (turrets, barrels, enemy units) — agents compute avoidance against a circle much faster than against a polygon. Set `.position` to place it. Use `GKSphereObstacle` instead for 3D (`GKAgent3D`).
- `GKGraphNode2D` uses the same Y-up coordinate space as SpriteKit on all platforms — `SKView` always uses Y-up regardless of the underlying AppKit/UIKit coordinate system, so no coordinate flip is needed.
- Throttle pathfinding — recompute paths at most every 0.3–0.5 s for moving entities; use the last known path between recalculations.
- Generate `GKObstacle` arrays from `SKNode` physics bodies via `SKNode.obstacles(fromNodeBounds:)` or `SKNode.obstacles(fromNodePhysicsBodies:)` — avoids duplicating shape definitions.
- For `GKGridGraph`, use `GKGridGraphNode` and enable 8-directional movement with `diagonalsAllowed: true` only when gameplay supports diagonal travel.

## GKObstacleGraph — Precise Pathfinding

```swift
import GameplayKit

class PathfindingManager {
    private var obstacleGraph: GKObstacleGraph<GKGraphNode2D>!

    // Build once from your scene's obstacle nodes
    func buildGraph(obstacleNodes: [SKNode]) {
        let obstacles = SKNode.obstacles(fromNodePhysicsBodies: obstacleNodes)
        obstacleGraph = GKObstacleGraph(
            obstacles: obstacles,
            bufferRadius: 20          // Match agent collision radius
        )
    }

    // Returns SpriteKit positions along the path, or nil if unreachable
    func findPath(from start: CGPoint, to end: CGPoint) -> [CGPoint]? {
        let startNode = GKGraphNode2D(point: SIMD2<Float>(Float(start.x), Float(start.y)))
        let endNode   = GKGraphNode2D(point: SIMD2<Float>(Float(end.x),   Float(end.y)))

        obstacleGraph.connectUsingObstacles(node: startNode)
        obstacleGraph.connectUsingObstacles(node: endNode)

        // findPath returns [] (not nil) when no path exists — check isEmpty
        let rawPath = obstacleGraph.findPath(from: startNode, to: endNode) as? [GKGraphNode2D]

        // Always remove temporary nodes after use
        obstacleGraph.remove([startNode, endNode])

        guard let rawPath, !rawPath.isEmpty else { return nil }
        return rawPath.map { CGPoint(x: CGFloat($0.position.x), y: CGFloat($0.position.y)) }
    }
}
```

## GKMeshGraph — Smooth Open-Area Pathfinding

```swift
// GKMeshGraph fills navigable space with a mesh — paths are smoother
func buildMeshGraph(obstacleNodes: [SKNode], sceneSize: CGSize) -> GKMeshGraph<GKGraphNode2D> {
    let obstacles = SKNode.obstacles(fromNodePhysicsBodies: obstacleNodes)
    let graph = GKMeshGraph<GKGraphNode2D>(
        bufferRadius: 20,
        minCoordinate: SIMD2<Float>(0, 0),
        maxCoordinate: SIMD2<Float>(Float(sceneSize.width), Float(sceneSize.height))
    )
    graph.addObstacles(obstacles)
    graph.triangulate()     // Must call after adding all obstacles
    return graph
}

// Re-triangulate only when obstacles change — it's expensive
func addDynamicObstacle(_ obstacle: GKPolygonObstacle, to graph: GKMeshGraph<GKGraphNode2D>) {
    graph.addObstacles([obstacle])
    graph.triangulate()     // Required after each structural change
}
```

## GKGridGraph — Grid/Tile Pathfinding

```swift
// Suitable for tile maps with discrete movement
func buildGridGraph(columns: Int, rows: Int, tileSize: CGFloat) -> GKGridGraph<GKGridGraphNode> {
    let graph = GKGridGraph(
        fromGridStartingAt: SIMD2<Int32>(0, 0),
        width: Int32(columns),
        height: Int32(rows),
        diagonalsAllowed: false     // true for 8-directional movement
    )
    return graph
}

// Remove impassable tiles after construction
func markImpassable(positions: [SIMD2<Int32>], graph: GKGridGraph<GKGridGraphNode>) {
    let nodes = positions.compactMap { graph.node(atGridPosition: $0) }
    graph.remove(nodes)
}

// Find a tile path
func tilePathFrom(_ start: SIMD2<Int32>, to end: SIMD2<Int32>,
                  graph: GKGridGraph<GKGridGraphNode>) -> [SIMD2<Int32>]? {
    guard let startNode = graph.node(atGridPosition: start),
          let endNode   = graph.node(atGridPosition: end) else { return nil }
    let path = graph.findPath(from: startNode, to: endNode) as? [GKGridGraphNode]
    return path?.map { $0.gridPosition }
}
```

## Following a Path with SKAction

```swift
// Convert a node path into an SKAction sequence
func walkPath(_ waypoints: [CGPoint], speed: CGFloat) -> SKAction {
    guard waypoints.count > 1 else { return .idle() }
    let moves = zip(waypoints, waypoints.dropFirst()).map { (from, to) -> SKAction in
        let distance = hypot(to.x - from.x, to.y - from.y)
        let duration = TimeInterval(distance / speed)
        return .move(to: to, duration: duration)
    }
    return .sequence(moves)
}

// Usage: recompute path at throttled interval
class EnemyEntity: GKEntity {
    private var pathTimer: TimeInterval = 0
    private let pathInterval: TimeInterval = 0.4
    private weak var pathfinder: PathfindingManager?

    override func update(deltaTime seconds: TimeInterval) {
        pathTimer += seconds
        guard pathTimer >= pathInterval else { return }
        pathTimer = 0
        recomputePath()
    }

    private func recomputePath() {
        guard let myPos = sprite?.position, let targetPos = player?.position,
              let waypoints = pathfinder?.findPath(from: myPos, to: targetPos) else { return }
        sprite?.removeAction(forKey: "path")
        sprite?.run(walkPath(waypoints, speed: 120), withKey: "path")
    }
}
```

## Generating Obstacles from SKNode Bounds

```swift
// From physics bodies — respects physicsBody shape
let physicsObstacles = SKNode.obstacles(fromNodePhysicsBodies: wallNodes)

// From visual bounds — uses node's frame rectangle
let boundsObstacles = SKNode.obstacles(fromNodeBounds: crateNodes)

// Manual convex polygon obstacle — prefer Swift init(points:) over init(points:count:)
let pts: [SIMD2<Float>] = [
    SIMD2(0, 0), SIMD2(100, 0), SIMD2(100, 100), SIMD2(0, 100)
]
let manualObstacle = GKPolygonObstacle(points: pts)

// Circle obstacle — cheaper for point-like avoidance targets
let circle = GKCircleObstacle(radius: 24)
circle.position = SIMD2<Float>(Float(turret.position.x), Float(turret.position.y))

// Combine with GKGoal for agent avoidance
let avoid = GKGoal(toAvoid: [circle, manualObstacle], maxPredictionTime: 1.0)
behavior.setWeight(2.0, for: avoid)
```
