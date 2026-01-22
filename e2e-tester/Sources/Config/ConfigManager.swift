import Foundation

/// Manages reading and writing config files (scenarios.json, settings.json)
class ConfigManager {
    let configDir: String
    
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    var scenariosPath: String {
        "\(configDir)/scenarios.json"
    }
    
    var settingsPath: String {
        "\(configDir)/settings.json"
    }
    
    init(configDir: String) {
        self.configDir = configDir
        
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Directory Management
    
    /// Ensure the config directory exists
    func ensureDir() throws {
        try fileManager.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    /// Clean up the config directory
    func cleanup() throws {
        if fileManager.fileExists(atPath: configDir) {
            try fileManager.removeItem(atPath: configDir)
        }
    }
    
    // MARK: - Scenarios
    
    /// Read scenarios from disk
    /// Returns empty array if file doesn't exist
    func readScenarios() throws -> [Scenario] {
        guard fileManager.fileExists(atPath: scenariosPath) else {
            return []
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: scenariosPath))
        return try decoder.decode([Scenario].self, from: data)
    }
    
    /// Write scenarios to disk
    func writeScenarios(_ scenarios: [Scenario]) throws {
        try ensureDir()
        let data = try encoder.encode(scenarios)
        try data.write(to: URL(fileURLWithPath: scenariosPath))
    }
    
    /// Wait for scenarios file to exist (controller may still be writing)
    func waitForScenariosFile(timeoutMs: Int = 5000) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        
        while Date() < deadline {
            if fileManager.fileExists(atPath: scenariosPath) {
                // Extra delay to ensure file is fully written
                try await Task.sleep(nanoseconds: 200_000_000)
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        throw TestError("Timeout waiting for scenarios.json to appear")
    }
    
    // MARK: - Settings
    
    /// Read settings from disk
    /// Returns defaults if file doesn't exist
    func readSettings() throws -> Settings {
        guard fileManager.fileExists(atPath: settingsPath) else {
            return Settings()
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
        return try decoder.decode(Settings.self, from: data)
    }
    
    /// Write settings to disk
    func writeSettings(_ settings: Settings) throws {
        try ensureDir()
        let data = try encoder.encode(settings)
        try data.write(to: URL(fileURLWithPath: settingsPath))
    }
    
    // MARK: - Utilities
    
    /// Check if scenarios file exists
    func scenariosFileExists() -> Bool {
        fileManager.fileExists(atPath: scenariosPath)
    }
    
    /// Get file modification date
    func scenariosModificationDate() -> Date? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: scenariosPath),
              let date = attrs[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
}
