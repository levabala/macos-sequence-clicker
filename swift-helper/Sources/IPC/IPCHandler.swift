import Foundation
import AppKit

/// Main IPC message handler
actor IPCHandler {
    private let reader: StdinReader
    private let writer: StdoutWriter
    private let decoder: JSONDecoder
    
    // Action controllers
    private let mouseController: MouseController
    private let keyboardController: KeyboardController
    private let screenCapture: ScreenCapture
    
    init() {
        self.reader = StdinReader()
        self.writer = StdoutWriter()
        self.decoder = JSONDecoder()
        self.mouseController = MouseController()
        self.keyboardController = KeyboardController()
        self.screenCapture = ScreenCapture()
    }
    
    /// Main message processing loop
    func run() async {
        // Setup overlay event callback (must be done on main thread)
        await MainActor.run {
            OverlayWindowController.shared.onEvent = { [weak self] event in
                await self?.sendEvent(event)
            }
        }
        
        while true {
            do {
                guard let line = try await reader.readLine() else {
                    // EOF - clean exit
                    break
                }
                
                await processMessage(line)
            } catch {
                // Log error but continue processing
                await logError("Error reading stdin: \(error)")
            }
        }
    }
    
    /// Send an event to stdout (for unsolicited events from UI)
    private func sendEvent(_ event: Encodable) async {
        do {
            try await writer.writeEvent(event)
        } catch {
            await logError("Failed to write event: \(error)")
        }
    }
    
    /// Process a single JSON message
    private func processMessage(_ json: String) async {
        guard let data = json.data(using: .utf8) else {
            await logError("Invalid UTF-8 in message")
            return
        }
        
        // First, parse the envelope to get id and method
        do {
            let envelope = try decoder.decode(IPCRequestEnvelope.self, from: data)
            await handleRequest(method: envelope.method, id: envelope.id, data: data)
        } catch {
            // Try to extract just the id for error response
            if let partial = try? decoder.decode(PartialRequest.self, from: data) {
                do {
                    try await writer.writeError(id: partial.id, error: "Invalid request: \(error)")
                } catch {
                    await logError("Failed to write error response: \(error)")
                }
            } else {
                await logError("Failed to parse request: \(error)")
            }
        }
    }
    
    /// Route request to appropriate handler
    private func handleRequest(method: IPCRequestMethod, id: String, data: Data) async {
        do {
            switch method {
            case .checkPermissions:
                let status = PermissionChecker.check()
                try await writer.writeSuccess(id: id, result: status)
                
            case .showRecorderOverlay:
                let request = try decoder.decode(ShowRecorderOverlayRequest.self, from: data)
                await MainActor.run {
                    OverlayWindowController.shared.showRecorderOverlay(at: request.params.position)
                }
                try await writer.writeVoid(id: id)
                
            case .hideRecorderOverlay:
                await MainActor.run {
                    OverlayWindowController.shared.hideRecorderOverlay()
                }
                try await writer.writeVoid(id: id)
                
            case .setRecorderState:
                let request = try decoder.decode(SetRecorderStateRequest.self, from: data)
                await MainActor.run {
                    OverlayWindowController.shared.setRecorderState(
                        request.params.state,
                        subState: request.params.subState
                    )
                }
                try await writer.writeVoid(id: id)
                
            case .showMagnifier:
                await MainActor.run {
                    OverlayWindowController.shared.showMagnifier()
                }
                try await writer.writeVoid(id: id)
                
            case .hideMagnifier:
                await MainActor.run {
                    OverlayWindowController.shared.hideMagnifier()
                }
                try await writer.writeVoid(id: id)
                
            case .executeClick:
                let request = try decoder.decode(ExecuteClickRequest.self, from: data)
                try await mouseController.click(at: request.params.position, button: request.params.button)
                try await writer.writeVoid(id: id)
                
            case .executeKeypress:
                let request = try decoder.decode(ExecuteKeypressRequest.self, from: data)
                try await keyboardController.press(key: request.params.key, modifiers: request.params.modifiers)
                try await writer.writeVoid(id: id)
                
            case .getPixelColor:
                let request = try decoder.decode(GetPixelColorRequest.self, from: data)
                let color = try await screenCapture.getPixelColor(at: request.params.position)
                let result = PixelColorResult(color: color)
                try await writer.writeSuccess(id: id, result: result)
                
            case .waitForPixelState:
                let request = try decoder.decode(WaitForPixelStateRequest.self, from: data)
                let matched = try await screenCapture.waitForPixelState(
                    at: request.params.position,
                    expectedColor: request.params.color,
                    threshold: request.params.threshold,
                    timeoutMs: request.params.timeoutMs
                )
                let result = WaitResult(matched: matched)
                try await writer.writeSuccess(id: id, result: result)
                
            case .waitForPixelZone:
                let request = try decoder.decode(WaitForPixelZoneRequest.self, from: data)
                let matched = try await screenCapture.waitForPixelZone(
                    rect: request.params.rect,
                    expectedColor: request.params.color,
                    threshold: request.params.threshold,
                    timeoutMs: request.params.timeoutMs
                )
                let result = WaitResult(matched: matched)
                try await writer.writeSuccess(id: id, result: result)
            }
        } catch {
            do {
                try await writer.writeError(id: id, error: "Handler error: \(error)")
            } catch {
                await logError("Failed to write error response: \(error)")
            }
        }
    }
    
    /// Log error to stderr (not stdout, to keep IPC clean)
    private func logError(_ message: String) async {
        FileHandle.standardError.write("[SequencerHelper] \(message)\n".data(using: .utf8)!)
    }
}

/// Helper struct for extracting just the id from a malformed request
private struct PartialRequest: Codable {
    let id: String
}

/// Result for wait operations
struct WaitResult: Codable {
    let matched: Bool
}
