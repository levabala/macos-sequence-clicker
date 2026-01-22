# Phase 7: Swift Recorder Overlay

## Goal
Build SwiftUI overlay windows for recording: toolbar, magnifier, and zone selector.

## Prerequisites
- Phase 2 complete (Swift IPC core)
- Phase 4 complete (Swift actions)

## Deliverables
- [ ] Floating recorder toolbar overlay
- [ ] Draggable toolbar with icon buttons
- [ ] Magnifier view (4x zoom) following cursor
- [ ] Zone selection overlay (click + drag)
- [ ] Global event monitoring for clicks/keypresses
- [ ] All UI events sent via IPC

---

## Tasks

### 7.1 Create Overlay Window Manager
Create `Sources/UI/OverlayWindowController.swift`:

```swift
class OverlayWindowController {
    private var recorderWindow: NSWindow?
    private var magnifierWindow: NSWindow?
    private var zoneSelectorWindow: NSWindow?
    private weak var ipcHandler: IPCHandler?
    
    func showRecorderOverlay(at position: Point?)
    func hideRecorderOverlay()
    func setRecorderState(_ state: String, subState: String?)
    func showMagnifier()
    func hideMagnifier()
}
```

Window configuration:
- `styleMask: [.borderless]`
- `level: .floating`
- `backgroundColor: .clear`
- `isOpaque: false`
- `collectionBehavior: [.canJoinAllSpaces, .stationary]`

### 7.2 Implement Recorder Toolbar
Create `Sources/UI/RecorderOverlayView.swift`:

```swift
struct RecorderOverlayView: View {
    let onIconClick: (String) -> Void
    let onDragEnd: (Point) -> Void
    let onClose: () -> Void
    
    @State private var state: RecorderState = .idle
    
    var body: some View {
        HStack(spacing: 12) {
            // Action status (●)
            IconButton(icon: "record.circle", label: "Action", 
                       isActive: state.isWaitingAction, activeColor: .red)
            
            // Transition status (→)
            IconButton(icon: "arrow.right", label: "Trans",
                       isActive: state.isWaitingTransition, activeColor: .red)
            
            Divider()
            
            // Mouse
            IconButton(icon: "cursorarrow.click", label: "Mouse",
                       isDisabled: state == .idle)
            
            // Keyboard
            IconButton(icon: "keyboard", label: "Key",
                       isDisabled: !state.canUseKeyboard)
            
            // Time
            IconButton(icon: "clock", label: "Time",
                       isDisabled: !state.canUseTime)
            
            Spacer()
            
            // Close
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.85)))
        .gesture(DragGesture().onEnded { onDragEnd(...) })
    }
}
```

State machine:
- `idle`: All icons gray except close
- `waitingAction`: Action icon red, mouse/keyboard enabled
- `waitingTransition`: Transition icon red, mouse/time enabled

### 7.3 Implement Magnifier View
Create `Sources/UI/MagnifierView.swift`:

```swift
struct MagnifierView: View {
    let onPixelSelected: (Point, RGB) -> Void
    let onZoneStart: () -> Void
    
    @State private var magnifiedImage: CGImage?
    @State private var centerColor: RGB
    
    let zoomLevel: CGFloat = 4
    let captureRadius: Int = 12  // 25x25 pixels
    let displaySize: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 4) {
            // Magnified image
            ZStack {
                Image(...)
                    .interpolation(.none)  // No smoothing
                
                // Crosshair
                CrosshairOverlay()
                
                // Center pixel highlight
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: zoomLevel, height: zoomLevel)
            }
            
            // Color info
            HStack {
                Rectangle().fill(Color(rgb: centerColor))
                Text("#RRGGBB")
            }
            
            Text("Click to select • Drag for zone")
        }
    }
}
```

Behavior:
- Window follows cursor with offset
- Continuous screen capture at ~30fps
- Click selects current pixel
- Drag starts zone selection

### 7.4 Implement Zone Selector
Create `Sources/UI/ZoneSelectorView.swift`:

```swift
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
                if let rect = selectionRect {
                    // Dimmed area outside (using eoFill)
                    // Selection border
                    // Size label
                }
            }
            .gesture(DragGesture()
                .onChanged { startPoint = ...; currentPoint = ... }
                .onEnded { onZoneSelected(rect) }
            )
        }
    }
}
```

### 7.5 Implement Time Input
Create `Sources/UI/TimeInputView.swift`:

```swift
struct TimeInputView: View {
    let onComplete: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            Text("Enter delay (ms)")
            TextField("", text: $inputText)
                .onSubmit {
                    if let ms = Int(inputText) {
                        onComplete(ms)
                    }
                }
        }
    }
}
```

### 7.6 Implement Global Event Monitor
Create `Sources/UI/GlobalEventMonitor.swift`:

```swift
class GlobalEventMonitor {
    private var monitor: Any?
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void)
    func start()
    func stop()
}
```

Monitor events:
- `.leftMouseDown`, `.rightMouseDown` - for click recording
- `.keyDown` - for keypress recording

Filter out:
- Clicks on the overlay itself
- Modifier-only key events

### 7.7 Add IPC Handlers
Update `Sources/IPC/IPCHandler.swift`:

Add handlers for:
- `showRecorderOverlay` → OverlayWindowController.show
- `hideRecorderOverlay` → OverlayWindowController.hide
- `setRecorderState` → Update toolbar state
- `showMagnifier` → Show magnifier window
- `hideMagnifier` → Hide magnifier window

### 7.8 Wire Up Event Emission
When recording:
- Click captured → Send `mouseClicked` event
- Key pressed → Send `keyPressed` event
- Pixel selected → Send `pixelSelected` event
- Zone selected → Send `zoneSelected` event
- Time entered → Send `timeInputCompleted` event
- Overlay moved → Send `overlayMoved` event
- Overlay closed → Send `overlayClosed` event

---

## Acceptance Criteria
- [ ] Recorder toolbar appears when requested
- [ ] Toolbar is draggable
- [ ] Icon states update correctly (idle/action/transition)
- [ ] Clicking icons sends IPC events
- [ ] Magnifier follows cursor
- [ ] Magnifier shows 4x zoom without interpolation
- [ ] Magnifier shows center pixel color
- [ ] Click in magnifier selects pixel
- [ ] Drag in magnifier starts zone selection
- [ ] Zone selector shows selection rectangle
- [ ] Zone selection sends correct rect
- [ ] Time input accepts numeric input
- [ ] Global clicks/keypresses are captured
- [ ] Overlay window doesn't capture its own clicks

---

## Files Created
```
swift-helper/Sources/UI/
├── OverlayWindowController.swift
├── RecorderOverlayView.swift
├── MagnifierView.swift
├── ZoneSelectorView.swift
├── TimeInputView.swift
└── GlobalEventMonitor.swift
```

## Testing Notes
- Test overlay positioning on multiple monitors
- Test drag behavior near screen edges
- Test magnifier at screen corners
- Test zone selection across the entire screen
- Verify overlay doesn't interfere with normal clicks

## Estimated Time: 8-10 hours
