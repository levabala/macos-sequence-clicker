# Phase 4: Swift Action Controllers

## Goal
Implement macOS native actions: mouse clicks, keyboard input, and screen capture.

## Prerequisites
- Phase 2 complete (Swift IPC working)
- macOS permissions granted (Accessibility, Screen Recording)

## Deliverables
- [ ] Mouse click simulation (left/right)
- [ ] Keyboard input simulation with modifiers
- [ ] Single pixel color capture
- [ ] Pixel zone scanning
- [ ] Pixel state/zone waiting with polling
- [ ] All actions accessible via IPC

---

## Tasks

### 4.1 Implement Mouse Controller
Create `Sources/Actions/MouseController.swift`:

```swift
actor MouseController {
    func click(at point: Point, button: String) throws
    func moveTo(point: Point)
    func getCurrentPosition() -> Point
}
```

Implementation details:
- Use `CGEvent` for mouse events
- Convert between coordinate systems (top-left vs bottom-left)
- Support left/right click via `CGMouseButton`
- Post events to `.cghidEventTap`

### 4.2 Implement Keyboard Controller
Create `Sources/Actions/KeyboardController.swift`:

```swift
actor KeyboardController {
    func press(key: String, modifiers: [String]) throws
}
```

Implementation details:
- Key code mapping (a-z, 0-9, special keys, F1-F12)
- Modifier handling (cmd, ctrl, alt, shift)
- Press modifiers → press key → release key → release modifiers
- Use `CGEvent` for keyboard events

### 4.3 Implement Screen Capture
Create `Sources/Actions/ScreenCapture.swift`:

```swift
actor ScreenCapture {
    func getPixelColor(at point: Point) throws -> RGB
    func checkPixelState(at point: Point, expectedColor: RGB, threshold: Double) throws -> Bool
    func checkPixelZone(rect: Rect, expectedColor: RGB, threshold: Double) throws -> Bool
    func waitForPixelState(...) async throws -> Bool
    func waitForPixelZone(...) async throws -> Bool
    func captureRegion(around point: Point, radius: Int) throws -> CGImage
}
```

Implementation details:
- `CGDisplayCreateImage` for screen capture
- Pixel data extraction from `CGImage`
- Euclidean RGB distance: `sqrt((r1-r2)² + (g1-g2)² + (b1-b2)²)`
- Polling loop with configurable interval (default 50ms)
- Timeout handling

### 4.4 Add IPC Handlers
Update `Sources/IPC/IPCHandler.swift`:

Add handlers for:
- `executeClick` → MouseController.click
- `executeKeypress` → KeyboardController.press
- `getPixelColor` → ScreenCapture.getPixelColor
- `waitForPixelState` → ScreenCapture.waitForPixelState
- `waitForPixelZone` → ScreenCapture.waitForPixelZone

### 4.5 Test Actions via IPC
Test each action from command line:

```bash
# Test click
echo '{"id":"1","method":"executeClick","params":{"position":{"x":100,"y":100},"button":"left"}}' | .build/release/SequencerHelper

# Test keypress
echo '{"id":"1","method":"executeKeypress","params":{"key":"a","modifiers":["cmd"]}}' | .build/release/SequencerHelper

# Test pixel color
echo '{"id":"1","method":"getPixelColor","params":{"position":{"x":100,"y":100}}}' | .build/release/SequencerHelper
```

### 4.6 Integration Test from Controller
Update `controller/src/index.tsx` to test:
```typescript
// Test click (clicks at position)
await ipc.executeClick({ x: 500, y: 500 }, 'left');

// Test pixel color
const color = await ipc.getPixelColor({ x: 100, y: 100 });
console.log('Pixel color:', color);
```

---

## Acceptance Criteria
- [ ] Click at specific coordinates works
- [ ] Right-click works
- [ ] Keypress with modifiers works (test ⌘+C)
- [ ] Single character keypress works
- [ ] Pixel color returns correct RGB values
- [ ] Pixel state wait completes when condition met
- [ ] Pixel state wait times out when condition not met
- [ ] Zone scan finds target color if present
- [ ] All errors are properly returned via IPC

---

## Files Created/Modified
```
swift-helper/Sources/
├── Actions/
│   ├── MouseController.swift    (new)
│   ├── KeyboardController.swift (new)
│   └── ScreenCapture.swift      (new)
└── IPC/
    └── IPCHandler.swift         (modified - add handlers)
```

## Testing Notes
- Test clicks on a specific UI element (e.g., menu bar)
- Test keypresses in a text editor
- Test pixel color on a known colored area
- Test pixel wait on a button hover state change

## Estimated Time: 4-5 hours
