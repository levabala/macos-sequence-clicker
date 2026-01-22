import Foundation
import AppKit
import SwiftUI

/// Custom NSWindow subclass that can become key even when borderless.
/// This is required for borderless windows to receive keyboard and mouse events properly.
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Central controller for all overlay windows (recorder toolbar, magnifier, zone selector, time input).
/// This class manages window lifecycle and bridges SwiftUI views to NSWindows.
@MainActor
class OverlayWindowController: NSObject {
    
    // MARK: - Singleton
    
    static let shared = OverlayWindowController()
    
    // MARK: - Windows
    
    private var recorderWindow: NSWindow?
    private var magnifierWindow: NSWindow?
    private var zoneSelectorWindow: NSWindow?
    private var timeInputWindow: NSWindow?
    
    // MARK: - Event Monitors
    
    private var mouseMonitor: GlobalEventMonitor?
    private var keyboardMonitor: GlobalEventMonitor?
    
    // MARK: - State
    
    private var currentState: RecorderState = .idle
    private var currentSubState: RecorderSubState?
    private var isRecordingMouse: Bool = false
    private var isRecordingKeyboard: Bool = false
    
    // MARK: - Callbacks
    
    /// Callback for sending IPC events (set by IPCHandler)
    var onEvent: ((Encodable) async -> Void)?
    
    // MARK: - Screen Capture (for magnifier)
    
    private let screenCapture = ScreenCapture()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        Logger.log("Overlay", "OverlayWindowController initialized")
    }
    
    // MARK: - Recorder Overlay
    
    /// Show the main recorder toolbar overlay
    /// - Parameter position: Optional position, or defaults to center-top
    func showRecorderOverlay(at position: Point?) {
        Logger.log("Overlay", "showRecorderOverlay called with position: \(String(describing: position))")
        
        // Create window if needed
        if recorderWindow == nil {
            Logger.log("Overlay", "Creating new recorder window")
            let window = createOverlayWindow(
                size: CGSize(width: 360, height: 60),
                level: .floating
            )
            
            let view = RecorderOverlayView(
                state: currentState,
                subState: currentSubState,
                onIconClick: { [weak self] icon in
                    Logger.log("Overlay", "onIconClick callback triggered: \(icon)")
                    Task { await self?.handleIconClick(icon) }
                },
                onDragEnd: { [weak self] position in
                    Logger.log("Overlay", "onDragEnd callback triggered: \(position)")
                    Task { await self?.handleOverlayMoved(position) }
                },
                onClose: { [weak self] in
                    Logger.log("Overlay", "onClose callback triggered")
                    Task { await self?.handleOverlayClosed() }
                }
            )
            
            window.contentView = NSHostingView(rootView: view)
            recorderWindow = window
            Logger.log("Overlay", "Recorder window created")
        }
        
        guard let window = recorderWindow else {
            Logger.log("Overlay", "ERROR: recorderWindow is nil after creation")
            return
        }
        
        // Position window
        if let pos = position {
            window.setFrameOrigin(NSPoint(x: pos.x, y: pos.y))
            Logger.log("Overlay", "Window positioned at: \(pos)")
        } else {
            // Default to center-top of main screen
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = screen.frame.height - window.frame.height - 100
                window.setFrameOrigin(NSPoint(x: x, y: y))
                Logger.log("Overlay", "Window positioned at default: x=\(x), y=\(y)")
            }
        }
        
        window.makeKeyAndOrderFront(nil)
        Logger.log("Overlay", "Recorder window shown, isVisible: \(window.isVisible)")
    }
    
    /// Hide the recorder toolbar overlay
    func hideRecorderOverlay() {
        recorderWindow?.close()
        recorderWindow = nil
        stopAllMonitors()
    }
    
    /// Update the recorder state (affects which icons are enabled/active)
    func setRecorderState(_ state: RecorderState, subState: RecorderSubState?) {
        Logger.log("Overlay", "setRecorderState called: state=\(state), subState=\(String(describing: subState))")
        currentState = state
        currentSubState = subState
        
        // Update window content
        if let window = recorderWindow {
            Logger.log("Overlay", "Updating recorder window content")
            let view = RecorderOverlayView(
                state: state,
                subState: subState,
                onIconClick: { [weak self] icon in
                    Logger.log("Overlay", "onIconClick callback triggered: \(icon)")
                    Task { await self?.handleIconClick(icon) }
                },
                onDragEnd: { [weak self] position in
                    Logger.log("Overlay", "onDragEnd callback triggered: \(position)")
                    Task { await self?.handleOverlayMoved(position) }
                },
                onClose: { [weak self] in
                    Logger.log("Overlay", "onClose callback triggered")
                    Task { await self?.handleOverlayClosed() }
                }
            )
            window.contentView = NSHostingView(rootView: view)
        } else {
            Logger.log("Overlay", "WARNING: recorderWindow is nil, cannot update content")
        }
        
        // Manage monitors based on subState
        handleSubStateChange(subState)
    }
    
    // MARK: - Magnifier
    
    /// Show the magnifier window (follows cursor with 4x zoom)
    func showMagnifier() {
        if magnifierWindow == nil {
            let window = createOverlayWindow(
                size: CGSize(width: 140, height: 180),
                level: .floating
            )
            
            let view = MagnifierView(
                screenCapture: screenCapture,
                onPixelSelected: { [weak self] position, color in
                    Task { await self?.handlePixelSelected(position: position, color: color) }
                },
                onZoneStart: { [weak self] in
                    self?.startZoneSelection()
                }
            )
            
            window.contentView = NSHostingView(rootView: view)
            window.ignoresMouseEvents = false
            magnifierWindow = window
        }
        
        magnifierWindow?.makeKeyAndOrderFront(nil)
    }
    
    /// Hide the magnifier window
    func hideMagnifier() {
        magnifierWindow?.close()
        magnifierWindow = nil
    }
    
    // MARK: - Zone Selector
    
    /// Start zone selection mode (full-screen overlay with drag-to-select)
    private func startZoneSelection() {
        // Hide magnifier during zone selection
        hideMagnifier()
        
        guard let screen = NSScreen.main else { return }
        
        // Create full-screen window
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let view = ZoneSelectorView(
            screenSize: screen.frame.size,
            onZoneSelected: { [weak self] rect in
                Task { await self?.handleZoneSelected(rect) }
            },
            onCancel: { [weak self] in
                self?.cancelZoneSelection()
            }
        )
        
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        zoneSelectorWindow = window
    }
    
    /// Cancel zone selection and return to previous state
    private func cancelZoneSelection() {
        zoneSelectorWindow?.close()
        zoneSelectorWindow = nil
        
        // Re-show magnifier if in pixel sub-state
        if currentSubState == .pixel {
            showMagnifier()
        }
    }
    
    // MARK: - Time Input
    
    /// Show the time input popup for entering delay in milliseconds
    func showTimeInput() {
        if timeInputWindow == nil {
            let window = createOverlayWindow(
                size: CGSize(width: 250, height: 120),
                level: .floating
            )
            
            let view = TimeInputView(
                onComplete: { [weak self] ms in
                    Task { await self?.handleTimeInputCompleted(ms) }
                },
                onCancel: { [weak self] in
                    self?.hideTimeInput()
                }
            )
            
            window.contentView = NSHostingView(rootView: view)
            timeInputWindow = window
        }
        
        // Center on screen
        if let screen = NSScreen.main, let window = timeInputWindow {
            let x = (screen.frame.width - window.frame.width) / 2
            let y = (screen.frame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        timeInputWindow?.makeKeyAndOrderFront(nil)
    }
    
    /// Hide the time input popup
    func hideTimeInput() {
        timeInputWindow?.close()
        timeInputWindow = nil
    }
    
    // MARK: - Event Monitors Management
    
    private func handleSubStateChange(_ subState: RecorderSubState?) {
        Logger.log("Overlay", "handleSubStateChange: \(String(describing: subState))")
        stopAllMonitors()
        hideMagnifier()
        hideTimeInput()
        
        switch subState {
        case .mouse:
            Logger.log("Overlay", "Starting mouse monitor for subState .mouse")
            startMouseMonitor()
        case .keyboard:
            Logger.log("Overlay", "Starting keyboard monitor for subState .keyboard")
            startKeyboardMonitor()
        case .pixel:
            Logger.log("Overlay", "Showing magnifier for subState .pixel")
            showMagnifier()
        case .time:
            Logger.log("Overlay", "Showing time input for subState .time")
            showTimeInput()
        case .none:
            Logger.log("Overlay", "No subState, all monitors stopped")
            break
        }
    }
    
    private func startMouseMonitor() {
        Logger.log("Overlay", "startMouseMonitor called, existing monitor: \(mouseMonitor != nil)")
        guard mouseMonitor == nil else {
            Logger.log("Overlay", "Mouse monitor already exists, skipping")
            return
        }
        isRecordingMouse = true
        
        mouseMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else {
                Logger.log("Overlay", "Mouse event received but self is nil")
                return
            }
            
            Logger.log("Overlay", "Mouse event received: type=\(event.type.rawValue), window=\(event.window?.title ?? "nil")")
            
            // Ignore clicks on our own windows
            if event.window?.isEqual(self.recorderWindow) == true {
                Logger.log("Overlay", "Ignoring click on recorder window")
                return
            }
            if event.window?.isEqual(self.magnifierWindow) == true {
                Logger.log("Overlay", "Ignoring click on magnifier window")
                return
            }
            if event.window?.isEqual(self.zoneSelectorWindow) == true {
                Logger.log("Overlay", "Ignoring click on zone selector window")
                return
            }
            if event.window?.isEqual(self.timeInputWindow) == true {
                Logger.log("Overlay", "Ignoring click on time input window")
                return
            }
            
            let info = MouseEventInfo(from: event)
            Logger.log("Overlay", "Processing mouse click at position: \(info.position), button: \(info.button)")
            Task { @MainActor in
                await self.handleMouseClicked(position: info.position, button: info.button)
            }
        }
        mouseMonitor?.start()
        Logger.log("Overlay", "Mouse monitor started")
    }
    
    private func startKeyboardMonitor() {
        Logger.log("Overlay", "startKeyboardMonitor called, existing monitor: \(keyboardMonitor != nil)")
        guard keyboardMonitor == nil else {
            Logger.log("Overlay", "Keyboard monitor already exists, skipping")
            return
        }
        isRecordingKeyboard = true
        
        keyboardMonitor = GlobalEventMonitor(mask: [.keyDown]) { [weak self] event in
            guard let self = self else {
                Logger.log("Overlay", "Key event received but self is nil")
                return
            }
            
            Logger.log("Overlay", "Key event received: keyCode=\(event.keyCode)")
            
            // Skip modifier-only events
            guard let keyInfo = KeyEventInfo(from: event) else {
                Logger.log("Overlay", "Skipping modifier-only key event")
                return
            }
            
            // Skip Escape (used for canceling)
            if keyInfo.key == "escape" {
                Logger.log("Overlay", "Escape pressed, canceling recording")
                Task { @MainActor in
                    self.setRecorderState(self.currentState, subState: nil)
                }
                return
            }
            
            Logger.log("Overlay", "Processing key press: key=\(keyInfo.key), modifiers=\(keyInfo.modifiers)")
            Task { @MainActor in
                await self.handleKeyPressed(key: keyInfo.key, modifiers: keyInfo.modifiers)
            }
        }
        keyboardMonitor?.start()
        Logger.log("Overlay", "Keyboard monitor started")
    }
    
    private func stopAllMonitors() {
        Logger.log("Overlay", "stopAllMonitors called")
        mouseMonitor?.stop()
        mouseMonitor = nil
        isRecordingMouse = false
        
        keyboardMonitor?.stop()
        keyboardMonitor = nil
        isRecordingKeyboard = false
        Logger.log("Overlay", "All monitors stopped")
    }
    
    // MARK: - Event Handlers (send IPC events)
    
    private func handleIconClick(_ icon: OverlayIcon) async {
        Logger.log("Overlay", "handleIconClick: \(icon), onEvent is set: \(onEvent != nil)")
        let event = OverlayIconClickedEvent(icon: icon)
        await onEvent?(event)
        Logger.log("Overlay", "handleIconClick event sent")
    }
    
    private func handleOverlayMoved(_ position: Point) async {
        Logger.log("Overlay", "handleOverlayMoved: \(position)")
        let event = OverlayMovedEvent(position: position)
        await onEvent?(event)
    }
    
    private func handleOverlayClosed() async {
        Logger.log("Overlay", "handleOverlayClosed")
        hideRecorderOverlay()
        let event = OverlayClosedEvent()
        await onEvent?(event)
    }
    
    private func handleMouseClicked(position: Point, button: MouseButton) async {
        Logger.log("Overlay", "handleMouseClicked: position=\(position), button=\(button), onEvent is set: \(onEvent != nil)")
        let event = MouseClickedEvent(position: position, button: button)
        await onEvent?(event)
        Logger.log("Overlay", "handleMouseClicked event sent")
    }
    
    private func handleKeyPressed(key: String, modifiers: [KeyModifier]) async {
        Logger.log("Overlay", "handleKeyPressed: key=\(key), modifiers=\(modifiers), onEvent is set: \(onEvent != nil)")
        let event = KeyPressedEvent(key: key, modifiers: modifiers)
        await onEvent?(event)
        Logger.log("Overlay", "handleKeyPressed event sent")
    }
    
    private func handlePixelSelected(position: Point, color: RGB) async {
        Logger.log("Overlay", "handlePixelSelected: position=\(position), color=\(color)")
        hideMagnifier()
        let event = PixelSelectedEvent(position: position, color: color)
        await onEvent?(event)
    }
    
    private func handleZoneSelected(_ rect: Rect) async {
        Logger.log("Overlay", "handleZoneSelected: \(rect)")
        zoneSelectorWindow?.close()
        zoneSelectorWindow = nil
        let event = ZoneSelectedEvent(rect: rect)
        await onEvent?(event)
    }
    
    private func handleTimeInputCompleted(_ ms: Double) async {
        Logger.log("Overlay", "handleTimeInputCompleted: \(ms)ms")
        hideTimeInput()
        let event = TimeInputCompletedEvent(ms: ms)
        await onEvent?(event)
    }
    
    // MARK: - Window Factory
    
    private func createOverlayWindow(size: CGSize, level: NSWindow.Level) -> NSWindow {
        // Use KeyableWindow to ensure borderless window can receive events
        let window = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = level
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Critical: allow the window to receive mouse events
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        
        Logger.log("Overlay", "Created KeyableWindow: level=\(level.rawValue), canBecomeKey=\(window.canBecomeKey), canBecomeMain=\(window.canBecomeMain)")
        
        return window
    }
}
