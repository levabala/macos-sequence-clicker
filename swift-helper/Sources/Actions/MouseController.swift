import Foundation
import CoreGraphics

/// Controller for mouse input simulation using CGEvent
actor MouseController {
    
    enum MouseError: Error, LocalizedError {
        case failedToCreateEvent
        case failedToGetCurrentPosition
        case invalidButton(String)
        
        var errorDescription: String? {
            switch self {
            case .failedToCreateEvent:
                return "Failed to create CGEvent for mouse action"
            case .failedToGetCurrentPosition:
                return "Failed to get current mouse position"
            case .invalidButton(let button):
                return "Invalid mouse button: \(button)"
            }
        }
    }
    
    /// Click at a specific position
    /// - Parameters:
    ///   - point: Screen coordinates (top-left origin)
    ///   - button: "left" or "right"
    func click(at point: Point, button: MouseButton) throws {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        
        let (downType, upType, cgButton) = try mouseEventTypes(for: button)
        
        // Move to position first
        moveTo(cgPoint)
        
        // Create and post mouse down event
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: cgPoint,
            mouseButton: cgButton
        ) else {
            throw MouseError.failedToCreateEvent
        }
        
        // Create and post mouse up event
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: cgPoint,
            mouseButton: cgButton
        ) else {
            throw MouseError.failedToCreateEvent
        }
        
        // Post events
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    /// Move mouse to a specific position without clicking
    /// - Parameter point: Screen coordinates (top-left origin)
    func moveTo(_ point: CGPoint) {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return
        }
        
        moveEvent.post(tap: .cghidEventTap)
    }
    
    /// Get the current mouse position
    /// - Returns: Current screen coordinates
    func getCurrentPosition() throws -> Point {
        let event = CGEvent(source: nil)
        guard let location = event?.location else {
            throw MouseError.failedToGetCurrentPosition
        }
        
        return Point(x: location.x, y: location.y)
    }
    
    // MARK: - Private Helpers
    
    private func mouseEventTypes(for button: MouseButton) throws -> (down: CGEventType, up: CGEventType, button: CGMouseButton) {
        switch button {
        case .left:
            return (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            return (.rightMouseDown, .rightMouseUp, .right)
        }
    }
}
