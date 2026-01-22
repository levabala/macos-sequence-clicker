// controller/src/store/scenarios.ts
// State store for scenario management with CRUD operations

import { nanoid } from "nanoid";
import type { Scenario, Step } from "../types";
import { loadScenarios, saveScenarios } from "./persistence";

export interface ScenariosState {
  scenarios: Scenario[];
  selectedScenarioId: string | null;
  selectedStepIndex: number | null;
}

type Listener = () => void;

export interface ScenariosStore {
  getState(): ScenariosState;
  subscribe(listener: Listener): () => void;

  // Initialization
  load(): Promise<void>;
  save(): Promise<void>;

  // Selection
  selectScenario(id: string | null): void;
  selectStep(index: number | null): void;

  // Scenario CRUD
  createScenario(name: string): Scenario;
  updateScenarioName(id: string, name: string): void;
  deleteScenario(id: string): Scenario | null;
  touchScenario(id: string): void; // Update lastUsedAt

  // Step operations
  addStep(scenarioId: string, step: Step, afterIndex?: number): void;
  updateStep(scenarioId: string, stepIndex: number, step: Step): void;
  removeStep(scenarioId: string, stepIndex: number): Step | null;
  swapSteps(scenarioId: string, indexA: number, indexB: number): void;

  // Queries
  getSortedScenarios(): Scenario[];
  getSelectedScenario(): Scenario | null;
  getScenarioById(id: string): Scenario | null;
}

export function createScenariosStore(): ScenariosStore {
  let state: ScenariosState = {
    scenarios: [],
    selectedScenarioId: null,
    selectedStepIndex: null,
  };

  const listeners = new Set<Listener>();

  function notify(): void {
    for (const listener of listeners) {
      listener();
    }
  }

  function setState(partial: Partial<ScenariosState>): void {
    state = { ...state, ...partial };
    notify();
  }

  function findScenarioIndex(id: string): number {
    return state.scenarios.findIndex((s) => s.id === id);
  }

  async function autoSave(): Promise<void> {
    // Debounced save could be added here if needed
    await saveScenarios(state.scenarios);
  }

  return {
    getState(): ScenariosState {
      return state;
    },

    subscribe(listener: Listener): () => void {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    async load(): Promise<void> {
      const scenarios = await loadScenarios();
      setState({ scenarios });
    },

    async save(): Promise<void> {
      await autoSave();
    },

    selectScenario(id: string | null): void {
      setState({
        selectedScenarioId: id,
        selectedStepIndex: null, // Reset step selection when scenario changes
      });
    },

    selectStep(index: number | null): void {
      setState({ selectedStepIndex: index });
    },

    createScenario(name: string): Scenario {
      const now = Date.now();
      const scenario: Scenario = {
        id: nanoid(),
        name: name || "Untitled Scenario",
        steps: [],
        createdAt: now,
        lastUsedAt: now,
      };

      setState({
        scenarios: [...state.scenarios, scenario],
        selectedScenarioId: scenario.id,
        selectedStepIndex: null,
      });

      autoSave();
      return scenario;
    },

    updateScenarioName(id: string, name: string): void {
      const index = findScenarioIndex(id);
      if (index === -1) return;

      const updated = [...state.scenarios];
      const existing = updated[index];
      if (!existing) return;
      updated[index] = { ...existing, name };
      setState({ scenarios: updated });
      autoSave();
    },

    deleteScenario(id: string): Scenario | null {
      const index = findScenarioIndex(id);
      if (index === -1) return null;

      const deleted = state.scenarios[index];
      if (!deleted) return null;
      const updated = state.scenarios.filter((s) => s.id !== id);

      // Update selection if needed
      let newSelectedId: string | null = state.selectedScenarioId;
      if (state.selectedScenarioId === id) {
        if (updated.length > 0) {
          const newSelectedScenario = updated[Math.min(index, updated.length - 1)];
          newSelectedId = newSelectedScenario?.id ?? null;
        } else {
          newSelectedId = null;
        }
      }

      setState({
        scenarios: updated,
        selectedScenarioId: newSelectedId,
        selectedStepIndex:
          state.selectedScenarioId === id ? null : state.selectedStepIndex,
      });

      autoSave();
      return deleted;
    },

    touchScenario(id: string): void {
      const index = findScenarioIndex(id);
      if (index === -1) return;

      const updated = [...state.scenarios];
      const existing = updated[index];
      if (!existing) return;
      updated[index] = { ...existing, lastUsedAt: Date.now() };
      setState({ scenarios: updated });
      autoSave();
    },

    addStep(scenarioId: string, step: Step, afterIndex?: number): void {
      const index = findScenarioIndex(scenarioId);
      if (index === -1) return;

      const scenario = state.scenarios[index];
      if (!scenario) return;
      const newSteps = [...scenario.steps];

      // Insert at specific position or at end
      const insertIndex =
        afterIndex !== undefined
          ? Math.min(afterIndex + 1, newSteps.length)
          : newSteps.length;

      newSteps.splice(insertIndex, 0, step);

      const updated = [...state.scenarios];
      updated[index] = {
        ...scenario,
        steps: newSteps,
        lastUsedAt: Date.now(),
      };

      setState({
        scenarios: updated,
        selectedStepIndex: insertIndex,
      });

      autoSave();
    },

    updateStep(scenarioId: string, stepIndex: number, step: Step): void {
      const index = findScenarioIndex(scenarioId);
      if (index === -1) return;

      const scenario = state.scenarios[index];
      if (!scenario) return;
      if (stepIndex < 0 || stepIndex >= scenario.steps.length) return;

      const newSteps = [...scenario.steps];
      newSteps[stepIndex] = step;

      const updated = [...state.scenarios];
      updated[index] = { ...scenario, steps: newSteps };

      setState({ scenarios: updated });
      autoSave();
    },

    removeStep(scenarioId: string, stepIndex: number): Step | null {
      const index = findScenarioIndex(scenarioId);
      if (index === -1) return null;

      const scenario = state.scenarios[index];
      if (!scenario) return null;
      if (stepIndex < 0 || stepIndex >= scenario.steps.length) return null;

      const removed = scenario.steps[stepIndex];
      if (!removed) return null;
      const newSteps = scenario.steps.filter((_, i) => i !== stepIndex);

      const updated = [...state.scenarios];
      updated[index] = { ...scenario, steps: newSteps };

      // Adjust selection
      const newSelectedStep =
        state.selectedStepIndex !== null
          ? state.selectedStepIndex >= newSteps.length
            ? newSteps.length > 0
              ? newSteps.length - 1
              : null
            : state.selectedStepIndex > stepIndex
              ? state.selectedStepIndex - 1
              : state.selectedStepIndex
          : null;

      setState({
        scenarios: updated,
        selectedStepIndex: newSelectedStep,
      });

      autoSave();
      return removed;
    },

    swapSteps(scenarioId: string, indexA: number, indexB: number): void {
      const index = findScenarioIndex(scenarioId);
      if (index === -1) return;

      const scenario = state.scenarios[index];
      if (!scenario) return;
      if (
        indexA < 0 ||
        indexA >= scenario.steps.length ||
        indexB < 0 ||
        indexB >= scenario.steps.length
      ) {
        return;
      }

      const newSteps = [...scenario.steps];
      const stepA = newSteps[indexA];
      const stepB = newSteps[indexB];
      if (!stepA || !stepB) return;
      newSteps[indexA] = stepB;
      newSteps[indexB] = stepA;

      const updated = [...state.scenarios];
      updated[index] = { ...scenario, steps: newSteps };

      // Update selection if it was one of the swapped items
      let newSelectedStep = state.selectedStepIndex;
      if (state.selectedStepIndex === indexA) {
        newSelectedStep = indexB;
      } else if (state.selectedStepIndex === indexB) {
        newSelectedStep = indexA;
      }

      setState({
        scenarios: updated,
        selectedStepIndex: newSelectedStep,
      });

      autoSave();
    },

    getSortedScenarios(): Scenario[] {
      return [...state.scenarios].sort((a, b) => b.lastUsedAt - a.lastUsedAt);
    },

    getSelectedScenario(): Scenario | null {
      if (!state.selectedScenarioId) return null;
      return state.scenarios.find((s) => s.id === state.selectedScenarioId) ?? null;
    },

    getScenarioById(id: string): Scenario | null {
      return state.scenarios.find((s) => s.id === id) ?? null;
    },
  };
}

// Singleton instance
export const scenariosStore = createScenariosStore();
