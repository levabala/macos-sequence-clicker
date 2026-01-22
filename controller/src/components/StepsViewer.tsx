// controller/src/components/StepsViewer.tsx
// Display steps of the selected scenario

import type { Step, Scenario } from "../types";
import { scenariosStore } from "../store/scenarios";
import { useStoreSubscription } from "../hooks/useStoreSubscription";

interface StepsViewerProps {
  focused: boolean;
  isInSubScenario?: boolean;
}

interface StepRowProps {
  step: Step;
  index: number;
  isFocused: boolean;
}

/**
 * Format a step for display
 */
function formatStep(step: Step, index: number): string {
  const num = `${index + 1}.`;

  switch (step.type) {
    case "click": {
      const btn = step.button === "left" ? "L" : "R";
      return `${num} Click ${btn} (${step.position.x}, ${step.position.y})`;
    }
    case "keypress": {
      const mods = step.modifiers
        .map((m) => {
          switch (m) {
            case "cmd":
              return "\u2318";
            case "ctrl":
              return "\u2303";
            case "alt":
              return "\u2325";
            case "shift":
              return "\u21E7";
            default:
              return m;
          }
        })
        .join("");
      return `${num} Key ${mods}${step.key.toUpperCase()}`;
    }
    case "delay":
      return `${num} Delay ${step.ms}ms`;
    case "pixel-state":
      return `${num} Pixel (${step.position.x}, ${step.position.y})`;
    case "pixel-zone":
      return `${num} Zone ${step.rect.width}x${step.rect.height}`;
    case "scenario-ref":
      return `${num} -> [${step.scenarioId}]`;
    default:
      return `${num} Unknown step`;
  }
}

function StepRow({ step, index, isFocused }: StepRowProps) {
  const prefix = isFocused ? "> " : "  ";
  const content = formatStep(step, index);

  // Color based on step type
  let fg = "#AAAAAA";
  switch (step.type) {
    case "click":
      fg = "#88CCFF"; // Light blue
      break;
    case "keypress":
      fg = "#FFCC88"; // Light orange
      break;
    case "delay":
      fg = "#88FF88"; // Light green
      break;
    case "pixel-state":
    case "pixel-zone":
      fg = "#FF88FF"; // Light magenta
      break;
    case "scenario-ref":
      fg = "#FFFF88"; // Light yellow
      break;
  }

  if (isFocused) {
    fg = "#FFFFFF";
  }

  const bg = isFocused ? "#444488" : undefined;

  return (
    // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
    <text fg={fg} backgroundColor={bg}>
      {prefix}{content}
    </text>
  );
}

export function StepsViewer({ focused, isInSubScenario = false }: StepsViewerProps) {
  const state = useStoreSubscription(scenariosStore);
  const scenario = scenariosStore.getSelectedScenario();
  const { selectedStepIndex } = state;

  if (!scenario) {
    return (
      <box flexDirection="column" padding={1}>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">Select a scenario</text>
      </box>
    );
  }

  if (scenario.steps.length === 0) {
    return (
      <box flexDirection="column" padding={1}>
        {isInSubScenario && (
          // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
          <text fg="#88FF88">[Sub] Ctrl+H to exit</text>
        )}
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">No steps</text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">Press 'r' to record</text>
      </box>
    );
  }

  return (
    <box flexDirection="column">
      {isInSubScenario && (
        // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
        <text fg="#88FF88">[Sub] Ctrl+H to exit</text>
      )}
      {scenario.steps.map((step, index) => (
        <StepRow
          key={`${scenario.id}-${index}`}
          step={step}
          index={index}
          isFocused={focused && index === selectedStepIndex}
        />
      ))}
    </box>
  );
}
