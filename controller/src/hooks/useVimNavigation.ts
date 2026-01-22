// controller/src/hooks/useVimNavigation.ts
// Vim-style navigation for the 3-column interface

import { useState, useCallback } from "react";
import { scenariosStore } from "../store/scenarios";

export type Column = 0 | 1 | 2; // scenarios, steps, preview

export interface VimNavigation {
  column: Column;
  
  // Sub-scenario navigation depth
  scenarioDepth: string[];
  isInSubScenario: boolean;

  // Column navigation
  moveLeft(): void;
  moveRight(): void;

  // Row navigation within column
  moveUp(): void;
  moveDown(): void;

  // Selection
  select(): void; // Ctrl+l - select scenario or enter sub-scenario
  back(): void; // Ctrl+h - deselect or exit sub-scenario

  // Step reordering
  swapUp(): void; // Ctrl+k - swap step with above
  swapDown(): void; // Ctrl+j - swap step with below
}

export function useVimNavigation(): VimNavigation {
  const [column, setColumn] = useState<Column>(0);
  const [scenarioDepth, setScenarioDepth] = useState<string[]>([]);

  const moveLeft = useCallback(() => {
    setColumn((c) => (c > 0 ? ((c - 1) as Column) : c));
  }, []);

  const moveRight = useCallback(() => {
    setColumn((c) => (c < 2 ? ((c + 1) as Column) : c));
  }, []);

  const moveUp = useCallback(() => {
    const state = scenariosStore.getState();
    const scenarios = scenariosStore.getSortedScenarios();

    if (column === 0) {
      // Navigate scenarios
      const currentIndex = scenarios.findIndex(
        (s) => s.id === state.selectedScenarioId
      );
      if (currentIndex > 0) {
        const prevScenario = scenarios[currentIndex - 1];
        if (prevScenario) {
          scenariosStore.selectScenario(prevScenario.id);
        }
      } else if (currentIndex === -1 && scenarios.length > 0) {
        // Nothing selected, select last
        const lastScenario = scenarios[scenarios.length - 1];
        if (lastScenario) {
          scenariosStore.selectScenario(lastScenario.id);
        }
      }
    } else if (column === 1) {
      // Navigate steps
      const scenario = scenariosStore.getSelectedScenario();
      if (!scenario) return;

      const currentStep = state.selectedStepIndex;
      if (currentStep === null) {
        // Select last step
        if (scenario.steps.length > 0) {
          scenariosStore.selectStep(scenario.steps.length - 1);
        }
      } else if (currentStep > 0) {
        scenariosStore.selectStep(currentStep - 1);
      }
    }
    // Column 2 (preview) has no row navigation
  }, [column]);

  const moveDown = useCallback(() => {
    const state = scenariosStore.getState();
    const scenarios = scenariosStore.getSortedScenarios();

    if (column === 0) {
      // Navigate scenarios
      const currentIndex = scenarios.findIndex(
        (s) => s.id === state.selectedScenarioId
      );
      if (currentIndex === -1 && scenarios.length > 0) {
        // Nothing selected, select first
        const firstScenario = scenarios[0];
        if (firstScenario) {
          scenariosStore.selectScenario(firstScenario.id);
        }
      } else if (currentIndex < scenarios.length - 1) {
        const nextScenario = scenarios[currentIndex + 1];
        if (nextScenario) {
          scenariosStore.selectScenario(nextScenario.id);
        }
      }
    } else if (column === 1) {
      // Navigate steps
      const scenario = scenariosStore.getSelectedScenario();
      if (!scenario) return;

      const currentStep = state.selectedStepIndex;
      if (currentStep === null) {
        // Select first step
        if (scenario.steps.length > 0) {
          scenariosStore.selectStep(0);
        }
      } else if (currentStep < scenario.steps.length - 1) {
        scenariosStore.selectStep(currentStep + 1);
      }
    }
    // Column 2 (preview) has no row navigation
  }, [column]);

  const select = useCallback(() => {
    // Ctrl+l: Move focus right and select, or enter sub-scenario
    if (column === 0) {
      // Select scenario and move to steps column
      const state = scenariosStore.getState();
      if (state.selectedScenarioId) {
        setColumn(1);
        // Auto-select first step if none selected
        const scenario = scenariosStore.getSelectedScenario();
        if (scenario && scenario.steps.length > 0 && state.selectedStepIndex === null) {
          scenariosStore.selectStep(0);
        }
      }
    } else if (column === 1) {
      // Check if current step is a scenario-ref - if so, enter it
      const state = scenariosStore.getState();
      const scenario = scenariosStore.getSelectedScenario();
      if (scenario && state.selectedStepIndex !== null) {
        const step = scenario.steps[state.selectedStepIndex];
        if (step?.type === "scenario-ref") {
          // Check if referenced scenario exists
          const referencedScenario = scenariosStore.getScenarioById(step.scenarioId);
          if (referencedScenario) {
            // Push current scenario to depth stack
            setScenarioDepth(prev => [...prev, scenario.id]);
            // Select the referenced scenario
            scenariosStore.selectScenario(step.scenarioId);
            scenariosStore.selectStep(referencedScenario.steps.length > 0 ? 0 : null);
            return;
          }
        }
      }
      // Default: Move to preview column
      setColumn(2);
    }
  }, [column]);

  const back = useCallback(() => {
    // Ctrl+h: Move focus left, or exit sub-scenario
    if (column === 2) {
      setColumn(1);
    } else if (column === 1) {
      // Check if we're in a sub-scenario - if so, exit it
      if (scenarioDepth.length > 0) {
        const parentId = scenarioDepth[scenarioDepth.length - 1];
        if (parentId) {
          setScenarioDepth(prev => prev.slice(0, -1));
          scenariosStore.selectScenario(parentId);
          scenariosStore.selectStep(null);
        }
        return;
      }
      setColumn(0);
      // Optionally clear step selection when going back to scenarios
      // scenariosStore.selectStep(null);
    }
  }, [column, scenarioDepth]);

  const swapUp = useCallback(() => {
    // Ctrl+k: Swap current step with the one above
    if (column !== 1) return;

    const state = scenariosStore.getState();
    const scenario = scenariosStore.getSelectedScenario();
    if (!scenario || state.selectedStepIndex === null) return;

    if (state.selectedStepIndex > 0) {
      scenariosStore.swapSteps(
        scenario.id,
        state.selectedStepIndex,
        state.selectedStepIndex - 1
      );
    }
  }, [column]);

  const swapDown = useCallback(() => {
    // Ctrl+j: Swap current step with the one below
    if (column !== 1) return;

    const state = scenariosStore.getState();
    const scenario = scenariosStore.getSelectedScenario();
    if (!scenario || state.selectedStepIndex === null) return;

    if (state.selectedStepIndex < scenario.steps.length - 1) {
      scenariosStore.swapSteps(
        scenario.id,
        state.selectedStepIndex,
        state.selectedStepIndex + 1
      );
    }
  }, [column]);

  return {
    column,
    scenarioDepth,
    isInSubScenario: scenarioDepth.length > 0,
    moveLeft,
    moveRight,
    moveUp,
    moveDown,
    select,
    back,
    swapUp,
    swapDown,
  };
}
