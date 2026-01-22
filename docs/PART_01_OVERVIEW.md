# Part 1: Project Overview

## Summary

**macOS Smart Sequencer** is a two-part automation tool for recording and replaying UI interaction sequences on macOS.

### Target Use Case

Automate repetitive UI workflows, such as:
1. Press right arrow
2. Click a button (opens dropdown)
3. Click dropdown item (new page opens)
4. Click button (progress modal, auto-closes)
5. Click button (switch tabs)
6. Click button (wait for progress bar to turn green)
7. End

### Core Concepts

**Actions** - User interactions:
- `click` - Mouse click at coordinates (left/right button)
- `keypress` - Keyboard input with optional modifiers (ctrl/alt/shift/cmd)

**Transitions** - Conditions to proceed to next action:
- `delay` - Wait for specified milliseconds
- `pixel-state` - Wait until a specific pixel matches a color (with threshold)
- `pixel-zone` - Wait until any pixel in a rectangle matches a color (with threshold)

**Scenario** - A sequence of steps (actions, transitions, or references to other scenarios)

---

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

### Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **Bun Controller** | UI, state management, scenario persistence, orchestration |
| **Swift Helper** | macOS API access, overlay UI, low-level input simulation |

### Communication

- **Protocol**: JSON over stdin/stdout (newline-delimited)
- **Pattern**: Request/Response + unsolicited Events
- **Type Safety**: TypeScript source → JSON Schema → Swift Codable (generated)

---

## Project Structure

```
macos-sequence-clicker/
├── docs/                       # Documentation (you are here)
│   ├── PART_01_OVERVIEW.md
│   ├── PART_02_SCHEMA.md
│   ├── PART_03_SWIFT_HELPER.md
│   ├── PART_04_CONTROLLER.md
│   ├── PART_05_UI.md
│   └── PART_06_RECORDING_EXECUTION.md
│
├── schema/                     # Shared type definitions (SOURCE OF TRUTH)
│   ├── src/
│   │   └── types.ts           # All IPC message types
│   ├── generated/
│   │   ├── schema.json        # Generated JSON Schema
│   │   └── Types.swift        # Generated Swift Codable
│   ├── package.json
│   └── generate.ts            # Codegen script
│
├── controller/                 # Bun/TypeScript terminal app
│   ├── src/
│   │   ├── index.tsx          # Entry point
│   │   ├── types/             # Type re-exports + controller-specific
│   │   ├── ipc/               # Swift communication
│   │   ├── store/             # State management
│   │   ├── components/        # OpenTUI React components
│   │   └── hooks/             # Custom React hooks
│   ├── package.json
│   └── tsconfig.json
│
├── swift-helper/              # Swift/SwiftUI native helper
│   ├── Package.swift
│   └── Sources/
│       ├── main.swift
│       ├── Generated/         # Types.swift (from schema)
│       ├── IPC/               # Message handling
│       ├── Actions/           # Mouse, keyboard, screen
│       ├── UI/                # Overlay, magnifier
│       └── Permissions/       # Accessibility, screen recording
│
├── scripts/
│   └── build-types.sh         # Runs schema generation
│
└── config/                    # Runtime config location
    └── ~/.config/macos-sequencer/
        ├── scenarios.json     # Saved scenarios
        └── settings.json      # User preferences
```

---

## Technology Choices

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| Controller runtime | Bun | Fast, TypeScript-native, good process spawning |
| Terminal UI | OpenTUI/React | Familiar React patterns for terminal apps |
| Native helper | Swift | Required for macOS APIs (CGEvent, screen capture) |
| Overlay UI | SwiftUI | Modern, declarative, easy floating windows |
| IPC format | JSON | Human-readable, debuggable |
| Type safety | JSON Schema bridge | TS types → JSON Schema → Swift Codable |
| Persistence | JSON files | Simple, inspectable, in ~/.config |
| Color comparison | Euclidean RGB | Simple `sqrt((r1-r2)² + (g1-g2)² + (b1-b2)²)` |

---

## Permissions Required

The Swift helper requires these macOS permissions (checked on startup):

1. **Accessibility** - For simulating clicks and keypresses
2. **Screen Recording** - For capturing pixel colors

If missing, the controller will display instructions to enable them in System Settings.

---

## Implementation Phases

1. **Schema & Types** - Define all shared types, set up codegen
2. **Swift Helper Core** - IPC loop, permission checking
3. **Controller Core** - IPC bridge, basic terminal UI
4. **Swift Actions** - Mouse, keyboard, screen capture
5. **Swift Overlay** - Recorder UI, magnifier
6. **Recording Flow** - Full recording integration
7. **Execution Engine** - Scenario playback
8. **Polish** - Error handling, edge cases
