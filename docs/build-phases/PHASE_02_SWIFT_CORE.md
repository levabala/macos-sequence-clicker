# Phase 2: Swift Helper Core

## Goal
Create Swift executable that communicates via stdin/stdout JSON and can check macOS permissions.

## Prerequisites
- Phase 1 complete (generated `Types.swift`)

## Deliverables
- [ ] Swift package that builds and runs
- [ ] IPC handler responding to JSON requests
- [ ] Permission checker for Accessibility + Screen Recording
- [ ] Responds to `checkPermissions` request correctly

---

## Tasks

### 2.1 Initialize Swift Package
```bash
mkdir -p swift-helper
cd swift-helper
swift package init --type executable --name SequencerHelper
```

Update `Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SequencerHelper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SequencerHelper",
            path: "Sources"
        )
    ]
)
```

### 2.2 Copy Generated Types
```bash
cp ../schema/generated/Types.swift swift-helper/Sources/Generated/
```

Or create symlink for development:
```bash
ln -s ../../schema/generated/Types.swift swift-helper/Sources/Generated/Types.swift
```

### 2.3 Implement Stdin Reader
Create `Sources/IPC/StdinReader.swift`:
- Async actor that reads lines from stdin
- Buffer management for partial reads
- Returns complete JSON lines

### 2.4 Implement Stdout Writer
Create `Sources/IPC/StdoutWriter.swift`:
- Actor for thread-safe stdout writes
- JSON encoding of responses and events
- Newline-delimited output

### 2.5 Implement IPC Handler
Create `Sources/IPC/IPCHandler.swift`:
- Main message dispatch loop
- Parse incoming JSON to request type
- Route to appropriate handler
- Return JSON response

### 2.6 Implement Permission Checker
Create `Sources/Permissions/PermissionChecker.swift`:
- `AXIsProcessTrusted()` for Accessibility
- `CGDisplayCreateImage` test for Screen Recording
- Return `PermissionStatus` struct

### 2.7 Create Entry Point
Create `Sources/main.swift`:
- Initialize NSApplication (for later UI)
- Start IPC handler on background task
- Run app loop

### 2.8 Test IPC Manually
```bash
swift build -c release
echo '{"id":"1","method":"checkPermissions"}' | .build/release/SequencerHelper
```

Expected output:
```json
{"id":"1","success":true,"result":{"accessibility":true,"screenRecording":true}}
```

---

## Acceptance Criteria
- [ ] `swift build` completes without errors
- [ ] Binary runs and waits for stdin input
- [ ] `checkPermissions` returns valid JSON response
- [ ] Permission values are accurate (test by revoking in System Settings)
- [ ] Invalid JSON input doesn't crash the helper
- [ ] EOF on stdin causes clean exit

---

## Files Created
```
swift-helper/
├── Package.swift
└── Sources/
    ├── main.swift
    ├── Generated/
    │   └── Types.swift (copied/linked)
    ├── IPC/
    │   ├── StdinReader.swift
    │   ├── StdoutWriter.swift
    │   └── IPCHandler.swift
    └── Permissions/
        └── PermissionChecker.swift
```

## Estimated Time: 3-4 hours
