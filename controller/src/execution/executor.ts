// controller/src/execution/executor.ts
// Execution engine for running scenarios

import { ipc } from "../ipc/protocol";
import { scenariosStore } from "../store/scenarios";
import type { Scenario, Step } from "../types";

export interface ExecutionProgress {
  currentStep: number;
  totalSteps: number;
  status: "running" | "waiting" | "completed" | "aborted" | "error";
  currentStepDescription?: string;
  error?: string;
}

export type ProgressCallback = (progress: ExecutionProgress) => void;

/**
 * Count total steps including sub-scenarios recursively
 */
function countTotalSteps(scenario: Scenario, visited = new Set<string>()): number {
  // Prevent infinite recursion with circular references
  if (visited.has(scenario.id)) return 0;
  visited.add(scenario.id);

  let count = 0;
  for (const step of scenario.steps) {
    if (step.type === "scenario-ref") {
      const subScenario = scenariosStore.getScenarioById(step.scenarioId);
      if (subScenario) {
        count += countTotalSteps(subScenario, visited);
      }
    } else {
      count++;
    }
  }
  return count;
}

/**
 * Describe a step for display
 */
export function describeStep(step: Step): string {
  switch (step.type) {
    case "click":
      return `Click ${step.button} at (${step.position.x}, ${step.position.y})`;
    case "keypress": {
      const mods = step.modifiers.length > 0 ? step.modifiers.join("+") + "+" : "";
      return `Press ${mods}${step.key}`;
    }
    case "delay":
      return `Wait ${step.ms}ms`;
    case "pixel-state":
      return `Wait for pixel at (${step.position.x}, ${step.position.y})`;
    case "pixel-zone":
      return `Wait for color in zone`;
    case "scenario-ref": {
      const sub = scenariosStore.getScenarioById(step.scenarioId);
      return `Run "${sub?.name ?? "unknown"}"`;
    }
  }
}

/**
 * Sleep that can be aborted via AbortSignal
 */
function abortableSleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) {
      reject(new DOMException("Aborted", "AbortError"));
      return;
    }

    const timeout = setTimeout(resolve, ms);
    
    const abortHandler = () => {
      clearTimeout(timeout);
      reject(new DOMException("Aborted", "AbortError"));
    };

    signal.addEventListener("abort", abortHandler, { once: true });
  });
}

/**
 * Execute a single step
 */
async function executeStep(
  step: Step,
  signal: AbortSignal,
  onProgress: ProgressCallback | undefined,
  executedSteps: { count: number },
  totalSteps: number,
  visited: Set<string>
): Promise<void> {
  // Check for abort before each step
  if (signal.aborted) {
    throw new DOMException("Aborted", "AbortError");
  }

  switch (step.type) {
    case "click":
      await ipc.executeClick(step.position, step.button);
      break;

    case "keypress":
      await ipc.executeKeypress(step.key, step.modifiers);
      break;

    case "delay":
      await abortableSleep(step.ms, signal);
      break;

    case "pixel-state":
      onProgress?.({
        currentStep: executedSteps.count,
        totalSteps,
        status: "waiting",
        currentStepDescription: describeStep(step),
      });
      // waitForPixelState will poll until matched
      // Pass undefined for timeoutMs to wait indefinitely (relies on user abort)
      await ipc.waitForPixelState(
        step.position,
        step.color,
        step.threshold
      );
      break;

    case "pixel-zone":
      onProgress?.({
        currentStep: executedSteps.count,
        totalSteps,
        status: "waiting",
        currentStepDescription: describeStep(step),
      });
      await ipc.waitForPixelZone(
        step.rect,
        step.color,
        step.threshold
      );
      break;

    case "scenario-ref": {
      const subScenario = scenariosStore.getScenarioById(step.scenarioId);
      if (!subScenario) {
        throw new Error(`Sub-scenario not found: ${step.scenarioId}`);
      }
      // Execute sub-scenario (don't increment count here, it's done inside)
      await executeScenarioInternal(
        subScenario,
        signal,
        onProgress,
        executedSteps,
        totalSteps,
        visited
      );
      // Don't increment executedSteps here - sub-scenario handles its own steps
      return;
    }
  }

  // Increment step count after successful execution
  executedSteps.count++;
}

/**
 * Internal recursive execution function
 */
async function executeScenarioInternal(
  scenario: Scenario,
  signal: AbortSignal,
  onProgress: ProgressCallback | undefined,
  executedSteps: { count: number },
  totalSteps: number,
  visited: Set<string>
): Promise<void> {
  // Prevent infinite recursion
  if (visited.has(scenario.id)) {
    throw new Error(`Circular reference detected: ${scenario.name}`);
  }
  visited.add(scenario.id);

  for (const step of scenario.steps) {
    if (signal.aborted) {
      throw new DOMException("Aborted", "AbortError");
    }

    onProgress?.({
      currentStep: executedSteps.count,
      totalSteps,
      status: "running",
      currentStepDescription: describeStep(step),
    });

    await executeStep(step, signal, onProgress, executedSteps, totalSteps, visited);
  }

  // Remove from visited after completion (allows same scenario to be called again in sequence)
  visited.delete(scenario.id);
}

/**
 * Execute a scenario with all its steps
 * @param scenario The scenario to execute
 * @param signal AbortSignal for cancellation
 * @param onProgress Optional callback for progress updates
 */
export async function executeScenario(
  scenario: Scenario,
  signal: AbortSignal,
  onProgress?: ProgressCallback
): Promise<void> {
  const totalSteps = countTotalSteps(scenario);
  const executedSteps = { count: 0 };
  const visited = new Set<string>();

  if (totalSteps === 0) {
    onProgress?.({
      currentStep: 0,
      totalSteps: 0,
      status: "completed",
    });
    return;
  }

  try {
    await executeScenarioInternal(
      scenario,
      signal,
      onProgress,
      executedSteps,
      totalSteps,
      visited
    );

    // Mark scenario as used
    scenariosStore.touchScenario(scenario.id);

    onProgress?.({
      currentStep: totalSteps,
      totalSteps,
      status: "completed",
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      onProgress?.({
        currentStep: executedSteps.count,
        totalSteps,
        status: "aborted",
      });
      throw error;
    }

    onProgress?.({
      currentStep: executedSteps.count,
      totalSteps,
      status: "error",
      error: String(error),
    });
    throw error;
  }
}
