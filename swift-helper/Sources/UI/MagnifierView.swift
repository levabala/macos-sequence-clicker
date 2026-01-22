import SwiftUI
import AppKit
import CoreGraphics

/// Magnifier view showing 4x zoom of screen content around the cursor.
/// Used for precise pixel selection during recording.
struct MagnifierView: View {
    let screenCapture: ScreenCapture
    let onPixelSelected: (Point, RGB) -> Void
    let onZoneStart: () -> Void
    
    // Configuration
    private let zoomLevel: CGFloat = 4
    private let captureRadius: Int = 12 // 25x25 pixels
    private let displaySize: CGFloat = 100
    
    @State private var magnifiedImage: CGImage?
    @State private var centerColor: RGB = RGB(r: 0, g: 0, b: 0)
    @State private var cursorPosition: CGPoint = .zero
    @State private var updateTimer: Timer?
    @State private var isDragging: Bool = false
    @State private var dragStartPosition: CGPoint?
    
    var body: some View {
        VStack(spacing: 8) {
            // Magnified image with crosshair
            magnifierContent
            
            // Color info
            colorInfoSection
            
            // Instructions
            Text("Click: select pixel")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Drag: select zone")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 8)
        )
        .onAppear {
            startCursorTracking()
        }
        .onDisappear {
            stopCursorTracking()
        }
    }
    
    // MARK: - Magnifier Content
    
    private var magnifierContent: some View {
        ZStack {
            // Magnified image
            if let image = magnifiedImage {
                Image(nsImage: NSImage(cgImage: image, size: NSSize(width: displaySize, height: displaySize)))
                    .interpolation(.none) // Pixelated look
                    .resizable()
                    .frame(width: displaySize, height: displaySize)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: displaySize, height: displaySize)
            }
            
            // Crosshair overlay
            crosshairOverlay
            
            // Center pixel highlight
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: zoomLevel, height: zoomLevel)
        }
        .frame(width: displaySize, height: displaySize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .gesture(clickGesture)
        .gesture(dragGesture)
    }
    
    // MARK: - Crosshair Overlay
    
    private var crosshairOverlay: some View {
        ZStack {
            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 1, height: displaySize)
            
            // Horizontal line
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: displaySize, height: 1)
        }
    }
    
    // MARK: - Color Info Section
    
    private var colorInfoSection: some View {
        HStack(spacing: 8) {
            // Color swatch
            Rectangle()
                .fill(Color(
                    red: Double(centerColor.r) / 255.0,
                    green: Double(centerColor.g) / 255.0,
                    blue: Double(centerColor.b) / 255.0
                ))
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Hex color code
            Text(hexColor)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            
            // RGB values
            Text("R:\(centerColor.r) G:\(centerColor.g) B:\(centerColor.b)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Gestures
    
    private var clickGesture: some Gesture {
        TapGesture()
            .onEnded { _ in
                // Select the current center pixel
                let screenHeight = NSScreen.main?.frame.height ?? 1080
                let position = Point(
                    x: Double(cursorPosition.x),
                    y: Double(screenHeight - cursorPosition.y) // Convert to top-left origin
                )
                onPixelSelected(position, centerColor)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartPosition = cursorPosition
                }
            }
            .onEnded { _ in
                if isDragging {
                    isDragging = false
                    dragStartPosition = nil
                    // Start zone selection
                    onZoneStart()
                }
            }
    }
    
    // MARK: - Cursor Tracking
    
    private func startCursorTracking() {
        // Update position at ~30fps on the main actor
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [self] _ in
            Task { @MainActor in
                updateMagnifierSync()
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func stopCursorTracking() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Synchronous update function that runs on the main thread (called by Timer)
    @MainActor
    private func updateMagnifierSync() {
        // Get current cursor position
        cursorPosition = NSEvent.mouseLocation
        
        // Convert to screen coordinates (top-left origin)
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let point = Point(
            x: Double(cursorPosition.x),
            y: Double(screenHeight - cursorPosition.y)
        )
        
        // Capture region around cursor (async, but we handle errors gracefully)
        Task {
            do {
                let image = try await screenCapture.captureRegion(around: point, radius: captureRadius)
                await MainActor.run {
                    magnifiedImage = image
                }
                
                // Get center pixel color
                let color = try await screenCapture.getPixelColor(at: point)
                await MainActor.run {
                    centerColor = color
                }
            } catch {
                // Ignore capture errors (may happen at screen edges)
            }
        }
        
        // Update window position to follow cursor (with offset) - all on main actor
        updateWindowPosition()
    }
    
    @MainActor
    private func updateWindowPosition() {
        // Find the magnifier window
        guard let window = findMagnifierWindow() else { return }
        
        let offset: CGFloat = 30
        let newX = cursorPosition.x + offset
        let newY = cursorPosition.y - window.frame.height - offset
        
        // Keep window on screen
        if let screen = NSScreen.main {
            let clampedX = min(max(newX, 0), screen.frame.width - window.frame.width)
            let clampedY = min(max(newY, 0), screen.frame.height - window.frame.height)
            window.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        } else {
            window.setFrameOrigin(NSPoint(x: newX, y: newY))
        }
    }
    
    @MainActor
    private func findMagnifierWindow() -> NSWindow? {
        // Find window by checking if it contains our hosting view
        for window in NSApp.windows {
            if let contentView = window.contentView,
               let hostingView = contentView.subviews.first,
               String(describing: type(of: hostingView)).contains("NSHostingView") {
                // Check if this is the magnifier window by size (rough check)
                if window.frame.width < 200 && window.frame.height < 250 {
                    return window
                }
            }
        }
        return nil
    }
    
    // MARK: - Helpers
    
    private var hexColor: String {
        String(format: "#%02X%02X%02X", centerColor.r, centerColor.g, centerColor.b)
    }
}

// MARK: - Preview

#if DEBUG
struct MagnifierView_Previews: PreviewProvider {
    static var previews: some View {
        MagnifierView(
            screenCapture: ScreenCapture(),
            onPixelSelected: { _, _ in },
            onZoneStart: {}
        )
        .frame(width: 140, height: 180)
        .background(Color.gray)
    }
}
#endif
