import Foundation
import CoreGraphics

/// Controller for keyboard input simulation using CGEvent
actor KeyboardController {
    
    enum KeyboardError: Error, LocalizedError {
        case failedToCreateEvent
        case unknownKey(String)
        
        var errorDescription: String? {
            switch self {
            case .failedToCreateEvent:
                return "Failed to create CGEvent for keyboard action"
            case .unknownKey(let key):
                return "Unknown key: \(key)"
            }
        }
    }
    
    /// Press a key with optional modifiers
    /// - Parameters:
    ///   - key: The key to press (a-z, 0-9, special keys, F1-F12)
    ///   - modifiers: Array of modifiers (cmd, ctrl, alt, shift)
    func press(key: String, modifiers: [KeyModifier]) throws {
        let keyCode = try keyCodeFor(key)
        let modifierFlags = modifierFlagsFor(modifiers)
        
        // Press modifiers first
        if modifierFlags != [] {
            try pressModifiers(modifiers, down: true)
        }
        
        // Press and release the key
        try pressKey(keyCode: keyCode, modifierFlags: modifierFlags, down: true)
        try pressKey(keyCode: keyCode, modifierFlags: modifierFlags, down: false)
        
        // Release modifiers
        if modifierFlags != [] {
            try pressModifiers(modifiers, down: false)
        }
    }
    
    // MARK: - Private Helpers
    
    private func pressKey(keyCode: CGKeyCode, modifierFlags: CGEventFlags, down: Bool) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else {
            throw KeyboardError.failedToCreateEvent
        }
        
        if modifierFlags != [] {
            event.flags = modifierFlags
        }
        
        event.post(tap: .cghidEventTap)
    }
    
    private func pressModifiers(_ modifiers: [KeyModifier], down: Bool) throws {
        for modifier in modifiers {
            let keyCode = modifierKeyCode(for: modifier)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else {
                throw KeyboardError.failedToCreateEvent
            }
            event.post(tap: .cghidEventTap)
        }
    }
    
    private func modifierFlagsFor(_ modifiers: [KeyModifier]) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        for modifier in modifiers {
            switch modifier {
            case .cmd:
                flags.insert(.maskCommand)
            case .ctrl:
                flags.insert(.maskControl)
            case .alt:
                flags.insert(.maskAlternate)
            case .shift:
                flags.insert(.maskShift)
            }
        }
        
        return flags
    }
    
    private func modifierKeyCode(for modifier: KeyModifier) -> CGKeyCode {
        switch modifier {
        case .cmd:
            return 55    // kVK_Command
        case .ctrl:
            return 59    // kVK_Control
        case .alt:
            return 58    // kVK_Option
        case .shift:
            return 56    // kVK_Shift
        }
    }
    
    /// Map key string to macOS virtual key code
    private func keyCodeFor(_ key: String) throws -> CGKeyCode {
        let lowercased = key.lowercased()
        
        // Try key code map first
        if let code = keyCodeMap[lowercased] {
            return code
        }
        
        // Single character - try to map it
        if key.count == 1, let char = key.first {
            if let code = characterKeyCode(char) {
                return code
            }
        }
        
        throw KeyboardError.unknownKey(key)
    }
    
    private func characterKeyCode(_ char: Character) -> CGKeyCode? {
        let lower = char.lowercased().first ?? char
        
        // Letters a-z
        if lower >= "a" && lower <= "z" {
            let offset = Int(lower.asciiValue! - Character("a").asciiValue!)
            return CGKeyCode(keyCodeMap["a"]!) + CGKeyCode(offset)
        }
        
        // Numbers 0-9 (top row)
        if lower >= "0" && lower <= "9" {
            return keyCodeMap[String(lower)]
        }
        
        return nil
    }
    
    /// macOS virtual key code mapping
    /// Reference: Carbon/Events.h (kVK_* constants)
    private let keyCodeMap: [String: CGKeyCode] = [
        // Letters (a is at 0x00, but layout varies)
        "a": 0,   "b": 11,  "c": 8,   "d": 2,   "e": 14,
        "f": 3,   "g": 5,   "h": 4,   "i": 34,  "j": 38,
        "k": 40,  "l": 37,  "m": 46,  "n": 45,  "o": 31,
        "p": 35,  "q": 12,  "r": 15,  "s": 1,   "t": 17,
        "u": 32,  "v": 9,   "w": 13,  "x": 7,   "y": 16,
        "z": 6,
        
        // Numbers (top row)
        "0": 29,  "1": 18,  "2": 19,  "3": 20,  "4": 21,
        "5": 23,  "6": 22,  "7": 26,  "8": 28,  "9": 25,
        
        // Function keys
        "f1": 122,  "f2": 120,  "f3": 99,   "f4": 118,
        "f5": 96,   "f6": 97,   "f7": 98,   "f8": 100,
        "f9": 101,  "f10": 109, "f11": 103, "f12": 111,
        
        // Special keys
        "return": 36,
        "enter": 76,       // Numpad enter
        "tab": 48,
        "space": 49,
        "delete": 51,      // Backspace
        "backspace": 51,
        "escape": 53,
        "esc": 53,
        
        // Arrow keys
        "left": 123,
        "right": 124,
        "down": 125,
        "up": 126,
        "arrowleft": 123,
        "arrowright": 124,
        "arrowdown": 125,
        "arrowup": 126,
        
        // Navigation
        "home": 115,
        "end": 119,
        "pageup": 116,
        "pagedown": 121,
        
        // Punctuation
        "-": 27,
        "=": 24,
        "[": 33,
        "]": 30,
        "\\": 42,
        ";": 41,
        "'": 39,
        ",": 43,
        ".": 47,
        "/": 44,
        "`": 50,
        
        // Aliases
        "minus": 27,
        "equal": 24,
        "equals": 24,
        "plus": 24,        // Shift+= but same key code
        "comma": 43,
        "period": 47,
        "slash": 44,
        "backslash": 42,
        "semicolon": 41,
        "quote": 39,
        "backtick": 50,
        "grave": 50,
    ]
}
