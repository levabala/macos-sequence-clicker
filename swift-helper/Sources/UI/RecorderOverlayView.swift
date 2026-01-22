import SwiftUI
import AppKit

/// Main recorder toolbar overlay with icon buttons for recording actions and transitions.
/// The toolbar is draggable and shows the current recording state.
struct RecorderOverlayView: View {
    let state: RecorderState
    let subState: RecorderSubState?
    let onIconClick: (OverlayIcon) -> Void
    let onDragEnd: (Point) -> Void
    let onClose: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var windowPosition: CGPoint = .zero
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicators
            statusSection
            
            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.3))
            
            // Action buttons
            actionSection
            
            Spacer()
            
            // Close button
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toolbarBackground)
        .gesture(dragGesture)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            // Action status indicator
            StatusIndicator(
                icon: "record.circle",
                label: "Action",
                isActive: state == .action,
                activeColor: .red
            )
            .onTapGesture {
                Logger.log("UI", "Action indicator tapped, current state: \(state)")
                if state != .action {
                    onIconClick(.action)
                }
            }
            
            // Transition status indicator
            StatusIndicator(
                icon: "arrow.right.circle",
                label: "Trans",
                isActive: state == .transition,
                activeColor: .orange
            )
            .onTapGesture {
                Logger.log("UI", "Transition indicator tapped, current state: \(state)")
                if state != .transition {
                    onIconClick(.transition)
                }
            }
        }
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        HStack(spacing: 8) {
            // Mouse button
            IconButton(
                icon: "cursorarrow.click",
                label: "Mouse",
                isDisabled: state == .idle,
                isSelected: subState == .mouse
            ) {
                onIconClick(.mouse)
            }
            
            // Keyboard button
            IconButton(
                icon: "keyboard",
                label: "Key",
                isDisabled: !canUseKeyboard,
                isSelected: subState == .keyboard
            ) {
                onIconClick(.keyboard)
            }
            
            // Time button
            IconButton(
                icon: "clock",
                label: "Time",
                isDisabled: !canUseTime,
                isSelected: subState == .time
            ) {
                onIconClick(.time)
            }
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: {
            Logger.log("UI", "Close button clicked")
            onClose()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help("Close recorder")
    }
    
    // MARK: - Background
    
    private var toolbarBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.85))
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Get current window position and update
                if let window = NSApp.windows.first(where: { $0.contentView?.subviews.first is NSHostingView<RecorderOverlayView> }) {
                    let newOrigin = NSPoint(
                        x: window.frame.origin.x + value.translation.width - dragOffset.width,
                        y: window.frame.origin.y - value.translation.height + dragOffset.height
                    )
                    window.setFrameOrigin(newOrigin)
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                dragOffset = .zero
                // Report final position
                if let window = NSApp.windows.first(where: { $0.contentView?.subviews.first is NSHostingView<RecorderOverlayView> }) {
                    let position = Point(
                        x: Double(window.frame.origin.x),
                        y: Double(window.frame.origin.y)
                    )
                    onDragEnd(position)
                }
            }
    }
    
    // MARK: - State Helpers
    
    private var canUseKeyboard: Bool {
        state == .action
    }
    
    private var canUseTime: Bool {
        state == .transition
    }
}

// MARK: - Status Indicator

private struct StatusIndicator: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isActive ? activeColor : .white.opacity(0.5))
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isActive ? activeColor : .white.opacity(0.5))
        }
        .frame(width: 50)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? activeColor.opacity(0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    let isSelected: Bool
    let action: () -> Void
    
    init(icon: String, label: String, isDisabled: Bool = false, isSelected: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isDisabled = isDisabled
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            Logger.log("UI", "IconButton '\(label)' clicked, isDisabled: \(isDisabled)")
            if !isDisabled {
                action()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(width: 44, height: 36)
            .foregroundColor(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
    }
    
    private var foregroundColor: Color {
        if isDisabled {
            return .white.opacity(0.3)
        } else if isSelected {
            return .blue
        } else {
            return .white.opacity(0.8)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue.opacity(0.3)
        } else {
            return .clear
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecorderOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecorderOverlayView(
                state: .idle,
                subState: nil,
                onIconClick: { _ in },
                onDragEnd: { _ in },
                onClose: {}
            )
            .previewDisplayName("Idle")
            
            RecorderOverlayView(
                state: .action,
                subState: .mouse,
                onIconClick: { _ in },
                onDragEnd: { _ in },
                onClose: {}
            )
            .previewDisplayName("Action - Mouse")
            
            RecorderOverlayView(
                state: .transition,
                subState: .time,
                onIconClick: { _ in },
                onDragEnd: { _ in },
                onClose: {}
            )
            .previewDisplayName("Transition - Time")
        }
        .frame(width: 360, height: 60)
        .background(Color.gray)
    }
}
#endif
