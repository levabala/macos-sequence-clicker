// controller/src/store/history.ts
// History store for undo functionality

import type { Step } from "../types";
import { scenariosStore } from "./scenarios";

const MAX_UNDO_STACK_SIZE = 50;

export interface HistoryEntry {
  type: "delete-step";
  scenarioId: string;
  stepIndex: number;
  step: Step;
  timestamp: number;
}

export interface HistoryState {
  undoStack: HistoryEntry[];
}

type Listener = () => void;

export interface HistoryStore {
  getState(): HistoryState;
  subscribe(listener: Listener): () => void;

  /**
   * Delete a step from a scenario and add to undo history
   */
  deleteStep(scenarioId: string, stepIndex: number): void;

  /**
   * Undo the last operation
   * Returns true if undo was successful
   */
  undo(): boolean;

  /**
   * Check if undo is available
   */
  canUndo(): boolean;

  /**
   * Get the description of what will be undone
   */
  getUndoDescription(): string | null;

  /**
   * Clear the undo history
   */
  clear(): void;
}

export function createHistoryStore(): HistoryStore {
  let state: HistoryState = {
    undoStack: [],
  };

  const listeners = new Set<Listener>();

  function notify(): void {
    for (const listener of listeners) {
      listener();
    }
  }

  function setState(partial: Partial<HistoryState>): void {
    state = { ...state, ...partial };
    notify();
  }

  function pushToStack(entry: HistoryEntry): void {
    const newStack = [...state.undoStack, entry];

    // Trim stack if it exceeds max size
    if (newStack.length > MAX_UNDO_STACK_SIZE) {
      newStack.shift();
    }

    setState({ undoStack: newStack });
  }

  function popFromStack(): HistoryEntry | null {
    if (state.undoStack.length === 0) return null;

    const entry = state.undoStack[state.undoStack.length - 1];
    if (!entry) return null;
    setState({ undoStack: state.undoStack.slice(0, -1) });
    return entry;
  }

  function getStepDescription(step: Step): string {
    switch (step.type) {
      case "click":
        return `${step.button} click at (${step.position.x}, ${step.position.y})`;
      case "keypress":
        const mods = step.modifiers.length > 0 ? step.modifiers.join("+") + "+" : "";
        return `keypress ${mods}${step.key}`;
      case "delay":
        return `delay ${step.ms}ms`;
      case "pixel-state":
        return `pixel-state at (${step.position.x}, ${step.position.y})`;
      case "pixel-zone":
        return `pixel-zone at (${step.rect.x}, ${step.rect.y})`;
      case "scenario-ref":
        return `scenario reference`;
      default:
        return "unknown step";
    }
  }

  return {
    getState(): HistoryState {
      return state;
    },

    subscribe(listener: Listener): () => void {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    deleteStep(scenarioId: string, stepIndex: number): void {
      // Get the step before deleting
      const scenario = scenariosStore.getScenarioById(scenarioId);
      if (!scenario) return;
      if (stepIndex < 0 || stepIndex >= scenario.steps.length) return;

      const step = scenario.steps[stepIndex];
      if (!step) return;

      // Remove from scenarios store
      const removed = scenariosStore.removeStep(scenarioId, stepIndex);
      if (!removed) return;

      // Add to undo history
      pushToStack({
        type: "delete-step",
        scenarioId,
        stepIndex,
        step,
        timestamp: Date.now(),
      });
    },

    undo(): boolean {
      const entry = popFromStack();
      if (!entry) return false;

      switch (entry.type) {
        case "delete-step": {
          // Check if scenario still exists
          const scenario = scenariosStore.getScenarioById(entry.scenarioId);
          if (!scenario) {
            // Scenario was deleted, can't undo
            console.warn(
              `Cannot undo: scenario ${entry.scenarioId} no longer exists`
            );
            return false;
          }

          // Reinsert step at original position (or at end if position is invalid)
          const insertIndex = Math.min(entry.stepIndex, scenario.steps.length);

          // Use addStep with afterIndex - 1 to insert at the correct position
          if (insertIndex === 0) {
            // Insert at beginning - need to use a workaround
            // Add at position 0 by temporarily manipulating
            const scenarioIndex = scenariosStore
              .getState()
              .scenarios.findIndex((s) => s.id === entry.scenarioId);
            if (scenarioIndex === -1) return false;

            const scenarios = [...scenariosStore.getState().scenarios];
            const targetScenario = scenarios[scenarioIndex];
            if (!targetScenario) return false;
            const updatedScenario = { ...targetScenario };
            updatedScenario.steps = [entry.step, ...updatedScenario.steps];
            scenarios[scenarioIndex] = updatedScenario;

            // Manually trigger re-save through scenarios store
            scenariosStore.addStep(entry.scenarioId, entry.step, -1);
            // The addStep with -1 will insert at position 0
          } else {
            scenariosStore.addStep(entry.scenarioId, entry.step, insertIndex - 1);
          }

          // Select the restored step
          scenariosStore.selectScenario(entry.scenarioId);
          scenariosStore.selectStep(insertIndex);

          return true;
        }
        default:
          return false;
      }
    },

    canUndo(): boolean {
      return state.undoStack.length > 0;
    },

    getUndoDescription(): string | null {
      if (state.undoStack.length === 0) return null;

      const entry = state.undoStack[state.undoStack.length - 1];
      if (!entry) return null;

      switch (entry.type) {
        case "delete-step":
          return `Restore deleted ${getStepDescription(entry.step)}`;
        default:
          return "Undo last action";
      }
    },

    clear(): void {
      setState({ undoStack: [] });
    },
  };
}

// Singleton instance
export const historyStore = createHistoryStore();
