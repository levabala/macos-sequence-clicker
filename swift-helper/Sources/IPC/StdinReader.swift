import Foundation

/// Actor for reading lines from stdin asynchronously
actor StdinReader {
    private let fileHandle: FileHandle
    private var buffer: Data = Data()
    private let newline = Data([0x0A]) // \n
    
    init() {
        self.fileHandle = FileHandle.standardInput
    }
    
    /// Reads the next complete line from stdin
    /// Returns nil on EOF
    func readLine() async throws -> String? {
        while true {
            // Check if we have a complete line in the buffer
            if let newlineRange = buffer.range(of: newline) {
                let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                buffer.removeSubrange(0...newlineRange.lowerBound)
                
                guard let line = String(data: lineData, encoding: .utf8) else {
                    continue // Skip invalid UTF-8 lines
                }
                
                return line.isEmpty ? nil : line
            }
            
            // Read more data from stdin using async/await pattern
            let chunk = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = self.fileHandle.availableData
                    continuation.resume(returning: data)
                }
            }
            
            // EOF - return any remaining data as last line
            if chunk.isEmpty {
                if buffer.isEmpty {
                    return nil
                }
                let remaining = buffer
                buffer = Data()
                return String(data: remaining, encoding: .utf8)
            }
            
            buffer.append(chunk)
        }
    }
}
