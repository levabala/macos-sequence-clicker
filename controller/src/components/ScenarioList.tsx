// controller/src/components/ScenarioList.tsx
// List of scenarios with selection and focus indicators

import type { Scenario } from "../types";
import { scenariosStore, type ScenariosState } from "../store/scenarios";
import { recorderStore, type RecorderState } from "../store/recorder";
import { useStoreSubscription } from "../hooks/useStoreSubscription";

interface ScenarioListProps {
  focused: boolean;
}

interface ScenarioRowProps {
  scenario: Scenario;
  isSelected: boolean;
  isFocused: boolean;
  isRecording: boolean;
  isNaming: boolean;
  namingValue: string;
  index: number;
}

function ScenarioRow({
  scenario,
  isSelected,
  isFocused,
  isRecording,
  isNaming,
  namingValue,
  index,
}: ScenarioRowProps) {
  // Build row content
  const prefix = isFocused ? "> " : "  ";
  
  // Display name - show naming cursor if in naming mode for this scenario
  let displayName: string;
  if (isNaming) {
    // Show the current input with a cursor
    const inputText = namingValue || "";
    displayName = inputText + "█";
    // Truncate if too long
    if (displayName.length > 18) {
      displayName = displayName.slice(0, 15) + "...█";
    }
  } else {
    displayName = scenario.name.length > 18 
      ? scenario.name.slice(0, 15) + "..." 
      : scenario.name;
  }
  
  // Recording indicator (red dot)
  const suffix = isRecording ? " ●" : "";
  const content = `${prefix}${displayName}${suffix}`;

  // Determine colors based on state
  let fg = "#888888";
  let bg: string | undefined = undefined;

  if (isSelected) {
    fg = "#FFFFFF";
    bg = "#444488";
  }
  if (isFocused) {
    fg = "#FFFF00";
    if (isSelected) {
      bg = "#666699";
    }
  }
  if (isRecording) {
    fg = "#FF4444";
  }
  if (isNaming) {
    fg = "#00FF00"; // Green for naming mode
    bg = "#224422";
  }

  return (
    // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
    <text fg={fg} backgroundColor={bg}>
      {content}
    </text>
  );
}

export function ScenarioList({ focused }: ScenarioListProps) {
  const scenariosState = useStoreSubscription(scenariosStore);
  const recorderState = useStoreSubscription(recorderStore);

  const scenarios = scenariosStore.getSortedScenarios();
  const { selectedScenarioId } = scenariosState;
  
  // Get recording/naming scenario info
  const recordingScenarioId =
    recorderState.status === "recording" ? recorderState.scenarioId : null;
  const namingScenarioId =
    recorderState.status === "naming" ? recorderState.scenarioId : null;
  const namingValue =
    recorderState.status === "naming" ? recorderState.name : "";

  // Find the focused index (which row has keyboard focus)
  const focusedIndex = focused
    ? scenarios.findIndex((s) => s.id === selectedScenarioId)
    : -1;

  if (scenarios.length === 0) {
    return (
      <box flexDirection="column" padding={1}>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">No scenarios</text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">Press 'c' to create</text>
      </box>
    );
  }

  return (
    <box flexDirection="column">
      {scenarios.map((scenario, index) => (
        <ScenarioRow
          key={scenario.id}
          scenario={scenario}
          index={index}
          isSelected={scenario.id === selectedScenarioId}
          isFocused={focused && index === focusedIndex}
          isRecording={scenario.id === recordingScenarioId}
          isNaming={scenario.id === namingScenarioId}
          namingValue={namingValue}
        />
      ))}
    </box>
  );
}
