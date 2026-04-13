# GameplayKit — Rule Systems & Decision Trees

## Rule Systems (GKRuleSystem)

- Use `GKRuleSystem` to externalize complex AI decision logic — keep if/else chains out of `update(deltaTime:)`.
- Populate `ruleSystem.state` dictionary with current world data before each call to `evaluate()` — rules read from `state`, never from captured closures.
- Call `ruleSystem.reset()` before each evaluation cycle to clear the `executed` list and retract all previous facts — stale facts from a prior frame cause incorrect decisions.
- Set `GKRule.salience` to control evaluation order — higher salience rules run first; use this to implement priority-based AI (combat > exploration > idle).
- Use `assertFact(_:grade:)` and `retractFact(_:grade:)` for fuzzy logic — grades accumulate; a fact with grade ≥ 1.0 is fully asserted.
- Use `grade(forFact:)` after evaluation to drive continuous outputs (e.g., "aggression" grade → blend attack animation).
- Use `GKRule(predicate:assertingFact:grade:)` or `GKRule(predicate:retractingFact:grade:)` to create predicate-backed rules that assert/retract a fact — these factory methods avoid subclassing while still using `NSPredicate`.
- When using `NSPredicate` with `ruleSystem.state`, always use a block-based predicate (not a format string) — format strings cannot key into `NSMutableDictionary` entries without an `@objc` model object.
- Subclass `GKNSPredicateRule` only when you need custom action logic beyond asserting/retracting a single fact — override `performAction(in:)` for the action, and set `predicate` in `init(predicate:)`.
- Prefer `GKRule(blockPredicate:action:)` for inline rules during development — refactor into `GKRule` subclasses when sharing across multiple systems.
- Keep rule systems stateless between evaluations — all mutable context belongs in `state`, never as stored properties on rule objects.

## Decision Trees (GKDecisionTree)

- Use `GKDecisionTree` for multi-branch decisions with a fixed, known question hierarchy — simpler to build than a rule system when branches don't interact.
- Build decision trees in code (not from data) for type safety — avoid stringly-typed attribute keys.
- Cache `GKDecisionTree` instances — tree construction is not cheap; build once per AI type, reuse for all instances.
- Use `findAction(forAnswers:)` to query the tree with a dictionary of answers — returns the leaf action for the given input combination.

## Rule System Code

```swift
import GameplayKit

// MARK: - Rule Definitions

// Block-based rule — concise for simple conditions
let lowHealthRule = GKRule(
    blockPredicate: { system in
        let hp = system.state["hp"] as? Int ?? 0
        return hp < 30
    },
    action: { system in
        system.assertFact("shouldFlee" as NSString)
    }
)
lowHealthRule.salience = 10    // Evaluated first

let nearPlayerRule = GKRule(
    blockPredicate: { system in
        let dist = system.state["distanceToPlayer"] as? CGFloat ?? .infinity
        return dist < 200
    },
    action: { system in
        system.assertFact("playerNearby" as NSString)
    }
)
nearPlayerRule.salience = 5

// NSPredicate-based rule — use GKRule factory method (not GKNSPredicateRule directly)
// Block predicate reads from ruleSystem.state (NSMutableDictionary) at evaluation time
let aggressiveRule = GKRule(
    predicate: NSPredicate { object, _ in
        guard let state = object as? NSMutableDictionary,
              let dist = state["distanceToPlayer"] as? CGFloat,
              let hp   = state["hp"] as? Int else { return false }
        return dist < 150 && hp > 50
    },
    assertingFact: "shouldAttack" as NSString,
    grade: 1.0
)

// MARK: - System Setup

class EnemyAISystem {
    let ruleSystem = GKRuleSystem()

    init() {
        ruleSystem.add([lowHealthRule, nearPlayerRule, aggressiveRule])
    }

    func evaluate(hp: Int, distanceToPlayer: CGFloat) -> EnemyAction {
        // Reset before every evaluation — clear stale facts
        ruleSystem.reset()

        // Populate state
        ruleSystem.state["hp"] = hp
        ruleSystem.state["distanceToPlayer"] = distanceToPlayer

        ruleSystem.evaluate()

        // Read conclusions
        if ruleSystem.grade(forFact: "shouldFlee" as NSString) > 0 {
            return .flee
        } else if ruleSystem.grade(forFact: "shouldAttack" as NSString) > 0 {
            return .attack
        } else if ruleSystem.grade(forFact: "playerNearby" as NSString) > 0 {
            return .stalk
        }
        return .idle
    }
}

enum EnemyAction { case idle, stalk, attack, flee }
```

## Fuzzy Logic with Grades

```swift
// Fuzzy system: aggression is a continuous value, not binary

let almostDeadRule = GKRule(
    blockPredicate: { $0.state["hp"] as? Int ?? 100 < 20 },
    action: { $0.assertFact("aggression" as NSString, grade: -0.8) }  // Reduce aggression
)

let fullHealthRule = GKRule(
    blockPredicate: { $0.state["hp"] as? Int ?? 0 > 80 },
    action: { $0.assertFact("aggression" as NSString, grade: 0.5) }   // Add aggression
)

let corneredRule = GKRule(
    blockPredicate: { $0.state["isCornered"] as? Bool ?? false },
    action: { $0.assertFact("aggression" as NSString, grade: 1.0) }   // Cornered: max aggression
)

// After evaluate(), read the cumulative grade
let aggressionLevel = ruleSystem.grade(forFact: "aggression" as NSString)
// 0.0 = passive, 1.0+ = berserk — drive animation blend or damage multiplier
let damageMultiplier = 1.0 + aggressionLevel
```

## Salience-Based Priority

```swift
// Higher salience = evaluated first
// Example: survival > combat > exploration
let panicRule = GKRule(
    blockPredicate: { ($0.state["hp"] as? Int ?? 100) < 10 },
    action: { $0.assertFact("panic" as NSString) }
)
let fleeRule = GKRule(
    blockPredicate: { ($0.state["hp"] as? Int ?? 100) < 30 },
    action: { $0.assertFact("flee" as NSString) }
)
let attackRule = GKRule(
    blockPredicate: { $0.state["canAttack"] as? Bool ?? false },
    action: { $0.assertFact("attack" as NSString) }
)
let patrolRule = GKRule(
    blockPredicate: { _ in true },
    action: { $0.assertFact("patrol" as NSString) }
)

panicRule.salience  = 100
fleeRule.salience   = 50
attackRule.salience = 20
patrolRule.salience = 0

ruleSystem.add([panicRule, fleeRule, attackRule, patrolRule])
```

## Decision Tree

```swift
// Build a decision tree for item pickup behavior.
// Root question: "hasEnoughSpace?"
//   yes → ask "itemValue?"
//     "high"  → action: "pickup"
//     "low"   → action: "ignore"
//   no  → action: "ignore"
let tree = GKDecisionTree(attribute: "hasEnoughSpace" as NSString)

// createBranch is on GKDecisionNode (tree.rootNode), not on GKDecisionTree
// Branch for yes (true) — ask a follow-up question about item value
let valueNode = tree.rootNode.createBranch(value: true as NSNumber,
                                           attribute: "itemValue" as NSString)

// Branch for no (false) — leaf: ignore
tree.rootNode.createBranch(value: false as NSNumber, attribute: "ignore" as NSString)

// Sub-branches under valueNode — intermediate nodes also return GKDecisionNode
valueNode.createBranch(value: "high" as NSString, attribute: "pickup" as NSString)
valueNode.createBranch(value: "low" as NSString,  attribute: "ignore" as NSString)

// Query the tree with a snapshot of answers
let answers: [NSString: NSObjectProtocol] = [
    "hasEnoughSpace": true as NSNumber,
    "itemValue":      "high" as NSString
]
let action = tree.findAction(forAnswers: answers)   // → "pickup"
```

## Integration in Entity Update

```swift
// Drive entity behavior from rule system each frame (throttled)
class RuleComponent: GKComponent {
    let aiSystem = EnemyAISystem()
    private var ruleTimer: TimeInterval = 0
    private let ruleInterval: TimeInterval = 0.2  // 5× per second is sufficient

    override func update(deltaTime seconds: TimeInterval) {
        ruleTimer += seconds
        guard ruleTimer >= ruleInterval else { return }
        ruleTimer = 0

        guard let hp    = entity?.component(ofType: HealthComponent.self)?.hp,
              let dist  = entity?.component(ofType: SensorComponent.self)?.distanceToPlayer
        else { return }

        let action = aiSystem.evaluate(hp: hp, distanceToPlayer: dist)
        entity?.component(ofType: MovementComponent.self)?.applyAction(action)
    }
}
```
