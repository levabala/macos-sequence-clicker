import Foundation
import AppKit
import CoreGraphics

/// Buttons available on the recorder overlay
/// Positions are calculated based on RecorderOverlayView.swift layout analysis
enum OverlayButton {
    case action       // Status indicator - left side
    case transition   // Status indicator - left side
    case mouse        // Action button - middle
    case keyboard     // Action button - middle
    case time         // Action button - middle
    case close        // Close button - right side
    
    /// Relative X position from overlay left edge to button center
    /// Based on RecorderOverlayView.swift layout:
    /// - HStack padding: 16px each side
    /// - Status section: 2x StatusIndicator (50px width each) with 12px spacing
    /// - Divider + spacing
    /// - Action section: 3x IconButton (44px width each) with 8px spacing
    /// - Close button: 20px icon
    var relativeX: CGFloat {
        switch self {
        case .action:     return 16 + 25       // padding + half of 50px StatusIndicator
        case .transition: return 16 + 50 + 12 + 25  // padding + action + spacing + half
        case .mouse:      return 16 + 50 + 12 + 50 + 8 + 10 + 22  // After divider + spacing
        case .keyboard:   return 16 + 50 + 12 + 50 + 8 + 10 + 44 + 8 + 22
        case .time:       return 16 + 50 + 12 + 50 + 8 + 10 + 44 + 8 + 44 + 8 + 22
        case .close:      return 360 - 16 - 10  // width - padding - half button
        }
    }
    
    /// Relative Y position from overlay top edge to button center
    /// Overlay height is 60, buttons are vertically centered
    var relativeY: CGFloat {
        return 30  // Center of 60px height
    }
    
    /// Relative position within overlay bounds
    var relativeCenter: CGPoint {
        CGPoint(x: relativeX, y: relativeY)
    }
}

/// Locates overlay windows and calculates button positions
class OverlayLocator {
    
    // Expected overlay sizes from OverlayWindowController.swift
    static let recorderOverlaySize = CGSize(width: 360, height: 60)
    static let magnifierSize = CGSize(width: 140, height: 180)
    static let timeInputSize = CGSize(width: 250, height: 120)
    
    /// Find the recorder overlay window frame
    /// Uses CGWindowListCopyWindowInfo to find windows matching the overlay size
    func findRecorderOverlay() -> CGRect? {
        return findWindow(
            matchingSize: Self.recorderOverlaySize,
            ownerName: "SequencerHelper",
            tolerance: 5
        )
    }
    
    /// Find the magnifier window frame
    func findMagnifier() -> CGRect? {
        return findWindow(
            matchingSize: Self.magnifierSize,
            ownerName: "SequencerHelper",
            tolerance: 5
        )
    }
    
    /// Find the time input window frame
    func findTimeInput() -> CGRect? {
        return findWindow(
            matchingSize: Self.timeInputSize,
            ownerName: "SequencerHelper",
            tolerance: 5
        )
    }
    
    /// Get absolute screen position for a button on the overlay
    /// - Parameter button: The button to locate
    /// - Returns: Screen coordinates of the button center, or nil if overlay not found
    func buttonPosition(_ button: OverlayButton) -> CGPoint? {
        guard let overlayFrame = findRecorderOverlay() else {
            return nil
        }
        
        // Note: CGWindowList uses top-left origin coordinate system
        // macOS screen coordinates use bottom-left origin
        // But CGEvent uses top-left, so we can use the window bounds directly
        return CGPoint(
            x: overlayFrame.origin.x + button.relativeX,
            y: overlayFrame.origin.y + button.relativeY
        )
    }
    
    /// Wait for the overlay to appear
    /// - Parameter timeoutMs: Maximum time to wait
    /// - Returns: Overlay frame when found
    func waitForOverlay(timeoutMs: Int = 5000) async throws -> CGRect {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        
        while Date() < deadline {
            if let frame = findRecorderOverlay() {
                return frame
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        throw TestError("Timeout waiting for overlay to appear")
    }
    
    /// Check if any overlay windows are visible
    func hasVisibleOverlay() -> Bool {
        findRecorderOverlay() != nil || findMagnifier() != nil || findTimeInput() != nil
    }
    
    // MARK: - Private
    
    private func findWindow(
        matchingSize: CGSize,
        ownerName: String,
        tolerance: CGFloat
    ) -> CGRect? {
        // Get list of all on-screen windows
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        
        for window in windowList {
            // Check owner name
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  owner == ownerName else {
                continue
            }
            
            // Get bounds
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            
            // Check if size matches within tolerance
            if abs(width - matchingSize.width) <= tolerance &&
               abs(height - matchingSize.height) <= tolerance {
                return CGRect(x: x, y: y, width: width, height: height)
            }
        }
        
        return nil
    }
    
    /// Debug: Print all windows from SequencerHelper
    func debugPrintWindows() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            print("Failed to get window list")
            return
        }
        
        print("Windows from SequencerHelper:")
        for window in windowList {
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  owner == "SequencerHelper" else {
                continue
            }
            
            if let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat] {
                print("  - \(boundsDict)")
            }
        }
    }
}
