# Part 6: Swift UI (Recorder Overlay & Magnifier)

## Overview

The Swift helper provides two overlay windows:
1. **Recorder Overlay** - Toolbar for recording actions/transitions
2. **Magnifier** - 4x zoom view for precise pixel selection

Both are SwiftUI views rendered in borderless, floating windows.

## Overlay Window Management

```swift
// UI/OverlayWindow.swift
import AppKit
import SwiftUI

class OverlayWindowController {
    private var recorderWindow: NSWindow?
    private var magnifierWindow: NSWindow?
    private var zoneSelectorWindow: NSWindow?
    
    private let ipcHandler: IPCHandler
    
    init(ipcHandler: IPCHandler) {
        self.ipcHandler = ipcHandler
    }
    
    // MARK: - Recorder Overlay
    
    func showRecorderOverlay(at position: Point?) {
        if recorderWindow != nil { return }
        
        let contentView = RecorderOverlayView(
            onIconClick: { [weak self] icon in
                self?.handleIconClick(icon)
            },
            onDragEnd: { [weak self] position in
                self?.handleOverlayMoved(position)
            },
            onClose: { [weak self] in
                self?.hideRecorderOverlay()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false
        
        // Position
        let screenFrame = NSScreen.main?.frame ?? .zero
        let x = position?.x ?? (screenFrame.width - 300) / 2
        let y = position?.y ?? 100
        window.setFrameOrigin(NSPoint(x: x, y: screenFrame.height - y - 60))
        
        window.orderFront(nil)
        recorderWindow = window
    }
    
    func hideRecorderOverlay() {
        recorderWindow?.close()
        recorderWindow = nil
        
        Task {
            await ipcHandler.sendEvent(OverlayClosedEvent(event: "overlayClosed", data: [:]))
        }
    }
    
    func setRecorderState(_ state: String, subState: String?) {
        // Update the SwiftUI view state via environment or binding
        // This would require a shared state object
    }
    
    // MARK: - Magnifier
    
    func showMagnifier() {
        if magnifierWindow != nil { return }
        
        let contentView = MagnifierView(
            onPixelSelected: { [weak self] position, color in
                self?.handlePixelSelected(position, color)
            },
            onZoneStart: { [weak self] in
                self?.startZoneSelection()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating + 1  // Above recorder
        window.ignoresMouseEvents = false
        
        // Follow cursor
        startCursorTracking(for: window)
        
        window.orderFront(nil)
        magnifierWindow = window
    }
    
    func hideMagnifier() {
        stopCursorTracking()
        magnifierWindow?.close()
        magnifierWindow = nil
    }
    
    // MARK: - Zone Selector
    
    private func startZoneSelection() {
        hideMagnifier()
        
        let contentView = ZoneSelectorView(
            onZoneSelected: { [weak self] rect in
                self?.handleZoneSelected(rect)
            },
            onCancel: { [weak self] in
                self?.cancelZoneSelection()
            }
        )
        
        // Full screen overlay
        let screenFrame = NSScreen.main?.frame ?? .zero
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window.level = .floating
        
        window.orderFront(nil)
        zoneSelectorWindow = window
    }
    
    private func cancelZoneSelection() {
        zoneSelectorWindow?.close()
        zoneSelectorWindow = nil
        showMagnifier()
    }
    
    // MARK: - Cursor Tracking
    
    private var cursorTrackingTimer: Timer?
    
    private func startCursorTracking(for window: NSWindow) {
        cursorTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self, weak window] _ in
            guard let window = window else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            let screenFrame = NSScreen.main?.frame ?? .zero
            
            // Offset so magnifier doesn't cover cursor
            let offset: CGFloat = 20
            var x = mouseLocation.x + offset
            var y = mouseLocation.y + offset
            
            // Keep on screen
            if x + window.frame.width > screenFrame.maxX {
                x = mouseLocation.x - window.frame.width - offset
            }
            if y + window.frame.height > screenFrame.maxY {
                y = mouseLocation.y - window.frame.height - offset
            }
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
            
            // Trigger view update for magnifier content
            if let magnifierView = window.contentView as? NSHostingView<MagnifierView> {
                // The view will read mouse position in its body
            }
        }
    }
    
    private func stopCursorTracking() {
        cursorTrackingTimer?.invalidate()
        cursorTrackingTimer = nil
    }
    
    // MARK: - Event Handlers
    
    private func handleIconClick(_ icon: String) {
        Task {
            await ipcHandler.sendEvent(OverlayIconClickedEvent(
                event: "overlayIconClicked",
                data: ["icon": icon]
            ))
        }
    }
    
    private func handleOverlayMoved(_ position: Point) {
        Task {
            await ipcHandler.sendEvent(OverlayMovedEvent(
                event: "overlayMoved",
                data: ["position": position]
            ))
        }
    }
    
    private func handlePixelSelected(_ position: Point, _ color: RGB) {
        Task {
            await ipcHandler.sendEvent(PixelSelectedEvent(
                event: "pixelSelected",
                data: ["position": position, "color": color]
            ))
        }
        hideMagnifier()
    }
    
    private func handleZoneSelected(_ rect: Rect) {
        zoneSelectorWindow?.close()
        zoneSelectorWindow = nil
        
        Task {
            await ipcHandler.sendEvent(ZoneSelectedEvent(
                event: "zoneSelected",
                data: ["rect": rect]
            ))
        }
    }
}
```

## Recorder Overlay View

```swift
// UI/RecorderOverlay.swift
import SwiftUI

struct RecorderOverlayView: View {
    let onIconClick: (String) -> Void
    let onDragEnd: (Point) -> Void
    let onClose: () -> Void
    
    @State private var recorderState: RecorderState = .idle
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    enum RecorderState {
        case idle
        case waitingAction(subState: ActionSubState)
        case waitingTransition(subState: TransitionSubState)
    }
    
    enum ActionSubState {
        case mouse
        case keyboard
    }
    
    enum TransitionSubState {
        case mouse  // pixel selection
        case time
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Action status indicator
            IconButton(
                icon: "record.circle",
                label: "Action",
                isActive: isWaitingAction,
                activeColor: .red,
                action: { onIconClick("action") }
            )
            
            // Transition status indicator
            IconButton(
                icon: "arrow.right",
                label: "Trans",
                isActive: isWaitingTransition,
                activeColor: .red,
                action: { onIconClick("transition") }
            )
            
            Divider()
                .frame(height: 30)
            
            // Mouse click
            IconButton(
                icon: "cursorarrow.click",
                label: "Mouse",
                isActive: false,
                isDisabled: recorderState == .idle,
                action: { onIconClick("mouse") }
            )
            
            // Keyboard
            IconButton(
                icon: "keyboard",
                label: "Key",
                isActive: false,
                isDisabled: !canUseKeyboard,
                action: { onIconClick("keyboard") }
            )
            
            // Time delay
            IconButton(
                icon: "clock",
                label: "Time",
                isActive: false,
                isDisabled: !canUseTime,
                action: { onIconClick("time") }
            )
            
            Spacer()
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(radius: 10)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // Calculate new position and report
                    let newPosition = Point(
                        x: Double(value.location.x),
                        y: Double(value.location.y)
                    )
                    onDragEnd(newPosition)
                }
        )
    }
    
    private var isWaitingAction: Bool {
        if case .waitingAction = recorderState { return true }
        return false
    }
    
    private var isWaitingTransition: Bool {
        if case .waitingTransition = recorderState { return true }
        return false
    }
    
    private var canUseKeyboard: Bool {
        if case .waitingAction = recorderState { return true }
        return false
    }
    
    private var canUseTime: Bool {
        if case .waitingTransition = recorderState { return true }
        return false
    }
    
    // Method to update state from IPC
    func updateState(_ state: String, subState: String?) {
        switch state {
        case "idle":
            recorderState = .idle
        case "action":
            let sub: ActionSubState = subState == "keyboard" ? .keyboard : .mouse
            recorderState = .waitingAction(subState: sub)
        case "transition":
            let sub: TransitionSubState = subState == "time" ? .time : .mouse
            recorderState = .waitingTransition(subState: sub)
        default:
            break
        }
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    var activeColor: Color = .blue
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(buttonColor)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(buttonColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
    
    private var buttonColor: Color {
        if isDisabled { return .gray.opacity(0.5) }
        if isActive { return activeColor }
        return .white
    }
}
```

## Magnifier View

```swift
// UI/MagnifierView.swift
import SwiftUI
import CoreGraphics

struct MagnifierView: View {
    let onPixelSelected: (Point, RGB) -> Void
    let onZoneStart: () -> Void
    
    @State private var magnifiedImage: CGImage?
    @State private var centerColor: RGB = RGB(r: 0, g: 0, b: 0)
    @State private var isZoneMode = false
    
    private let zoomLevel: CGFloat = 4
    private let captureRadius: Int = 12  // Capture 25x25 pixels
    private let displaySize: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 4) {
            // Magnified view
            ZStack {
                if let image = magnifiedImage {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: displaySize, height: displaySize)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: displaySize, height: displaySize)
                }
                
                // Crosshair
                Path { path in
                    let center = displaySize / 2
                    // Horizontal line
                    path.move(to: CGPoint(x: 0, y: center))
                    path.addLine(to: CGPoint(x: center - 5, y: center))
                    path.move(to: CGPoint(x: center + 5, y: center))
                    path.addLine(to: CGPoint(x: displaySize, y: center))
                    // Vertical line
                    path.move(to: CGPoint(x: center, y: 0))
                    path.addLine(to: CGPoint(x: center, y: center - 5))
                    path.move(to: CGPoint(x: center, y: center + 5))
                    path.addLine(to: CGPoint(x: center, y: displaySize))
                }
                .stroke(Color.white, lineWidth: 1)
                
                // Center pixel highlight
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: zoomLevel, height: zoomLevel)
            }
            .frame(width: displaySize, height: displaySize)
            .border(Color.white, width: 2)
            
            // Color info
            HStack {
                Rectangle()
                    .fill(Color(
                        red: Double(centerColor.r) / 255,
                        green: Double(centerColor.g) / 255,
                        blue: Double(centerColor.b) / 255
                    ))
                    .frame(width: 20, height: 20)
                    .border(Color.white, width: 1)
                
                Text(colorHex)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Instructions
            Text("Click to select • Drag for zone")
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
        )
        .onAppear {
            startCapturing()
        }
        .onTapGesture {
            selectCurrentPixel()
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in
                    if !isZoneMode {
                        isZoneMode = true
                        onZoneStart()
                    }
                }
        )
    }
    
    private var colorHex: String {
        String(format: "#%02X%02X%02X", centerColor.r, centerColor.g, centerColor.b)
    }
    
    private func startCapturing() {
        // Use a timer to continuously update the magnified view
        Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { _ in
            updateMagnifiedView()
        }
    }
    
    private func updateMagnifiedView() {
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        
        // Convert to top-left coordinate system
        let point = Point(
            x: mouseLocation.x,
            y: screenHeight - mouseLocation.y
        )
        
        // Capture region around cursor
        let displayID = CGMainDisplayID()
        let captureRect = CGRect(
            x: point.x - Double(captureRadius),
            y: point.y - Double(captureRadius),
            width: Double(captureRadius * 2 + 1),
            height: Double(captureRadius * 2 + 1)
        )
        
        guard let image = CGDisplayCreateImage(displayID, rect: captureRect) else {
            return
        }
        
        magnifiedImage = image
        
        // Get center pixel color
        if let dataProvider = image.dataProvider,
           let data = dataProvider.data,
           let bytes = CFDataGetBytePtr(data) {
            let centerOffset = captureRadius * image.bytesPerRow + captureRadius * (image.bitsPerPixel / 8)
            centerColor = RGB(
                r: Int(bytes[centerOffset]),
                g: Int(bytes[centerOffset + 1]),
                b: Int(bytes[centerOffset + 2])
            )
        }
    }
    
    private func selectCurrentPixel() {
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        
        let point = Point(
            x: mouseLocation.x,
            y: screenHeight - mouseLocation.y
        )
        
        onPixelSelected(point, centerColor)
    }
}
```

## Zone Selector View

```swift
// UI/ZoneSelector.swift
import SwiftUI

struct ZoneSelectorView: View {
    let onZoneSelected: (Rect) -> Void
    let onCancel: () -> Void
    
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.3)
                
                // Selection rectangle
                if let start = startPoint, let current = currentPoint {
                    let rect = normalizedRect(from: start, to: current)
                    
                    // Dimmed area outside selection
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        path.addRect(rect)
                    }
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    
                    // Selection border
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Size label
                    Text("\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .position(x: rect.midX, y: rect.maxY + 20)
                }
                
                // Instructions
                VStack {
                    Text("Drag to select zone")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text("Press ESC to cancel")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .position(x: geometry.size.width / 2, y: 50)
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.startLocation
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        guard let start = startPoint else { return }
                        
                        let screenHeight = geometry.size.height
                        let rect = normalizedRect(from: start, to: value.location)
                        
                        // Convert to top-left coordinate system
                        let finalRect = Rect(
                            x: Double(rect.minX),
                            y: Double(rect.minY),  // Already in screen coords
                            width: Double(rect.width),
                            height: Double(rect.height)
                        )
                        
                        onZoneSelected(finalRect)
                    }
            )
            .onReceive(NotificationCenter.default.publisher(for: .zoneSelectionCancel)) { _ in
                onCancel()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: minX, y: minY, width: max(width, 1), height: max(height, 1))
    }
}

extension Notification.Name {
    static let zoneSelectionCancel = Notification.Name("zoneSelectionCancel")
}
```

## Time Input View

```swift
// UI/TimeInputView.swift
import SwiftUI

struct TimeInputView: View {
    let onComplete: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Enter delay (ms)")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            TextField("", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 24, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 120)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .focused($isFocused)
                .onSubmit {
                    if let ms = Int(inputText), ms > 0 {
                        onComplete(ms)
                    }
                }
                .onAppear {
                    isFocused = true
                }
            
            Text("Press Enter to confirm")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
        )
        .onReceive(NotificationCenter.default.publisher(for: .escapePressed)) { _ in
            onCancel()
        }
    }
}
```

## Global Event Monitor

For capturing clicks and keypresses outside the overlay:

```swift
// UI/GlobalEventMonitor.swift
import AppKit

class GlobalEventMonitor {
    private var monitor: Any?
    private let handler: (NSEvent) -> Void
    private let mask: NSEvent.EventTypeMask
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
        }
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    deinit {
        stop()
    }
}

// Usage in OverlayWindowController
extension OverlayWindowController {
    func startGlobalEventMonitoring() {
        // Monitor clicks for action recording
        let clickMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let position = Point(
                x: event.locationInWindow.x,
                y: screenHeight - event.locationInWindow.y
            )
            let button = event.type == .rightMouseDown ? "right" : "left"
            
            Task {
                await self.ipcHandler.sendEvent(MouseClickedEvent(
                    event: "mouseClicked",
                    data: ["position": position, "button": button]
                ))
            }
        }
        clickMonitor.start()
        
        // Monitor keypresses for action recording
        let keyMonitor = GlobalEventMonitor(mask: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            var modifiers: [String] = []
            if event.modifierFlags.contains(.command) { modifiers.append("cmd") }
            if event.modifierFlags.contains(.control) { modifiers.append("ctrl") }
            if event.modifierFlags.contains(.option) { modifiers.append("alt") }
            if event.modifierFlags.contains(.shift) { modifiers.append("shift") }
            
            let key = event.charactersIgnoringModifiers ?? ""
            
            Task {
                await self.ipcHandler.sendEvent(KeyPressedEvent(
                    event: "keyPressed",
                    data: ["key": key, "modifiers": modifiers]
                ))
            }
        }
        keyMonitor.start()
    }
}
```

## State Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Recording State Machine                           │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────┐
                              │   IDLE   │
                              └────┬─────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │ click Action       │ click Transition   │
              ▼                    │                    ▼
      ┌───────────────┐            │           ┌───────────────┐
      │ WAIT_ACTION   │            │           │ WAIT_TRANS    │
      └───────┬───────┘            │           └───────┬───────┘
              │                    │                   │
    ┌─────────┼─────────┐          │         ┌─────────┼─────────┐
    │ mouse   │ keyboard│          │         │ mouse   │ time    │
    ▼         ▼         │          │         ▼         ▼         │
 [click]   [keypress]   │          │    [magnifier] [time input] │
    │         │         │          │         │         │         │
    └────┬────┘         │          │         │         │         │
         │              │          │         │    ┌────┴────┐    │
         ▼              │          │         │    ▼         ▼    │
    Step Added ─────────┴──────────┴─────────┴── Step Added ─────┘
         │                                              │
         └────────────── Back to IDLE ◄─────────────────┘
```
