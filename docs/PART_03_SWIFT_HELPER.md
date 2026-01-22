# Part 3: Swift Helper

## Overview

The Swift helper is a command-line macOS application that:
1. Communicates with the Bun controller via stdin/stdout JSON
2. Provides native macOS capabilities (clicks, keypresses, screen capture)
3. Displays SwiftUI overlay windows (recorder toolbar, magnifier)

## Project Structure

```
swift-helper/
├── Package.swift
└── Sources/
    └── SequencerHelper/
        ├── main.swift              # Entry point, IPC loop
        ├── Generated/
        │   └── Types.swift         # Generated from schema
        ├── IPC/
        │   ├── IPCHandler.swift    # Message routing
        │   ├── StdinReader.swift   # Async line reading
        │   └── StdoutWriter.swift  # Thread-safe output
        ├── Actions/
        │   ├── MouseController.swift
        │   ├── KeyboardController.swift
        │   └── ScreenCapture.swift
        ├── UI/
        │   ├── OverlayWindow.swift
        │   ├── RecorderOverlay.swift
        │   ├── MagnifierView.swift
        │   └── ZoneSelector.swift
        └── Permissions/
            └── PermissionChecker.swift
```

## Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SequencerHelper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SequencerHelper",
            path: "Sources/SequencerHelper"
        )
    ]
)
```

## Entry Point

```swift
// main.swift
import AppKit
import SwiftUI

@main
struct SequencerHelper {
    static func main() async {
        // Initialize the app for UI capabilities
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)  // No dock icon
        
        // Start IPC handler
        let handler = IPCHandler()
        
        // Run on background thread, keep main thread for UI
        Task.detached {
            await handler.run()
        }
        
        // Run the app (needed for SwiftUI windows)
        app.run()
    }
}
```

## IPC Layer

### StdinReader

```swift
// IPC/StdinReader.swift
import Foundation

actor StdinReader {
    private let fileHandle = FileHandle.standardInput
    private var buffer = Data()
    
    func readLine() async -> String? {
        while true {
            // Check buffer for newline
            if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer = Data(buffer.suffix(from: buffer.index(after: newlineIndex)))
                return String(data: lineData, encoding: .utf8)
            }
            
            // Read more data
            guard let data = try? fileHandle.availableData, !data.isEmpty else {
                return nil  // EOF
            }
            buffer.append(data)
        }
    }
}
```

### StdoutWriter

```swift
// IPC/StdoutWriter.swift
import Foundation

actor StdoutWriter {
    private let fileHandle = FileHandle.standardOutput
    private let encoder = JSONEncoder()
    
    func write<T: Encodable>(_ message: T) {
        do {
            let data = try encoder.encode(message)
            fileHandle.write(data)
            fileHandle.write(Data("\n".utf8))
        } catch {
            // Log error but don't crash
            FileHandle.standardError.write(Data("Encode error: \(error)\n".utf8))
        }
    }
    
    func writeResponse(id: String, success: Bool, result: Any? = nil, error: String? = nil) {
        let response: [String: Any] = [
            "id": id,
            "success": success,
            "result": result as Any,
            "error": error as Any
        ].compactMapValues { $0 }
        
        if let data = try? JSONSerialization.data(withJSONObject: response) {
            fileHandle.write(data)
            fileHandle.write(Data("\n".utf8))
        }
    }
    
    func writeEvent(_ event: IPCEvent) {
        write(event)
    }
}
```

### IPCHandler

```swift
// IPC/IPCHandler.swift
import Foundation

actor IPCHandler {
    private let reader = StdinReader()
    private let writer = StdoutWriter()
    private let mouseController = MouseController()
    private let keyboardController = KeyboardController()
    private let screenCapture = ScreenCapture()
    private var overlayController: OverlayController?
    
    func run() async {
        while let line = await reader.readLine() {
            await handleMessage(line)
        }
        // Stdin closed, exit
        exit(0)
    }
    
    private func handleMessage(_ json: String) async {
        guard let data = json.data(using: .utf8),
              let request = try? JSONDecoder().decode(IPCRequest.self, from: data) else {
            return  // Invalid JSON, ignore
        }
        
        do {
            let result = try await dispatch(request)
            await writer.writeResponse(id: request.id, success: true, result: result)
        } catch {
            await writer.writeResponse(id: request.id, success: false, error: error.localizedDescription)
        }
    }
    
    private func dispatch(_ request: IPCRequest) async throws -> Any? {
        switch request.method {
        case "checkPermissions":
            return try await checkPermissions()
            
        case "showRecorderOverlay":
            return try await showRecorderOverlay(request.params)
            
        case "hideRecorderOverlay":
            return await hideRecorderOverlay()
            
        case "setRecorderState":
            return try await setRecorderState(request.params)
            
        case "showMagnifier":
            return await showMagnifier()
            
        case "hideMagnifier":
            return await hideMagnifier()
            
        case "executeClick":
            return try await executeClick(request.params)
            
        case "executeKeypress":
            return try await executeKeypress(request.params)
            
        case "getPixelColor":
            return try await getPixelColor(request.params)
            
        case "waitForPixelState":
            return try await waitForPixelState(request.params)
            
        case "waitForPixelZone":
            return try await waitForPixelZone(request.params)
            
        default:
            throw IPCError.unknownMethod(request.method)
        }
    }
    
    // Send unsolicited event to controller
    func sendEvent(_ event: IPCEvent) async {
        await writer.writeEvent(event)
    }
}

enum IPCError: Error {
    case unknownMethod(String)
    case invalidParams
    case permissionDenied(String)
    case timeout
}
```

## Permission Checker

```swift
// Permissions/PermissionChecker.swift
import AppKit
import ApplicationServices

struct PermissionChecker {
    
    /// Check if accessibility permission is granted
    static func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Check if screen recording permission is granted
    /// This is done by attempting a minimal screen capture
    static func checkScreenRecording() -> Bool {
        let displayID = CGMainDisplayID()
        
        // Attempt to capture a 1x1 pixel
        guard let image = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            return false
        }
        
        // If we got an image, permission is granted
        return image.width > 0
    }
    
    /// Check all required permissions
    static func checkAll() -> PermissionStatus {
        return PermissionStatus(
            accessibility: checkAccessibility(),
            screenRecording: checkScreenRecording()
        )
    }
    
    /// Prompt user to grant accessibility permission
    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

struct PermissionStatus: Codable {
    let accessibility: Bool
    let screenRecording: Bool
}
```

## Action Controllers

### MouseController

```swift
// Actions/MouseController.swift
import Foundation
import CoreGraphics

actor MouseController {
    
    func click(at point: Point, button: String) throws {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        
        let mouseButton: CGMouseButton = button == "right" ? .right : .left
        let mouseDownType: CGEventType = button == "right" ? .rightMouseDown : .leftMouseDown
        let mouseUpType: CGEventType = button == "right" ? .rightMouseUp : .leftMouseUp
        
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseDownType,
            mouseCursorPosition: cgPoint,
            mouseButton: mouseButton
        ) else {
            throw MouseError.eventCreationFailed
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseUpType,
            mouseCursorPosition: cgPoint,
            mouseButton: mouseButton
        ) else {
            throw MouseError.eventCreationFailed
        }
        
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    func moveTo(point: Point) {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        CGWarpMouseCursorPosition(cgPoint)
    }
    
    func getCurrentPosition() -> Point {
        let location = NSEvent.mouseLocation
        // Convert from bottom-left to top-left coordinate system
        let screenHeight = NSScreen.main?.frame.height ?? 0
        return Point(x: location.x, y: screenHeight - location.y)
    }
}

enum MouseError: Error {
    case eventCreationFailed
}
```

### KeyboardController

```swift
// Actions/KeyboardController.swift
import Foundation
import CoreGraphics
import Carbon.HIToolbox

actor KeyboardController {
    
    func press(key: String, modifiers: [String]) throws {
        let keyCode = try keyCodeFor(key)
        let modifierFlags = modifierFlagsFor(modifiers)
        
        // Press modifiers
        for modifier in modifiers {
            if let modKeyCode = modifierKeyCode(modifier) {
                postKeyEvent(keyCode: modKeyCode, keyDown: true, flags: modifierFlags)
            }
        }
        
        // Press and release the main key
        postKeyEvent(keyCode: keyCode, keyDown: true, flags: modifierFlags)
        postKeyEvent(keyCode: keyCode, keyDown: false, flags: modifierFlags)
        
        // Release modifiers
        for modifier in modifiers.reversed() {
            if let modKeyCode = modifierKeyCode(modifier) {
                postKeyEvent(keyCode: modKeyCode, keyDown: false, flags: [])
            }
        }
    }
    
    private func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
    
    private func keyCodeFor(_ key: String) throws -> CGKeyCode {
        // Common key mappings
        let keyMap: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, " ": 49, "space": 49,
            "return": 36, "enter": 36, "tab": 48, "delete": 51, "backspace": 51,
            "escape": 53, "esc": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111
        ]
        
        guard let code = keyMap[key.lowercased()] else {
            throw KeyboardError.unknownKey(key)
        }
        return code
    }
    
    private func modifierKeyCode(_ modifier: String) -> CGKeyCode? {
        switch modifier {
        case "cmd": return 55
        case "shift": return 56
        case "alt": return 58
        case "ctrl": return 59
        default: return nil
        }
    }
    
    private func modifierFlagsFor(_ modifiers: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt": flags.insert(.maskAlternate)
            case "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        return flags
    }
}

enum KeyboardError: Error {
    case unknownKey(String)
}
```

### ScreenCapture

```swift
// Actions/ScreenCapture.swift
import Foundation
import CoreGraphics
import AppKit

actor ScreenCapture {
    
    /// Get the color of a single pixel
    func getPixelColor(at point: Point) throws -> RGB {
        let displayID = CGMainDisplayID()
        let rect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        
        guard let image = CGDisplayCreateImage(displayID, rect: rect) else {
            throw ScreenCaptureError.captureFailedvarpermissionDenied
        }
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            throw ScreenCaptureError.dataExtractionFailed
        }
        
        // Assuming RGBA format
        let r = Int(bytes[0])
        let g = Int(bytes[1])
        let b = Int(bytes[2])
        
        return RGB(r: r, g: g, b: b)
    }
    
    /// Check if a pixel matches a color within threshold
    func checkPixelState(at point: Point, expectedColor: RGB, threshold: Double) throws -> Bool {
        let actualColor = try getPixelColor(at: point)
        let distance = colorDistance(actualColor, expectedColor)
        return distance <= threshold
    }
    
    /// Check if any pixel in a zone matches a color within threshold
    func checkPixelZone(rect: Rect, expectedColor: RGB, threshold: Double) throws -> Bool {
        let displayID = CGMainDisplayID()
        let cgRect = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        
        guard let image = CGDisplayCreateImage(displayID, rect: cgRect) else {
            throw ScreenCaptureError.captureFailed
        }
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data else {
            throw ScreenCaptureError.dataExtractionFailed
        }
        
        let bytes = CFDataGetBytePtr(data)!
        let bytesPerRow = image.bytesPerRow
        let bitsPerPixel = image.bitsPerPixel / 8
        
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = y * bytesPerRow + x * bitsPerPixel
                let r = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let b = Int(bytes[offset + 2])
                
                let pixelColor = RGB(r: r, g: g, b: b)
                if colorDistance(pixelColor, expectedColor) <= threshold {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Euclidean RGB distance
    private func colorDistance(_ c1: RGB, _ c2: RGB) -> Double {
        let dr = Double(c1.r - c2.r)
        let dg = Double(c1.g - c2.g)
        let db = Double(c1.b - c2.b)
        return sqrt(dr*dr + dg*dg + db*db)
    }
    
    /// Wait for pixel to match condition (polling)
    func waitForPixelState(
        at point: Point,
        expectedColor: RGB,
        threshold: Double,
        timeoutMs: Int = 30000,
        pollIntervalMs: Int = 50
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        
        while Date() < deadline {
            if try checkPixelState(at: point, expectedColor: expectedColor, threshold: threshold) {
                return true
            }
            try await Task.sleep(nanoseconds: UInt64(pollIntervalMs) * 1_000_000)
        }
        
        throw ScreenCaptureError.timeout
    }
    
    /// Wait for any pixel in zone to match condition (polling)
    func waitForPixelZone(
        rect: Rect,
        expectedColor: RGB,
        threshold: Double,
        timeoutMs: Int = 30000,
        pollIntervalMs: Int = 50
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        
        while Date() < deadline {
            if try checkPixelZone(rect: rect, expectedColor: expectedColor, threshold: threshold) {
                return true
            }
            try await Task.sleep(nanoseconds: UInt64(pollIntervalMs) * 1_000_000)
        }
        
        throw ScreenCaptureError.timeout
    }
    
    /// Capture a region for magnifier display
    func captureRegion(around point: Point, radius: Int) throws -> CGImage {
        let displayID = CGMainDisplayID()
        let rect = CGRect(
            x: point.x - Double(radius),
            y: point.y - Double(radius),
            width: Double(radius * 2),
            height: Double(radius * 2)
        )
        
        guard let image = CGDisplayCreateImage(displayID, rect: rect) else {
            throw ScreenCaptureError.captureFailed
        }
        
        return image
    }
}

enum ScreenCaptureError: Error {
    case captureFailed
    case permissionDenied
    case dataExtractionFailed
    case timeout
}
```

## Building & Running

```bash
# Build
cd swift-helper
swift build -c release

# Run (for testing)
.build/release/SequencerHelper

# The binary will be spawned by the Bun controller
```

## Testing IPC Manually

```bash
# Start the helper
.build/release/SequencerHelper

# Send a request (type this and press enter)
{"id":"1","method":"checkPermissions"}

# Expected response:
{"id":"1","success":true,"result":{"accessibility":true,"screenRecording":true}}
```
