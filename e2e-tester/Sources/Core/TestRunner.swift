import Foundation

/// Orchestrates test execution
@MainActor
class TestRunner {
    private let tests: [TestCase]
    private let verbose: Bool
    private let projectRoot: String
    
    init(tests: [TestCase], verbose: Bool = false, projectRoot: String) {
        self.tests = tests
        self.verbose = verbose
        self.projectRoot = projectRoot
    }
    
    /// List all available test names
    func listTests() -> [(name: String, description: String)] {
        tests.map { ($0.name, $0.description) }
    }
    
    /// Run all tests serially
    func runAll() async -> TestSummary {
        let startTime = Date()
        var results: [TestResult] = []
        
        printHeader()
        print("\nRunning \(tests.count) test(s)...\n")
        
        for test in tests {
            let result = await runSingleTest(test)
            results.append(result)
        }
        
        let summary = TestSummary(
            results: results,
            totalDuration: Date().timeIntervalSince(startTime)
        )
        
        printSummary(summary)
        return summary
    }
    
    /// Run a specific test by name
    func runTest(named name: String) async -> TestResult? {
        guard let test = tests.first(where: { $0.name == name }) else {
            print("Error: Test '\(name)' not found")
            print("Available tests:")
            for t in tests {
                print("  - \(t.name)")
            }
            return nil
        }
        
        printHeader()
        print("\nRunning test: \(name)\n")
        
        let result = await runSingleTest(test)
        
        printSingleResult(result)
        return result
    }
    
    // MARK: - Private
    
    private func runSingleTest(_ test: TestCase) async -> TestResult {
        printTestStart(test)
        
        let startTime = Date()
        var logs: [String] = []
        var errorMessage: String? = nil
        var passed = false
        
        // Create isolated config directory for this test
        let configDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-test-\(UUID().uuidString)")
            .path
        
        do {
            // Setup
            try FileManager.default.createDirectory(
                atPath: configDir,
                withIntermediateDirectories: true
            )
            
            // Create context with all utilities
            let terminal = TerminalManager(projectRoot: projectRoot)
            let input = InputSimulator()
            let overlay = OverlayLocator()
            let config = ConfigManager(configDir: configDir)
            
            let context = TestContext(
                terminal: terminal,
                input: input,
                overlay: overlay,
                config: config,
                configDir: configDir,
                verbose: verbose
            )
            
            // Run the test
            try await test.run(context: context)
            
            logs = context.logs
            passed = true
            
        } catch let err as TestError {
            errorMessage = err.message
            
        } catch let err as AssertionError {
            errorMessage = err.description
            
        } catch {
            errorMessage = String(describing: error)
        }
        
        // Cleanup config directory
        try? FileManager.default.removeItem(atPath: configDir)
        
        let duration = Date().timeIntervalSince(startTime)
        let result = TestResult(
            testName: test.name,
            passed: passed,
            duration: duration,
            error: errorMessage,
            logs: logs
        )
        
        printTestEnd(result)
        return result
    }
    
    // MARK: - Output Formatting
    
    private func printHeader() {
        print("")
        print("╔════════════════════════════════════════════════════════════╗")
        print("║           E2E Tests for macOS Smart Sequencer              ║")
        print("╚════════════════════════════════════════════════════════════╝")
    }
    
    private func printTestStart(_ test: TestCase) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("TEST: \(test.name)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func printTestEnd(_ result: TestResult) {
        if let error = result.error {
            print("\n  ❌ FAILED: \(error)")
        }
        print("\n  \(result.statusEmoji) \(result.statusText) (\(String(format: "%.2f", result.duration))s)\n")
    }
    
    private func printSingleResult(_ result: TestResult) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("RESULT: \(result.statusEmoji) \(result.statusText)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func printSummary(_ summary: TestSummary) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("RESULTS: \(summary.passedCount) passed, \(summary.failedCount) failed")
        print("Total time: \(String(format: "%.2f", summary.totalDuration))s")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if !summary.allPassed {
            print("\nFailed tests:")
            for result in summary.results where !result.passed {
                print("  ❌ \(result.testName)")
                if let error = result.error {
                    print("     \(error)")
                }
            }
        }
        print("")
    }
}
