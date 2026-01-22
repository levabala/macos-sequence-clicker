import Foundation

/// Scenario-specific assertions
struct ScenarioAssertions {
    
    /// Assert the number of scenarios
    static func assertCount(
        _ scenarios: [Scenario],
        equals expected: Int,
        file: String = #file,
        line: Int = #line
    ) throws {
        if scenarios.count != expected {
            throw AssertionError(
                message: "Expected \(expected) scenario(s), got \(scenarios.count)",
                file: file,
                line: line
            )
        }
    }
    
    /// Assert a scenario exists with a given name
    static func assertExists(
        named name: String,
        in scenarios: [Scenario],
        file: String = #file,
        line: Int = #line
    ) throws -> Scenario {
        guard let scenario = scenarios.first(where: { $0.name == name }) else {
            let names = scenarios.map { $0.name }.joined(separator: ", ")
            throw AssertionError(
                message: "Scenario '\(name)' not found. Available: [\(names)]",
                file: file,
                line: line
            )
        }
        return scenario
    }
    
    /// Assert the number of steps in a scenario
    static func assertStepCount(
        _ scenario: Scenario,
        equals expected: Int,
        file: String = #file,
        line: Int = #line
    ) throws {
        if scenario.steps.count != expected {
            throw AssertionError(
                message: "Expected \(expected) step(s) in '\(scenario.name)', got \(scenario.steps.count)",
                file: file,
                line: line
            )
        }
    }
    
    /// Assert a step at index has a specific type
    static func assertStepType(
        _ scenario: Scenario,
        at index: Int,
        is expectedType: String,
        file: String = #file,
        line: Int = #line
    ) throws -> Step {
        guard index < scenario.steps.count else {
            throw AssertionError(
                message: "Step index \(index) out of bounds (scenario has \(scenario.steps.count) steps)",
                file: file,
                line: line
            )
        }
        
        let step = scenario.steps[index]
        if step.type != expectedType {
            throw AssertionError(
                message: "Expected step[\(index)] to be '\(expectedType)', got '\(step.type)'",
                file: file,
                line: line
            )
        }
        
        return step
    }
    
    /// Assert a click step has expected position (with tolerance)
    static func assertClickPosition(
        _ step: Step,
        x expectedX: Double,
        y expectedY: Double,
        tolerance: Double = 10,
        file: String = #file,
        line: Int = #line
    ) throws {
        guard case .click(let click) = step else {
            throw AssertionError(
                message: "Expected click step, got \(step.type)",
                file: file,
                line: line
            )
        }
        
        let dx = abs(click.position.x - expectedX)
        let dy = abs(click.position.y - expectedY)
        
        if dx > tolerance || dy > tolerance {
            throw AssertionError(
                message: "Click position (\(click.position.x), \(click.position.y)) differs from expected (\(expectedX), \(expectedY)) by more than \(tolerance)",
                file: file,
                line: line
            )
        }
    }
    
    /// Assert scenario was used (lastUsedAt > createdAt or > some threshold)
    static func assertWasExecuted(
        _ scenario: Scenario,
        file: String = #file,
        line: Int = #line
    ) throws {
        if scenario.lastUsedAt <= 0 {
            throw AssertionError(
                message: "Scenario '\(scenario.name)' was not executed (lastUsedAt = \(scenario.lastUsedAt))",
                file: file,
                line: line
            )
        }
    }
}
