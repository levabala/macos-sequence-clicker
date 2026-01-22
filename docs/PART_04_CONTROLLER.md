# Part 4: Bun Controller

## Overview

The Bun controller is a TypeScript/React terminal application that:
1. Manages scenarios (CRUD, persistence)
2. Provides terminal UI with vim-style navigation
3. Orchestrates recording via Swift helper
4. Executes scenarios

## Project Structure

```
controller/
├── src/
│   ├── index.tsx              # Entry point
│   ├── types/
│   │   ├── index.ts           # Re-export schema types
│   │   └── internal.ts        # Controller-specific types
│   ├── ipc/
│   │   ├── bridge.ts          # Swift process management
│   │   └── protocol.ts        # Request/response handling
│   ├── store/
│   │   ├── scenarios.ts       # Scenario state & operations
│   │   ├── recorder.ts        # Recording state machine
│   │   ├── history.ts         # Undo stack for step deletion
│   │   └── persistence.ts     # JSON file I/O
│   ├── components/
│   │   ├── App.tsx            # Root layout
│   │   ├── ScenarioList.tsx   # Left column
│   │   ├── StepsViewer.tsx    # Center column
│   │   ├── StepPreview.tsx    # Right column
│   │   ├── PlayModal.tsx      # Hotkey capture modal
│   │   └── StatusBar.tsx      # Bottom status
│   └── hooks/
│       ├── useVimNavigation.ts
│       ├── useRecording.ts
│       └── useScenarios.ts
├── package.json
└── tsconfig.json
```

## Package Configuration

```json
// controller/package.json
{
  "name": "@sequencer/controller",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run src/index.tsx",
    "build": "bun build src/index.tsx --outdir dist --target bun"
  },
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

```json
// controller/tsconfig.json
{
  "compilerOptions": {
    "lib": ["ESNext", "DOM"],
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "jsxImportSource": "@opentui/react",
    "strict": true,
    "skipLibCheck": true,
    "paths": {
      "@/*": ["./src/*"],
      "@sequencer/schema": ["../schema/src/types"]
    }
  },
  "include": ["src/**/*"]
}
```

## IPC Bridge

### Process Management

```typescript
// ipc/bridge.ts
import { spawn, type Subprocess } from 'bun';
import { EventEmitter } from 'events';
import type { IPCRequest, IPCResponse, IPCEvent } from '@sequencer/schema';

export class SwiftBridge extends EventEmitter {
  private process: Subprocess | null = null;
  private pendingRequests = new Map<string, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
  }>();
  private buffer = '';
  private requestId = 0;

  async start(): Promise<void> {
    const helperPath = new URL('../../swift-helper/.build/release/SequencerHelper', import.meta.url).pathname;
    
    this.process = spawn({
      cmd: [helperPath],
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'inherit',
    });

    // Read stdout line by line
    this.readLoop();
  }

  private async readLoop() {
    if (!this.process?.stdout) return;
    
    const reader = this.process.stdout.getReader();
    const decoder = new TextDecoder();

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      this.buffer += decoder.decode(value, { stream: true });
      
      // Process complete lines
      let newlineIndex;
      while ((newlineIndex = this.buffer.indexOf('\n')) !== -1) {
        const line = this.buffer.slice(0, newlineIndex);
        this.buffer = this.buffer.slice(newlineIndex + 1);
        this.handleMessage(line);
      }
    }
  }

  private handleMessage(json: string) {
    try {
      const message = JSON.parse(json);
      
      // Check if it's a response (has 'id' and 'success')
      if ('id' in message && 'success' in message) {
        const response = message as IPCResponse;
        const pending = this.pendingRequests.get(response.id);
        if (pending) {
          this.pendingRequests.delete(response.id);
          if (response.success) {
            pending.resolve(response.result);
          } else {
            pending.reject(new Error(response.error));
          }
        }
      }
      // Otherwise it's an event
      else if ('event' in message) {
        const event = message as IPCEvent;
        this.emit('event', event);
        this.emit(event.event, event.data);
      }
    } catch (e) {
      console.error('Failed to parse IPC message:', json);
    }
  }

  async request<T = unknown>(requestBody: Omit<IPCRequest, 'id'>): Promise<T> {
    if (!this.process?.stdin) {
      throw new Error('Swift helper not running');
    }

    const id = `req-${++this.requestId}`;
    const request: IPCRequest = { id, ...requestBody } as IPCRequest;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, { 
        resolve: resolve as (value: unknown) => void, 
        reject 
      });

      const json = JSON.stringify(request) + '\n';
      this.process!.stdin!.write(json);

      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }

  stop() {
    this.process?.kill();
    this.process = null;
    this.pendingRequests.clear();
  }
}

// Singleton instance
export const swiftBridge = new SwiftBridge();
```

### Typed Protocol Helpers

```typescript
// ipc/protocol.ts
import { swiftBridge } from './bridge';
import type { 
  PermissionStatus, 
  Point, 
  RGB, 
  Rect 
} from '@sequencer/schema';

export const ipc = {
  checkPermissions(): Promise<PermissionStatus> {
    return swiftBridge.request({ method: 'checkPermissions' });
  },

  showRecorderOverlay(position?: Point): Promise<void> {
    return swiftBridge.request({ 
      method: 'showRecorderOverlay', 
      params: { position } 
    });
  },

  hideRecorderOverlay(): Promise<void> {
    return swiftBridge.request({ method: 'hideRecorderOverlay' });
  },

  setRecorderState(
    state: 'idle' | 'action' | 'transition',
    subState?: 'mouse' | 'keyboard' | 'time' | 'pixel'
  ): Promise<void> {
    return swiftBridge.request({
      method: 'setRecorderState',
      params: { state, subState }
    });
  },

  showMagnifier(): Promise<void> {
    return swiftBridge.request({ method: 'showMagnifier' });
  },

  hideMagnifier(): Promise<void> {
    return swiftBridge.request({ method: 'hideMagnifier' });
  },

  executeClick(position: Point, button: 'left' | 'right'): Promise<void> {
    return swiftBridge.request({
      method: 'executeClick',
      params: { position, button }
    });
  },

  executeKeypress(key: string, modifiers: string[]): Promise<void> {
    return swiftBridge.request({
      method: 'executeKeypress',
      params: { key, modifiers }
    });
  },

  getPixelColor(position: Point): Promise<RGB> {
    return swiftBridge.request({
      method: 'getPixelColor',
      params: { position }
    });
  },

  waitForPixelState(
    position: Point,
    color: RGB,
    threshold: number,
    timeoutMs?: number
  ): Promise<boolean> {
    return swiftBridge.request({
      method: 'waitForPixelState',
      params: { position, color, threshold, timeoutMs }
    });
  },

  waitForPixelZone(
    rect: Rect,
    color: RGB,
    threshold: number,
    timeoutMs?: number
  ): Promise<boolean> {
    return swiftBridge.request({
      method: 'waitForPixelZone',
      params: { rect, color, threshold, timeoutMs }
    });
  }
};
```

## State Management

### Scenarios Store

```typescript
// store/scenarios.ts
import { nanoid } from 'nanoid';
import type { Scenario, Step } from '@sequencer/schema';
import { loadScenarios, saveScenarios } from './persistence';

export interface ScenariosState {
  scenarios: Scenario[];
  selectedScenarioId: string | null;
  selectedStepIndex: number | null;
}

const initialState: ScenariosState = {
  scenarios: [],
  selectedScenarioId: null,
  selectedStepIndex: null,
};

export function createScenariosStore() {
  let state = { ...initialState };
  const listeners = new Set<() => void>();

  const notify = () => listeners.forEach(fn => fn());

  return {
    getState: () => state,
    subscribe: (listener: () => void) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },

    // Initialize from disk
    async load() {
      state.scenarios = await loadScenarios();
      notify();
    },

    // Persist to disk
    async save() {
      await saveScenarios(state.scenarios);
    },

    // Selection
    selectScenario(id: string | null) {
      state = { 
        ...state, 
        selectedScenarioId: id,
        selectedStepIndex: null 
      };
      notify();
    },

    selectStep(index: number | null) {
      state = { ...state, selectedStepIndex: index };
      notify();
    },

    // CRUD
    createScenario(name: string): Scenario {
      const scenario: Scenario = {
        id: nanoid(),
        name,
        steps: [],
        createdAt: Date.now(),
        lastUsedAt: Date.now(),
      };
      state = {
        ...state,
        scenarios: [...state.scenarios, scenario],
        selectedScenarioId: scenario.id,
      };
      notify();
      this.save();
      return scenario;
    },

    updateScenarioName(id: string, name: string) {
      state = {
        ...state,
        scenarios: state.scenarios.map(s =>
          s.id === id ? { ...s, name } : s
        ),
      };
      notify();
      this.save();
    },

    // Step operations
    addStep(scenarioId: string, step: Step, afterIndex?: number) {
      state = {
        ...state,
        scenarios: state.scenarios.map(s => {
          if (s.id !== scenarioId) return s;
          const steps = [...s.steps];
          const insertIndex = afterIndex !== undefined ? afterIndex + 1 : steps.length;
          steps.splice(insertIndex, 0, step);
          return { ...s, steps };
        }),
      };
      notify();
      this.save();
    },

    removeStep(scenarioId: string, stepIndex: number): Step | null {
      let removedStep: Step | null = null;
      state = {
        ...state,
        scenarios: state.scenarios.map(s => {
          if (s.id !== scenarioId) return s;
          const steps = [...s.steps];
          [removedStep] = steps.splice(stepIndex, 1);
          return { ...s, steps };
        }),
      };
      notify();
      this.save();
      return removedStep;
    },

    swapSteps(scenarioId: string, indexA: number, indexB: number) {
      state = {
        ...state,
        scenarios: state.scenarios.map(s => {
          if (s.id !== scenarioId) return s;
          const steps = [...s.steps];
          if (indexA >= 0 && indexA < steps.length && indexB >= 0 && indexB < steps.length) {
            [steps[indexA], steps[indexB]] = [steps[indexB], steps[indexA]];
          }
          return { ...s, steps };
        }),
      };
      notify();
      this.save();
    },

    // Mark as used (for sorting)
    touchScenario(id: string) {
      state = {
        ...state,
        scenarios: state.scenarios.map(s =>
          s.id === id ? { ...s, lastUsedAt: Date.now() } : s
        ),
      };
      notify();
      this.save();
    },

    // Get sorted scenarios
    getSortedScenarios(): Scenario[] {
      return [...state.scenarios].sort((a, b) => b.lastUsedAt - a.lastUsedAt);
    },

    // Get selected scenario
    getSelectedScenario(): Scenario | null {
      return state.scenarios.find(s => s.id === state.selectedScenarioId) ?? null;
    },
  };
}

export const scenariosStore = createScenariosStore();
```

### History Store (Undo)

```typescript
// store/history.ts
import type { Step } from '@sequencer/schema';
import { scenariosStore } from './scenarios';

interface HistoryEntry {
  type: 'delete-step';
  scenarioId: string;
  stepIndex: number;
  step: Step;
  timestamp: number;
}

const MAX_HISTORY = 50;

export function createHistoryStore() {
  let undoStack: HistoryEntry[] = [];
  const listeners = new Set<() => void>();

  const notify = () => listeners.forEach(fn => fn());

  return {
    getState: () => ({ undoStack }),
    subscribe: (listener: () => void) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },

    // Delete step and record for undo
    deleteStep(scenarioId: string, stepIndex: number) {
      const removedStep = scenariosStore.removeStep(scenarioId, stepIndex);
      if (removedStep) {
        undoStack = [
          ...undoStack.slice(-MAX_HISTORY + 1),
          {
            type: 'delete-step',
            scenarioId,
            stepIndex,
            step: removedStep,
            timestamp: Date.now(),
          },
        ];
        notify();
      }
    },

    // Undo last deletion
    undo(): boolean {
      const entry = undoStack.pop();
      if (!entry) return false;

      if (entry.type === 'delete-step') {
        // Re-insert the step at original position
        const scenario = scenariosStore.getState().scenarios.find(
          s => s.id === entry.scenarioId
        );
        if (scenario) {
          // Insert at the original index (or end if out of bounds)
          const insertIndex = Math.min(entry.stepIndex, scenario.steps.length);
          scenariosStore.addStep(
            entry.scenarioId, 
            entry.step, 
            insertIndex - 1  // addStep inserts AFTER the index
          );
        }
      }

      notify();
      return true;
    },

    canUndo(): boolean {
      return undoStack.length > 0;
    },

    clear() {
      undoStack = [];
      notify();
    },
  };
}

export const historyStore = createHistoryStore();
```

### Recorder State

```typescript
// store/recorder.ts
export type RecorderState = 
  | { status: 'idle' }
  | { status: 'recording'; scenarioId: string; insertAfterIndex: number | null }
  | { status: 'naming'; scenarioId: string; name: string };

export function createRecorderStore() {
  let state: RecorderState = { status: 'idle' };
  const listeners = new Set<() => void>();

  const notify = () => listeners.forEach(fn => fn());

  return {
    getState: () => state,
    subscribe: (listener: () => void) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },

    startRecording(scenarioId: string, insertAfterIndex: number | null) {
      state = { status: 'recording', scenarioId, insertAfterIndex };
      notify();
    },

    stopRecording() {
      state = { status: 'idle' };
      notify();
    },

    startNaming(scenarioId: string) {
      state = { status: 'naming', scenarioId, name: '' };
      notify();
    },

    appendToName(char: string) {
      if (state.status === 'naming') {
        state = { ...state, name: state.name + char };
        notify();
      }
    },

    backspaceName() {
      if (state.status === 'naming' && state.name.length > 0) {
        state = { ...state, name: state.name.slice(0, -1) };
        notify();
      }
    },

    finishNaming(): string | null {
      if (state.status === 'naming') {
        const name = state.name;
        state = { status: 'idle' };
        notify();
        return name;
      }
      return null;
    },

    isRecording(): boolean {
      return state.status === 'recording';
    },

    isNaming(): boolean {
      return state.status === 'naming';
    },
  };
}

export const recorderStore = createRecorderStore();
```

### Persistence

```typescript
// store/persistence.ts
import { existsSync, mkdirSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import type { Scenario } from '@sequencer/schema';

const CONFIG_DIR = join(homedir(), '.config', 'macos-sequencer');
const SCENARIOS_FILE = join(CONFIG_DIR, 'scenarios.json');
const SETTINGS_FILE = join(CONFIG_DIR, 'settings.json');

function ensureConfigDir() {
  if (!existsSync(CONFIG_DIR)) {
    mkdirSync(CONFIG_DIR, { recursive: true });
  }
}

export async function loadScenarios(): Promise<Scenario[]> {
  ensureConfigDir();
  try {
    const file = Bun.file(SCENARIOS_FILE);
    if (await file.exists()) {
      return await file.json();
    }
  } catch (e) {
    console.error('Failed to load scenarios:', e);
  }
  return [];
}

export async function saveScenarios(scenarios: Scenario[]): Promise<void> {
  ensureConfigDir();
  try {
    await Bun.write(SCENARIOS_FILE, JSON.stringify(scenarios, null, 2));
  } catch (e) {
    console.error('Failed to save scenarios:', e);
  }
}

export interface Settings {
  lastOverlayPosition?: { x: number; y: number };
  defaultThreshold: number;
  pollIntervalMs: number;
}

const DEFAULT_SETTINGS: Settings = {
  defaultThreshold: 15,
  pollIntervalMs: 50,
};

export async function loadSettings(): Promise<Settings> {
  ensureConfigDir();
  try {
    const file = Bun.file(SETTINGS_FILE);
    if (await file.exists()) {
      return { ...DEFAULT_SETTINGS, ...(await file.json()) };
    }
  } catch (e) {
    console.error('Failed to load settings:', e);
  }
  return DEFAULT_SETTINGS;
}

export async function saveSettings(settings: Settings): Promise<void> {
  ensureConfigDir();
  try {
    await Bun.write(SETTINGS_FILE, JSON.stringify(settings, null, 2));
  } catch (e) {
    console.error('Failed to save settings:', e);
  }
}
```

## Entry Point

```typescript
// index.tsx
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
    console.error('Missing permissions:');
    if (!permissions.accessibility) {
      console.error('  - Accessibility: Enable in System Settings > Privacy & Security > Accessibility');
    }
    if (!permissions.screenRecording) {
      console.error('  - Screen Recording: Enable in System Settings > Privacy & Security > Screen Recording');
    }
    process.exit(1);
  }

  // Load saved scenarios
  await scenariosStore.load();

  // Create renderer and start UI
  const renderer = await createCliRenderer({
    exitOnCtrlC: false,  // We handle Ctrl+C ourselves
  });

  createRoot(renderer).render(<App />);
}

main().catch(console.error);
```

## Execution Engine

```typescript
// execution/executor.ts
import type { Scenario, Step } from '@sequencer/schema';
import { ipc } from '../ipc/protocol';
import { scenariosStore } from '../store/scenarios';

export interface ExecutionProgress {
  currentStep: number;
  totalSteps: number;
  status: 'running' | 'waiting' | 'completed' | 'aborted' | 'error';
  error?: string;
}

export async function executeScenario(
  scenario: Scenario,
  signal: AbortSignal,
  onProgress?: (progress: ExecutionProgress) => void
): Promise<void> {
  const totalSteps = scenario.steps.length;

  for (let i = 0; i < scenario.steps.length; i++) {
    if (signal.aborted) {
      onProgress?.({ currentStep: i, totalSteps, status: 'aborted' });
      throw new DOMException('Execution aborted', 'AbortError');
    }

    const step = scenario.steps[i];
    onProgress?.({ currentStep: i, totalSteps, status: 'running' });

    try {
      await executeStep(step, signal, onProgress, i, totalSteps);
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') {
        throw e;
      }
      onProgress?.({ 
        currentStep: i, 
        totalSteps, 
        status: 'error', 
        error: String(e) 
      });
      throw e;
    }
  }

  // Mark scenario as used
  scenariosStore.touchScenario(scenario.id);
  
  onProgress?.({ currentStep: totalSteps, totalSteps, status: 'completed' });
}

async function executeStep(
  step: Step,
  signal: AbortSignal,
  onProgress: ((p: ExecutionProgress) => void) | undefined,
  currentIndex: number,
  totalSteps: number
): Promise<void> {
  switch (step.type) {
    case 'click':
      await ipc.executeClick(step.position, step.button);
      break;

    case 'keypress':
      await ipc.executeKeypress(step.key, step.modifiers);
      break;

    case 'delay':
      await sleep(step.ms, signal);
      break;

    case 'pixel-state':
      onProgress?.({ currentStep: currentIndex, totalSteps, status: 'waiting' });
      await ipc.waitForPixelState(
        step.position,
        step.color,
        step.threshold
      );
      break;

    case 'pixel-zone':
      onProgress?.({ currentStep: currentIndex, totalSteps, status: 'waiting' });
      await ipc.waitForPixelZone(
        step.rect,
        step.color,
        step.threshold
      );
      break;

    case 'scenario-ref':
      const subScenario = scenariosStore.getState().scenarios.find(
        s => s.id === step.scenarioId
      );
      if (!subScenario) {
        throw new Error(`Sub-scenario not found: ${step.scenarioId}`);
      }
      await executeScenario(subScenario, signal, onProgress);
      break;
  }
}

function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(resolve, ms);
    signal.addEventListener('abort', () => {
      clearTimeout(timeout);
      reject(new DOMException('Execution aborted', 'AbortError'));
    }, { once: true });
  });
}
```
