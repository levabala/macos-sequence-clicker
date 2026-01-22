# Part 5: Terminal UI

## Overview

The terminal UI uses OpenTUI/React with vim-style navigation. It consists of:
- Three-column layout (scenarios, steps, preview)
- Vim keybindings for navigation
- Modal for play hotkey capture

## Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ macOS Smart Sequencer                                          [r]ec [p]lay │
├─────────────────┬───────────────────────────┬───────────────────────────────┤
│   Scenarios     │         Steps             │          Preview              │
├─────────────────┼───────────────────────────┼───────────────────────────────┤
│ > Morning Setup │  1. Click (100, 200)      │ ┌─ Click Action ────────────┐ │
│   Video Export  │  2. Delay 500ms           │ │ Position: (100, 200)      │ │
│   Batch Process │  3. KeyPress ⌘+S          │ │ Button: Left              │ │
│                 │> 4. Pixel (300, 400)      │ │                           │ │
│                 │  5. Click (500, 600)      │ │ ┌────────────────────┐    │ │
│                 │                           │ │ │                    │    │ │
│                 │                           │ │ │         ×          │    │ │
│                 │                           │ │ │                    │    │ │
│                 │                           │ │ └────────────────────┘    │ │
│                 │                           │ └───────────────────────────┘ │
├─────────────────┴───────────────────────────┴───────────────────────────────┤
│ h/l: columns | j/k: rows | C-l: select | C-h: back | d: delete | u: undo    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Bindings

| Key | Context | Action |
|-----|---------|--------|
| `h` | Any | Move to left column |
| `l` | Any | Move to right column |
| `j` | Any column | Move down in current column |
| `k` | Any column | Move up in current column |
| `Ctrl+l` | Scenarios column | Select scenario (focus steps) |
| `Ctrl+l` | Steps (on sub-scenario) | Enter sub-scenario |
| `Ctrl+h` | Steps column | Deselect scenario (focus scenarios) |
| `Ctrl+h` | Steps (in sub-scenario) | Back to parent scenario |
| `Ctrl+j` | Steps column | Swap current step with below |
| `Ctrl+k` | Steps column | Swap current step with above |
| `n` | Scenario selected | Edit scenario name |
| `r` | No scenario selected | Create new scenario + record |
| `r` | Scenario selected | Record after current step |
| `r` | Recording | Stop recording |
| `p` | Scenario selected | Open play modal |
| `d` | Step selected | Delete step (adds to undo stack) |
| `u` | Any | Undo last step deletion |
| `Esc` | During execution | Abort execution |
| `Esc` | In modal | Close modal |

## Components

### App.tsx

```tsx
// components/App.tsx
import { useEffect, useState } from 'react';
import { useKeyboard } from '@opentui/react';
import { ScenarioList } from './ScenarioList';
import { StepsViewer } from './StepsViewer';
import { StepPreview } from './StepPreview';
import { PlayModal } from './PlayModal';
import { StatusBar } from './StatusBar';
import { useVimNavigation } from '../hooks/useVimNavigation';
import { useRecording } from '../hooks/useRecording';
import { scenariosStore } from '../store/scenarios';
import { historyStore } from '../store/history';
import { recorderStore } from '../store/recorder';

export function App() {
  const [showPlayModal, setShowPlayModal] = useState(false);
  const nav = useVimNavigation();
  const recording = useRecording();

  // Subscribe to stores
  const [scenarios, setScenarios] = useState(scenariosStore.getState());
  const [recorder, setRecorder] = useState(recorderStore.getState());

  useEffect(() => {
    const unsub1 = scenariosStore.subscribe(() => setScenarios(scenariosStore.getState()));
    const unsub2 = recorderStore.subscribe(() => setRecorder(recorderStore.getState()));
    return () => { unsub1(); unsub2(); };
  }, []);

  useKeyboard((key) => {
    // Handle naming mode separately
    if (recorder.status === 'naming') {
      if (key.name === 'return') {
        recording.finishNaming();
      } else if (key.name === 'backspace') {
        recorderStore.backspaceName();
      } else if (key.name.length === 1) {
        recorderStore.appendToName(key.name);
      }
      return;
    }

    // Handle play modal
    if (showPlayModal) {
      if (key.name === 'escape') {
        setShowPlayModal(false);
      }
      // Hotkey capture handled by PlayModal
      return;
    }

    // Navigation
    if (key.name === 'h') nav.moveLeft();
    if (key.name === 'l') nav.moveRight();
    if (key.name === 'j') nav.moveDown();
    if (key.name === 'k') nav.moveUp();

    // Selection with Ctrl
    if (key.ctrl && key.name === 'l') nav.select();
    if (key.ctrl && key.name === 'h') nav.back();

    // Reorder with Ctrl+j/k
    if (key.ctrl && key.name === 'j') nav.swapDown();
    if (key.ctrl && key.name === 'k') nav.swapUp();

    // Actions
    if (key.name === 'n' && scenarios.selectedScenarioId) {
      recorderStore.startNaming(scenarios.selectedScenarioId);
    }

    if (key.name === 'r') {
      recording.toggleRecording();
    }

    if (key.name === 'p' && scenarios.selectedScenarioId) {
      setShowPlayModal(true);
    }

    if (key.name === 'd' && scenarios.selectedStepIndex !== null) {
      historyStore.deleteStep(
        scenarios.selectedScenarioId!,
        scenarios.selectedStepIndex
      );
    }

    if (key.name === 'u') {
      historyStore.undo();
    }
  });

  const selectedScenario = scenariosStore.getSelectedScenario();
  const selectedStep = selectedScenario?.steps[scenarios.selectedStepIndex ?? -1];

  return (
    <box flexDirection="column" width="100%" height="100%">
      {/* Header */}
      <box border borderStyle="single" height={3} padding={1}>
        <text>
          macOS Smart Sequencer
          {recorder.status === 'recording' && (
            <span fg="red"> ● REC</span>
          )}
        </text>
        <box flexGrow={1} />
        <text fg="#888">
          [r]ec [p]lay
        </text>
      </box>

      {/* Main content */}
      <box flexDirection="row" flexGrow={1}>
        {/* Scenarios column */}
        <box width="20%" border borderStyle="single">
          <ScenarioList
            focused={nav.column === 0}
            selectedIndex={nav.getScenarioIndex()}
          />
        </box>

        {/* Steps column */}
        <box width="40%" border borderStyle="single">
          <StepsViewer
            scenario={selectedScenario}
            focused={nav.column === 1}
            selectedIndex={scenarios.selectedStepIndex}
          />
        </box>

        {/* Preview column */}
        <box width="40%" border borderStyle="single">
          <StepPreview
            step={selectedStep}
            focused={nav.column === 2}
          />
        </box>
      </box>

      {/* Status bar */}
      <StatusBar />

      {/* Play modal */}
      {showPlayModal && selectedScenario && (
        <PlayModal
          scenario={selectedScenario}
          onClose={() => setShowPlayModal(false)}
        />
      )}
    </box>
  );
}
```

### ScenarioList.tsx

```tsx
// components/ScenarioList.tsx
import { useEffect, useState } from 'react';
import { scenariosStore } from '../store/scenarios';
import { recorderStore } from '../store/recorder';
import type { Scenario } from '@sequencer/schema';

interface Props {
  focused: boolean;
  selectedIndex: number;
}

export function ScenarioList({ focused, selectedIndex }: Props) {
  const [state, setState] = useState(scenariosStore.getState());
  const [recorder, setRecorder] = useState(recorderStore.getState());

  useEffect(() => {
    const unsub1 = scenariosStore.subscribe(() => setState(scenariosStore.getState()));
    const unsub2 = recorderStore.subscribe(() => setRecorder(recorderStore.getState()));
    return () => { unsub1(); unsub2(); };
  }, []);

  const scenarios = scenariosStore.getSortedScenarios();

  return (
    <box flexDirection="column" title="Scenarios">
      {scenarios.length === 0 ? (
        <text fg="#666">No scenarios yet. Press 'r' to create one.</text>
      ) : (
        scenarios.map((scenario, index) => (
          <ScenarioRow
            key={scenario.id}
            scenario={scenario}
            isSelected={state.selectedScenarioId === scenario.id}
            isFocused={focused && index === selectedIndex}
            isRecording={
              recorder.status === 'recording' && 
              recorder.scenarioId === scenario.id
            }
            isNaming={
              recorder.status === 'naming' && 
              recorder.scenarioId === scenario.id
            }
            namingValue={
              recorder.status === 'naming' ? recorder.name : undefined
            }
          />
        ))
      )}
    </box>
  );
}

interface ScenarioRowProps {
  scenario: Scenario;
  isSelected: boolean;
  isFocused: boolean;
  isRecording: boolean;
  isNaming: boolean;
  namingValue?: string;
}

function ScenarioRow({ 
  scenario, 
  isSelected, 
  isFocused, 
  isRecording,
  isNaming,
  namingValue 
}: ScenarioRowProps) {
  const prefix = isFocused ? '>' : ' ';
  const bg = isFocused ? '#333' : isSelected ? '#222' : undefined;
  
  let displayName = scenario.name;
  if (isNaming) {
    displayName = namingValue + '█';  // Show cursor
  }

  return (
    <box backgroundColor={bg}>
      <text>
        {prefix} {displayName}
        {isRecording && <span fg="red"> ●</span>}
      </text>
    </box>
  );
}
```

### StepsViewer.tsx

```tsx
// components/StepsViewer.tsx
import type { Scenario, Step } from '@sequencer/schema';

interface Props {
  scenario: Scenario | null;
  focused: boolean;
  selectedIndex: number | null;
}

export function StepsViewer({ scenario, focused, selectedIndex }: Props) {
  if (!scenario) {
    return (
      <box flexDirection="column" title="Steps">
        <text fg="#666">Select a scenario to view steps</text>
      </box>
    );
  }

  if (scenario.steps.length === 0) {
    return (
      <box flexDirection="column" title="Steps">
        <text fg="#666">No steps yet. Press 'r' to start recording.</text>
      </box>
    );
  }

  return (
    <box flexDirection="column" title={`Steps - ${scenario.name}`}>
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

interface StepRowProps {
  step: Step;
  index: number;
  isFocused: boolean;
}

function StepRow({ step, index, isFocused }: StepRowProps) {
  const prefix = isFocused ? '>' : ' ';
  const bg = isFocused ? '#333' : undefined;
  const num = String(index + 1).padStart(2, ' ');

  return (
    <box backgroundColor={bg}>
      <text>
        {prefix} {num}. {formatStep(step)}
      </text>
    </box>
  );
}

function formatStep(step: Step): string {
  switch (step.type) {
    case 'click':
      const btn = step.button === 'right' ? 'R' : 'L';
      return `Click ${btn} (${step.position.x}, ${step.position.y})`;
    
    case 'keypress':
      const mods = step.modifiers.map(m => {
        switch (m) {
          case 'cmd': return '⌘';
          case 'ctrl': return '⌃';
          case 'alt': return '⌥';
          case 'shift': return '⇧';
          default: return m;
        }
      }).join('');
      return `Key ${mods}${step.key}`;
    
    case 'delay':
      return `Delay ${formatDuration(step.ms)}`;
    
    case 'pixel-state':
      return `Pixel (${step.position.x}, ${step.position.y})`;
    
    case 'pixel-zone':
      return `Zone (${step.rect.x}, ${step.rect.y}) ${step.rect.width}×${step.rect.height}`;
    
    case 'scenario-ref':
      return `→ [${step.scenarioId.slice(0, 8)}...]`;
    
    default:
      return 'Unknown';
  }
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  return `${(ms / 60000).toFixed(1)}m`;
}
```

### StepPreview.tsx

```tsx
// components/StepPreview.tsx
import type { Step } from '@sequencer/schema';

interface Props {
  step: Step | undefined;
  focused: boolean;
}

export function StepPreview({ step, focused }: Props) {
  if (!step) {
    return (
      <box flexDirection="column" title="Preview">
        <text fg="#666">Select a step to preview</text>
      </box>
    );
  }

  return (
    <box flexDirection="column" title="Preview">
      {renderStepPreview(step)}
    </box>
  );
}

function renderStepPreview(step: Step) {
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
    default:
      return <text>Unknown step type</text>;
  }
}

function ClickPreview({ step }: { step: { type: 'click'; position: { x: number; y: number }; button: string } }) {
  return (
    <box flexDirection="column">
      <box border title="Click Action" padding={1}>
        <text>Position: ({step.position.x}, {step.position.y})</text>
        <text>Button: {step.button === 'right' ? 'Right' : 'Left'}</text>
      </box>
      <box height={1} />
      <ScreenPositionDiagram x={step.position.x} y={step.position.y} />
    </box>
  );
}

function KeypressPreview({ step }: { step: { type: 'keypress'; key: string; modifiers: string[] } }) {
  const modSymbols = step.modifiers.map(m => {
    switch (m) {
      case 'cmd': return '⌘ Command';
      case 'ctrl': return '⌃ Control';
      case 'alt': return '⌥ Option';
      case 'shift': return '⇧ Shift';
      default: return m;
    }
  });

  return (
    <box flexDirection="column">
      <box border title="Keypress Action" padding={1}>
        <text>Key: {step.key}</text>
        {modSymbols.length > 0 && (
          <text>Modifiers: {modSymbols.join(' + ')}</text>
        )}
      </box>
    </box>
  );
}

function DelayPreview({ step }: { step: { type: 'delay'; ms: number } }) {
  return (
    <box flexDirection="column">
      <box border title="Delay Transition" padding={1}>
        <text>Duration: {step.ms}ms</text>
        <text>({formatHumanDuration(step.ms)})</text>
      </box>
    </box>
  );
}

function PixelStatePreview({ step }: { step: { type: 'pixel-state'; position: { x: number; y: number }; color: { r: number; g: number; b: number }; threshold: number } }) {
  const hex = rgbToHex(step.color);
  
  return (
    <box flexDirection="column">
      <box border title="Pixel State Transition" padding={1}>
        <text>Position: ({step.position.x}, {step.position.y})</text>
        <text>Color: {hex} ({step.color.r}, {step.color.g}, {step.color.b})</text>
        <text>Threshold: {step.threshold}</text>
      </box>
      <box height={1} />
      <ScreenPositionDiagram 
        x={step.position.x} 
        y={step.position.y} 
        color={hex}
      />
    </box>
  );
}

function PixelZonePreview({ step }: { step: { type: 'pixel-zone'; rect: { x: number; y: number; width: number; height: number }; color: { r: number; g: number; b: number }; threshold: number } }) {
  const hex = rgbToHex(step.color);
  
  return (
    <box flexDirection="column">
      <box border title="Pixel Zone Transition" padding={1}>
        <text>Position: ({step.rect.x}, {step.rect.y})</text>
        <text>Size: {step.rect.width} × {step.rect.height}</text>
        <text>Target Color: {hex}</text>
        <text>Threshold: {step.threshold}</text>
      </box>
      <box height={1} />
      <ScreenZoneDiagram 
        x={step.rect.x} 
        y={step.rect.y}
        width={step.rect.width}
        height={step.rect.height}
        color={hex}
      />
    </box>
  );
}

function ScenarioRefPreview({ step }: { step: { type: 'scenario-ref'; scenarioId: string } }) {
  return (
    <box flexDirection="column">
      <box border title="Scenario Reference" padding={1}>
        <text>References: {step.scenarioId}</text>
        <text fg="#666">Press Ctrl+L to enter</text>
      </box>
    </box>
  );
}

// ASCII diagram showing pixel position on screen
function ScreenPositionDiagram({ x, y, color }: { x: number; y: number; color?: string }) {
  // Assume 1920x1080 screen, scale to 30x15 ASCII
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
        line += '×';
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

// ASCII diagram showing zone on screen
function ScreenZoneDiagram({ x, y, width, height, color }: { 
  x: number; y: number; width: number; height: number; color: string 
}) {
  const screenW = 1920, screenH = 1080;
  const diagW = 28, diagH = 12;
  
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
      <text>
        Target: <span fg={color}>████</span> {color}
      </text>
    </box>
  );
}

function rgbToHex(color: { r: number; g: number; b: number }): string {
  const toHex = (n: number) => n.toString(16).padStart(2, '0');
  return `#${toHex(color.r)}${toHex(color.g)}${toHex(color.b)}`.toUpperCase();
}

function formatHumanDuration(ms: number): string {
  if (ms < 1000) return `${ms} milliseconds`;
  if (ms < 60000) {
    const s = ms / 1000;
    return `${s.toFixed(1)} second${s !== 1 ? 's' : ''}`;
  }
  const m = ms / 60000;
  return `${m.toFixed(1)} minute${m !== 1 ? 's' : ''}`;
}
```

### PlayModal.tsx

```tsx
// components/PlayModal.tsx
import { useState, useEffect, useRef } from 'react';
import { useKeyboard } from '@opentui/react';
import type { Scenario } from '@sequencer/schema';
import { executeScenario, type ExecutionProgress } from '../execution/executor';

interface Props {
  scenario: Scenario;
  onClose: () => void;
}

type ModalState = 
  | { phase: 'capture' }
  | { phase: 'ready'; hotkey: string }
  | { phase: 'executing'; progress: ExecutionProgress }
  | { phase: 'done'; error?: string };

export function PlayModal({ scenario, onClose }: Props) {
  const [state, setState] = useState<ModalState>({ phase: 'capture' });
  const abortController = useRef<AbortController | null>(null);

  useKeyboard((key) => {
    if (key.name === 'escape') {
      if (state.phase === 'executing') {
        abortController.current?.abort();
      }
      onClose();
      return;
    }

    if (state.phase === 'capture') {
      // Capture the hotkey
      const modifiers: string[] = [];
      if (key.ctrl) modifiers.push('Ctrl');
      if (key.alt) modifiers.push('Alt');
      if (key.shift) modifiers.push('Shift');
      if (key.meta) modifiers.push('Cmd');
      
      const hotkey = [...modifiers, key.name.toUpperCase()].join('+');
      setState({ phase: 'ready', hotkey });
      return;
    }

    if (state.phase === 'ready') {
      // Check if pressed key matches captured hotkey
      const modifiers: string[] = [];
      if (key.ctrl) modifiers.push('Ctrl');
      if (key.alt) modifiers.push('Alt');
      if (key.shift) modifiers.push('Shift');
      if (key.meta) modifiers.push('Cmd');
      
      const pressed = [...modifiers, key.name.toUpperCase()].join('+');
      
      if (pressed === state.hotkey) {
        startExecution();
      }
    }
  });

  async function startExecution() {
    abortController.current = new AbortController();
    setState({ 
      phase: 'executing', 
      progress: { currentStep: 0, totalSteps: scenario.steps.length, status: 'running' } 
    });

    try {
      await executeScenario(
        scenario,
        abortController.current.signal,
        (progress) => setState({ phase: 'executing', progress })
      );
      setState({ phase: 'done' });
      setTimeout(onClose, 1500);
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') {
        setState({ phase: 'done', error: 'Aborted' });
      } else {
        setState({ phase: 'done', error: String(e) });
      }
    }
  }

  return (
    <box
      style={{
        position: 'absolute',
        top: '50%',
        left: '50%',
        transform: 'translate(-50%, -50%)',
        width: 50,
        height: 10,
        border: true,
        borderStyle: 'double',
        backgroundColor: '#1a1a1a',
        padding: 2,
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
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
          <text>
            Step {state.progress.currentStep + 1} / {state.progress.totalSteps}
          </text>
          <text fg="#666">
            {state.progress.status === 'waiting' ? 'Waiting for condition...' : 'Running...'}
          </text>
          <text fg="#666">(ESC to abort)</text>
        </>
      )}

      {state.phase === 'done' && (
        <>
          {state.error ? (
            <text fg="red">Error: {state.error}</text>
          ) : (
            <text fg="green">Completed!</text>
          )}
        </>
      )}
    </box>
  );
}
```

### StatusBar.tsx

```tsx
// components/StatusBar.tsx
import { useEffect, useState } from 'react';
import { historyStore } from '../store/history';

export function StatusBar() {
  const [canUndo, setCanUndo] = useState(historyStore.canUndo());

  useEffect(() => {
    return historyStore.subscribe(() => setCanUndo(historyStore.canUndo()));
  }, []);

  return (
    <box 
      border 
      borderStyle="single" 
      height={3}
      padding={1}
      flexDirection="row"
    >
      <text fg="#888">
        h/l: columns | j/k: rows | C-l: select | C-h: back | d: delete
        {canUndo && ' | u: undo'}
      </text>
    </box>
  );
}
```

## Hooks

### useVimNavigation.ts

```typescript
// hooks/useVimNavigation.ts
import { useState, useCallback } from 'react';
import { scenariosStore } from '../store/scenarios';

interface NavState {
  column: 0 | 1 | 2;  // 0=scenarios, 1=steps, 2=preview
  scenarioDepth: string[];  // Stack of scenario IDs for sub-scenario navigation
}

export function useVimNavigation() {
  const [nav, setNav] = useState<NavState>({
    column: 0,
    scenarioDepth: [],
  });

  const scenarios = scenariosStore.getSortedScenarios();
  const selectedScenario = scenariosStore.getSelectedScenario();
  const { selectedStepIndex, selectedScenarioId } = scenariosStore.getState();

  const moveLeft = useCallback(() => {
    setNav(prev => ({
      ...prev,
      column: Math.max(0, prev.column - 1) as 0 | 1 | 2,
    }));
  }, []);

  const moveRight = useCallback(() => {
    setNav(prev => ({
      ...prev,
      column: Math.min(2, prev.column + 1) as 0 | 1 | 2,
    }));
  }, []);

  const moveUp = useCallback(() => {
    if (nav.column === 0) {
      // Scenarios column
      const currentIdx = scenarios.findIndex(s => s.id === selectedScenarioId);
      if (currentIdx > 0) {
        scenariosStore.selectScenario(scenarios[currentIdx - 1].id);
      }
    } else if (nav.column === 1 && selectedScenario) {
      // Steps column
      const newIdx = Math.max(0, (selectedStepIndex ?? 0) - 1);
      scenariosStore.selectStep(newIdx);
    }
  }, [nav.column, scenarios, selectedScenarioId, selectedScenario, selectedStepIndex]);

  const moveDown = useCallback(() => {
    if (nav.column === 0) {
      const currentIdx = scenarios.findIndex(s => s.id === selectedScenarioId);
      if (currentIdx < scenarios.length - 1) {
        scenariosStore.selectScenario(scenarios[currentIdx + 1].id);
      }
    } else if (nav.column === 1 && selectedScenario) {
      const maxIdx = selectedScenario.steps.length - 1;
      const newIdx = Math.min(maxIdx, (selectedStepIndex ?? -1) + 1);
      scenariosStore.selectStep(newIdx);
    }
  }, [nav.column, scenarios, selectedScenarioId, selectedScenario, selectedStepIndex]);

  const select = useCallback(() => {
    if (nav.column === 0 && selectedScenarioId) {
      // Move to steps column
      setNav(prev => ({ ...prev, column: 1 }));
      if (selectedScenario && selectedScenario.steps.length > 0) {
        scenariosStore.selectStep(0);
      }
    } else if (nav.column === 1 && selectedStepIndex !== null && selectedScenario) {
      const step = selectedScenario.steps[selectedStepIndex];
      if (step.type === 'scenario-ref') {
        // Enter sub-scenario
        setNav(prev => ({
          ...prev,
          scenarioDepth: [...prev.scenarioDepth, selectedScenarioId!],
        }));
        scenariosStore.selectScenario(step.scenarioId);
        scenariosStore.selectStep(0);
      }
    }
  }, [nav.column, selectedScenarioId, selectedStepIndex, selectedScenario]);

  const back = useCallback(() => {
    if (nav.column === 1) {
      if (nav.scenarioDepth.length > 0) {
        // Go back to parent scenario
        const parentId = nav.scenarioDepth[nav.scenarioDepth.length - 1];
        setNav(prev => ({
          ...prev,
          scenarioDepth: prev.scenarioDepth.slice(0, -1),
        }));
        scenariosStore.selectScenario(parentId);
        scenariosStore.selectStep(null);
      } else {
        // Go back to scenarios column
        setNav(prev => ({ ...prev, column: 0 }));
        scenariosStore.selectStep(null);
      }
    }
  }, [nav.column, nav.scenarioDepth]);

  const swapUp = useCallback(() => {
    if (nav.column === 1 && selectedScenarioId && selectedStepIndex !== null && selectedStepIndex > 0) {
      scenariosStore.swapSteps(selectedScenarioId, selectedStepIndex, selectedStepIndex - 1);
      scenariosStore.selectStep(selectedStepIndex - 1);
    }
  }, [nav.column, selectedScenarioId, selectedStepIndex]);

  const swapDown = useCallback(() => {
    if (nav.column === 1 && selectedScenarioId && selectedStepIndex !== null && selectedScenario) {
      if (selectedStepIndex < selectedScenario.steps.length - 1) {
        scenariosStore.swapSteps(selectedScenarioId, selectedStepIndex, selectedStepIndex + 1);
        scenariosStore.selectStep(selectedStepIndex + 1);
      }
    }
  }, [nav.column, selectedScenarioId, selectedStepIndex, selectedScenario]);

  const getScenarioIndex = useCallback(() => {
    return scenarios.findIndex(s => s.id === selectedScenarioId);
  }, [scenarios, selectedScenarioId]);

  return {
    column: nav.column,
    scenarioDepth: nav.scenarioDepth,
    moveLeft,
    moveRight,
    moveUp,
    moveDown,
    select,
    back,
    swapUp,
    swapDown,
    getScenarioIndex,
  };
}
```

### useRecording.ts

```typescript
// hooks/useRecording.ts
import { useEffect, useCallback } from 'react';
import { scenariosStore } from '../store/scenarios';
import { recorderStore } from '../store/recorder';
import { swiftBridge } from '../ipc/bridge';
import { ipc } from '../ipc/protocol';
import type { Step, IPCEvent } from '@sequencer/schema';

export function useRecording() {
  const state = recorderStore.getState();

  // Listen for Swift events during recording
  useEffect(() => {
    if (state.status !== 'recording') return;

    const handleEvent = (event: IPCEvent) => {
      const recState = recorderStore.getState();
      if (recState.status !== 'recording') return;

      let step: Step | null = null;

      switch (event.event) {
        case 'mouseClicked':
          step = {
            type: 'click',
            position: event.data.position,
            button: event.data.button,
          };
          break;

        case 'keyPressed':
          step = {
            type: 'keypress',
            key: event.data.key,
            modifiers: event.data.modifiers,
          };
          break;

        case 'pixelSelected':
          step = {
            type: 'pixel-state',
            position: event.data.position,
            color: event.data.color,
            threshold: 15,  // Default threshold
          };
          break;

        case 'zoneSelected':
          // Need to capture color - for now use placeholder
          step = {
            type: 'pixel-zone',
            rect: event.data.rect,
            color: { r: 0, g: 255, b: 0 },  // Will be set by magnifier
            threshold: 15,
          };
          break;

        case 'timeInputCompleted':
          step = {
            type: 'delay',
            ms: event.data.ms,
          };
          break;

        case 'overlayClosed':
          recorderStore.stopRecording();
          return;
      }

      if (step) {
        // Calculate insert index
        const currentIdx = recState.insertAfterIndex;
        scenariosStore.addStep(recState.scenarioId, step, currentIdx ?? undefined);
        
        // Update insert index for next step
        recorderStore.startRecording(
          recState.scenarioId,
          currentIdx !== null ? currentIdx + 1 : scenariosStore.getSelectedScenario()!.steps.length - 1
        );
      }
    };

    swiftBridge.on('event', handleEvent);
    return () => {
      swiftBridge.off('event', handleEvent);
    };
  }, [state.status]);

  const toggleRecording = useCallback(async () => {
    const recState = recorderStore.getState();
    const scenState = scenariosStore.getState();

    if (recState.status === 'recording') {
      // Stop recording
      await ipc.hideRecorderOverlay();
      recorderStore.stopRecording();
      return;
    }

    if (recState.status === 'naming') {
      // Already naming, ignore
      return;
    }

    // Start recording
    if (!scenState.selectedScenarioId) {
      // No scenario selected - create new one
      const scenario = scenariosStore.createScenario('New Scenario');
      recorderStore.startNaming(scenario.id);
    } else {
      // Scenario selected - start recording after current step
      await ipc.showRecorderOverlay();
      recorderStore.startRecording(
        scenState.selectedScenarioId,
        scenState.selectedStepIndex
      );
    }
  }, []);

  const finishNaming = useCallback(async () => {
    const name = recorderStore.finishNaming();
    const recState = recorderStore.getState();
    
    if (name && recState.status === 'idle') {
      // Get the scenario that was being named
      const scenario = scenariosStore.getState().scenarios.find(
        s => s.name === 'New Scenario'  // Find by default name
      );
      if (scenario) {
        scenariosStore.updateScenarioName(scenario.id, name || 'Unnamed');
        await ipc.showRecorderOverlay();
        recorderStore.startRecording(scenario.id, null);
      }
    }
  }, []);

  return {
    isRecording: state.status === 'recording',
    isNaming: state.status === 'naming',
    toggleRecording,
    finishNaming,
  };
}
```
