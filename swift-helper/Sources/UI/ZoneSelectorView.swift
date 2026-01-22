import SwiftUI
import AppKit

/// Full-screen overlay for selecting a rectangular zone on screen.
/// User clicks and drags to define the selection area.
struct ZoneSelectorView: View {
    let screenSize: CGSize
    let onZoneSelected: (Rect) -> Void
    let onCancel: () -> Void
    
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var isSelecting: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())
                
                // Selection visualization
                if let rect = selectionRect {
                    // Dimmed area outside selection (using shape subtraction)
                    DimmedMask(selection: rect, screenSize: geometry.size)
                    
                    // Selection border
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Size label
                    sizeLabel(for: rect)
                }
                
                // Instructions (when not selecting)
                if !isSelecting {
                    instructionsOverlay
                }
            }
            .gesture(selectionGesture)
            .onAppear {
                setupKeyboardMonitor()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Selection Rectangle
    
    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else {
            return nil
        }
        
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        
        return CGRect(x: x, y: y, width: max(width, 1), height: max(height, 1))
    }
    
    // MARK: - Size Label
    
    private func sizeLabel(for rect: CGRect) -> some View {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        
        return Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
            .position(x: rect.midX, y: rect.maxY + 20)
    }
    
    // MARK: - Instructions Overlay
    
    private var instructionsOverlay: some View {
        VStack(spacing: 8) {
            Text("Click and drag to select a zone")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("Press Escape to cancel")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
    }
    
    // MARK: - Selection Gesture
    
    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isSelecting {
                    isSelecting = true
                    startPoint = value.startLocation
                }
                currentPoint = value.location
            }
            .onEnded { value in
                guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
                    // Too small, cancel
                    resetSelection()
                    return
                }
                
                // Convert to top-left origin coordinates
                let screenHeight = NSScreen.main?.frame.height ?? screenSize.height
                let resultRect = Rect(
                    x: Double(rect.minX),
                    y: Double(screenHeight - rect.maxY), // Flip Y axis
                    width: Double(rect.width),
                    height: Double(rect.height)
                )
                
                onZoneSelected(resultRect)
            }
    }
    
    // MARK: - Keyboard Monitor
    
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                onCancel()
                return nil // Consume the event
            }
            return event
        }
    }
    
    // MARK: - Helpers
    
    private func resetSelection() {
        isSelecting = false
        startPoint = nil
        currentPoint = nil
    }
}

// MARK: - Dimmed Mask

/// Creates a dimmed overlay with a transparent cutout for the selection area.
private struct DimmedMask: View {
    let selection: CGRect
    let screenSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Full screen dimmed area
            let fullRect = CGRect(origin: .zero, size: size)
            
            // Create path with cutout
            var path = Path()
            path.addRect(fullRect)
            path.addRect(selection)
            
            // Fill with even-odd rule to create cutout
            context.fill(path, with: .color(.black.opacity(0.4)), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ZoneSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ZoneSelectorView(
            screenSize: CGSize(width: 1920, height: 1080),
            onZoneSelected: { _ in },
            onCancel: {}
        )
        .frame(width: 800, height: 600)
    }
}
#endif
