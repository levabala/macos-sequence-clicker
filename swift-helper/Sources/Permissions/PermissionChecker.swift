import Foundation
import ApplicationServices
import CoreGraphics

/// Checks macOS permissions required for the helper
struct PermissionChecker {
    
    /// Check all required permissions and return status
    static func check() -> PermissionStatus {
        return PermissionStatus(
            accessibility: checkAccessibility(),
            screenRecording: checkScreenRecording()
        )
    }
    
    /// Check Accessibility permission using AXIsProcessTrusted
    /// This is required for simulating mouse clicks and keyboard input
    private static func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Check Screen Recording permission by attempting to capture the screen
    /// This is required for reading pixel colors
    private static func checkScreenRecording() -> Bool {
        // Try to capture a 1x1 pixel from the main display
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID? else {
            return false
        }
        
        // Attempt to create an image from the display
        // This will fail (return nil) if Screen Recording permission is not granted
        let image = CGDisplayCreateImage(mainDisplay, rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        return image != nil
    }
    
    /// Request accessibility permission (opens System Settings dialog)
    static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
