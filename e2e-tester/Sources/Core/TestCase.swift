import Foundation

/// Protocol for defining a test case
protocol TestCase {
    /// Unique name for the test (used for CLI filtering)
    var name: String { get }
    
    /// Human-readable description
    var description: String { get }
    
    /// Run the test
    func run(context: TestContext) async throws
}

/// Error thrown by tests
struct TestError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        message
    }
}

/// Assertion failure
struct AssertionError: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: Int
    
    var description: String {
        "\(file):\(line) - Assertion failed: \(message)"
    }
}
