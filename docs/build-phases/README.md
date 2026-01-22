# Build Phases

This directory contains the implementation plan broken into logical phases. Each phase builds on the previous ones and has clear deliverables.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 1: SCHEMA                                │
│                    TypeScript types → JSON Schema → Swift                   │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    │                                           │
                    ▼                                           ▼
┌───────────────────────────────────┐       ┌───────────────────────────────────┐
│       PHASE 2: SWIFT CORE         │       │    PHASE 3: CONTROLLER BRIDGE     │
│   IPC handler + permissions       │◄─────►│      Spawn Swift + typed IPC      │
└───────────────────┬───────────────┘       └───────────────────┬───────────────┘
                    │                                           │
                    ▼                                           ▼
┌───────────────────────────────────┐       ┌───────────────────────────────────┐
│      PHASE 4: SWIFT ACTIONS       │       │    PHASE 5: CONTROLLER STATE      │
│   Mouse, keyboard, screen cap     │       │   Scenarios, history, persistence │
└───────────────────┬───────────────┘       └───────────────────┬───────────────┘
                    │                                           │
                    ▼                                           ▼
┌───────────────────────────────────┐       ┌───────────────────────────────────┐
│      PHASE 7: SWIFT OVERLAY       │       │      PHASE 6: TERMINAL UI         │
│   Recorder toolbar, magnifier     │       │   3-column layout, vim navigation │
└───────────────────┬───────────────┘       └───────────────────┬───────────────┘
                    │                                           │
                    └─────────────────────┬─────────────────────┘
                                          │
                                          ▼
                    ┌───────────────────────────────────────────┐
                    │          PHASE 8: RECORDING               │
                    │   Connect UI ↔ Swift, capture events      │
                    └─────────────────────┬─────────────────────┘
                                          │
                                          ▼
                    ┌───────────────────────────────────────────┐
                    │          PHASE 9: EXECUTION               │
                    │   Play modal, run steps, abort            │
                    └─────────────────────┬─────────────────────┘
                                          │
                                          ▼
                    ┌───────────────────────────────────────────┐
                    │       PHASE 10: PREVIEW & POLISH          │
                    │   ASCII diagrams, delete/undo, errors     │
                    └───────────────────────────────────────────┘
```

## Phases

| Phase | Name | Description | Est. Time |
|-------|------|-------------|-----------|
| [1](PHASE_01_SCHEMA.md) | Schema & Types | Define shared types, setup codegen | 2-3 hrs |
| [2](PHASE_02_SWIFT_CORE.md) | Swift Core | IPC handler, permission checker | 3-4 hrs |
| [3](PHASE_03_CONTROLLER_BRIDGE.md) | Controller Bridge | Spawn Swift, typed communication | 3-4 hrs |
| [4](PHASE_04_SWIFT_ACTIONS.md) | Swift Actions | Mouse, keyboard, screen capture | 4-5 hrs |
| [5](PHASE_05_CONTROLLER_STATE.md) | Controller State | Stores, persistence, undo | 3-4 hrs |
| [6](PHASE_06_TERMINAL_UI.md) | Terminal UI | 3-column layout, vim navigation | 5-6 hrs |
| [7](PHASE_07_SWIFT_OVERLAY.md) | Swift Overlay | Recorder toolbar, magnifier | 8-10 hrs |
| [8](PHASE_08_RECORDING.md) | Recording | Connect UI to Swift, capture events | 5-6 hrs |
| [9](PHASE_09_EXECUTION.md) | Execution | Play modal, run scenarios | 4-5 hrs |
| [10](PHASE_10_PREVIEW_POLISH.md) | Preview & Polish | ASCII diagrams, error handling | 5-6 hrs |

**Total Estimated Time: ~45-55 hours**

## Dependencies

```
Phase 1 ─┬─► Phase 2 ─► Phase 4 ─► Phase 7 ─┐
         │                                   │
         └─► Phase 3 ─► Phase 5 ─► Phase 6 ─┼─► Phase 8 ─► Phase 9 ─► Phase 10
                                             │
                                             └─────────────────────────────────┘
```

**Critical path:** 1 → 2 → 4 → 7 → 8 → 9 → 10

**Can be parallelized:**
- Phases 2+3 (after Phase 1)
- Phases 4+5 (after their prerequisites)
- Phases 6+7 (after their prerequisites)

## How to Use

1. **Start with Phase 1** - Foundation for everything
2. **Work through in order** - Each phase has clear prerequisites
3. **Check acceptance criteria** - Don't move on until all boxes checked
4. **Test incrementally** - Each phase should be testable independently

## Quick Reference

### Files by Phase

| Phase | Schema | Swift | Controller |
|-------|--------|-------|------------|
| 1 | `src/types.ts`, `generate.ts` | - | - |
| 2 | - | `main.swift`, `IPC/*`, `Permissions/*` | - |
| 3 | - | - | `ipc/bridge.ts`, `ipc/protocol.ts` |
| 4 | - | `Actions/*` | - |
| 5 | - | - | `store/*` |
| 6 | - | - | `components/*`, `hooks/useVimNavigation.ts` |
| 7 | - | `UI/*` | - |
| 8 | - | - | `hooks/useRecording.ts` |
| 9 | - | - | `execution/*`, `components/PlayModal.tsx` |
| 10 | - | - | `components/StepPreview.tsx` (updates) |

### Key Technologies

- **Schema:** TypeScript, typescript-json-schema, quicktype
- **Swift:** Swift 5.9, SwiftUI, CoreGraphics, AppKit
- **Controller:** Bun, React, OpenTUI

## Checklist

- [x] Phase 1: Schema & Types
- [x] Phase 2: Swift Core
- [x] Phase 3: Controller Bridge
- [x] Phase 4: Swift Actions
- [x] Phase 5: Controller State
- [x] Phase 6: Terminal UI
- [x] Phase 7: Swift Overlay
- [x] Phase 8: Recording
- [x] Phase 9: Execution
- [x] Phase 10: Preview & Polish

---

## Implementation Notes

### Phase 1: Schema & Types (Completed)

**Files Created:**
```
schema/
├── package.json           # @sequencer/schema package
├── tsconfig.json          # TypeScript config
├── generate.ts            # Codegen script
├── src/
│   └── types.ts           # Source of truth (all TS types)
└── generated/
    ├── schema.json        # JSON Schema (1400+ lines)
    └── Types.swift        # Swift Codable types (648 lines)
```

**Key Findings:**

1. **quicktype limitations**: The `quicktype` CLI struggled with complex TypeScript union types and generic types like `IPCResponse<T>`. Solution: Generate Swift types directly in `generate.ts` with proper tagged union handling.

2. **Type discriminators**: All union types use a `type` or `event` field as discriminator:
   - `Step` union: discriminated by `type` ("click", "keypress", "delay", "pixel-state", "pixel-zone", "scenario-ref")
   - `IPCEvent` union: discriminated by `event` ("mouseClicked", "keyPressed", etc.)

3. **Swift compilation verification**: Added `swiftc -typecheck` step to catch Swift syntax errors during codegen.

4. **Types coverage**:
   - Primitives: `RGB`, `Point`, `Rect`
   - Actions: `ClickAction`, `KeypressAction`
   - Transitions: `DelayTransition`, `PixelStateTransition`, `PixelZoneTransition`
   - 11 IPC request types
   - 8 IPC event types
   - Generic response wrappers

**Commands:**
```bash
# Regenerate types after modifying schema/src/types.ts
cd schema && bun run generate

# Verify Swift compiles
swiftc -typecheck schema/generated/Types.swift
```

**Next Steps:** Phase 2 (Swift Core) and Phase 3 (Controller Bridge) can now proceed in parallel, both depending on the generated types.

### Phase 2: Swift Core (Completed)

**Files Created:**
```
swift-helper/
├── Package.swift               # Swift package manifest (macOS 13+)
└── Sources/
    ├── main.swift              # Entry point with RunLoop + async Task
    ├── Generated/
    │   └── Types.swift         # Copied from schema/generated/
    ├── IPC/
    │   ├── StdinReader.swift   # Async actor for reading JSON lines
    │   ├── StdoutWriter.swift  # Actor for thread-safe JSON output
    │   └── IPCHandler.swift    # Message dispatch and routing
    └── Permissions/
        └── PermissionChecker.swift  # AXIsProcessTrusted + CGDisplayCreateImage
```

**Key Findings:**

1. **Swift async main pattern**: Cannot use `@main` with top-level code. Instead, use top-level code with `Task { await ... }` and `RunLoop.main.run()` to keep the process alive.

2. **NSApplication for CLI**: Even command-line Swift apps need `NSApplication.shared` initialized if they will later show windows (recorder overlay). Using `.accessory` activation policy hides dock icon.

3. **Actor-based IPC**: Using Swift actors (`StdinReader`, `StdoutWriter`, `IPCHandler`) provides thread-safe async I/O without manual locking.

4. **Permission checking**:
   - Accessibility: `AXIsProcessTrusted()` from ApplicationServices
   - Screen Recording: Attempt `CGDisplayCreateImage` - returns nil if not permitted

5. **Error isolation**: Invalid JSON logged to stderr, doesn't crash. EOF causes clean exit.

6. **Generic constraints**: `IPCResponseSuccess<T>` requires `T: Codable`, not just `Encodable`.

**Test Commands:**
```bash
# Build
cd swift-helper && swift build -c release

# Test checkPermissions
echo '{"id":"1","method":"checkPermissions"}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"1","result":{"accessibility":false,"screenRecording":true}}

# Test void response
echo '{"id":"2","method":"showRecorderOverlay","params":{"position":null}}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"2"}

# Test invalid JSON (logs to stderr, no crash)
echo 'invalid' | .build/release/SequencerHelper

# Test EOF (clean exit)
echo '' | .build/release/SequencerHelper; echo "Exit: $?"
```

**Next Steps:** Phase 3 (Controller Bridge) can now spawn this binary and communicate via the IPC protocol. Phase 4 (Swift Actions) can add mouse/keyboard/screen implementations to the handler.

### Phase 3: Controller Bridge (Completed)

**Files Created:**
```
controller/
├── package.json               # @sequencer/controller package
├── tsconfig.json              # TypeScript config with bundler resolution
└── src/
    ├── index.ts               # Entry point / test harness
    ├── types/
    │   └── index.ts           # Re-exports from schema/src/types.ts
    └── ipc/
        ├── bridge.ts          # SwiftBridge class - subprocess + IPC
        └── protocol.ts        # Typed wrappers for all IPC methods
```

**Key Findings:**

1. **Bun subprocess spawning**: `Bun.spawn()` with `stdin/stdout/stderr: "pipe"` provides async streams. Using `getReader()` on stdout enables async iteration over chunks.

2. **Line buffering for JSON IPC**: Messages are newline-delimited JSON. Buffer partial chunks and split on `\n` to handle messages that span multiple reads.

3. **Request/Response correlation**: Each request has a unique `id` (nanoid). Responses include the same `id`. Pending requests stored in a `Map<string, PendingRequest>` with timeout handling.

4. **Event emission pattern**: Events from Swift (unsolicited messages with `event` field) are emitted via a simple listener map. Typed event callbacks for each event type.

5. **Clean shutdown**: Closing stdin and calling `process.kill()` properly terminates the Swift helper. Exit code 143 (128 + 15 = SIGTERM) is expected.

6. **Direct type imports**: Using relative imports from `../../../schema/src/types.ts` works with Bun's bundler resolution. No npm workspace needed.

7. **Concurrent requests work**: Multiple `Promise.all()` requests are correctly correlated by ID and resolved independently.

**Test Output:**
```
Starting controller...
Spawning Swift helper...
Swift helper started successfully

--- Testing checkPermissions ---
Permissions: { accessibility: false, screenRecording: true }
  Accessibility: NOT GRANTED
  Screen Recording: GRANTED

--- Testing concurrent requests ---
Concurrent requests completed:
  Request 1: { accessibility: false, screenRecording: true }
  Request 2: { accessibility: false, screenRecording: true }
  Request 3: { accessibility: false, screenRecording: true }

--- Testing showRecorderOverlay ---
showRecorderOverlay: Success (or stub)
hideRecorderOverlay: Success (or stub)

--- All tests passed ---

Stopping Swift helper...
Done
Swift helper exited with code: 143
```

**Commands:**
```bash
# Run controller
cd controller && bun run start

# Development mode with watch
cd controller && bun run dev
```

**Next Steps:** Phase 4 (Swift Actions) and Phase 5 (Controller State) can now proceed in parallel. Phase 4 adds mouse/keyboard/screen implementations to Swift. Phase 5 adds scenario storage and state management to the controller.

### Phase 4: Swift Actions (Completed)

**Files Created:**
```
swift-helper/Sources/
└── Actions/
    ├── MouseController.swift      # CGEvent-based click simulation
    ├── KeyboardController.swift   # CGEvent-based keypress with modifiers
    └── ScreenCapture.swift        # CGDisplayCreateImage pixel capture
```

**Files Modified:**
```
swift-helper/Sources/IPC/
└── IPCHandler.swift               # Wired up action handlers
controller/src/ipc/
└── protocol.ts                    # Updated wait functions to return boolean
```

**Key Findings:**

1. **CGEvent for input simulation**: Both mouse and keyboard use `CGEvent` with `.cghidEventTap` for posting events. This requires Accessibility permission but provides reliable cross-application input.

2. **macOS virtual key codes**: Key codes are not ASCII values. Used hardcoded `keyCodeMap` based on Carbon `kVK_*` constants. Letters a-z are not sequential (e.g., a=0, s=1, d=2, f=3).

3. **Modifier key handling**: Modifiers must be:
   - Set in `CGEventFlags` on the key event (for apps to see ⌘+C, etc.)
   - Optionally sent as separate keyDown/keyUp events (for modifier-only scenarios)

4. **CGImage pixel format detection**: `CGDisplayCreateImage` returns images with varying pixel formats. Must check `alphaInfo` to determine byte order:
   - `.premultipliedFirst`, `.first`, `.noneSkipFirst` → ARGB (skip byte 0)
   - Otherwise → RGBA or RGB (read bytes 0-2)

5. **Async polling for pixel waits**: Using `Task.sleep(nanoseconds:)` with 50ms polling interval. Returns `WaitResult { matched: Bool }` instead of void to indicate timeout vs success.

6. **Actor isolation**: All three controllers (`MouseController`, `KeyboardController`, `ScreenCapture`) are actors for thread safety, matching the existing `IPCHandler` pattern.

**Test Commands:**
```bash
# Build
cd swift-helper && swift build -c release

# Test click
echo '{"id":"1","method":"executeClick","params":{"position":{"x":100,"y":100},"button":"left"}}' | .build/release/SequencerHelper

# Test keypress with modifier
echo '{"id":"1","method":"executeKeypress","params":{"key":"c","modifiers":["cmd"]}}' | .build/release/SequencerHelper

# Test pixel color
echo '{"id":"1","method":"getPixelColor","params":{"position":{"x":100,"y":100}}}' | .build/release/SequencerHelper
# Output: {"success":true,"result":{"color":{"r":0,"g":0,"b":255}},"id":"1"}

# Test waitForPixelState (matching)
echo '{"id":"1","method":"waitForPixelState","params":{"position":{"x":100,"y":100},"color":{"r":0,"g":0,"b":255},"threshold":10,"timeoutMs":500}}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"1","result":{"matched":true}}

# Test waitForPixelState (timeout)
echo '{"id":"1","method":"waitForPixelState","params":{"position":{"x":100,"y":100},"color":{"r":255,"g":255,"b":255},"threshold":5,"timeoutMs":500}}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"1","result":{"matched":false}}
```

**Controller Integration Test:**
```
--- Testing getPixelColor ---
Pixel color at (100, 100): { b: 255, r: 0, g: 0 }

--- Testing waitForPixelState ---
waitForPixelState: matched

--- Testing waitForPixelState (timeout case) ---
waitForPixelState (expecting timeout): timed out
```

**Next Steps:** Phase 5 (Controller State) adds scenario storage and persistence. Phase 7 (Swift Overlay) can proceed in parallel to build the recorder UI that will use these actions.

### Phase 5: Controller State (Completed)

**Files Created:**
```
controller/src/store/
├── index.ts              # Re-exports all stores
├── persistence.ts        # JSON file I/O to ~/.config/macos-sequencer/
├── scenarios.ts          # CRUD operations for scenarios with auto-save
├── history.ts            # Undo stack for step deletions
├── recorder.ts           # State machine for recording/naming modes
└── settings.ts           # User preferences store

controller/src/
└── test-stores.ts        # Comprehensive test harness
```

**Data Files:**
```
~/.config/macos-sequencer/
├── scenarios.json        # Persisted scenarios (pretty-printed)
└── settings.json         # User settings (threshold, poll interval, overlay position)
```

**Key Findings:**

1. **Simple pub/sub pattern**: All stores use a lightweight subscribe/notify pattern without external dependencies. `Set<Listener>` for subscribers, manual `notify()` on state changes.

2. **Auto-save strategy**: Scenario mutations (create, update, delete, add step, remove step) trigger `autoSave()` automatically. No manual save required from UI.

3. **Undo architecture**: The `historyStore` wraps `scenariosStore.removeStep()` to capture the deleted step before removal. Undo re-inserts at the original index. Stack limited to 50 entries.

4. **Selection tracking**: `scenariosStore` tracks both `selectedScenarioId` and `selectedStepIndex`. Step selection resets when scenario changes. Selection adjusts automatically after step deletion.

5. **Recorder state machine**: Three states: `idle`, `recording`, `naming`. Clean transitions with guard checks to prevent invalid state changes.

6. **Bun file APIs**: Using `Bun.file()` with `.exists()` and `.text()` for reading, `Bun.write()` for writing. `mkdir -p` via `Bun.spawn()` for directory creation.

7. **Config directory**: Uses `os.homedir()` + `~/.config/macos-sequencer/` following XDG conventions. Files are human-readable JSON.

**Test Output:**
```
=== Testing Scenarios CRUD ===
Created scenario: 220m2dKy-NyLBueHTZNWF Test Scenario
After rename: Updated Scenario
Added delay step, steps count: 1
Added keypress after index 0:
  Steps: [ "delay", "keypress", "click" ]
After swapping 0 and 2:
  Steps: [ "click", "keypress", "delay" ]

=== Testing History/Undo ===
After deleting index 1:
  Steps: [ "click", "delay" ]
  Undo description: Restore deleted keypress cmd+a
After undo:
  Steps: [ "click", "keypress", "delay" ]

=== Testing Subscriptions ===
Total callback invocations: 3
After unsubscribe, callback count: 3
```

**Commands:**
```bash
# Run store tests
cd controller && bun run test:stores

# Check persisted data
cat ~/.config/macos-sequencer/scenarios.json
cat ~/.config/macos-sequencer/settings.json
```

**Next Steps:** Phase 6 (Terminal UI) can now build on these stores. Phase 7 (Swift Overlay) can proceed in parallel.

### Phase 6: Terminal UI (Completed)

**Files Created:**
```
controller/src/
├── components/
│   ├── index.ts              # Component re-exports
│   ├── App.tsx               # Main app shell with 3-column layout
│   ├── ScenarioList.tsx      # Scenario list with selection highlighting
│   ├── StepsViewer.tsx       # Steps list with step type coloring
│   ├── StepPreview.tsx       # Detailed step preview panel
│   └── StatusBar.tsx         # Keybinding hints and mode indicator
├── hooks/
│   ├── index.ts              # Hook re-exports
│   ├── useVimNavigation.ts   # Vim-style navigation state machine
│   └── useStoreSubscription.ts  # React hook for store reactivity
├── opentui.d.ts              # JSX type declarations for OpenTUI
└── index.tsx                 # Updated entry point with UI rendering
```

**Dependencies Added:**
```json
{
  "@opentui/core": "^0.1.74",
  "@opentui/react": "^0.1.74",
  "react": "^19.2.3",
  "@types/react": "^19.2.9",
  "bun-types": "^1.3.6"
}
```

**Key Findings:**

1. **OpenTUI React integration**: OpenTUI provides React components (`box`, `text`, `input`, etc.) that render to terminal. Uses `createCliRenderer()` and `createRoot()` similar to React DOM.

2. **JSX type conflicts**: OpenTUI's JSX elements (especially `text`) conflict with React's SVG types since both define `text` in JSX.IntrinsicElements. Workaround: Use module augmentation in `opentui.d.ts`. TypeScript shows errors but Bun runtime works correctly.

3. **Direct props vs style prop**: OpenTUI supports both direct props (`<text fg="#00FF00">`) and style prop (`<box style={{ flexDirection: "column" }}>`). Direct props are more type-safe with current definitions.

4. **useKeyboard hook**: OpenTUI provides `useKeyboard((key) => {...})` for terminal input handling. Key events include `name`, `sequence`, `ctrl`, `meta`, `shift` properties.

5. **Store-to-UI reactivity**: Custom `useStoreSubscription` hook bridges the non-React stores to React components. Uses `useState` + `useEffect` with store's `subscribe()` method.

6. **Vim navigation state**: Navigation is handled via column state (0=scenarios, 1=steps, 2=preview) with h/j/k/l movement. Ctrl+l/h for entering/exiting sub-contexts.

7. **Permission flow**: App checks permissions on startup via Swift helper, displays warning if missing, and allows user to continue anyway (some features may not work).

**Layout Structure:**
```
┌─────────────────────────────────────────────────────────────────┐
│                      macOS Smart Sequencer                       │
├─────────────────┬─────────────────────┬─────────────────────────┤
│   Scenarios     │       Steps         │        Preview          │
│   (25%)         │       (35%)         │        (40%)            │
│                 │                     │                         │
│ > Scenario 1    │ > 1. Click L (x,y)  │  Click Action           │
│   Scenario 2    │   2. Key ⌘S         │  Button: left           │
│   Scenario 3 *  │   3. Delay 500ms    │  Position: (100, 200)   │
│                 │                     │                         │
├─────────────────┴─────────────────────┴─────────────────────────┤
│ h/l: columns | j/k: rows | C-l: select | d: delete | q: quit    │
│ [Scenarios] | Steps | Preview                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Keybindings:**
- `h`/`l` - Move between columns
- `j`/`k` - Move up/down within column
- `Ctrl+l` - Select/enter (move right and select)
- `Ctrl+h` - Back (move left)
- `Ctrl+j`/`Ctrl+k` - Swap steps up/down (in steps column)
- `c` - Create new scenario
- `n` - Rename selected scenario
- `d` - Delete selected step
- `u` - Undo last deletion
- `q` - Quit

**Commands:**
```bash
# Run the terminal UI
cd controller && bun run start

# Development mode with watch
cd controller && bun run dev
```

**Known Limitations:**

1. TypeScript errors for OpenTUI JSX elements due to React type conflicts (code runs correctly)
2. Recording (`r`) and playback (`p`) show placeholder messages (implemented in Phases 7-9)
3. Step preview is text-only (ASCII diagrams added in Phase 10)

**Next Steps:** Phase 7 (Swift Overlay) builds the SwiftUI recorder toolbar and magnifier. Phase 8 connects the UI to Swift for recording. Both depend on this phase.

### Phase 7: Swift Overlay (Completed)

**Files Created:**
```
swift-helper/Sources/UI/
├── GlobalEventMonitor.swift      # NSEvent monitoring for clicks/keypresses
├── OverlayWindowController.swift # Central window manager (singleton)
├── RecorderOverlayView.swift     # Draggable toolbar with icon buttons
├── MagnifierView.swift           # 4x zoom pixel selector with crosshair
├── ZoneSelectorView.swift        # Full-screen rectangle selection
└── TimeInputView.swift           # Delay input popup with presets
```

**Files Modified:**
```
swift-helper/Sources/IPC/
└── IPCHandler.swift              # Wired up overlay IPC methods
```

**Key Findings:**

1. **@MainActor for UI**: All overlay window operations must run on the main actor. Using `@MainActor` class annotation for `OverlayWindowController` and `await MainActor.run {}` blocks in IPCHandler for UI calls.

2. **NSWindow configuration for overlays**: Floating windows require specific configuration:
   - `styleMask: [.borderless]` - No title bar
   - `level: .floating` - Above normal windows
   - `backgroundColor: .clear` and `isOpaque: false` - Transparent background
   - `collectionBehavior: [.canJoinAllSpaces, .stationary]` - Visible on all spaces

3. **SwiftUI in NSWindow**: Using `NSHostingView(rootView:)` to embed SwiftUI views in NSWindow. Window content can be replaced by re-creating the hosting view with new state.

4. **Global event monitoring**: `NSEvent.addGlobalMonitorForEvents()` requires Accessibility permission. Also need local monitor (`addLocalMonitorForEvents`) for events in own windows.

5. **Coordinate system conversion**: macOS uses bottom-left origin, but CGEvent uses top-left. Convert with `screenHeight - y` when sending positions to controller.

6. **Timer-based magnifier update**: Using `Timer.scheduledTimer` at 30fps for cursor tracking. Screen capture is async but window position updates are sync on main actor.

7. **Event emission pattern**: UI events (clicks, keypresses, pixel selection) are sent as unsolicited JSON messages to stdout via `StdoutWriter.writeEvent()`.

8. **State machine for recorder**: `RecorderState` (idle/action/transition) and `RecorderSubState` (mouse/keyboard/time/pixel) control which UI elements are shown and which monitors are active.

**IPC Methods Implemented:**
- `showRecorderOverlay` - Shows draggable toolbar at position
- `hideRecorderOverlay` - Hides toolbar and stops all monitors
- `setRecorderState` - Updates toolbar state and shows appropriate sub-views
- `showMagnifier` - Shows cursor-following magnifier
- `hideMagnifier` - Hides magnifier

**Events Emitted:**
- `overlayIconClicked` - When toolbar icon is clicked
- `mouseClicked` - When global mouse click captured
- `keyPressed` - When global keypress captured
- `pixelSelected` - When pixel selected in magnifier
- `zoneSelected` - When zone selection completed
- `timeInputCompleted` - When delay entered
- `overlayMoved` - When toolbar dragged
- `overlayClosed` - When close button clicked

**Test Commands:**
```bash
# Build
cd swift-helper && swift build -c release

# Test showRecorderOverlay
echo '{"id":"1","method":"showRecorderOverlay","params":{"position":null}}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"1"}

# Test setRecorderState
echo '{"id":"2","method":"setRecorderState","params":{"state":"action","subState":"mouse"}}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"2"}

# Test showMagnifier
echo '{"id":"3","method":"showMagnifier"}' | .build/release/SequencerHelper
# Output: {"success":true,"id":"3"}
```

**Known Limitations:**

1. Magnifier window finding uses size heuristic (may need refinement if multiple similar windows)
2. Zone selector keyboard monitor leaks (should use dedicated instance)
3. Global event monitors require Accessibility permission - UI appears but events won't be captured without it

**Next Steps:** Phase 8 (Recording) connects the Terminal UI to these overlay controls. The controller will orchestrate the recording flow: show overlay → set state → capture events → add steps to scenario.

### Phase 8: Recording Integration (Completed)

**Files Created:**
```
controller/src/hooks/
└── useRecording.ts          # Recording hook with event handling
```

**Files Modified:**
```
controller/src/
├── hooks/
│   └── index.ts              # Added useRecording export
├── components/
│   ├── App.tsx               # Integrated recording flow
│   ├── ScenarioList.tsx      # Naming mode display with cursor
│   └── StatusBar.tsx         # Recording/naming mode indicators
```

**Key Findings:**

1. **Recording state machine**: Recording has three states:
   - `idle` - Normal operation, vim navigation enabled
   - `naming` - Creating new scenario, capturing text input for name
   - `recording` - Capturing actions from Swift overlay

2. **Event listener lifecycle**: Using `useEffect` cleanup properly is critical. Event listeners must be attached when entering recording mode and removed when exiting to prevent memory leaks and duplicate handlers.

3. **Overlay state tracking**: The overlay has its own state (`action`/`transition` mode with sub-states). This must be tracked in a ref to properly handle incoming events (e.g., only capture clicks when in action/mouse mode).

4. **Two-step zone selection**: `pixel-zone` steps require two user interactions:
   - First: Select the zone rectangle (fires `zoneSelected` event)
   - Then: Select the target color with magnifier (fires `pixelSelected` event)
   The pending zone is stored in a ref and combined with the color to create the step.

5. **Step insertion logic**: New steps are inserted after the currently selected step. After insertion, the `insertAfterIndex` is updated to point to the new step so subsequent steps are added in order.

6. **UI feedback**: Recording state is shown with:
   - Red `●` indicator next to recording scenario name
   - Green background with `█` cursor during naming
   - Status bar shows mode-specific keybinding hints

7. **Graceful quit handling**: When quitting during recording, the overlay is hidden first to ensure clean shutdown.

**Recording Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                         Press 'r'                                │
├─────────────────────────┬───────────────────────────────────────┤
│  No scenario selected   │     Scenario selected                  │
│           ↓             │            ↓                           │
│  Create new scenario    │     Start recording                    │
│           ↓             │            ↓                           │
│  Enter NAMING mode      │     Show overlay                       │
│  (type name + Enter)    │            ↓                           │
│           ↓             │     Wait for events from Swift         │
│  Start recording        │            ↓                           │
│           ↓             │     mouseClicked → ClickAction         │
│       (same) ─────────────────► keyPressed → KeypressAction      │
│                         │     pixelSelected → PixelStateTransition│
│                         │     zoneSelected + pixelSelected →      │
│                         │         PixelZoneTransition             │
│                         │     timeInputCompleted →                │
│                         │         DelayTransition                 │
├─────────────────────────┴───────────────────────────────────────┤
│                   Press 'r' or ESC to stop                       │
│                         ↓                                        │
│                 Hide overlay, return to idle                     │
└─────────────────────────────────────────────────────────────────┘
```

**Keybindings:**

| Key | Idle Mode | Naming Mode | Recording Mode |
|-----|-----------|-------------|----------------|
| `r` | Toggle recording | - | Stop recording |
| `c` | Create + name scenario | - | - |
| `n` | Rename scenario | - | - |
| `Enter` | - | Confirm name, start recording | - |
| `ESC` | - | Cancel naming, delete scenario | Stop recording |
| `Backspace` | - | Delete character | - |
| `a-z, 0-9` | - | Append to name | - |

**Test Commands:**
```bash
# Run the controller
cd controller && bun run start

# Test flow:
# 1. Press 'c' to create new scenario
# 2. Type a name, press Enter
# 3. Overlay appears - use it to capture actions
# 4. Press 'r' to stop recording
# 5. Steps should appear in the Steps column
```

**Known Limitations:**

1. Overlay state is tracked in a ref, not synced bidirectionally - if Swift overlay state changes unexpectedly, controller won't know
2. No visual feedback in terminal when actions are captured (steps appear silently)
3. Requires Accessibility permission for event capture - overlay shows but events won't work without it

**Next Steps:** Phase 9 (Execution) will implement scenario playback. Phase 10 will add ASCII diagrams in preview and polish error handling.

### Phase 9: Execution (Completed)

**Files Created:**
```
controller/src/
├── execution/
│   ├── index.ts              # Module exports
│   └── executor.ts           # Execution engine with progress tracking
└── components/
    ├── PlayModal.tsx         # Modal with hotkey capture and progress
    └── ProgressBar.tsx       # Unicode block progress bar
```

**Files Modified:**
```
controller/src/
├── components/
│   ├── App.tsx               # Integrated PlayModal with 'p' key
│   ├── StatusBar.tsx         # Added EXECUTING mode indicator
│   └── index.ts              # Added new component exports
└── opentui.d.ts              # Extended box/text props for modal positioning
```

**Key Findings:**

1. **Hotkey capture pattern**: The PlayModal uses a two-phase flow:
   - Phase 1 (`capture`): User presses any key/combo to set as trigger
   - Phase 2 (`ready`): Waiting for user to press the trigger key again
   This allows the user to switch to another app before execution starts.

2. **AbortController for cancellation**: Using standard `AbortController` and `AbortSignal` for clean cancellation. The `abortableSleep()` helper wraps `setTimeout` with abort listener to enable delay cancellation.

3. **Recursive sub-scenario execution**: The executor tracks visited scenario IDs to prevent infinite recursion from circular references. The visited set is cleared after each scenario completes to allow the same scenario to be called multiple times in sequence.

4. **Progress tracking with refs**: Using `{ count: number }` object ref for `executedSteps` allows the nested recursive calls to share and update the same counter, providing accurate progress across sub-scenarios.

5. **Total step counting**: `countTotalSteps()` recursively counts steps including sub-scenarios before execution starts, enabling accurate progress bar display.

6. **Overlay hidden during execution**: Before starting execution, `hideRecorderOverlay()` is called to ensure the Swift overlay doesn't interfere with the automated actions.

7. **Auto-close on success**: After successful completion, the modal auto-closes after 1.5 seconds, providing brief visual confirmation before returning to normal UI.

8. **Key matching for trigger**: The `keysMatch()` function compares both the key name and all modifier flags (ctrl, meta, shift, alt) to ensure the trigger fires only on exact match.

**Execution Flow:**

```
┌───────────────────────────────────────────────────────────────────┐
│                      Press 'p' (scenario selected)                 │
│                               ↓                                    │
│                 ┌─────────────────────────────┐                    │
│                 │   PlayModal opens           │                    │
│                 │   "Press a key to set       │                    │
│                 │    trigger..."              │                    │
│                 └─────────────────────────────┘                    │
│                               ↓                                    │
│                    User presses e.g. F5                            │
│                               ↓                                    │
│                 ┌─────────────────────────────┐                    │
│                 │   "Press F5 to execute"     │                    │
│                 │   (user can switch apps)    │                    │
│                 └─────────────────────────────┘                    │
│                               ↓                                    │
│                    User presses F5 again                           │
│                               ↓                                    │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Hide overlay → Execute steps sequentially → Update progress│   │
│  │                                                              │   │
│  │  For each step:                                              │   │
│  │    click      → ipc.executeClick()                           │   │
│  │    keypress   → ipc.executeKeypress()                        │   │
│  │    delay      → abortableSleep()                             │   │
│  │    pixel-*    → ipc.waitForPixel*() (status: "waiting")      │   │
│  │    scenario-ref → executeScenario() (recursive)              │   │
│  └────────────────────────────────────────────────────────────┘   │
│                               ↓                                    │
│                 ┌─────────────────────────────┐                    │
│                 │   "Completed successfully!" │                    │
│                 │   (auto-close after 1.5s)   │                    │
│                 └─────────────────────────────┘                    │
└───────────────────────────────────────────────────────────────────┘

ESC at any point → Abort execution → "Aborted by user"
```

**Modal States:**

| Phase | Display | User Action |
|-------|---------|-------------|
| `capture` | "Press a key combination..." | Any key sets trigger |
| `ready` | "Press {hotkey} to execute" | Trigger key starts, ESC cancels |
| `executing` | Progress bar + status | ESC aborts |
| `done` | "Completed!" or error | Any key or auto-close |

**Test Commands:**
```bash
# Run the controller
cd controller && bun run start

# Test flow:
# 1. Select scenario with steps
# 2. Press 'p' to open play modal
# 3. Press any key (e.g., F5) to set trigger
# 4. Switch to target application
# 5. Press trigger key (F5) to start execution
# 6. Watch progress bar update
# 7. Press ESC during execution to abort

# Or to test abort:
# 1. Select scenario with delay step (e.g., 5000ms)
# 2. Press 'p', set trigger, press trigger
# 3. During delay, press ESC
# 4. Should show "Aborted by user"
```

**Known Limitations:**

1. TypeScript errors persist for `text` elements due to React SVG type conflicts (runtime works correctly)
2. No timeout for pixel wait conditions (relies on user abort or optional `timeoutMs` in step)
3. Modal positioning uses `position: absolute` with `top/left: 50%` - may not center perfectly in all terminal sizes
4. Sub-scenario progress counts may jump if sub-scenario has many steps

**Next Steps:** Phase 10 (Preview & Polish) will add ASCII diagrams to the step preview, improve error handling, and implement step deletion with undo confirmation.

### Phase 10: Preview & Polish (Completed)

**Files Modified:**
```
controller/src/
├── components/
│   ├── StepPreview.tsx           # Added ASCII diagrams for positions/zones
│   ├── App.tsx                   # Sub-scenario title indicator
│   └── StepsViewer.tsx           # Sub-scenario breadcrumb indicator
├── hooks/
│   └── useVimNavigation.ts       # Added sub-scenario depth tracking
└── store/
    └── recorder.ts               # Added initialName support for rename
```

**Key Findings:**

1. **ASCII diagram rendering**: Created `ScreenPositionDiagram` and `ScreenZoneDiagram` components that render 28x12 character ASCII boxes showing pixel positions and zones. Uses Unicode box-drawing characters (┌─┐│└┘) and block elements (× ░ █) for visualization.

2. **Coordinate scaling**: Screen coordinates (assumed 1920x1080) are scaled to diagram coordinates using:
   ```typescript
   const px = Math.round((x / 1920) * (DIAG_W - 1));
   const py = Math.round((y / 1080) * (DIAG_H - 1));
   ```
   With clamping to ensure markers stay within diagram bounds.

3. **Color display**: Using Unicode full block character (█) with `fg={hexColor}` to show colored swatches inline with hex values.

4. **Scenario rename pre-fill**: Modified `recorderStore.startNaming()` to accept optional `initialName` parameter. When pressing `n` to rename, the existing scenario name is pre-filled for editing.

5. **Sub-scenario navigation with depth stack**: Added `scenarioDepth: string[]` state to track navigation history. When entering a scenario-ref step:
   - Push current scenario ID to depth stack
   - Select referenced scenario
   - Show "[Sub] Ctrl+H to exit" indicator
   
   When pressing Ctrl+H:
   - Pop from depth stack
   - Select parent scenario
   - Reset step selection

6. **TypeScript strict mode issues**: Many existing files had potential `undefined` vs `null` mismatches that TypeScript catches. Bun runtime is more lenient but these should be addressed in a future cleanup.

7. **Delete/Undo already implemented**: Phases 5-6 already implemented `d` for delete and `u` for undo - no additional work needed.

**ASCII Diagram Examples:**

Position diagram (click/pixel-state):
```
┌────────────────────────────┐
│                            │
│                            │
│        ×                   │
│                            │
│                            │
│                            │
│                            │
│                            │
│                            │
│                            │
│                            │
└────────────────────────────┘
Target: ████ #FF5500
```

Zone diagram (pixel-zone):
```
┌────────────────────────────┐
│                            │
│                            │
│    ░░░░░░                  │
│    ░░░░░░                  │
│    ░░░░░░                  │
│                            │
│                            │
│                            │
│                            │
│                            │
│                            │
└────────────────────────────┘
Target: ████ #00FF00
```

**Sub-scenario Navigation Flow:**

```
┌───────────────────────────────────────────────────────────────┐
│ Steps column with scenario-ref selected                        │
│                                                                │
│   1. Click L (100, 200)                                       │
│ > 2. -> [Login Flow]     ← Press Ctrl+L to enter              │
│   3. Delay 500ms                                              │
└───────────────────────────────────────────────────────────────┘
                              ↓ Ctrl+L
┌───────────────────────────────────────────────────────────────┐
│ Steps (sub) ← Title shows "(sub)"                             │
│                                                                │
│ [Sub] Ctrl+H to exit    ← Breadcrumb indicator                │
│ > 1. Click L (400, 100)                                       │
│   2. Key ⌘⇧P                                                  │
│   3. Pixel (600, 300)                                         │
└───────────────────────────────────────────────────────────────┘
                              ↓ Ctrl+H
┌───────────────────────────────────────────────────────────────┐
│ Steps                                                          │
│                                                                │
│   1. Click L (100, 200)                                       │
│ > 2. -> [Login Flow]     ← Back to parent, selection reset    │
│   3. Delay 500ms                                              │
└───────────────────────────────────────────────────────────────┘
```

**Edge Cases Handled:**

1. **Empty scenario** - Shows "No steps" with hint to record
2. **Invalid scenario-ref** - Shows warning in preview, Ctrl+L does nothing
3. **Long scenario names** - Truncated to 15 chars + "..."
4. **Permissions missing** - App continues with warning, features gracefully degrade
5. **Out-of-bounds diagram coordinates** - Clamped to diagram edges

**Commands:**
```bash
# Run the controller
cd controller && bun run start

# Test sub-scenario navigation:
# 1. Create scenario with a scenario-ref step
# 2. Navigate to steps column, select the ref step
# 3. Press Ctrl+L to enter the sub-scenario
# 4. Press Ctrl+H to return to parent
```

**Known Limitations:**

1. TypeScript strict mode violations in stores (undefined vs null)
2. ASCII diagrams assume 1920x1080 screen resolution
3. No visual feedback when entering/exiting sub-scenarios (just column title change)
4. Scenario name cursor position fixed at end during rename

**Project Complete!** All 10 phases have been implemented. The macOS Smart Sequencer is now a functional automation tool with:
- Terminal UI with vim-style navigation
- Recording of clicks, keypresses, and pixel conditions
- Scenario playback with progress tracking
- Sub-scenario composition and navigation
- ASCII visualization of screen positions and zones
- Undo support for step deletions
- Persistent storage in ~/.config/macos-sequencer/
