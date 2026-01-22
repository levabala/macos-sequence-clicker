import Foundation
import Carbon.HIToolbox

/// macOS virtual key codes for keyboard input simulation
/// These are NOT ASCII values - they are hardware key codes
enum KeyCodes {
    // Letters
    static let a: UInt16 = 0x00
    static let b: UInt16 = 0x0B
    static let c: UInt16 = 0x08
    static let d: UInt16 = 0x02
    static let e: UInt16 = 0x0E
    static let f: UInt16 = 0x03
    static let g: UInt16 = 0x05
    static let h: UInt16 = 0x04
    static let i: UInt16 = 0x22
    static let j: UInt16 = 0x26
    static let k: UInt16 = 0x28
    static let l: UInt16 = 0x25
    static let m: UInt16 = 0x2E
    static let n: UInt16 = 0x2D
    static let o: UInt16 = 0x1F
    static let p: UInt16 = 0x23
    static let q: UInt16 = 0x0C
    static let r: UInt16 = 0x0F
    static let s: UInt16 = 0x01
    static let t: UInt16 = 0x11
    static let u: UInt16 = 0x20
    static let v: UInt16 = 0x09
    static let w: UInt16 = 0x0D
    static let x: UInt16 = 0x07
    static let y: UInt16 = 0x10
    static let z: UInt16 = 0x06
    
    // Numbers
    static let num0: UInt16 = 0x1D
    static let num1: UInt16 = 0x12
    static let num2: UInt16 = 0x13
    static let num3: UInt16 = 0x14
    static let num4: UInt16 = 0x15
    static let num5: UInt16 = 0x17
    static let num6: UInt16 = 0x16
    static let num7: UInt16 = 0x1A
    static let num8: UInt16 = 0x1C
    static let num9: UInt16 = 0x19
    
    // Special keys
    static let returnKey: UInt16 = 0x24
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    static let delete: UInt16 = 0x33  // Backspace
    static let escape: UInt16 = 0x35
    static let forwardDelete: UInt16 = 0x75
    
    // Arrow keys
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
    
    // Modifiers (key codes, not flags)
    static let command: UInt16 = 0x37
    static let shift: UInt16 = 0x38
    static let capsLock: UInt16 = 0x39
    static let option: UInt16 = 0x3A  // Alt
    static let control: UInt16 = 0x3B
    static let rightShift: UInt16 = 0x3C
    static let rightOption: UInt16 = 0x3D
    static let rightControl: UInt16 = 0x3E
    
    // Punctuation
    static let minus: UInt16 = 0x1B
    static let equal: UInt16 = 0x18
    static let leftBracket: UInt16 = 0x21
    static let rightBracket: UInt16 = 0x1E
    static let backslash: UInt16 = 0x2A
    static let semicolon: UInt16 = 0x29
    static let quote: UInt16 = 0x27
    static let comma: UInt16 = 0x2B
    static let period: UInt16 = 0x2F
    static let slash: UInt16 = 0x2C
    static let grave: UInt16 = 0x32  // Backtick
    
    /// Map from key name strings to key codes
    static let keyCodeMap: [String: UInt16] = [
        // Letters
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h,
        "i": i, "j": j, "k": k, "l": l, "m": m, "n": n, "o": o, "p": p,
        "q": q, "r": r, "s": s, "t": t, "u": u, "v": v, "w": w, "x": x,
        "y": y, "z": z,
        
        // Numbers
        "0": num0, "1": num1, "2": num2, "3": num3, "4": num4,
        "5": num5, "6": num6, "7": num7, "8": num8, "9": num9,
        
        // Special keys
        "return": returnKey, "enter": returnKey,
        "tab": tab,
        "space": space, " ": space,
        "delete": delete, "backspace": delete,
        "escape": escape, "esc": escape,
        
        // Arrow keys
        "left": leftArrow, "right": rightArrow,
        "down": downArrow, "up": upArrow,
        
        // Punctuation
        "-": minus, "=": equal,
        "[": leftBracket, "]": rightBracket,
        "\\": backslash,
        ";": semicolon, "'": quote,
        ",": comma, ".": period, "/": slash,
        "`": grave,
    ]
    
    /// Get key code for a character or key name
    static func keyCode(for key: String) -> UInt16? {
        let lowercased = key.lowercased()
        return keyCodeMap[lowercased]
    }
}

/// Modifier key flags for CGEvent
enum ModifierFlags {
    static let shift: CGEventFlags = .maskShift
    static let control: CGEventFlags = .maskControl
    static let option: CGEventFlags = .maskAlternate  // Alt
    static let command: CGEventFlags = .maskCommand
    
    /// Parse modifier strings to CGEventFlags
    static func flags(from modifiers: [Modifier]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod {
            case .shift: flags.insert(.maskShift)
            case .ctrl: flags.insert(.maskControl)
            case .alt: flags.insert(.maskAlternate)
            case .cmd: flags.insert(.maskCommand)
            }
        }
        return flags
    }
}

/// Modifier key enum matching the controller's types
enum Modifier: String, CaseIterable {
    case ctrl
    case alt
    case shift
    case cmd
}
