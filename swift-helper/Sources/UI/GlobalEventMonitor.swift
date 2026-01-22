import Foundation
import AppKit

/// Monitors global NSEvents (mouse clicks and key presses) for recording purposes.
/// Requires Accessibility permission to monitor events outside the app.
class GlobalEventMonitor {
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void
    
    /// Initialize a global event monitor
    /// - Parameters:
    ///   - mask: Event types to monitor (e.g., `.leftMouseDown`, `.keyDown`)
    ///   - handler: Callback for each captured event
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
        Logger.log("EventMonitor", "Initialized with mask: \(mask)")
    }
    
    deinit {
        Logger.log("EventMonitor", "Deinitializing")
        stop()
    }
    
    /// Start monitoring events globally
    func start() {
        Logger.log("EventMonitor", "Starting monitors for mask: \(mask)")
        
        // Monitor events in other applications (requires Accessibility permission)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Logger.log("EventMonitor", "Global event received: type=\(event.type.rawValue), location=\(event.locationInWindow)")
            self?.handler(event)
        }
        Logger.log("EventMonitor", "Global monitor registered: \(globalMonitor != nil)")
        
        // Also monitor events in our own windows (for local clicks)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Logger.log("EventMonitor", "Local event received: type=\(event.type.rawValue), location=\(event.locationInWindow), window=\(event.window?.title ?? "nil")")
            self?.handler(event)
            return event // Pass event through
        }
        Logger.log("EventMonitor", "Local monitor registered: \(localMonitor != nil)")
    }
    
    /// Stop monitoring events
    func stop() {
        Logger.log("EventMonitor", "Stopping monitors")
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
            Logger.log("EventMonitor", "Global monitor removed")
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
            Logger.log("EventMonitor", "Local monitor removed")
        }
    }
}

/// Helper to convert NSEvent key to string and extract modifiers
struct KeyEventInfo {
    let key: String
    let modifiers: [KeyModifier]
    
    init?(from event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              !characters.isEmpty else {
            // Skip modifier-only events
            return nil
        }
        
        // Special keys mapping
        let key: String
        switch event.keyCode {
        case 36: key = "return"
        case 48: key = "tab"
        case 49: key = "space"
        case 51: key = "backspace"
        case 53: key = "escape"
        case 123: key = "left"
        case 124: key = "right"
        case 125: key = "down"
        case 126: key = "up"
        case 117: key = "delete"
        case 115: key = "home"
        case 119: key = "end"
        case 116: key = "pageup"
        case 121: key = "pagedown"
        case 122: key = "f1"
        case 120: key = "f2"
        case 99: key = "f3"
        case 118: key = "f4"
        case 96: key = "f5"
        case 97: key = "f6"
        case 98: key = "f7"
        case 100: key = "f8"
        case 101: key = "f9"
        case 109: key = "f10"
        case 103: key = "f11"
        case 111: key = "f12"
        default:
            // Use the character as-is for regular keys
            key = characters
        }
        
        self.key = key
        
        // Extract modifiers
        var mods: [KeyModifier] = []
        let flags = event.modifierFlags
        
        if flags.contains(.command) {
            mods.append(.cmd)
        }
        if flags.contains(.control) {
            mods.append(.ctrl)
        }
        if flags.contains(.option) {
            mods.append(.alt)
        }
        if flags.contains(.shift) {
            mods.append(.shift)
        }
        
        self.modifiers = mods
    }
}

/// Helper to extract mouse button from NSEvent
struct MouseEventInfo {
    let position: Point
    let button: MouseButton
    
    init(from event: NSEvent) {
        // Get screen coordinates (not window coordinates)
        let screenPoint = NSEvent.mouseLocation
        // Flip Y coordinate to match CGEvent coordinate system (top-left origin)
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        self.position = Point(x: Double(screenPoint.x), y: Double(screenHeight - screenPoint.y))
        
        switch event.type {
        case .leftMouseDown, .leftMouseUp:
            self.button = .left
        case .rightMouseDown, .rightMouseUp:
            self.button = .right
        default:
            // Default to left for other types
            self.button = .left
        }
    }
}
