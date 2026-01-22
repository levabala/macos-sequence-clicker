# Phase 10: Preview & Polish

## Goal
Complete step preview with ASCII visualizations, implement remaining features, and polish the application.

## Prerequisites
- All previous phases complete

## Deliverables
- [ ] ASCII screen diagram for pixel position
- [ ] ASCII zone visualization
- [ ] Step deletion with `d`
- [ ] Undo with `u`
- [ ] Scenario rename with `n`
- [ ] Sub-scenario navigation (Ctrl+l into, Ctrl+h out)
- [ ] Error handling throughout
- [ ] Edge case handling

---

## Tasks

### 10.1 ASCII Screen Position Diagram
Update `controller/src/components/StepPreview.tsx`:

```tsx
function ScreenPositionDiagram({ x, y, color }: { x: number; y: number; color?: string }) {
  // Assume 1920x1080, scale to 30x15 ASCII
  const screenW = 1920, screenH = 1080;
  const diagW = 28, diagH = 12;
  
  const px = Math.round((x / screenW) * (diagW - 2));
  const py = Math.round((y / screenH) * (diagH - 2));
  
  const lines: string[] = [];
  lines.push('┌' + '─'.repeat(diagW) + '┐');
  
  for (let row = 0; row < diagH; row++) {
    let line = '│';
    for (let col = 0; col < diagW; col++) {
      if (row === py && col === px) {
        line += '×';  // Pixel position marker
      } else {
        line += ' ';
      }
    }
    line += '│';
    lines.push(line);
  }
  
  lines.push('└' + '─'.repeat(diagW) + '┘');
  
  return (
    <box flexDirection="column">
      {lines.map((line, i) => (
        <text key={i} fg="#666">{line}</text>
      ))}
      {color && (
        <text>
          Color: <span fg={color}>████</span> {color}
        </text>
      )}
    </box>
  );
}
```

### 10.2 ASCII Zone Visualization
```tsx
function ScreenZoneDiagram({ x, y, width, height, color }: { 
  x: number; y: number; width: number; height: number; color: string 
}) {
  const screenW = 1920, screenH = 1080;
  const diagW = 28, diagH = 12;
  
  // Scale zone to diagram coordinates
  const zx1 = Math.round((x / screenW) * (diagW - 2));
  const zy1 = Math.round((y / screenH) * (diagH - 2));
  const zx2 = Math.round(((x + width) / screenW) * (diagW - 2));
  const zy2 = Math.round(((y + height) / screenH) * (diagH - 2));
  
  const lines: string[] = [];
  lines.push('┌' + '─'.repeat(diagW) + '┐');
  
  for (let row = 0; row < diagH; row++) {
    let line = '│';
    for (let col = 0; col < diagW; col++) {
      const inZone = col >= zx1 && col <= zx2 && row >= zy1 && row <= zy2;
      line += inZone ? '█' : ' ';
    }
    line += '│';
    lines.push(line);
  }
  
  lines.push('└' + '─'.repeat(diagW) + '┘');
  
  return (
    <box flexDirection="column">
      {lines.map((line, i) => (
        <text key={i} fg="#666">{line}</text>
      ))}
      <text>Target: <span fg={color}>████</span> {color}</text>
    </box>
  );
}
```

### 10.3 Complete Step Previews
For each step type:

**Click:**
- Position coordinates
- Button (Left/Right)
- Screen position diagram

**Keypress:**
- Key name
- Modifiers (⌘ ⌃ ⌥ ⇧)

**Delay:**
- Duration in ms
- Human readable (e.g., "2.5 seconds")

**Pixel State:**
- Position coordinates
- Color hex + RGB
- Threshold value
- Screen position diagram with color

**Pixel Zone:**
- Position and size
- Target color
- Threshold
- Zone diagram with color

**Scenario Ref:**
- Referenced scenario name
- Step count
- Hint: "Ctrl+L to enter"

### 10.4 Implement Deletion
Update `controller/src/components/App.tsx`:

```tsx
useKeyboard((key) => {
  if (key.name === 'd') {
    const { selectedScenarioId, selectedStepIndex } = scenariosStore.getState();
    if (selectedScenarioId && selectedStepIndex !== null) {
      historyStore.deleteStep(selectedScenarioId, selectedStepIndex);
      
      // Adjust selection
      const scenario = scenariosStore.getSelectedScenario();
      if (scenario && selectedStepIndex >= scenario.steps.length) {
        scenariosStore.selectStep(Math.max(0, scenario.steps.length - 1));
      }
    }
  }
});
```

### 10.5 Implement Undo
```tsx
useKeyboard((key) => {
  if (key.name === 'u') {
    const success = historyStore.undo();
    if (success) {
      // Optionally show a message or update selection
    }
  }
});
```

### 10.6 Implement Scenario Rename
```tsx
useKeyboard((key) => {
  if (key.name === 'n') {
    const selected = scenariosStore.getSelectedScenario();
    if (selected && !recorderStore.isRecording()) {
      recorderStore.startNaming(selected.id);
      // Pre-fill with current name? Or start empty?
    }
  }
});
```

Update naming mode to handle existing scenario:
```typescript
// In recorder store
startNaming(scenarioId: string, initialName?: string) {
  state = { 
    status: 'naming', 
    scenarioId, 
    name: initialName ?? '' 
  };
}

// When finishing
finishNaming(): string | null {
  if (state.status === 'naming') {
    const name = state.name.trim() || 'Unnamed';
    scenariosStore.updateScenarioName(state.scenarioId, name);
    state = { status: 'idle' };
    return name;
  }
  return null;
}
```

### 10.7 Sub-scenario Navigation
Update `hooks/useVimNavigation.ts`:

```typescript
select(): void {
  if (nav.column === 1 && selectedStepIndex !== null) {
    const step = selectedScenario?.steps[selectedStepIndex];
    if (step?.type === 'scenario-ref') {
      // Push current scenario to depth stack
      nav.scenarioDepth.push(selectedScenarioId);
      // Select the referenced scenario
      scenariosStore.selectScenario(step.scenarioId);
      scenariosStore.selectStep(0);
    }
  }
}

back(): void {
  if (nav.column === 1 && nav.scenarioDepth.length > 0) {
    // Pop from depth stack
    const parentId = nav.scenarioDepth.pop();
    scenariosStore.selectScenario(parentId);
    scenariosStore.selectStep(null);
  }
}
```

Show breadcrumb in steps header:
```tsx
<box title={`Steps${nav.scenarioDepth.length > 0 ? ' (sub)' : ''}`}>
```

### 10.8 Error Handling
Add error boundaries and handlers:

**IPC errors:**
```typescript
try {
  await ipc.executeClick(...);
} catch (e) {
  if (e.message.includes('permission')) {
    showError('Permission denied. Check System Settings.');
  } else {
    showError(`Action failed: ${e.message}`);
  }
}
```

**Swift helper crash:**
```typescript
swiftBridge.on('exit', (code) => {
  if (code !== 0) {
    showError('Swift helper crashed. Restarting...');
    swiftBridge.start();
  }
});
```

**Invalid scenarios:**
```typescript
// When loading
scenarios.filter(s => {
  if (!s.id || !s.name) {
    console.warn('Skipping invalid scenario');
    return false;
  }
  return true;
});
```

### 10.9 Edge Cases
Handle:
- Empty scenario (no steps) → show "No steps" message
- Scenario with invalid sub-scenario ref → show error in preview
- Very long scenario names → truncate with ellipsis
- Many scenarios → scroll behavior (if OpenTUI supports)
- Screen resolution changes → update diagrams
- Permission revoked during use → graceful error

### 10.10 Final Testing
Comprehensive test:
1. Fresh start with no scenarios
2. Create scenario, record various steps
3. Delete steps, undo
4. Rename scenario
5. Create second scenario with sub-scenario ref
6. Navigate into sub-scenario and back
7. Execute scenario with all step types
8. Abort during execution
9. Close and reopen (persistence)

---

## Acceptance Criteria
- [ ] Pixel position shows ASCII diagram with marker
- [ ] Pixel zone shows ASCII diagram with filled area
- [ ] Color displays as colored block + hex code
- [ ] `d` deletes selected step
- [ ] `u` undoes deletion
- [ ] `n` enables rename mode
- [ ] Ctrl+L on scenario-ref enters sub-scenario
- [ ] Ctrl+H exits sub-scenario
- [ ] Breadcrumb shows when in sub-scenario
- [ ] Errors display gracefully
- [ ] No crashes on edge cases
- [ ] All features work together

---

## Files Modified
```
controller/src/
├── components/
│   ├── StepPreview.tsx          (major updates)
│   ├── App.tsx                  (add d/u/n handlers)
│   └── StepsViewer.tsx          (breadcrumb)
├── hooks/
│   └── useVimNavigation.ts      (sub-scenario nav)
└── store/
    └── recorder.ts              (rename support)
```

## Estimated Time: 5-6 hours
