# Phase 6: Terminal UI

## Goal
Build the three-column terminal interface with vim-style navigation using OpenTUI/React.

## Prerequisites
- Phase 3 complete (Controller package initialized)
- Phase 5 complete (State stores working)

## Deliverables
- [ ] Three-column layout rendering
- [ ] Vim navigation hook (h/j/k/l, Ctrl+h/l)
- [ ] Scenario list component with selection
- [ ] Steps viewer component with selection
- [ ] Step preview component (basic)
- [ ] Status bar with keybinding hints

---

## Tasks

### 6.1 Create App Shell
Create `controller/src/components/App.tsx`:

```tsx
export function App() {
  return (
    <box flexDirection="column" width="100%" height="100%">
      {/* Header */}
      <box border height={3}>
        <text>macOS Smart Sequencer</text>
      </box>
      
      {/* Main content - 3 columns */}
      <box flexDirection="row" flexGrow={1}>
        <box width="20%" border title="Scenarios">
          <ScenarioList />
        </box>
        <box width="40%" border title="Steps">
          <StepsViewer />
        </box>
        <box width="40%" border title="Preview">
          <StepPreview />
        </box>
      </box>
      
      {/* Status bar */}
      <StatusBar />
    </box>
  );
}
```

### 6.2 Implement Vim Navigation Hook
Create `controller/src/hooks/useVimNavigation.ts`:

```typescript
interface NavState {
  column: 0 | 1 | 2;  // scenarios, steps, preview
  scenarioDepth: string[];  // For sub-scenario navigation
}

export function useVimNavigation() {
  const [nav, setNav] = useState<NavState>({ column: 0, scenarioDepth: [] });
  
  return {
    column: nav.column,
    moveLeft(): void,   // h
    moveRight(): void,  // l
    moveUp(): void,     // k - moves selection up in current column
    moveDown(): void,   // j - moves selection down in current column
    select(): void,     // Ctrl+l - select scenario or enter sub-scenario
    back(): void,       // Ctrl+h - deselect or exit sub-scenario
    swapUp(): void,     // Ctrl+k - swap step with above
    swapDown(): void,   // Ctrl+j - swap step with below
    getScenarioIndex(): number,
  };
}
```

Navigation rules:
- Column 0 (scenarios): j/k moves selection, Ctrl+l focuses column 1
- Column 1 (steps): j/k moves selection, Ctrl+j/k reorders, Ctrl+h goes back
- Column 2 (preview): read-only, h goes back to column 1

### 6.3 Implement Scenario List
Create `controller/src/components/ScenarioList.tsx`:

```tsx
interface Props {
  focused: boolean;
  selectedIndex: number;
}

export function ScenarioList({ focused, selectedIndex }: Props) {
  const scenarios = scenariosStore.getSortedScenarios();
  const { selectedScenarioId } = scenariosStore.getState();
  const recorderState = recorderStore.getState();
  
  return (
    <box flexDirection="column">
      {scenarios.map((scenario, index) => (
        <ScenarioRow
          key={scenario.id}
          scenario={scenario}
          isSelected={scenario.id === selectedScenarioId}
          isFocused={focused && index === selectedIndex}
          isRecording={recorderState.status === 'recording' && 
                       recorderState.scenarioId === scenario.id}
        />
      ))}
    </box>
  );
}
```

Display:
- `>` prefix for focused row
- `●` suffix for recording scenario
- Highlight background for selected

### 6.4 Implement Steps Viewer
Create `controller/src/components/StepsViewer.tsx`:

```tsx
interface Props {
  scenario: Scenario | null;
  focused: boolean;
  selectedIndex: number | null;
}

export function StepsViewer({ scenario, focused, selectedIndex }: Props) {
  if (!scenario) {
    return <text fg="#666">Select a scenario</text>;
  }
  
  return (
    <box flexDirection="column">
      {scenario.steps.map((step, index) => (
        <StepRow
          key={index}
          step={step}
          index={index}
          isFocused={focused && index === selectedIndex}
        />
      ))}
    </box>
  );
}
```

Step formatting:
- `1. Click L (100, 200)` - click action
- `2. Key ⌘S` - keypress action
- `3. Delay 500ms` - delay transition
- `4. Pixel (300, 400)` - pixel state
- `5. Zone 50×30` - pixel zone
- `6. → [scenario-name]` - scenario ref

### 6.5 Implement Basic Step Preview
Create `controller/src/components/StepPreview.tsx`:

```tsx
export function StepPreview({ step, focused }: Props) {
  if (!step) {
    return <text fg="#666">Select a step to preview</text>;
  }
  
  switch (step.type) {
    case 'click':
      return <ClickPreview step={step} />;
    case 'keypress':
      return <KeypressPreview step={step} />;
    case 'delay':
      return <DelayPreview step={step} />;
    case 'pixel-state':
      return <PixelStatePreview step={step} />;
    case 'pixel-zone':
      return <PixelZonePreview step={step} />;
    case 'scenario-ref':
      return <ScenarioRefPreview step={step} />;
  }
}
```

For now, show basic text info. ASCII diagrams in Phase 9.

### 6.6 Implement Status Bar
Create `controller/src/components/StatusBar.tsx`:

```tsx
export function StatusBar() {
  const canUndo = historyStore.canUndo();
  
  return (
    <box border height={3} padding={1}>
      <text fg="#888">
        h/l: columns | j/k: rows | C-l: select | C-h: back | d: delete
        {canUndo && ' | u: undo'}
      </text>
    </box>
  );
}
```

### 6.7 Wire Up Keyboard Handling
Update `controller/src/components/App.tsx`:

```tsx
export function App() {
  const nav = useVimNavigation();
  
  useKeyboard((key) => {
    // Navigation
    if (key.name === 'h') nav.moveLeft();
    if (key.name === 'l') nav.moveRight();
    if (key.name === 'j') nav.moveDown();
    if (key.name === 'k') nav.moveUp();
    if (key.ctrl && key.name === 'l') nav.select();
    if (key.ctrl && key.name === 'h') nav.back();
    if (key.ctrl && key.name === 'j') nav.swapDown();
    if (key.ctrl && key.name === 'k') nav.swapUp();
    
    // Actions (to be implemented in later phases)
    if (key.name === 'd') { /* delete step */ }
    if (key.name === 'u') { /* undo */ }
    if (key.name === 'n') { /* rename */ }
    if (key.name === 'r') { /* record */ }
    if (key.name === 'p') { /* play */ }
  });
  
  // ... render
}
```

### 6.8 Update Entry Point
Update `controller/src/index.tsx`:

```tsx
import { createCliRenderer } from '@opentui/core';
import { createRoot } from '@opentui/react';
import { App } from './components/App';
import { swiftBridge } from './ipc/bridge';
import { scenariosStore } from './store/scenarios';
import { ipc } from './ipc/protocol';

async function main() {
  // Start Swift helper
  await swiftBridge.start();
  
  // Check permissions
  const permissions = await ipc.checkPermissions();
  if (!permissions.accessibility || !permissions.screenRecording) {
    console.error('Missing permissions. Enable in System Settings.');
    process.exit(1);
  }
  
  // Load scenarios
  await scenariosStore.load();
  
  // Start UI
  const renderer = await createCliRenderer({ exitOnCtrlC: false });
  createRoot(renderer).render(<App />);
}

main().catch(console.error);
```

---

## Acceptance Criteria
- [ ] UI renders with three columns
- [ ] h/l navigates between columns
- [ ] j/k navigates within columns
- [ ] Ctrl+l selects scenario (moves focus to steps)
- [ ] Ctrl+h deselects (moves focus to scenarios)
- [ ] Ctrl+j/k swaps steps in steps column
- [ ] Selected scenario/step is highlighted
- [ ] Focus indicator (>) shows current position
- [ ] Empty states show helpful messages
- [ ] Status bar shows available commands

---

## Files Created
```
controller/src/
├── index.tsx                    (updated)
├── components/
│   ├── App.tsx
│   ├── ScenarioList.tsx
│   ├── StepsViewer.tsx
│   ├── StepPreview.tsx
│   └── StatusBar.tsx
└── hooks/
    └── useVimNavigation.ts
```

## Estimated Time: 5-6 hours
