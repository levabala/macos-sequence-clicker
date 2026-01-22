# E2E Tester for macOS Smart Sequencer

End-to-end testing framework for the macOS Smart Sequencer application.

## Overview

This tester automates UI interactions to verify the complete workflow:
1. Launches Terminal.app with the controller running
2. Sends keypresses/clicks to test controller UI (vim navigation, scenario CRUD)
3. Interacts with the recorder overlay (detecting window positions, clicking buttons)
4. Verifies results by reading config files (scenarios.json)
5. Uses isolated temp config directories for each test

## Prerequisites

- macOS 13.0+
- Swift 5.9+
- Bun (for running the controller)
- **Accessibility permission** for this app or Terminal.app

## Build

```bash
cd e2e-tester
swift build -c release
```

The binary will be at `.build/release/E2ETester`.

## Usage

```bash
# Run all tests
.build/release/E2ETester

# Run with verbose output
.build/release/E2ETester --verbose

# Run specific test
.build/release/E2ETester --test recordAndExecuteScenario

# List available tests
.build/release/E2ETester --list

# Specify project root (if auto-detection fails)
.build/release/E2ETester --project-root /path/to/macos-sequence-clicker
```

## Available Tests

| Test | Description |
|------|-------------|
| `recordAndExecuteScenario` | E2E: Create scenario, record a click, execute it, verify |

## Permissions

The tester requires **Accessibility** permission to:
- Send keypresses and mouse clicks to Terminal.app
- Simulate clicks on the recorder overlay

To grant permission:
1. Open System Settings > Privacy & Security > Accessibility
2. Add Terminal.app (or the E2ETester binary) to the list

## Architecture

```
e2e-tester/
├── Package.swift
├── Sources/
│   ├── main.swift              # CLI entry point
│   ├── Core/
│   │   ├── TestRunner.swift    # Test orchestrator
│   │   ├── TestCase.swift      # Test protocol
│   │   ├── TestResult.swift    # Result types
│   │   └── TestContext.swift   # Context with utilities
│   ├── Terminal/
│   │   └── TerminalManager.swift   # AppleScript terminal control
│   ├── Input/
│   │   ├── InputSimulator.swift    # CGEvent keyboard/mouse
│   │   └── KeyCodes.swift          # macOS key code mappings
│   ├── Overlay/
│   │   └── OverlayLocator.swift    # Window discovery & button positions
│   ├── Config/
│   │   ├── ConfigManager.swift     # Read/write scenarios.json
│   │   └── Types.swift             # Codable scenario types
│   ├── Assertions/
│   │   └── Assertions.swift        # Test assertion helpers
│   └── Tests/
│       └── RecordAndExecuteTest.swift  # Core E2E test
└── README.md
```

## How It Works

### Test Isolation
Each test run creates a unique temporary config directory (e.g., `/tmp/e2e-test-UUID/`). The controller is launched with `SEQUENCER_CONFIG_DIR` environment variable pointing to this directory, ensuring complete isolation.

### Terminal Control
Uses AppleScript to:
- Launch Terminal.app with the controller command
- Focus the terminal window
- Get window position/size
- Close terminal after test

### Input Simulation
Uses CGEvent API to:
- Send key presses (with modifier support)
- Type text character by character
- Click at screen coordinates

### Overlay Detection
Uses `CGWindowListCopyWindowInfo` to:
- Find windows owned by "SequencerHelper"
- Match by window size (360x60 for recorder overlay)
- Calculate button positions from known layout

### Result Verification
Reads `scenarios.json` from the isolated config directory to verify:
- Scenarios were created with correct names
- Steps were recorded correctly
- Execution updated `lastUsedAt` timestamp

## Adding New Tests

1. Create a new file in `Sources/Tests/`
2. Implement the `TestCase` protocol:

```swift
struct MyNewTest: TestCase {
    let name = "myNewTest"
    let description = "Description of what this tests"
    
    func run(context: TestContext) async throws {
        // Use context.terminal, context.input, context.overlay, context.config
        context.log("Doing something...")
        
        // Assert results
        try context.assert(someCondition, "Expected something")
    }
}
```

3. Register the test in `main.swift`:
```swift
let tests: [TestCase] = [
    RecordAndExecuteTest(),
    MyNewTest(),  // Add here
]
```

## Troubleshooting

### "Accessibility permission required"
Grant Accessibility permission to Terminal.app or the E2ETester binary.

### "Could not detect project root"
Run from the project root directory or use `--project-root` flag.

### "Overlay not found"
The test waits up to 5 seconds for the overlay. If it still times out:
- Check that the swift-helper is built (`cd swift-helper && swift build -c release`)
- Ensure the controller can start without errors

### Test flakiness
E2E tests depend on timing. If tests are flaky:
- Increase wait times in the test
- Check for focus issues (Terminal may lose focus)
- Run with `--verbose` to see detailed logs
