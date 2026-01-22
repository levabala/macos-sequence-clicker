import Foundation

/// E2E test that creates a scenario, records a click action, and executes it
struct RecordAndExecuteTest: TestCase {
    let name = "recordAndExecuteScenario"
    let description = "E2E: Create scenario, record a click, execute it, verify"
    
    func run(context: TestContext) async throws {
        var session: TerminalSession? = nil
        
        do {
            context.log("=== Starting recordAndExecuteScenario test ===")
            
            // Step 1: Launch controller with fresh config
            context.log("Step 1: Launching controller...")
            session = try await context.terminal.launchController(
                configDir: context.configDir
            )
            await context.wait(ms: 3000) // Wait for UI to render
            
            // Step 2: Focus terminal
            context.log("Step 2: Focusing terminal...")
            try await context.terminal.focusTerminal(session!)
            await context.wait(ms: 500)
            
            // Step 3: Create a new scenario (press 'c')
            context.log("Step 3: Creating new scenario (pressing 'c')...")
            await context.input.pressKey("c")
            await context.wait(ms: 500)
            
            // Step 4: Type scenario name and confirm
            context.log("Step 4: Typing scenario name...")
            await context.input.typeText("E2E Test Scenario")
            await context.wait(ms: 200)
            await context.input.pressKey("return")
            await context.wait(ms: 1000)
            
            // Step 5: Start recording (press 'r')
            context.log("Step 5: Starting recording (pressing 'r')...")
            await context.input.pressKey("r")
            await context.wait(ms: 1500) // Wait for overlay to appear
            
            // Step 6: Find overlay
            context.log("Step 6: Looking for recorder overlay...")
            let overlayFrame = try await context.overlay.waitForOverlay(timeoutMs: 5000)
            context.log("  Overlay found at: \(overlayFrame)")
            
            // Step 7: Click "Action" mode button (to switch to action mode)
            context.log("Step 7: Clicking Action button...")
            guard let actionPos = context.overlay.buttonPosition(.action) else {
                throw TestError("Failed to get Action button position")
            }
            context.log("  Action button at: \(actionPos)")
            await context.input.click(at: actionPos)
            await context.wait(ms: 500)
            
            // Step 8: Click "Mouse" button to start mouse capture
            context.log("Step 8: Clicking Mouse button...")
            guard let mousePos = context.overlay.buttonPosition(.mouse) else {
                throw TestError("Failed to get Mouse button position")
            }
            context.log("  Mouse button at: \(mousePos)")
            await context.input.click(at: mousePos)
            await context.wait(ms: 500)
            
            // Step 9: Click somewhere on screen (this will be recorded)
            // Use a position that's not on the overlay
            let testClickPos = CGPoint(x: 100, y: 400)
            context.log("Step 9: Recording click at \(testClickPos)...")
            await context.input.click(at: testClickPos)
            await context.wait(ms: 1000)
            
            // Step 10: Stop recording
            context.log("Step 10: Stopping recording (pressing Escape)...")
            // Refocus terminal first (it may have lost focus)
            try await context.terminal.focusTerminal(session!)
            await context.wait(ms: 300)
            await context.input.pressKey("escape")
            await context.wait(ms: 1500)
            
            // Step 11: Verify scenario was created with click step
            context.log("Step 11: Verifying recorded scenario...")
            
            // Wait for config file to be written
            try await context.config.waitForScenariosFile(timeoutMs: 5000)
            
            let scenarios = try context.config.readScenarios()
            context.log("  Found \(scenarios.count) scenario(s)")
            
            try ScenarioAssertions.assertCount(scenarios, equals: 1)
            
            let scenario = try ScenarioAssertions.assertExists(
                named: "E2E Test Scenario",
                in: scenarios
            )
            context.log("  Scenario name: '\(scenario.name)'")
            context.log("  Steps count: \(scenario.steps.count)")
            
            try ScenarioAssertions.assertStepCount(scenario, equals: 1)
            
            let step = try ScenarioAssertions.assertStepType(scenario, at: 0, is: "click")
            context.log("  Step[0] type: \(step.type)")
            
            if case .click(let click) = step {
                context.log("  Click position: (\(click.position.x), \(click.position.y))")
                context.log("  Click button: \(click.button)")
            }
            
            // Step 12: Execute the scenario
            context.log("Step 12: Executing recorded scenario (pressing 'p')...")
            try await context.terminal.focusTerminal(session!)
            await context.wait(ms: 300)
            await context.input.pressKey("p") // Play
            await context.wait(ms: 3000) // Wait for execution + modal
            
            // Press Escape to close any modal
            await context.input.pressKey("escape")
            await context.wait(ms: 500)
            
            // Step 13: Verify execution (lastUsedAt should be updated)
            context.log("Step 13: Verifying scenario was executed...")
            let scenariosAfter = try context.config.readScenarios()
            let scenarioAfter = scenariosAfter[0]
            
            context.log("  lastUsedAt before: \(scenario.lastUsedAt)")
            context.log("  lastUsedAt after: \(scenarioAfter.lastUsedAt)")
            
            try ScenarioAssertions.assertWasExecuted(scenarioAfter)
            
            // Step 14: Cleanup - quit the app
            context.log("Step 14: Cleaning up (pressing 'q')...")
            try await context.terminal.focusTerminal(session!)
            await context.wait(ms: 300)
            await context.input.pressKey("q")
            await context.wait(ms: 1000)
            
            try await context.terminal.closeSession(session!)
            session = nil
            
            context.log("=== Test completed successfully! ===")
            
        } catch {
            // Cleanup on failure
            if let session = session {
                context.log("Cleaning up after failure...")
                await context.terminal.forceKill(session)
            }
            throw error
        }
    }
}
