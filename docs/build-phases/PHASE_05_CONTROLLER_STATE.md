# Phase 5: Controller State Management

## Goal
Implement state stores for scenarios, recording, and undo history with JSON persistence.

## Prerequisites
- Phase 3 complete (Controller IPC working)

## Deliverables
- [ ] Scenarios store with CRUD operations
- [ ] History store for undo functionality
- [ ] Recorder state machine
- [ ] JSON persistence to ~/.config/macos-sequencer/
- [ ] Settings persistence

---

## Tasks

### 5.1 Create Persistence Layer
Create `controller/src/store/persistence.ts`:

```typescript
const CONFIG_DIR = '~/.config/macos-sequencer';
const SCENARIOS_FILE = 'scenarios.json';
const SETTINGS_FILE = 'settings.json';

export async function loadScenarios(): Promise<Scenario[]>
export async function saveScenarios(scenarios: Scenario[]): Promise<void>
export async function loadSettings(): Promise<Settings>
export async function saveSettings(settings: Settings): Promise<void>
```

Implementation details:
- Create config directory if not exists
- Handle file not found gracefully (return defaults)
- Pretty-print JSON for readability
- Use `Bun.file()` and `Bun.write()`

### 5.2 Create Scenarios Store
Create `controller/src/store/scenarios.ts`:

```typescript
interface ScenariosState {
  scenarios: Scenario[];
  selectedScenarioId: string | null;
  selectedStepIndex: number | null;
}

export function createScenariosStore() {
  return {
    getState(): ScenariosState,
    subscribe(listener: () => void): () => void,
    
    // Initialization
    load(): Promise<void>,
    save(): Promise<void>,
    
    // Selection
    selectScenario(id: string | null): void,
    selectStep(index: number | null): void,
    
    // Scenario CRUD
    createScenario(name: string): Scenario,
    updateScenarioName(id: string, name: string): void,
    touchScenario(id: string): void,  // Update lastUsedAt
    
    // Step operations
    addStep(scenarioId: string, step: Step, afterIndex?: number): void,
    removeStep(scenarioId: string, stepIndex: number): Step | null,
    swapSteps(scenarioId: string, indexA: number, indexB: number): void,
    
    // Queries
    getSortedScenarios(): Scenario[],  // By lastUsedAt desc
    getSelectedScenario(): Scenario | null,
  };
}

export const scenariosStore = createScenariosStore();
```

### 5.3 Create History Store (Undo)
Create `controller/src/store/history.ts`:

```typescript
interface HistoryEntry {
  type: 'delete-step';
  scenarioId: string;
  stepIndex: number;
  step: Step;
  timestamp: number;
}

export function createHistoryStore() {
  return {
    getState(): { undoStack: HistoryEntry[] },
    subscribe(listener: () => void): () => void,
    
    deleteStep(scenarioId: string, stepIndex: number): void,
    undo(): boolean,
    canUndo(): boolean,
    clear(): void,
  };
}

export const historyStore = createHistoryStore();
```

Implementation details:
- Max 50 entries in undo stack
- `deleteStep` removes from scenarios store AND pushes to history
- `undo` pops from history AND reinserts into scenarios store
- Handle edge case: scenario deleted between delete and undo

### 5.4 Create Recorder Store
Create `controller/src/store/recorder.ts`:

```typescript
type RecorderState = 
  | { status: 'idle' }
  | { status: 'recording'; scenarioId: string; insertAfterIndex: number | null }
  | { status: 'naming'; scenarioId: string; name: string };

export function createRecorderStore() {
  return {
    getState(): RecorderState,
    subscribe(listener: () => void): () => void,
    
    startRecording(scenarioId: string, insertAfterIndex: number | null): void,
    stopRecording(): void,
    
    startNaming(scenarioId: string): void,
    appendToName(char: string): void,
    backspaceName(): void,
    finishNaming(): string | null,
    
    isRecording(): boolean,
    isNaming(): boolean,
  };
}

export const recorderStore = createRecorderStore();
```

### 5.5 Create Settings Store
Create `controller/src/store/settings.ts`:

```typescript
interface Settings {
  lastOverlayPosition?: Point;
  defaultThreshold: number;
  pollIntervalMs: number;
}

const DEFAULT_SETTINGS: Settings = {
  defaultThreshold: 15,
  pollIntervalMs: 50,
};
```

### 5.6 Test Store Operations
Create `controller/src/test-stores.ts`:

```typescript
import { scenariosStore } from './store/scenarios';
import { historyStore } from './store/history';

async function test() {
  // Load
  await scenariosStore.load();
  console.log('Loaded scenarios:', scenariosStore.getState().scenarios.length);
  
  // Create scenario
  const scenario = scenariosStore.createScenario('Test Scenario');
  console.log('Created:', scenario);
  
  // Add steps
  scenariosStore.addStep(scenario.id, { type: 'delay', ms: 1000 });
  scenariosStore.addStep(scenario.id, { type: 'click', position: { x: 100, y: 200 }, button: 'left' });
  
  // Delete step
  historyStore.deleteStep(scenario.id, 0);
  console.log('After delete:', scenariosStore.getSelectedScenario()?.steps);
  
  // Undo
  historyStore.undo();
  console.log('After undo:', scenariosStore.getSelectedScenario()?.steps);
  
  // Verify persistence
  await scenariosStore.load();
  console.log('After reload:', scenariosStore.getState().scenarios);
}

test();
```

---

## Acceptance Criteria
- [ ] Scenarios persist to `~/.config/macos-sequencer/scenarios.json`
- [ ] Scenarios load on startup
- [ ] Creating scenario auto-saves
- [ ] Adding/removing steps auto-saves
- [ ] Step deletion adds to undo stack
- [ ] Undo restores step at correct position
- [ ] Undo stack limited to 50 entries
- [ ] Recorder state machine transitions correctly
- [ ] Multiple subscribers receive updates

---

## Files Created
```
controller/src/store/
├── persistence.ts
├── scenarios.ts
├── history.ts
├── recorder.ts
└── settings.ts
```

## Data Files
```
~/.config/macos-sequencer/
├── scenarios.json
└── settings.json
```

## Estimated Time: 3-4 hours
