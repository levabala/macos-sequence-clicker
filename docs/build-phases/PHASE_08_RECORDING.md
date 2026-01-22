# Phase 8: Recording Integration

## Goal
Connect terminal UI recording commands to Swift overlay, capture events, and add steps to scenarios.

## Prerequisites
- Phase 5 complete (State stores)
- Phase 6 complete (Terminal UI)
- Phase 7 complete (Swift overlay)

## Deliverables
- [ ] `r` key starts/stops recording
- [ ] New scenario creation with naming
- [ ] Swift overlay shows during recording
- [ ] Captured actions/transitions added to scenario
- [ ] Steps appear live in terminal UI
- [ ] Recording state indicator in UI

---

## Tasks

### 8.1 Implement Recording Hook
Create `controller/src/hooks/useRecording.ts`:

```typescript
export function useRecording() {
  // Subscribe to Swift events during recording
  useEffect(() => {
    if (!recorderStore.isRecording()) return;
    
    const handleEvent = (event: IPCEvent) => {
      const state = recorderStore.getState();
      if (state.status !== 'recording') return;
      
      let step: Step | null = null;
      
      switch (event.event) {
        case 'mouseClicked':
          step = { type: 'click', position: event.data.position, button: event.data.button };
          break;
        case 'keyPressed':
          step = { type: 'keypress', key: event.data.key, modifiers: event.data.modifiers };
          break;
        case 'pixelSelected':
          step = { type: 'pixel-state', position: event.data.position, 
                   color: event.data.color, threshold: DEFAULT_THRESHOLD };
          break;
        case 'zoneSelected':
          // Need to also capture color - shown after zone selection
          break;
        case 'timeInputCompleted':
          step = { type: 'delay', ms: event.data.ms };
          break;
        case 'overlayClosed':
          recorderStore.stopRecording();
          return;
      }
      
      if (step) {
        addStepToScenario(state.scenarioId, step, state.insertAfterIndex);
      }
    };
    
    swiftBridge.on('event', handleEvent);
    return () => swiftBridge.off('event', handleEvent);
  }, [recorderStore.isRecording()]);
  
  return {
    toggleRecording(): Promise<void>,
    finishNaming(): Promise<void>,
    isRecording: boolean,
    isNaming: boolean,
  };
}
```

### 8.2 Implement Recording Flow

**When no scenario selected + `r` pressed:**
1. Create new scenario with temporary name "New Scenario"
2. Enter naming mode (status: 'naming')
3. Capture keystrokes as name
4. On Enter: finalize name, start recording

**When scenario selected + `r` pressed:**
1. Get current selected step index (or null for end)
2. Show Swift overlay
3. Enter recording mode (status: 'recording')
4. New steps inserted after selected index

**When recording + `r` pressed:**
1. Hide Swift overlay
2. Exit recording mode (status: 'idle')

### 8.3 Implement Naming Mode
Update `controller/src/components/App.tsx`:

```typescript
useKeyboard((key) => {
  const recState = recorderStore.getState();
  
  // Handle naming mode
  if (recState.status === 'naming') {
    if (key.name === 'return') {
      recording.finishNaming();
    } else if (key.name === 'backspace') {
      recorderStore.backspaceName();
    } else if (key.name === 'escape') {
      // Cancel naming, delete the empty scenario
      scenariosStore.deleteScenario(recState.scenarioId);
      recorderStore.stopRecording();
    } else if (key.name.length === 1 && !key.ctrl && !key.alt && !key.meta) {
      recorderStore.appendToName(key.name);
    }
    return;  // Don't process other keys
  }
  
  // Normal mode keys...
});
```

### 8.4 Update Scenario List UI
Update `controller/src/components/ScenarioList.tsx`:

Show naming cursor:
```tsx
function ScenarioRow({ scenario, isNaming, namingValue }) {
  let displayName = scenario.name;
  
  if (isNaming) {
    displayName = (namingValue || '') + '█';  // Blinking cursor
  }
  
  return (
    <text>
      {prefix} {displayName}
      {isRecording && <span fg="red"> ●</span>}
    </text>
  );
}
```

### 8.5 Handle Overlay State Sync
When overlay icon clicked, update Swift overlay state:

```typescript
swiftBridge.on('overlayIconClicked', async ({ icon }) => {
  switch (icon) {
    case 'action':
      await ipc.setRecorderState('action', 'mouse');  // Default to mouse
      break;
    case 'transition':
      await ipc.setRecorderState('transition', 'mouse');  // Default to pixel
      break;
    case 'mouse':
      // Already in action/transition mode, this sets subState
      const current = /* get current state */;
      if (current.state === 'action') {
        await ipc.showMagnifier();  // No, wait - mouse in action = click capture
      } else {
        await ipc.showMagnifier();  // Pixel selection
      }
      break;
    case 'keyboard':
      await ipc.setRecorderState('action', 'keyboard');
      break;
    case 'time':
      // Show time input in overlay
      break;
  }
});
```

### 8.6 Implement Step Insertion Logic
In `controller/src/hooks/useRecording.ts`:

```typescript
function addStepToScenario(scenarioId: string, step: Step, afterIndex: number | null) {
  scenariosStore.addStep(scenarioId, step, afterIndex ?? undefined);
  
  // Update insertAfterIndex for next step
  const scenario = scenariosStore.getState().scenarios.find(s => s.id === scenarioId);
  if (scenario) {
    const newIndex = afterIndex !== null ? afterIndex + 1 : scenario.steps.length - 1;
    recorderStore.startRecording(scenarioId, newIndex);
  }
}
```

### 8.7 Handle Zone + Color Selection
Zone selection needs a second step to pick the target color:

1. User selects zone → `zoneSelected` event with rect
2. Show magnifier for color picking
3. User clicks pixel → `pixelSelected` event with color
4. Combine rect + color into `pixel-zone` step

```typescript
let pendingZone: Rect | null = null;

swiftBridge.on('zoneSelected', ({ rect }) => {
  pendingZone = rect;
  ipc.showMagnifier();  // Now pick the color
});

swiftBridge.on('pixelSelected', ({ position, color }) => {
  if (pendingZone) {
    // Create pixel-zone step
    const step: PixelZoneTransition = {
      type: 'pixel-zone',
      rect: pendingZone,
      color,
      threshold: DEFAULT_THRESHOLD,
    };
    addStepToScenario(...);
    pendingZone = null;
  } else {
    // Create pixel-state step
    const step: PixelStateTransition = {
      type: 'pixel-state',
      position,
      color,
      threshold: DEFAULT_THRESHOLD,
    };
    addStepToScenario(...);
  }
});
```

### 8.8 Test Recording Flow
Manual test checklist:
1. Press `r` with no scenario → naming mode starts
2. Type name + Enter → recording starts, overlay shows
3. Click overlay Action icon → action mode
4. Click somewhere → click step added
5. Click overlay Transition icon → transition mode
6. Click overlay Time icon → type 500, Enter → delay step added
7. Press `r` → recording stops, overlay hides

---

## Acceptance Criteria
- [ ] `r` with no scenario creates new scenario
- [ ] Naming mode captures keystrokes
- [ ] Enter finalizes name and starts recording
- [ ] Escape cancels scenario creation
- [ ] `r` with scenario selected starts recording after current step
- [ ] `r` during recording stops recording
- [ ] Overlay appears during recording
- [ ] Clicking Action icon → action mode (red indicator)
- [ ] Clicking Transition icon → transition mode (red indicator)
- [ ] Click captured and added as step
- [ ] Keypress captured and added as step
- [ ] Time input creates delay step
- [ ] Pixel selection creates pixel-state step
- [ ] Zone selection + color creates pixel-zone step
- [ ] Steps appear in UI immediately
- [ ] Recording indicator (●) shows in scenario list

---

## Files Created/Modified
```
controller/src/
├── hooks/
│   └── useRecording.ts          (new)
├── components/
│   ├── App.tsx                  (modified - add recording keyboard handling)
│   └── ScenarioList.tsx         (modified - add naming display)
└── store/
    └── recorder.ts              (may need modifications)
```

## Estimated Time: 5-6 hours
