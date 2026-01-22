# Phase 9: Scenario Execution

## Goal
Implement scenario playback with hotkey trigger, progress display, and abort capability.

## Prerequisites
- Phase 4 complete (Swift actions work)
- Phase 6 complete (Terminal UI)
- Phase 8 complete (Recording works)

## Deliverables
- [ ] Play modal with hotkey capture
- [ ] Execution engine running steps sequentially
- [ ] Progress display during execution
- [ ] ESC aborts execution
- [ ] Sub-scenario (nested) execution
- [ ] Overlay hidden during execution

---

## Tasks

### 9.1 Implement Execution Engine
Create `controller/src/execution/executor.ts`:

```typescript
export interface ExecutionProgress {
  currentStep: number;
  totalSteps: number;
  status: 'running' | 'waiting' | 'completed' | 'aborted' | 'error';
  currentStepDescription?: string;
  error?: string;
}

export async function executeScenario(
  scenario: Scenario,
  signal: AbortSignal,
  onProgress?: (progress: ExecutionProgress) => void
): Promise<void> {
  const totalSteps = countTotalSteps(scenario);  // Including sub-scenarios
  let executedSteps = 0;
  
  for (const step of scenario.steps) {
    if (signal.aborted) {
      throw new DOMException('Aborted', 'AbortError');
    }
    
    onProgress?.({
      currentStep: executedSteps,
      totalSteps,
      status: 'running',
      currentStepDescription: describeStep(step),
    });
    
    await executeStep(step, signal, onProgress);
    executedSteps++;
  }
  
  // Mark as used
  scenariosStore.touchScenario(scenario.id);
  
  onProgress?.({
    currentStep: totalSteps,
    totalSteps,
    status: 'completed',
  });
}

async function executeStep(
  step: Step,
  signal: AbortSignal,
  onProgress?: (progress: ExecutionProgress) => void
): Promise<void> {
  switch (step.type) {
    case 'click':
      await ipc.executeClick(step.position, step.button);
      break;
      
    case 'keypress':
      await ipc.executeKeypress(step.key, step.modifiers);
      break;
      
    case 'delay':
      await abortableSleep(step.ms, signal);
      break;
      
    case 'pixel-state':
      onProgress?.({ ..., status: 'waiting' });
      await ipc.waitForPixelState(
        step.position, 
        step.color, 
        step.threshold
      );
      break;
      
    case 'pixel-zone':
      onProgress?.({ ..., status: 'waiting' });
      await ipc.waitForPixelZone(
        step.rect,
        step.color,
        step.threshold
      );
      break;
      
    case 'scenario-ref':
      const subScenario = scenariosStore.getState().scenarios
        .find(s => s.id === step.scenarioId);
      if (!subScenario) {
        throw new Error(`Sub-scenario not found: ${step.scenarioId}`);
      }
      await executeScenario(subScenario, signal, onProgress);
      break;
  }
}

function abortableSleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(resolve, ms);
    signal.addEventListener('abort', () => {
      clearTimeout(timeout);
      reject(new DOMException('Aborted', 'AbortError'));
    }, { once: true });
  });
}
```

### 9.2 Implement Play Modal
Create `controller/src/components/PlayModal.tsx`:

```tsx
type ModalPhase = 
  | { phase: 'capture' }
  | { phase: 'ready'; hotkey: string }
  | { phase: 'executing'; progress: ExecutionProgress }
  | { phase: 'done'; error?: string };

export function PlayModal({ scenario, onClose }: Props) {
  const [state, setState] = useState<ModalPhase>({ phase: 'capture' });
  const abortController = useRef<AbortController | null>(null);
  
  useKeyboard((key) => {
    // ESC always closes/aborts
    if (key.name === 'escape') {
      if (state.phase === 'executing') {
        abortController.current?.abort();
      }
      onClose();
      return;
    }
    
    // Phase: capture hotkey
    if (state.phase === 'capture') {
      const hotkey = formatHotkey(key);
      setState({ phase: 'ready', hotkey });
      return;
    }
    
    // Phase: ready - check if hotkey matches
    if (state.phase === 'ready') {
      if (formatHotkey(key) === state.hotkey) {
        startExecution();
      }
    }
  });
  
  async function startExecution() {
    // Hide recorder overlay if visible
    await ipc.hideRecorderOverlay();
    
    abortController.current = new AbortController();
    setState({ phase: 'executing', progress: { currentStep: 0, totalSteps: scenario.steps.length, status: 'running' } });
    
    try {
      await executeScenario(
        scenario,
        abortController.current.signal,
        (progress) => setState({ phase: 'executing', progress })
      );
      setState({ phase: 'done' });
      setTimeout(onClose, 1500);  // Auto-close after success
    } catch (e) {
      if (e.name === 'AbortError') {
        setState({ phase: 'done', error: 'Aborted by user' });
      } else {
        setState({ phase: 'done', error: String(e) });
      }
    }
  }
  
  return (
    <box style={{ /* centered modal */ }}>
      {state.phase === 'capture' && (
        <>
          <text>Press a key combination to trigger execution</text>
          <text fg="#666">(ESC to cancel)</text>
        </>
      )}
      
      {state.phase === 'ready' && (
        <>
          <text>Press <span fg="yellow">{state.hotkey}</span> to execute</text>
          <text fg="#666">"{scenario.name}"</text>
          <text fg="#666">(ESC to cancel)</text>
        </>
      )}
      
      {state.phase === 'executing' && (
        <>
          <text>Executing: {scenario.name}</text>
          <ProgressBar current={state.progress.currentStep} total={state.progress.totalSteps} />
          <text fg="#666">
            {state.progress.status === 'waiting' ? 'Waiting for condition...' : 
             state.progress.currentStepDescription || 'Running...'}
          </text>
          <text fg="#666">(ESC to abort)</text>
        </>
      )}
      
      {state.phase === 'done' && (
        state.error ? (
          <text fg="red">Error: {state.error}</text>
        ) : (
          <text fg="green">Completed successfully!</text>
        )
      )}
    </box>
  );
}
```

### 9.3 Create Progress Bar Component
Create `controller/src/components/ProgressBar.tsx`:

```tsx
interface Props {
  current: number;
  total: number;
  width?: number;
}

export function ProgressBar({ current, total, width = 30 }: Props) {
  const filled = Math.round((current / total) * width);
  const empty = width - filled;
  
  return (
    <text>
      [{'\u2588'.repeat(filled)}{'\u2591'.repeat(empty)}] {current}/{total}
    </text>
  );
}
```

### 9.4 Add Play Command to App
Update `controller/src/components/App.tsx`:

```tsx
export function App() {
  const [showPlayModal, setShowPlayModal] = useState(false);
  
  useKeyboard((key) => {
    // ... other handlers
    
    if (key.name === 'p') {
      const selected = scenariosStore.getSelectedScenario();
      if (selected && selected.steps.length > 0) {
        setShowPlayModal(true);
      }
    }
  });
  
  return (
    <>
      {/* ... main UI ... */}
      
      {showPlayModal && selectedScenario && (
        <PlayModal
          scenario={selectedScenario}
          onClose={() => setShowPlayModal(false)}
        />
      )}
    </>
  );
}
```

### 9.5 Format Hotkey Display
```typescript
function formatHotkey(key: KeyEvent): string {
  const parts: string[] = [];
  if (key.ctrl) parts.push('Ctrl');
  if (key.alt) parts.push('Alt');
  if (key.shift) parts.push('Shift');
  if (key.meta) parts.push('Cmd');
  
  // Handle special key names
  let keyName = key.name;
  if (keyName === ' ') keyName = 'Space';
  if (keyName === 'return') keyName = 'Enter';
  
  parts.push(keyName.toUpperCase());
  return parts.join('+');
}
```

### 9.6 Step Description Formatter
```typescript
function describeStep(step: Step): string {
  switch (step.type) {
    case 'click':
      return `Click ${step.button} at (${step.position.x}, ${step.position.y})`;
    case 'keypress':
      const mods = step.modifiers.join('+');
      return `Press ${mods ? mods + '+' : ''}${step.key}`;
    case 'delay':
      return `Wait ${step.ms}ms`;
    case 'pixel-state':
      return `Wait for pixel at (${step.position.x}, ${step.position.y})`;
    case 'pixel-zone':
      return `Wait for color in zone`;
    case 'scenario-ref':
      return `Run sub-scenario`;
  }
}
```

### 9.7 Test Execution
Manual test checklist:
1. Select scenario with steps
2. Press `p` → modal shows "Press a key..."
3. Press a key (e.g., F1) → modal shows "Press F1 to execute"
4. Press F1 → execution starts
5. Progress bar updates
6. "Waiting for condition..." shows during pixel waits
7. Execution completes → "Completed!" message
8. Press ESC during execution → "Aborted" message
9. Test with sub-scenario reference

---

## Acceptance Criteria
- [ ] `p` opens play modal when scenario selected
- [ ] Modal captures any key/combo as trigger
- [ ] Pressing trigger starts execution
- [ ] Progress bar shows current/total steps
- [ ] Status shows "Running" or "Waiting for condition"
- [ ] ESC aborts execution cleanly
- [ ] Completion shows success message
- [ ] Errors are displayed
- [ ] Sub-scenarios execute recursively
- [ ] Recorder overlay hidden during execution
- [ ] Scenario `lastUsedAt` updated after execution

---

## Files Created
```
controller/src/
├── execution/
│   └── executor.ts
└── components/
    ├── PlayModal.tsx
    └── ProgressBar.tsx
```

## Estimated Time: 4-5 hours
