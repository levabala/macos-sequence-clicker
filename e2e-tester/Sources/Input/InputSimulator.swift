import Foundation
import AppKit
import CoreGraphics

/// Mouse button types
enum MouseButton {
    case left
    case right
}

/// Simulates keyboard and mouse input using CGEvent
@MainActor
class InputSimulator {
    
    // MARK: - Keyboard
    
    /// Press a single key with optional modifiers
    /// - Parameters:
    ///   - key: Key name (e.g., "a", "return", "escape")
    ///   - modifiers: Array of modifier keys
    func pressKey(_ key: String, modifiers: [Modifier] = []) async {
        guard let keyCode = KeyCodes.keyCode(for: key) else {
            print("Warning: Unknown key '\(key)'")
            return
        }
        
        let flags = ModifierFlags.flags(from: modifiers)
        
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("Warning: Failed to create key down event")
            return
        }
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)
        
        // Small delay between down and up
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("Warning: Failed to create key up event")
            return
        }
        keyUp.flags = flags
        keyUp.post(tap: .cghidEventTap)
        
        // Small delay after key press
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    /// Type a string character by character
    /// - Parameters:
    ///   - text: The text to type
    ///   - delayMs: Delay between characters in milliseconds
    func typeText(_ text: String, delayMs: Int = 50) async {
        for char in text {
            let charStr = String(char)
            
            // Check if it's an uppercase letter
            let isUppercase = char.isUppercase
            let modifiers: [Modifier] = isUppercase ? [.shift] : []
            
            // Get the key code (use lowercase for lookup)
            let keyName = charStr.lowercased()
            
            if let keyCode = KeyCodes.keyCode(for: keyName) {
                let flags = ModifierFlags.flags(from: modifiers)
                
                // Key down
                if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                    keyDown.flags = flags
                    keyDown.post(tap: .cghidEventTap)
                }
                
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                
                // Key up
                if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    keyUp.flags = flags
                    keyUp.post(tap: .cghidEventTap)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            } else {
                print("Warning: Cannot type character '\(char)'")
            }
        }
    }
    
    // MARK: - Mouse
    
    /// Click at a screen position
    /// - Parameters:
    ///   - point: Screen coordinates
    ///   - button: Mouse button to click
    func click(at point: CGPoint, button: MouseButton = .left) async {
        let mouseDownType: CGEventType
        let mouseUpType: CGEventType
        let mouseButton: CGMouseButton
        
        switch button {
        case .left:
            mouseDownType = .leftMouseDown
            mouseUpType = .leftMouseUp
            mouseButton = .left
        case .right:
            mouseDownType = .rightMouseDown
            mouseUpType = .rightMouseUp
            mouseButton = .right
        }
        
        // Create mouse down event
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseDownType,
            mouseCursorPosition: point,
            mouseButton: mouseButton
        ) else {
            print("Warning: Failed to create mouse down event")
            return
        }
        
        mouseDown.post(tap: .cghidEventTap)
        
        // Small delay
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Create mouse up event
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseUpType,
            mouseCursorPosition: point,
            mouseButton: mouseButton
        ) else {
            print("Warning: Failed to create mouse up event")
            return
        }
        
        mouseUp.post(tap: .cghidEventTap)
        
        // Delay after click
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    /// Double-click at a screen position
    func doubleClick(at point: CGPoint) async {
        // First click
        guard let mouseDown1 = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        mouseDown1.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseDown1.post(tap: .cghidEventTap)
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        guard let mouseUp1 = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        mouseUp1.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp1.post(tap: .cghidEventTap)
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Second click
        guard let mouseDown2 = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        mouseDown2.setIntegerValueField(.mouseEventClickState, value: 2)
        mouseDown2.post(tap: .cghidEventTap)
        
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        guard let mouseUp2 = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        mouseUp2.setIntegerValueField(.mouseEventClickState, value: 2)
        mouseUp2.post(tap: .cghidEventTap)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    /// Move the mouse to a position
    func moveMouse(to point: CGPoint) async {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        
        moveEvent.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    
    // MARK: - Utilities
    
    /// Wait for specified duration
    func wait(ms: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }
    
    /// Get current mouse position
    func mousePosition() -> CGPoint {
        NSEvent.mouseLocation
    }
}
