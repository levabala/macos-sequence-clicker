import Foundation
import AppKit
import SwiftUI

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
    }
    
    // MARK: - Recorder Overlay
    
    /// Show the main recorder toolbar overlay
    /// - Parameter position: Optional position, or defaults to center-top
    func showRecorderOverlay(at position: Point?) {
        // Create window if needed
        if recorderWindow == nil {
            let window = createOverlayWindow(
                size: CGSize(width: 360, height: 60),
                level: .floating
            )
            
            let view = RecorderOverlayView(
                state: currentState,
                subState: currentSubState,
                onIconClick: { [weak self] icon in
                    Task { await self?.handleIconClick(icon) }
                },
                onDragEnd: { [weak self] position in
                    Task { await self?.handleOverlayMoved(position) }
                },
                onClose: { [weak self] in
                    Task { await self?.handleOverlayClosed() }
                }
            )
            
            window.contentView = NSHostingView(rootView: view)
            recorderWindow = window
        }
        
        guard let window = recorderWindow else { return }
        
        // Position window
        if let pos = position {
            window.setFrameOrigin(NSPoint(x: pos.x, y: pos.y))
        } else {
            // Default to center-top of main screen
            if let screen = NSScreen.main {
                let x = (screen.frame.width - window.frame.width) / 2
                let y = screen.frame.height - window.frame.height - 100
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        window.makeKeyAndOrderFront(nil)
    }
    
    /// Hide the recorder toolbar overlay
    func hideRecorderOverlay() {
        recorderWindow?.close()
        recorderWindow = nil
        stopAllMonitors()
    }
    
    /// Update the recorder state (affects which icons are enabled/active)
    func setRecorderState(_ state: RecorderState, subState: RecorderSubState?) {
        currentState = state
        currentSubState = subState
        
        // Update window content
        if let window = recorderWindow {
            let view = RecorderOverlayView(
                state: state,
                subState: subState,
                onIconClick: { [weak self] icon in
                    Task { await self?.handleIconClick(icon) }
                },
                onDragEnd: { [weak self] position in
                    Task { await self?.handleOverlayMoved(position) }
                },
                onClose: { [weak self] in
                    Task { await self?.handleOverlayClosed() }
                }
            )
            window.contentView = NSHostingView(rootView: view)
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
        stopAllMonitors()
        hideMagnifier()
        hideTimeInput()
        
        switch subState {
        case .mouse:
            startMouseMonitor()
        case .keyboard:
            startKeyboardMonitor()
        case .pixel:
            showMagnifier()
        case .time:
            showTimeInput()
        case .none:
            break
        }
    }
    
    private func startMouseMonitor() {
        guard mouseMonitor == nil else { return }
        isRecordingMouse = true
        
        mouseMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Ignore clicks on our own windows
            if event.window?.isEqual(self.recorderWindow) == true { return }
            if event.window?.isEqual(self.magnifierWindow) == true { return }
            if event.window?.isEqual(self.zoneSelectorWindow) == true { return }
            if event.window?.isEqual(self.timeInputWindow) == true { return }
            
            let info = MouseEventInfo(from: event)
            Task { @MainActor in
                await self.handleMouseClicked(position: info.position, button: info.button)
            }
        }
        mouseMonitor?.start()
    }
    
    private func startKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }
        isRecordingKeyboard = true
        
        keyboardMonitor = GlobalEventMonitor(mask: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Skip modifier-only events
            guard let keyInfo = KeyEventInfo(from: event) else { return }
            
            // Skip Escape (used for canceling)
            if keyInfo.key == "escape" {
                Task { @MainActor in
                    self.setRecorderState(self.currentState, subState: nil)
                }
                return
            }
            
            Task { @MainActor in
                await self.handleKeyPressed(key: keyInfo.key, modifiers: keyInfo.modifiers)
            }
        }
        keyboardMonitor?.start()
    }
    
    private func stopAllMonitors() {
        mouseMonitor?.stop()
        mouseMonitor = nil
        isRecordingMouse = false
        
        keyboardMonitor?.stop()
        keyboardMonitor = nil
        isRecordingKeyboard = false
    }
    
    // MARK: - Event Handlers (send IPC events)
    
    private func handleIconClick(_ icon: OverlayIcon) async {
        let event = OverlayIconClickedEvent(icon: icon)
        await onEvent?(event)
    }
    
    private func handleOverlayMoved(_ position: Point) async {
        let event = OverlayMovedEvent(position: position)
        await onEvent?(event)
    }
    
    private func handleOverlayClosed() async {
        hideRecorderOverlay()
        let event = OverlayClosedEvent()
        await onEvent?(event)
    }
    
    private func handleMouseClicked(position: Point, button: MouseButton) async {
        let event = MouseClickedEvent(position: position, button: button)
        await onEvent?(event)
    }
    
    private func handleKeyPressed(key: String, modifiers: [KeyModifier]) async {
        let event = KeyPressedEvent(key: key, modifiers: modifiers)
        await onEvent?(event)
    }
    
    private func handlePixelSelected(position: Point, color: RGB) async {
        hideMagnifier()
        let event = PixelSelectedEvent(position: position, color: color)
        await onEvent?(event)
    }
    
    private func handleZoneSelected(_ rect: Rect) async {
        zoneSelectorWindow?.close()
        zoneSelectorWindow = nil
        let event = ZoneSelectedEvent(rect: rect)
        await onEvent?(event)
    }
    
    private func handleTimeInputCompleted(_ ms: Double) async {
        hideTimeInput()
        let event = TimeInputCompletedEvent(ms: ms)
        await onEvent?(event)
    }
    
    // MARK: - Window Factory
    
    private func createOverlayWindow(size: CGSize, level: NSWindow.Level) -> NSWindow {
        let window = NSWindow(
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
        return window
    }
}
