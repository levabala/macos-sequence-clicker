import Foundation
import AppKit

/// Represents an active terminal session running the controller
struct TerminalSession {
    let windowId: Int
    let configDir: String
    let startTime: Date
}

/// Manages Terminal.app for launching and controlling the controller app
@MainActor
class TerminalManager {
    private let projectRoot: String
    private var currentSession: TerminalSession?
    
    init(projectRoot: String) {
        self.projectRoot = projectRoot
    }
    
    /// Launch Terminal.app with the controller running
    /// - Parameter configDir: Custom config directory for isolation
    /// - Returns: A session representing the launched terminal
    func launchController(configDir: String) async throws -> TerminalSession {
        // Build the command to run in terminal
        let controllerPath = "\(projectRoot)/controller"
        let command = "cd \"\(controllerPath)\" && SEQUENCER_CONFIG_DIR=\"\(configDir)\" bun run start"
        
        // AppleScript to open Terminal and run command
        let script = """
        tell application "Terminal"
            activate
            set newWindow to do script "\(command)"
            delay 0.5
            set windowId to id of front window
            return windowId
        end tell
        """
        
        guard let windowId = try runAppleScript(script) else {
            throw TestError("Failed to get Terminal window ID")
        }
        
        let session = TerminalSession(
            windowId: windowId,
            configDir: configDir,
            startTime: Date()
        )
        currentSession = session
        
        return session
    }
    
    /// Focus the terminal window
    func focusTerminal(_ session: TerminalSession) async throws {
        let script = """
        tell application "Terminal"
            activate
            set index of window id \(session.windowId) to 1
        end tell
        """
        
        _ = try runAppleScript(script)
        
        // Small delay to ensure focus is complete
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    
    /// Get the frame of the terminal window
    func getWindowFrame(_ session: TerminalSession) async throws -> CGRect {
        let script = """
        tell application "Terminal"
            set theWindow to window id \(session.windowId)
            set {x, y} to position of theWindow
            set {w, h} to size of theWindow
            return {x, y, w, h}
        end tell
        """
        
        guard let result = try runAppleScriptForList(script),
              result.count == 4 else {
            throw TestError("Failed to get window frame")
        }
        
        return CGRect(
            x: CGFloat(result[0]),
            y: CGFloat(result[1]),
            width: CGFloat(result[2]),
            height: CGFloat(result[3])
        )
    }
    
    /// Close the terminal session gracefully
    func closeSession(_ session: TerminalSession) async throws {
        let script = """
        tell application "Terminal"
            close window id \(session.windowId)
        end tell
        """
        
        _ = try? runAppleScript(script)
        currentSession = nil
    }
    
    /// Force kill the terminal window (for cleanup on failure)
    func forceKill(_ session: TerminalSession) async {
        let script = """
        tell application "Terminal"
            try
                close window id \(session.windowId) saving no
            end try
        end tell
        """
        
        _ = try? runAppleScript(script)
        currentSession = nil
    }
    
    /// Send text input to the terminal (types characters)
    func sendText(_ text: String, to session: TerminalSession) async throws {
        // Escape special characters for AppleScript
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "System Events"
            tell process "Terminal"
                keystroke "\(escaped)"
            end tell
        end tell
        """
        
        _ = try runAppleScript(script)
    }
    
    /// Send a key code to the terminal
    func sendKeyCode(_ keyCode: Int, modifiers: [String] = [], to session: TerminalSession) async throws {
        var modifierString = ""
        if !modifiers.isEmpty {
            modifierString = " using {\(modifiers.joined(separator: ", "))}"
        }
        
        let script = """
        tell application "System Events"
            tell process "Terminal"
                key code \(keyCode)\(modifierString)
            end tell
        end tell
        """
        
        _ = try runAppleScript(script)
    }
    
    // MARK: - Private Helpers
    
    private func runAppleScript(_ script: String) throws -> Int? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw TestError("Failed to create AppleScript")
        }
        
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw TestError("AppleScript error: \(errorMessage)")
        }
        
        return result.int32Value != 0 ? Int(result.int32Value) : nil
    }
    
    private func runAppleScriptForList(_ script: String) throws -> [Int]? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw TestError("Failed to create AppleScript")
        }
        
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw TestError("AppleScript error: \(errorMessage)")
        }
        
        // Parse list result
        let count = result.numberOfItems
        guard count > 0 else { return nil }
        
        var values: [Int] = []
        for i in 1...count {
            let item = result.atIndex(i)
            values.append(Int(item?.int32Value ?? 0))
        }
        
        return values
    }
}
