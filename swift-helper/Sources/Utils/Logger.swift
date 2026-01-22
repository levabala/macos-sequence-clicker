import Foundation

/// Simple file-based logger that writes to /tmp/sequencer-helper.log
/// Always enabled for debugging purposes
/// Log file is cleared on each app start
enum Logger {
    private static let logFile = "/tmp/sequencer-helper.log"
    private static let lock = NSLock()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Clear the log file (call once at startup)
    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove existing file and create empty one
        try? FileManager.default.removeItem(atPath: logFile)
        FileManager.default.createFile(atPath: logFile, contents: nil)
    }
    
    /// Log a message with timestamp and source info
    static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let entry = "[\(timestamp)] [\(fileName):\(line)] \(function) - \(message)\n"
        
        lock.lock()
        defer { lock.unlock() }
        
        // Append to log file
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = FileHandle(forWritingAtPath: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
        
        // Also write to stderr for immediate visibility
        FileHandle.standardError.write(entry.data(using: .utf8)!)
    }
    
    /// Log with a category prefix
    static func log(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log("[\(category)] \(message)", file: file, function: function, line: line)
    }
}
