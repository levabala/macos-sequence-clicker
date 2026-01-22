import Foundation

/// Context provided to each test with all necessary utilities
class TestContext {
    let terminal: TerminalManager
    let input: InputSimulator
    let overlay: OverlayLocator
    let config: ConfigManager
    let configDir: String
    let verbose: Bool
    
    private var _logs: [String] = []
    private let logsLock = NSLock()
    
    var logs: [String] {
        logsLock.lock()
        defer { logsLock.unlock() }
        return _logs
    }
    
    init(
        terminal: TerminalManager,
        input: InputSimulator,
        overlay: OverlayLocator,
        config: ConfigManager,
        configDir: String,
        verbose: Bool = false
    ) {
        self.terminal = terminal
        self.input = input
        self.overlay = overlay
        self.config = config
        self.configDir = configDir
        self.verbose = verbose
    }
    
    /// Log a message (stored and optionally printed)
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)"
        logsLock.lock()
        _logs.append(logLine)
        logsLock.unlock()
        if verbose {
            print("  [LOG] \(message)")
        }
    }
    
    /// Assert a condition is true
    func assert(
        _ condition: Bool,
        _ message: String,
        file: String = #file,
        line: Int = #line
    ) throws {
        if !condition {
            log("ASSERTION FAILED: \(message)")
            throw AssertionError(message: message, file: file, line: line)
        }
    }
    
    /// Assert two values are equal
    func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String? = nil,
        file: String = #file,
        line: Int = #line
    ) throws {
        if actual != expected {
            let msg = message ?? "Expected \(expected), got \(actual)"
            log("ASSERTION FAILED: \(msg)")
            throw AssertionError(message: msg, file: file, line: line)
        }
    }
    
    /// Wait for a condition with timeout
    func waitUntil(
        timeoutMs: Int,
        pollIntervalMs: Int = 100,
        _ condition: () async throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        
        while Date() < deadline {
            if try await condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(pollIntervalMs) * 1_000_000)
        }
        
        throw TestError("Timeout after \(timeoutMs)ms waiting for condition")
    }
    
    /// Wait for a file to exist
    func waitForFile(_ path: String, timeoutMs: Int = 5000) async throws {
        try await waitUntil(timeoutMs: timeoutMs) {
            FileManager.default.fileExists(atPath: path)
        }
    }
    
    /// Simple delay
    func wait(ms: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }
}
