# AGENTS.md - Developer Guide for macOS Smart Sequencer

## Project Overview

**macOS Smart Sequencer** is a two-part automation tool for recording and replaying UI interaction sequences on macOS. It consists of:

1. **Bun Controller** - Terminal UI (TypeScript/React/OpenTUI) for scenario management
2. **Swift Helper** - Native macOS subprocess for input simulation and screen capture

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Terminal                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Bun Controller (OpenTUI/React)               │  │
│  │  - Terminal UI with vim-style navigation                  │  │
│  │  - Scenario management (CRUD, persistence)                │  │
│  │  - Recording orchestration                                │  │
│  │  - Execution engine                                       │  │
│  └─────────────────────────┬─────────────────────────────────┘  │
│                            │ stdin/stdout JSON IPC              │
│  ┌─────────────────────────▼─────────────────────────────────┐  │
│  │                 Swift Helper (subprocess)                 │  │
│  │  - macOS native interactions (click, keypress)            │  │
│  │  - Screen capture for pixel detection                     │  │
│  │  - SwiftUI recorder overlay                               │  │
│  │  - Magnifier view for pixel selection                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
macos-sequence-clicker/
├── schema/                     # SHARED TYPE DEFINITIONS (SOURCE OF TRUTH)
│   ├── src/types.ts           # All TypeScript types
│   ├── generated/
│   │   ├── schema.json        # Generated JSON Schema
│   │   └── Types.swift        # Generated Swift Codable types
│   └── generate.ts            # Codegen script
│
├── controller/                 # Bun/TypeScript terminal app
│   └── src/
│       ├── index.tsx          # Entry point
│       ├── types/             # Re-exports from schema
│       ├── ipc/               # Swift communication (bridge.ts, protocol.ts)
│       ├── store/             # State management (scenarios, history, recorder, settings)
│       ├── components/        # OpenTUI React components
│       ├── hooks/             # useVimNavigation, useRecording, useStoreSubscription
│       └── execution/         # Scenario playback engine
│
├── swift-helper/              # Swift/SwiftUI native helper
│   └── Sources/
│       ├── main.swift         # Entry point
│       ├── Generated/         # Types.swift (copied from schema)
│       ├── IPC/               # StdinReader, StdoutWriter, IPCHandler
│       ├── Actions/           # MouseController, KeyboardController, ScreenCapture
│       ├── UI/                # Overlay windows, magnifier, zone selector
│       └── Permissions/       # Accessibility, screen recording checks
│
├── e2e-tester/                # E2E testing framework (Swift)
│   └── Sources/
│       ├── main.swift         # CLI entry point
│       ├── Core/              # TestRunner, TestCase, TestContext
│       ├── Terminal/          # AppleScript Terminal.app control
│       ├── Input/             # CGEvent keyboard/mouse simulation
│       ├── Overlay/           # Window discovery, button positions
│       ├── Config/            # Read/write scenarios.json
│       ├── Assertions/        # Test assertion helpers
│       └── Tests/             # Test implementations
│
└── docs/                      # Full documentation
    └── build-phases/          # Implementation phases with detailed notes
```

## Core Concepts

### Domain Model

- **Actions** - User interactions: `click`, `keypress`
- **Transitions** - Conditions to proceed: `delay`, `pixel-state`, `pixel-zone`
- **Scenario** - A sequence of steps (actions, transitions, or refs to other scenarios)
- **Step** - Union type: `ClickAction | KeypressAction | DelayTransition | PixelStateTransition | PixelZoneTransition | ScenarioRef`

### Type System (Source of Truth)

**All types are defined in `schema/src/types.ts`**. This is the single source of truth.

```bash
# Regenerate types after modifying schema/src/types.ts
cd schema && bun run generate
```

This generates:
- `schema/generated/schema.json` - JSON Schema
- `schema/generated/Types.swift` - Swift Codable types (copied to swift-helper)

**Key pattern**: TypeScript types use discriminated unions with a `type` field:
```typescript
type Step = 
  | { type: 'click'; position: Point; button: 'left' | 'right' }
  | { type: 'keypress'; key: string; modifiers: Modifier[] }
  | { type: 'delay'; ms: number }
  // ...
```

### IPC Protocol

Communication between Controller and Swift Helper uses **newline-delimited JSON** over stdin/stdout.

**Request/Response Pattern:**
```typescript
// Request (Controller → Swift)
{ "id": "abc123", "method": "executeClick", "params": { "position": { "x": 100, "y": 200 }, "button": "left" } }

// Response (Swift → Controller)
{ "success": true, "id": "abc123", "result": { ... } }
// or
{ "success": false, "id": "abc123", "error": "..." }
```

**Events (Swift → Controller, unsolicited):**
```typescript
{ "event": "mouseClicked", "position": { "x": 100, "y": 200 }, "button": "left" }
```

## Important Patterns

### 1. Swift Actor Pattern

All Swift controllers use actors for thread safety:
```swift
actor MouseController {
    func click(at position: Point, button: MouseButton) async { ... }
}
```

### 2. Store Subscription Pattern (Controller)

Stores use a simple pub/sub pattern without external dependencies:
```typescript
// Store implementation
class ScenariosStore {
  private listeners = new Set<() => void>();
  subscribe(listener: () => void) { this.listeners.add(listener); return () => this.listeners.delete(listener); }
  private notify() { this.listeners.forEach(l => l()); }
}

// React hook usage
const scenarios = useStoreSubscription(scenariosStore, s => s.getScenarios());
```

### 3. Vim Navigation State Machine

Navigation uses column-based state (0=scenarios, 1=steps, 2=preview) with h/j/k/l movement:
- `h`/`l` - Move between columns
- `j`/`k` - Move up/down within column
- `Ctrl+l` - Select/enter (including sub-scenarios)
- `Ctrl+h` - Back (exit sub-scenario)

### 4. Recording State Machine

Three states: `idle` → `naming` → `recording`
- `idle`: Normal vim navigation
- `naming`: Capturing text input for new scenario name
- `recording`: Capturing events from Swift overlay

### 5. Execution with AbortController

Scenario execution uses standard `AbortController` for cancellation:
```typescript
const controller = new AbortController();
await executeScenario(scenario, { signal: controller.signal });
// ESC → controller.abort()
```

### 6. SwiftUI in NSWindow

Overlay windows embed SwiftUI in NSWindow:
```swift
let hostingView = NSHostingView(rootView: RecorderOverlayView(...))
window.contentView = hostingView
```

Window configuration for overlays:
- `styleMask: [.borderless]`
- `level: .floating`
- `backgroundColor: .clear`, `isOpaque: false`
- `collectionBehavior: [.canJoinAllSpaces, .stationary]`

### 7. Coordinate System

macOS uses bottom-left origin, CGEvent uses top-left. Convert with:
```swift
let adjustedY = screenHeight - y
```

## Key Commands

```bash
# Build Swift helper
cd swift-helper && swift build -c release

# Run controller
cd controller && bun run start

# Regenerate types
cd schema && bun run generate

# Verify Swift types compile
swiftc -typecheck schema/generated/Types.swift

# Build E2E tester
cd e2e-tester && swift build -c release

# Run E2E tests
cd e2e-tester && .build/release/E2ETester

# Run specific E2E test
cd e2e-tester && .build/release/E2ETester --test recordAndExecuteScenario

# List available E2E tests
cd e2e-tester && .build/release/E2ETester --list
```

## Permission Requirements

The Swift helper requires:
1. **Accessibility** - For simulating clicks/keypresses (`AXIsProcessTrusted()`)
2. **Screen Recording** - For capturing pixel colors (`CGDisplayCreateImage`)

Enable in System Settings → Privacy & Security.

## Common Gotchas

### 1. OpenTUI JSX Type Conflicts
OpenTUI's `text` element conflicts with React's SVG types. TypeScript shows errors but runtime works. Workaround is in `opentui.d.ts`.

### 2. Swift Generic Constraints
`IPCResponseSuccess<T>` requires `T: Codable`, not just `Encodable`.

### 3. CGImage Pixel Format
`CGDisplayCreateImage` returns varying pixel formats. Check `alphaInfo` to determine byte order (ARGB vs RGBA).

### 4. macOS Virtual Key Codes
Key codes are NOT ASCII values. See `keyCodeMap` in `KeyboardController.swift`.

### 5. Modifier Keys
Modifiers must be set in both:
- `CGEventFlags` on the key event (for apps to see Cmd+C, etc.)
- Optionally as separate keyDown/keyUp events

### 6. Global Event Monitoring
`NSEvent.addGlobalMonitorForEvents()` requires Accessibility permission. Also need `addLocalMonitorForEvents` for events in own windows.

## Data Persistence

Files stored in `~/.config/macos-sequencer/` (overridable via `SEQUENCER_CONFIG_DIR` env var):
- `scenarios.json` - Saved scenarios (auto-saved on mutation)
- `settings.json` - User preferences

**Config Override:**
```bash
# Use custom config directory (useful for testing)
SEQUENCER_CONFIG_DIR=/tmp/test-config bun run start
```

## Testing

### Unit Testing (Swift Helper)

```bash
# Test Swift helper directly
echo '{"id":"1","method":"checkPermissions"}' | .build/release/SequencerHelper

# Test click
echo '{"id":"1","method":"executeClick","params":{"position":{"x":100,"y":100},"button":"left"}}' | .build/release/SequencerHelper

# Test pixel color
echo '{"id":"1","method":"getPixelColor","params":{"position":{"x":100,"y":100}}}' | .build/release/SequencerHelper
```

### E2E Testing

The E2E tester automates full workflows by:
1. Launching Terminal.app with the controller
2. Sending keypresses/clicks to test UI interactions
3. Detecting and interacting with the recorder overlay
4. Verifying results by reading config files

**Build and run:**
```bash
cd e2e-tester
swift build -c release
.build/release/E2ETester
```

**Key features:**
- **Test isolation** - Each test uses a unique temp config directory via `SEQUENCER_CONFIG_DIR`
- **Serial execution** - Tests run one at a time for predictable results
- **Overlay detection** - Uses `CGWindowListCopyWindowInfo` to find and click overlay buttons
- **Result verification** - Reads `scenarios.json` to verify scenarios were recorded/executed

**Permissions required:**
- Accessibility permission (for sending keypresses/clicks)
- Grant to Terminal.app or the E2ETester binary

**Available tests:**
- `recordAndExecuteScenario` - E2E: Create scenario, record a click, execute it, verify

See `e2e-tester/README.md` for full documentation.

## File Reference by Feature

| Feature | Controller Files | Swift Files |
|---------|-----------------|-------------|
| Type definitions | `schema/src/types.ts` | `Generated/Types.swift` |
| IPC communication | `ipc/bridge.ts`, `ipc/protocol.ts` | `IPC/*.swift` |
| State management | `store/*.ts` | - |
| Terminal UI | `components/*.tsx` | - |
| Vim navigation | `hooks/useVimNavigation.ts` | - |
| Recording | `hooks/useRecording.ts` | `UI/*.swift` |
| Execution | `execution/executor.ts` | `Actions/*.swift` |
| Permissions | - | `Permissions/PermissionChecker.swift` |
| E2E Testing | - | `e2e-tester/Sources/**/*.swift` |

## Documentation

Full documentation available in `docs/`:
- `PART_01_OVERVIEW.md` - Architecture overview
- `PART_02_SCHEMA.md` - Type definitions
- `PART_03_SWIFT_HELPER.md` - Swift helper details
- `PART_04_CONTROLLER.md` - Controller details
- `PART_05_UI.md` - Terminal UI
- `PART_06_SWIFT_UI.md` - Swift overlay UI
- `build-phases/README.md` - Implementation phases with detailed notes

## Rules

When asked for any change - add the following final TODO item: "Update AGENTS.md with any important info"
When asked for a non-trivial change - add the following final TODO item: "commit&push"
