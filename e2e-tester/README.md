# E2E Tester for macOS Smart Sequencer

End-to-end testing framework for the macOS Smart Sequencer application.

## Overview

This tester automates full UI workflows to verify the complete application:
1. **Launches Terminal.app** with the controller running in an isolated config directory
2. **Sends keypresses/clicks** to test controller UI (vim navigation, scenario CRUD)
3. **Interacts with recorder overlay** by detecting window positions and clicking buttons
4. **Verifies results** by reading config files (scenarios.json) and checking state changes
5. **Test isolation** - Each test uses a unique temporary config directory

The E2E tester is built in Swift and uses native macOS APIs (CGEvent, AppleScript, CGWindowListCopyWindowInfo) to provide reliable, automated testing of the entire application stack.

## Prerequisites

- macOS 13.0+
- Swift 5.9+
- Bun (for running the controller)
- **Accessibility permission** for this app or Terminal.app

## Quick Start

```bash
# 1. Build the tester
cd e2e-tester
swift build -c release

# 2. Ensure prerequisites are built
cd ../swift-helper && swift build -c release
cd ../controller && bun install

# 3. Run tests
cd ../e2e-tester
.build/release/E2ETester

# Or run with verbose logging
.build/release/E2ETester --verbose
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

| Test | Description | What It Tests |
|------|-------------|---------------|
| `recordAndExecuteScenario` | Complete E2E workflow | - Scenario creation via 'c' key<br>- Text input (scenario naming)<br>- Recording activation via 'r' key<br>- Overlay window detection<br>- Button click interaction<br>- Mouse click recording<br>- Scenario execution via 'p' key<br>- Config file persistence<br>- lastUsedAt timestamp update |

### Test Details: recordAndExecuteScenario

This test exercises the full application workflow:

1. **Launch & Setup** (3 seconds)
   - Spawns Terminal.app
   - Runs controller with isolated config
   - Waits for UI to initialize

2. **Scenario Creation** (~2 seconds)
   - Presses 'c' to create new scenario
   - Types "E2E Test Scenario"
   - Presses Enter to confirm

3. **Recording** (~3 seconds)
   - Presses 'r' to start recording
   - Detects recorder overlay window (360x60px)
   - Clicks "Action" button
   - Clicks "Mouse" button
   - Records a click at (100, 400)
   - Presses Escape to stop

4. **Verification** (~1 second)
   - Reads scenarios.json
   - Verifies 1 scenario exists
   - Checks scenario name matches
   - Verifies 1 click step recorded
   - Validates click position (±10px tolerance)

5. **Execution** (~3 seconds)
   - Presses 'p' to play scenario
   - Waits for execution
   - Closes play modal with Escape

6. **Execution Verification** (~1 second)
   - Re-reads scenarios.json
   - Confirms lastUsedAt was updated

7. **Cleanup**
   - Presses 'q' to quit
   - Closes terminal
   - Removes temp config directory

**Total runtime:** ~13-15 seconds

## Permissions

The tester requires **Accessibility** permission to:
- Send keypresses and mouse clicks via CGEvent API
- Simulate user input to Terminal.app and overlay windows
- Monitor window information with CGWindowListCopyWindowInfo

### Granting Permissions

**Option 1: Grant to Terminal.app** (Recommended)
1. Open System Settings > Privacy & Security > Accessibility
2. Click the lock icon and authenticate
3. Click "+" and add Terminal.app (`/System/Applications/Utilities/Terminal.app`)
4. Enable the checkbox

**Option 2: Grant to E2ETester binary**
1. Open System Settings > Privacy & Security > Accessibility
2. Click the lock icon and authenticate
3. Click "+" and navigate to `.build/release/E2ETester`
4. Enable the checkbox

**Note:** If running from a different terminal app (iTerm2, etc.), grant permission to that app instead.

### Verifying Permissions

The tester will check permissions on startup and display a helpful error message if they're missing:

```
⚠️  Accessibility permission required!

To grant permission:
1. Open System Settings > Privacy & Security > Accessibility
2. Add this terminal app (or E2ETester) to the list
```

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

Each test run creates a **unique temporary config directory**:
```
/tmp/e2e-test-<UUID>/
├── scenarios.json
└── settings.json
```

The controller is launched with the `SEQUENCER_CONFIG_DIR` environment variable:
```bash
SEQUENCER_CONFIG_DIR=/tmp/e2e-test-abc123 bun run start
```

This ensures:
- ✅ No interference between test runs
- ✅ No pollution of production config (`~/.config/macos-sequencer/`)
- ✅ Clean slate for each test
- ✅ Automatic cleanup after test completion

### Terminal Control via AppleScript

The `TerminalManager` uses AppleScript to control Terminal.app:

```applescript
tell application "Terminal"
    activate
    set newWindow to do script "cd /path && SEQUENCER_CONFIG_DIR=/tmp/test bun run start"
    set windowId to id of front window
    return windowId
end tell
```

**Capabilities:**
- Launch commands in new Terminal windows
- Focus specific windows by ID
- Get window position/size for targeting
- Close windows programmatically
- Works reliably across macOS versions

### Input Simulation via CGEvent

The `InputSimulator` uses the CGEvent API for native input:

**Keyboard simulation:**
```swift
// Create key down event with modifiers
let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
keyDown.flags = modifierFlags  // .maskCommand, .maskShift, etc.
keyDown.post(tap: .cghidEventTap)

// Small delay
Task.sleep(nanoseconds: 20_000_000)

// Create key up event
let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
keyUp.post(tap: .cghidEventTap)
```

**Mouse simulation:**
```swift
let mouseDown = CGEvent(
    mouseEventSource: nil,
    mouseType: .leftMouseDown,
    mouseCursorPosition: CGPoint(x: 100, y: 200),
    mouseButton: .left
)
mouseDown.post(tap: .cghidEventTap)
```

**Key features:**
- Uses virtual key codes (not ASCII values)
- Supports modifier keys (Cmd, Shift, Ctrl, Alt)
- Character-by-character text typing
- Precise screen coordinate clicking
- Configurable delays between events

### Overlay Detection via Window Discovery

The `OverlayLocator` finds overlay windows using `CGWindowListCopyWindowInfo`:

```swift
// Get all on-screen windows
let windowList = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
)

// Filter by owner and size
for window in windowList {
    if owner == "SequencerHelper" &&
       abs(width - 360) < 5 &&
       abs(height - 60) < 5 {
        // Found recorder overlay!
    }
}
```

**Button position calculation:**

Based on the known layout from `RecorderOverlayView.swift`:
- Overlay size: 360×60px
- Button centers calculated from layout analysis:
  - Action: (41, 30)
  - Transition: (91, 30)
  - Mouse: (152, 30)
  - Keyboard: (204, 30)
  - Time: (256, 30)
  - Close: (340, 30)

The locator returns absolute screen coordinates by adding overlay origin:
```swift
buttonPos = overlayOrigin + buttonRelativeCenter
```

### Result Verification via Config Files

The `ConfigManager` reads the isolated config directory to verify test results:

```swift
// Read scenarios.json
let scenarios = try configManager.readScenarios()

// Verify scenario was created
assert(scenarios.count == 1)
assert(scenarios[0].name == "E2E Test Scenario")

// Verify steps were recorded
assert(scenarios[0].steps.count == 1)
assert(scenarios[0].steps[0].type == "click")

// Verify execution occurred
assert(scenarios[0].lastUsedAt > 0)
```

**What we verify:**
- ✅ Scenario creation (count, name, timestamps)
- ✅ Step recording (type, position, button, modifiers)
- ✅ Scenario execution (lastUsedAt update)
- ✅ Config persistence (file exists, valid JSON)

### Error Handling & Cleanup

Every test includes comprehensive error handling:

```swift
do {
    // Run test steps
    try await test.run(context: context)
} catch {
    // Capture error details
    errorMessage = String(describing: error)
} finally {
    // Always cleanup
    try? FileManager.default.removeItem(atPath: configDir)
    await terminal.forceKill(session)
}
```

**Cleanup guarantees:**
- Temp config directories removed even on failure
- Terminal windows closed gracefully
- No orphaned processes
- Detailed error messages for debugging

## Adding New Tests

### Step-by-Step Guide

**1. Create a new test file**

```bash
cd e2e-tester/Sources/Tests
touch CreateScenarioTest.swift
```

**2. Implement the `TestCase` protocol**

```swift
import Foundation

struct CreateScenarioTest: TestCase {
    let name = "createScenario"
    let description = "Test scenario creation and naming"
    
    func run(context: TestContext) async throws {
        var session: TerminalSession? = nil
        
        do {
            context.log("Starting createScenario test")
            
            // 1. Launch controller
            session = try await context.terminal.launchController(
                configDir: context.configDir
            )
            await context.wait(ms: 3000)
            
            // 2. Focus terminal
            try await context.terminal.focusTerminal(session!)
            await context.wait(ms: 500)
            
            // 3. Create scenario
            context.log("Creating scenario...")
            await context.input.pressKey("c")
            await context.wait(ms: 500)
            
            // 4. Type name
            await context.input.typeText("Test Scenario")
            await context.input.pressKey("return")
            await context.wait(ms: 1000)
            
            // 5. Verify in config
            context.log("Verifying scenario creation...")
            try await context.config.waitForScenariosFile(timeoutMs: 5000)
            
            let scenarios = try context.config.readScenarios()
            try context.assertEqual(scenarios.count, 1)
            
            let scenario = try ScenarioAssertions.assertExists(
                named: "Test Scenario",
                in: scenarios
            )
            
            context.log("Scenario created successfully: \(scenario.name)")
            
            // 6. Cleanup
            try await context.terminal.focusTerminal(session!)
            await context.input.pressKey("q")
            await context.wait(ms: 1000)
            try await context.terminal.closeSession(session!)
            session = nil
            
        } catch {
            if let session = session {
                await context.terminal.forceKill(session)
            }
            throw error
        }
    }
}
```

**3. Register in main.swift**

```swift
// In Sources/main.swift
let tests: [TestCase] = [
    RecordAndExecuteTest(),
    CreateScenarioTest(),  // Add here
]
```

**4. Build and test**

```bash
swift build -c release
.build/release/E2ETester --test createScenario
```

---

### TestContext API Reference

The `TestContext` provides utilities for test implementation:

#### Terminal Control
```swift
// Launch controller with isolated config
let session = try await context.terminal.launchController(
    configDir: context.configDir
)

// Focus terminal window
try await context.terminal.focusTerminal(session)

// Get window frame
let frame = try await context.terminal.getWindowFrame(session)

// Close terminal
try await context.terminal.closeSession(session)

// Force kill (cleanup)
await context.terminal.forceKill(session)
```

#### Input Simulation
```swift
// Press single key
await context.input.pressKey("c")
await context.input.pressKey("return")
await context.input.pressKey("escape")

// Press with modifiers
await context.input.pressKey("c", modifiers: [.cmd])  // Cmd+C

// Type text
await context.input.typeText("Hello World")

// Click at position
await context.input.click(at: CGPoint(x: 100, y: 200))
await context.input.click(at: point, button: .right)  // Right click

// Wait
await context.wait(ms: 1000)
```

#### Overlay Detection
```swift
// Find recorder overlay
if let frame = context.overlay.findRecorderOverlay() {
    print("Overlay at: \(frame)")
}

// Wait for overlay to appear
let frame = try await context.overlay.waitForOverlay(timeoutMs: 5000)

// Get button position
if let pos = context.overlay.buttonPosition(.action) {
    await context.input.click(at: pos)
}

// Available buttons: .action, .transition, .mouse, .keyboard, .time, .close
```

#### Config Management
```swift
// Read scenarios
let scenarios = try context.config.readScenarios()

// Write scenarios (for test setup)
try context.config.writeScenarios([scenario])

// Wait for file to appear
try await context.config.waitForScenariosFile(timeoutMs: 5000)

// Check if file exists
if context.config.scenariosFileExists() {
    // ...
}
```

#### Assertions
```swift
// Basic assertion
try context.assert(condition, "Expected X but got Y")

// Equality assertion
try context.assertEqual(actual, expected)

// Scenario assertions
try ScenarioAssertions.assertCount(scenarios, equals: 1)
try ScenarioAssertions.assertExists(named: "Test", in: scenarios)
try ScenarioAssertions.assertStepCount(scenario, equals: 3)
try ScenarioAssertions.assertStepType(scenario, at: 0, is: "click")
try ScenarioAssertions.assertWasExecuted(scenario)

// Custom assertion with position tolerance
try ScenarioAssertions.assertClickPosition(
    step,
    x: 100,
    y: 200,
    tolerance: 10
)
```

#### Logging
```swift
// Log messages (visible with --verbose)
context.log("Starting test phase 2...")
context.log("Found \(scenarios.count) scenarios")

// Logs are captured and included in test results
// Access via: result.logs
```

#### Wait Utilities
```swift
// Simple delay
await context.wait(ms: 1000)

// Wait for condition
try await context.waitUntil(timeoutMs: 5000) {
    // Return true when condition is met
    return context.config.scenariosFileExists()
}

// Wait for file
try await context.waitForFile("/path/to/file", timeoutMs: 3000)
```

---

### Test Patterns & Best Practices

#### Pattern 1: Session Cleanup

Always use try-catch-finally for terminal session cleanup:

```swift
var session: TerminalSession? = nil

do {
    session = try await context.terminal.launchController(...)
    // Test logic here
    
    // Normal cleanup
    try await context.terminal.closeSession(session!)
    session = nil
    
} catch {
    // Failure cleanup
    if let session = session {
        await context.terminal.forceKill(session)
    }
    throw error
}
```

#### Pattern 2: Robust Waiting

Use multiple wait strategies for reliability:

```swift
// 1. Wait for UI to render
await context.wait(ms: 3000)

// 2. Wait for config file
try await context.config.waitForScenariosFile()

// 3. Additional buffer for writes to complete
await context.wait(ms: 500)

// Now safe to read
let scenarios = try context.config.readScenarios()
```

#### Pattern 3: Focus Management

Always refocus terminal before sending keys:

```swift
// After clicking overlay or other windows
await context.input.click(at: overlayButton)
await context.wait(ms: 500)

// Refocus before next keypress
try await context.terminal.focusTerminal(session)
await context.wait(ms: 300)

await context.input.pressKey("escape")
```

#### Pattern 4: Defensive Assertions

Check intermediate state, not just final state:

```swift
// After creating scenario
let scenariosAfterCreate = try context.config.readScenarios()
try context.assertEqual(scenariosAfterCreate.count, 1)

// After recording step
let scenariosAfterRecord = try context.config.readScenarios()
try context.assertEqual(scenariosAfterRecord[0].steps.count, 1)

// After execution
let scenariosAfterExec = try context.config.readScenarios()
try context.assert(scenariosAfterExec[0].lastUsedAt > 0, "Not executed")
```

#### Pattern 5: Descriptive Logging

Log every major step for debugging:

```swift
context.log("=== Phase 1: Launch ===")
session = try await context.terminal.launchController(...)

context.log("=== Phase 2: Create Scenario ===")
await context.input.pressKey("c")
// ...

context.log("=== Phase 3: Record Step ===")
// ...

context.log("=== Phase 4: Verify ===")
let scenarios = try context.config.readScenarios()
context.log("  Found: \(scenarios.count) scenarios")
```

---

### Example Tests

See `Sources/Tests/RecordAndExecuteTest.swift` for a complete example of:
- Session management
- Error handling
- Overlay interaction
- Config verification
- Comprehensive logging

## Troubleshooting

### Common Issues

#### "Accessibility permission required"

**Cause:** The E2ETester or Terminal.app doesn't have Accessibility permission.

**Solution:**
1. Open System Settings > Privacy & Security > Accessibility
2. Click the lock icon and authenticate
3. Add Terminal.app or the E2ETester binary
4. Restart the tester

**Verification:**
```bash
# Check if current process has permission
.build/release/E2ETester --list
# Should show test list, not permission error
```

---

#### "Could not detect project root"

**Cause:** The tester can't find the project root directory (needs `controller/` subdirectory).

**Solutions:**

**Option 1:** Run from project root
```bash
cd /path/to/macos-sequence-clicker
e2e-tester/.build/release/E2ETester
```

**Option 2:** Use `--project-root` flag
```bash
.build/release/E2ETester --project-root /path/to/macos-sequence-clicker
```

**Option 3:** Check build location
```bash
# If running from .build/release, go up to project root
cd ../../..
e2e-tester/.build/release/E2ETester
```

---

#### "Overlay not found" / "Timeout waiting for overlay"

**Cause:** The recorder overlay window didn't appear within 5 seconds.

**Diagnostic steps:**

1. **Check swift-helper is built:**
   ```bash
   cd swift-helper
   swift build -c release
   ls .build/release/SequencerHelper  # Should exist
   ```

2. **Test swift-helper directly:**
   ```bash
   echo '{"id":"1","method":"checkPermissions"}' | .build/release/SequencerHelper
   # Should return permissions status
   ```

3. **Test controller manually:**
   ```bash
   cd controller
   SEQUENCER_CONFIG_DIR=/tmp/test-manual bun run start
   # Should launch without errors
   # Press 'r' and verify overlay appears
   ```

4. **Check for conflicting processes:**
   ```bash
   ps aux | grep SequencerHelper
   # Kill any stray processes
   pkill SequencerHelper
   ```

**Common causes:**
- Swift helper not built or wrong path
- Controller dependencies not installed (`cd controller && bun install`)
- Permissions not granted to swift-helper
- Previous test left orphaned process

---

#### Test flakiness / Random failures

**Cause:** E2E tests depend on timing and focus. macOS window management can be unpredictable.

**Solutions:**

**1. Increase wait times:**

Edit the test file and increase delays:
```swift
// In RecordAndExecuteTest.swift
await context.wait(ms: 3000)  // Increase from 1500 to 3000
```

**2. Check for focus issues:**

Terminal might lose focus to other apps. Run with fewer apps open:
```bash
# Close other apps
# Disable notifications temporarily
# Run test
.build/release/E2ETester --test recordAndExecuteScenario
```

**3. Use verbose logging:**
```bash
.build/release/E2ETester --verbose --test recordAndExecuteScenario
```

Look for:
- Window detection failures
- Focus loss messages
- Timing issues in logs

**4. Run multiple times:**
```bash
# Run 5 times to identify flakiness patterns
for i in {1..5}; do
  echo "Run $i"
  .build/release/E2ETester --test recordAndExecuteScenario
  echo "---"
done
```

---

#### Terminal window doesn't close

**Cause:** Test failed before cleanup or Terminal.app is unresponsive.

**Solution:**
```bash
# Kill Terminal windows manually
osascript -e 'tell application "Terminal" to close (every window whose name contains "sequencer")'

# Or kill all Terminal windows
osascript -e 'tell application "Terminal" to close every window'

# Force quit Terminal.app if needed
killall Terminal
```

---

#### Config directory not cleaned up

**Cause:** Test crashed before cleanup code ran.

**Solution:**
```bash
# Clean up temp directories manually
rm -rf /tmp/e2e-test-*

# Check for orphaned configs
ls -la /tmp/ | grep e2e-test
```

---

### Debug Mode

Enable verbose logging to see detailed execution:

```bash
.build/release/E2ETester --verbose
```

**Verbose output shows:**
- 📋 Each log message with timestamp
- 🪟 Window detection results
- ⌨️ Keypresses and mouse clicks
- 📄 Config file reads/writes
- ✅ Assertion checks

**Example verbose output:**
```
[2026-01-22T10:30:45Z] Starting recordAndExecuteScenario test
[2026-01-22T10:30:45Z] Launching controller...
[2026-01-22T10:30:48Z] Creating new scenario (pressing 'c')...
[2026-01-22T10:30:51Z] Looking for recorder overlay...
[2026-01-22T10:30:51Z] Overlay found at (512.0, 668.0, 360.0, 60.0)
[2026-01-22T10:30:52Z] Clicking Action button at (553.0, 698.0)...
...
```

---

### Performance Issues

If tests are slow:

**1. Check Bun startup time:**
```bash
cd controller
time SEQUENCER_CONFIG_DIR=/tmp/test bun run start
# Should start in < 2 seconds
```

**2. Check system load:**
```bash
top -l 1 | grep "CPU usage"
# High CPU usage may slow tests
```

**3. Disable unnecessary features:**
- Close other apps
- Disable Spotlight indexing temporarily
- Disable antivirus scanning for /tmp

---

### Getting Help

If problems persist:

1. **Collect diagnostic info:**
   ```bash
   # System info
   sw_vers
   
   # Swift version
   swift --version
   
   # Bun version
   bun --version
   
   # Test with verbose
   .build/release/E2ETester --verbose 2>&1 | tee test-output.log
   ```

2. **Check logs:**
   - E2E test logs (verbose output)
   - Swift helper logs (if implemented)
   - System logs: `log show --predicate 'process == "Terminal"' --last 5m`

3. **File an issue** with:
   - macOS version
   - Test output
   - Steps to reproduce
   - Whether it works manually
