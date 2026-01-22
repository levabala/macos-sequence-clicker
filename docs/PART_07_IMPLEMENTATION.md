# Part 7: Implementation Plan

## Implementation Order

### Phase 1: Foundation (Steps 1-4)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 1.1 | Create project structure | `schema/`, `controller/`, `swift-helper/` | 30 min |
| 1.2 | Define TypeScript types | `schema/src/types.ts` | 1 hr |
| 1.3 | Setup codegen pipeline | `schema/package.json`, `schema/generate.ts` | 1 hr |
| 1.4 | Generate Swift types | `schema/generated/Types.swift` | 30 min |

**Deliverable:** Type definitions that compile, codegen working

### Phase 2: Swift IPC Core (Steps 5-7)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 2.1 | Swift package setup | `swift-helper/Package.swift` | 15 min |
| 2.2 | Stdin/stdout IPC | `StdinReader.swift`, `StdoutWriter.swift`, `IPCHandler.swift` | 2 hr |
| 2.3 | Permission checker | `PermissionChecker.swift` | 1 hr |

**Deliverable:** Swift helper that responds to `checkPermissions` request

### Phase 3: Controller IPC (Steps 8-9)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 3.1 | Bun package setup | `controller/package.json`, `tsconfig.json` | 30 min |
| 3.2 | IPC bridge | `ipc/bridge.ts`, `ipc/protocol.ts` | 2 hr |

**Deliverable:** Controller can spawn Swift helper and exchange messages

### Phase 4: Basic Terminal UI (Steps 10-13)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 4.1 | Entry point + permission check | `index.tsx` | 1 hr |
| 4.2 | Three-column layout | `App.tsx` | 2 hr |
| 4.3 | Scenario list component | `ScenarioList.tsx` | 1 hr |
| 4.4 | Steps viewer component | `StepsViewer.tsx` | 1 hr |

**Deliverable:** Terminal UI renders with empty columns

### Phase 5: Navigation & State (Steps 14-17)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 5.1 | Vim navigation hook | `hooks/useVimNavigation.ts` | 2 hr |
| 5.2 | Scenarios store | `store/scenarios.ts` | 1 hr |
| 5.3 | Persistence | `store/persistence.ts` | 1 hr |
| 5.4 | History/undo store | `store/history.ts` | 1 hr |

**Deliverable:** Can navigate UI, scenarios persist to disk

### Phase 6: Swift Action Controllers (Steps 18-20)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 6.1 | Mouse controller | `Actions/MouseController.swift` | 1.5 hr |
| 6.2 | Keyboard controller | `Actions/KeyboardController.swift` | 2 hr |
| 6.3 | Screen capture | `Actions/ScreenCapture.swift` | 2 hr |

**Deliverable:** Swift helper can click, type, and capture pixels

### Phase 7: Swift Overlay UI (Steps 21-24)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 7.1 | Overlay window management | `UI/OverlayWindow.swift` | 2 hr |
| 7.2 | Recorder toolbar | `UI/RecorderOverlay.swift` | 3 hr |
| 7.3 | Magnifier view | `UI/MagnifierView.swift` | 2 hr |
| 7.4 | Zone selector | `UI/ZoneSelector.swift` | 1.5 hr |

**Deliverable:** Recorder overlay appears and responds to clicks

### Phase 8: Recording Integration (Steps 25-27)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 8.1 | Recorder state machine | `store/recorder.ts` | 1 hr |
| 8.2 | Recording hook | `hooks/useRecording.ts` | 2 hr |
| 8.3 | Global event monitoring | `UI/GlobalEventMonitor.swift` | 1.5 hr |

**Deliverable:** Can record clicks/keypresses into scenarios

### Phase 9: Preview & Execution (Steps 28-31)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 9.1 | Step preview component | `StepPreview.tsx` | 2 hr |
| 9.2 | Execution engine | `execution/executor.ts` | 2 hr |
| 9.3 | Play modal | `PlayModal.tsx` | 1.5 hr |
| 9.4 | Status bar | `StatusBar.tsx` | 30 min |

**Deliverable:** Full recording and playback working

### Phase 10: Polish (Steps 32-35)

| Step | Task | Files | Est. Time |
|------|------|-------|-----------|
| 10.1 | Error handling | Various | 2 hr |
| 10.2 | Edge cases | Various | 2 hr |
| 10.3 | Settings persistence | `store/persistence.ts` | 1 hr |
| 10.4 | Testing | Manual testing | 2 hr |

**Deliverable:** Production-ready application

---

## Total Estimated Time

| Phase | Hours |
|-------|-------|
| Phase 1: Foundation | 3 |
| Phase 2: Swift IPC | 3.25 |
| Phase 3: Controller IPC | 2.5 |
| Phase 4: Basic UI | 5 |
| Phase 5: Navigation & State | 5 |
| Phase 6: Swift Actions | 5.5 |
| Phase 7: Swift Overlay | 8.5 |
| Phase 8: Recording | 4.5 |
| Phase 9: Preview & Execution | 6 |
| Phase 10: Polish | 7 |
| **Total** | **~50 hours** |

---

## Quick Start Commands

```bash
# 1. Initialize schema package
cd schema
bun init
bun add -d typescript-json-schema quicktype typescript

# 2. Initialize controller package
cd ../controller
bun init
bun add @opentui/core @opentui/react react nanoid
bun add -d @types/react typescript

# 3. Initialize Swift package
cd ../swift-helper
swift package init --type executable --name SequencerHelper

# 4. Generate types (after writing types.ts)
cd ../schema
bun run generate

# 5. Build Swift helper
cd ../swift-helper
swift build -c release

# 6. Run controller
cd ../controller
bun run src/index.tsx
```

---

## Testing Checklist

### IPC Testing
- [ ] Swift helper starts and responds to checkPermissions
- [ ] Controller spawns Swift helper successfully
- [ ] Request/response round-trip works
- [ ] Events flow from Swift to Controller

### UI Testing
- [ ] Three columns render correctly
- [ ] h/l navigation between columns works
- [ ] j/k navigation within columns works
- [ ] C-l/C-h select/back works
- [ ] Scenario name editing (n key) works
- [ ] Step deletion (d key) works
- [ ] Undo (u key) works

### Recording Testing
- [ ] r key creates new scenario when none selected
- [ ] r key starts recording when scenario selected
- [ ] Recorder overlay appears
- [ ] Mouse clicks are captured
- [ ] Keyboard presses are captured
- [ ] Pixel selection with magnifier works
- [ ] Zone selection works
- [ ] Time delay input works
- [ ] r key stops recording

### Execution Testing
- [ ] p key opens play modal
- [ ] Hotkey capture works
- [ ] Scenario executes on hotkey press
- [ ] Progress is displayed
- [ ] ESC aborts execution
- [ ] Pixel wait transitions work
- [ ] Sub-scenario execution works

### Persistence Testing
- [ ] Scenarios save to ~/.config/macos-sequencer/scenarios.json
- [ ] Scenarios load on startup
- [ ] Settings save and load

---

## Dependencies Summary

### Controller (Bun/TypeScript)
```json
{
  "dependencies": {
    "@opentui/core": "^0.1.0",
    "@opentui/react": "^0.1.0",
    "react": "^18.2.0",
    "nanoid": "^5.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.3.0"
  }
}
```

### Schema (Codegen)
```json
{
  "devDependencies": {
    "typescript-json-schema": "^0.62.0",
    "quicktype": "^23.0.0",
    "typescript": "^5.3.0"
  }
}
```

### Swift Helper
- macOS 13.0+
- Swift 5.9+
- Frameworks: AppKit, SwiftUI, CoreGraphics, ApplicationServices

---

## Open Items for Future

1. **Scenario deletion** - Not implemented per requirements, may add later
2. **Sub-scenario insertion** - Need UX for adding scenario-refs
3. **Export/Import** - Sharing scenarios between machines
4. **Execution loops** - Repeat scenario N times or until condition
5. **Conditional branching** - If pixel matches X, do A, else do B
