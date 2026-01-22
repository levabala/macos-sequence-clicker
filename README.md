# macOS Smart Sequencer

A macOS automation tool for recording and replaying UI interaction sequences.

## Features

- **Record** clicks, keypresses, and wait conditions
- **Playback** scenarios with customizable hotkeys
- **Pixel detection** for conditional transitions
- **Vim-style** terminal UI navigation
- **Nested scenarios** for complex workflows

## Architecture

```
┌─────────────────────────────────────────┐
│     Bun Controller (Terminal UI)        │
│     - OpenTUI/React interface           │
│     - Scenario management               │
│     - Recording orchestration           │
├─────────────────────────────────────────┤
│          stdin/stdout JSON IPC          │
├─────────────────────────────────────────┤
│     Swift Helper (Native macOS)         │
│     - Click/keypress simulation         │
│     - Screen capture                    │
│     - Recorder overlay UI               │
└─────────────────────────────────────────┘
```

## Requirements

- macOS 13.0+
- [Bun](https://bun.sh/) 1.0+
- Swift 5.9+ (included with Xcode)
- Accessibility permission (System Settings → Privacy & Security → Accessibility)
- Screen Recording permission (System Settings → Privacy & Security → Screen Recording)

## Quick Start

```bash
# Build everything (first time)
./build.sh

# Run the app
./run.sh
```

### Manual build steps

If you prefer to run steps individually:

```bash
# 1. Install dependencies and generate types
cd schema && bun install && bun run generate && cd ..

# 2. Build the Swift helper
cd swift-helper && swift build -c release && cd ..

# 3. Install controller dependencies
cd controller && bun install && cd ..

# 4. Run
cd controller && bun run start
```

### Development mode

```bash
cd controller && bun run dev
```

## Permissions

On first run, macOS will prompt for permissions. You need to grant:

1. **Accessibility** - Required for simulating clicks and keypresses
2. **Screen Recording** - Required for pixel color detection

Go to **System Settings → Privacy & Security** and add the terminal app (Terminal.app, iTerm, etc.) to both lists.

## Usage

1. **Create a scenario**: Press `c`, type a name, press `Enter`
2. **Record actions**: The overlay toolbar appears - click icons to add:
   - Mouse clicks (captured on next click)
   - Keypresses (captured on next keypress)
   - Delays (enter milliseconds)
   - Pixel conditions (use magnifier to select)
3. **Stop recording**: Press `r` or `ESC`
4. **Play a scenario**: Select it, press `p`, set a trigger key, switch to target app, press trigger

## Key Bindings

| Key | Action |
|-----|--------|
| `h/l` | Navigate columns |
| `j/k` | Navigate rows |
| `Ctrl+l` | Select / Enter sub-scenario |
| `Ctrl+h` | Back / Exit sub-scenario |
| `Ctrl+j/k` | Swap steps up/down |
| `c` | Create new scenario |
| `r` | Toggle recording |
| `p` | Play scenario |
| `d` | Delete step |
| `u` | Undo deletion |
| `n` | Rename scenario |
| `q` | Quit |

## Documentation

- [Part 1: Overview](docs/PART_01_OVERVIEW.md) - Architecture and concepts
- [Part 2: Schema](docs/PART_02_SCHEMA.md) - Type definitions and codegen
- [Part 3: Swift Helper](docs/PART_03_SWIFT_HELPER.md) - Native macOS component
- [Part 4: Controller](docs/PART_04_CONTROLLER.md) - Bun/TypeScript app
- [Part 5: Terminal UI](docs/PART_05_UI.md) - OpenTUI components
- [Part 6: Swift UI](docs/PART_06_SWIFT_UI.md) - Overlay and magnifier
- [Build Phases](docs/build-phases/README.md) - Implementation details

## Data Storage

Scenarios and settings are stored in:
```
~/.config/macos-sequencer/
├── scenarios.json
└── settings.json
```

## License

MIT
