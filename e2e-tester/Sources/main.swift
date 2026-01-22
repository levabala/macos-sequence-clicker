import Foundation
import ArgumentParser
import AppKit

struct E2ETester: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "e2e-tester",
        abstract: "E2E tests for macOS Smart Sequencer",
        version: "1.0.0"
    )
    
    @Option(name: .shortAndLong, help: "Run specific test by name")
    var test: String?
    
    @Flag(name: .shortAndLong, help: "List available tests")
    var list: Bool = false
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Project root directory (default: auto-detect)")
    var projectRoot: String?
    
    mutating func run() async throws {
        // Ensure we're running on macOS
        #if !os(macOS)
        print("Error: E2E tests only run on macOS")
        throw ExitCode.failure
        #endif
        
        // Check for Accessibility permissions
        if !checkAccessibilityPermissions() {
            print("")
            print("⚠️  Accessibility permission required!")
            print("")
            print("To grant permission:")
            print("1. Open System Settings > Privacy & Security > Accessibility")
            print("2. Add this terminal app (or E2ETester) to the list")
            print("")
            throw ExitCode.failure
        }
        
        // Detect project root
        let root = try detectProjectRoot()
        
        // Create all test cases
        let tests: [TestCase] = [
            RecordAndExecuteTest(),
        ]
        
        // Handle --list flag
        if list {
            printTestList(tests)
            return
        }
        
        // Create runner
        let runner = await TestRunner(tests: tests, verbose: verbose, projectRoot: root)
        
        // Run tests
        if let testName = test {
            // Run specific test
            guard let result = await runner.runTest(named: testName) else {
                throw ExitCode.failure
            }
            if !result.passed {
                throw ExitCode.failure
            }
        } else {
            // Run all tests
            let summary = await runner.runAll()
            if !summary.allPassed {
                throw ExitCode.failure
            }
        }
    }
    
    // MARK: - Helpers
    
    private func checkAccessibilityPermissions() -> Bool {
        // Check if we have accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func detectProjectRoot() throws -> String {
        if let root = projectRoot {
            return root
        }
        
        // Try to find project root from executable location
        // The executable is at: project/e2e-tester/.build/release/E2ETester
        // So project root is 3 levels up
        let executablePath = CommandLine.arguments[0]
        let executableURL = URL(fileURLWithPath: executablePath).standardizedFileURL
        
        // If running from .build, go up 3 levels
        if executablePath.contains(".build") {
            var url = executableURL
            for _ in 0..<3 {
                url = url.deletingLastPathComponent()
            }
            // Should be at e2e-tester, go up one more
            url = url.deletingLastPathComponent()
            let path = url.path
            
            // Verify it looks like the project root
            let controllerPath = "\(path)/controller"
            if FileManager.default.fileExists(atPath: controllerPath) {
                return path
            }
        }
        
        // Try current directory
        let cwd = FileManager.default.currentDirectoryPath
        if FileManager.default.fileExists(atPath: "\(cwd)/controller") {
            return cwd
        }
        
        // Try parent of cwd (in case we're in e2e-tester/)
        let parent = URL(fileURLWithPath: cwd).deletingLastPathComponent().path
        if FileManager.default.fileExists(atPath: "\(parent)/controller") {
            return parent
        }
        
        print("Error: Could not detect project root directory")
        print("Please run from the project root or use --project-root flag")
        throw ExitCode.failure
    }
    
    private func printTestList(_ tests: [TestCase]) {
        print("")
        print("Available tests:")
        print("")
        for test in tests {
            print("  \(test.name)")
            print("    \(test.description)")
            print("")
        }
    }
}

// Entry point
E2ETester.main()
