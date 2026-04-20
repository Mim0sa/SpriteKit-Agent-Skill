# GameplayKit — Spatial Partitioning

- Use `GKQuadtree` (2D) or `GKOctree` (3D) instead of a linear scan over `entities` when you need frequent "what's near point P" or "what's in region R" queries with hundreds of entities — quadtree search is near-constant time; linear scan is O(n) per query.
- Choose `GKRTree` over `GKQuadtree` when the queries are mostly region-overlap tests and objects rarely move; choose `GKQuadtree` when objects move every frame or are uniformly distributed.
- Rebuild the tree at most once per frame — do not add/remove the same element multiple times per frame. For per-frame moving entities, rebuild the whole tree instead of updating it incrementally.
- Generic parameter must be an `NSObject` subclass: `GKQuadtree<ElementType> where ElementType: NSObject`. Wrap non-NSObject entities or use `GKEntity` directly (already an `NSObject`).
- Pick `minimumCellSize` to roughly match the typical query radius — too small wastes memory on deep subdivisions; too large degrades to linear scan within a cell.
- `elements(at:)` takes a point; `elements(in:)` takes a `GKQuad`. Both return `[ElementType]`, not optionals.

## GKQuadtree — Nearest-Entity Lookup

```swift
import GameplayKit

class SpatialIndex {
    private var tree: GKQuadtree<GKEntity>

    init(sceneSize: CGSize) {
        let bounds = GKQuad(
            quadMin: SIMD2<Float>(0, 0),
            quadMax: SIMD2<Float>(Float(sceneSize.width), Float(sceneSize.height))
        )
        tree = GKQuadtree(boundingQuad: bounds, minimumCellSize: 32)
    }

    // Rebuild once per frame from current entity positions
    func rebuild(entities: [GKEntity]) {
        tree = GKQuadtree(boundingQuad: tree.boundingQuad, minimumCellSize: 32)
        for entity in entities {
            guard let node = entity.component(ofType: SpriteComponent.self)?.node else { continue }
            let p = SIMD2<Float>(Float(node.position.x), Float(node.position.y))
            tree.add(entity, at: p)
        }
    }

    // Query: all entities within `radius` of `point`
    func entities(near point: CGPoint, radius: CGFloat) -> [GKEntity] {
        let r = Float(radius)
        let min = SIMD2<Float>(Float(point.x) - r, Float(point.y) - r)
        let max = SIMD2<Float>(Float(point.x) + r, Float(point.y) + r)
        return tree.elements(in: GKQuad(quadMin: min, quadMax: max))
    }
}
```
