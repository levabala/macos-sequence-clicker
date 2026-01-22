import Foundation

/// Actor for thread-safe stdout writes
actor StdoutWriter {
    private let fileHandle: FileHandle
    private let encoder: JSONEncoder
    
    init() {
        self.fileHandle = FileHandle.standardOutput
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [] // Compact JSON, no pretty printing
    }
    
    /// Writes an encodable value as JSON followed by newline
    func write<T: Encodable>(_ value: T) throws {
        let data = try encoder.encode(value)
        var outputData = data
        outputData.append(contentsOf: [0x0A]) // Add newline
        try fileHandle.write(contentsOf: outputData)
    }
    
    /// Writes a success response with result
    func writeSuccess<T: Codable>(id: String, result: T) throws {
        let response = IPCResponseSuccess(id: id, result: result)
        try write(response)
    }
    
    /// Writes a success response without result (void)
    func writeVoid(id: String) throws {
        let response = IPCResponseVoid(id: id)
        try write(response)
    }
    
    /// Writes an error response
    func writeError(id: String, error: String) throws {
        let response = IPCResponseError(id: id, error: error)
        try write(response)
    }
    
    /// Writes an event (unsolicited message to controller)
    func writeEvent(_ event: some Encodable) throws {
        try write(event)
    }
}
