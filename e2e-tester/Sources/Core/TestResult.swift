import Foundation

/// Result of running a single test
struct TestResult {
    let testName: String
    let passed: Bool
    let duration: TimeInterval
    let error: String?
    let logs: [String]
    
    var statusEmoji: String {
        passed ? "✅" : "❌"
    }
    
    var statusText: String {
        passed ? "PASSED" : "FAILED"
    }
}

/// Summary of all test results
struct TestSummary {
    let results: [TestResult]
    let totalDuration: TimeInterval
    
    var passedCount: Int {
        results.filter { $0.passed }.count
    }
    
    var failedCount: Int {
        results.filter { !$0.passed }.count
    }
    
    var allPassed: Bool {
        failedCount == 0
    }
}
