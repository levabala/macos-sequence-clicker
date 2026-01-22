// controller/src/components/App.tsx
// Main application shell with 3-column layout

import { useState } from "react";
import { useKeyboard, useRenderer } from "@opentui/react";
import { useVimNavigation } from "../hooks/useVimNavigation";
import { useRecording } from "../hooks/useRecording";
import { ScenarioList } from "./ScenarioList";
import { StepsViewer } from "./StepsViewer";
import { StepPreview } from "./StepPreview";
import { StatusBar } from "./StatusBar";
import { PlayModal } from "./PlayModal";
import { scenariosStore } from "../store/scenarios";
import { historyStore } from "../store/history";
import { recorderStore } from "../store/recorder";
import { useStoreSubscription } from "../hooks/useStoreSubscription";
import { ipc } from "../ipc/protocol";

export function App() {
  const nav = useVimNavigation();
  const renderer = useRenderer();
  const recorderState = useStoreSubscription(recorderStore);
  const recording = useRecording();
  const [showPlayModal, setShowPlayModal] = useState(false);
  const scenariosState = useStoreSubscription(scenariosStore);

  // Handle keyboard input
  useKeyboard((key) => {
    // Global escape handler
    if (key.name === "escape") {
      if (recorderState.status === "recording") {
        // Stop recording and hide overlay
        recording.toggleRecording();
        return;
      }
      if (recorderState.status === "naming") {
        recording.cancelNaming();
        return;
      }
    }

    // While recording, only handle escape and 'r' to stop
    if (recorderState.status === "recording") {
      if (key.name === "r") {
        recording.toggleRecording();
      }
      return;
    }

    // While naming, handle text input
    if (recorderState.status === "naming") {
      if (key.name === "return") {
        recording.finishNaming();
        return;
      }
      if (key.name === "backspace") {
        recorderStore.backspaceName();
        return;
      }
      // Regular character input
      if (key.sequence && key.sequence.length === 1 && !key.ctrl && !key.meta) {
        recorderStore.appendToName(key.sequence);
        return;
      }
      return;
    }

    // Vim navigation
    if (key.name === "h" && !key.ctrl) {
      nav.moveLeft();
      return;
    }
    if (key.name === "l" && !key.ctrl) {
      nav.moveRight();
      return;
    }
    if (key.name === "j" && !key.ctrl) {
      nav.moveDown();
      return;
    }
    if (key.name === "k" && !key.ctrl) {
      nav.moveUp();
      return;
    }

    // Ctrl+L: select/enter
    if (key.name === "l" && key.ctrl) {
      nav.select();
      return;
    }
    // Ctrl+H: back
    if (key.name === "h" && key.ctrl) {
      nav.back();
      return;
    }
    // Ctrl+J: swap down
    if (key.name === "j" && key.ctrl) {
      nav.swapDown();
      return;
    }
    // Ctrl+K: swap up
    if (key.name === "k" && key.ctrl) {
      nav.swapUp();
      return;
    }

    // Actions
    if (key.name === "c") {
      // Create new scenario and enter naming mode
      const scenario = scenariosStore.createScenario("New Scenario");
      recorderStore.startNaming(scenario.id);
      return;
    }

    if (key.name === "n") {
      // Rename selected scenario (pre-fill with existing name)
      const scenario = scenariosStore.getSelectedScenario();
      if (scenario) {
        recorderStore.startNaming(scenario.id, scenario.name);
      }
      return;
    }

    if (key.name === "d") {
      // Delete selected step
      const state = scenariosStore.getState();
      if (
        state.selectedScenarioId &&
        state.selectedStepIndex !== null &&
        nav.column === 1
      ) {
        historyStore.deleteStep(state.selectedScenarioId, state.selectedStepIndex);
      }
      return;
    }

    if (key.name === "u") {
      // Undo
      historyStore.undo();
      return;
    }

    if (key.name === "q") {
      // Quit - always try to hide overlay in case it's showing
      ipc.hideRecorderOverlay().catch(() => {});
      renderer.destroy();
      process.exit(0);
    }

    // Recording
    if (key.name === "r") {
      recording.toggleRecording();
      return;
    }

    if (key.name === "p") {
      // Play - open play modal if scenario has steps
      const scenario = scenariosStore.getSelectedScenario();
      if (scenario && scenario.steps.length > 0) {
        setShowPlayModal(true);
      }
      return;
    }
  });

  // Get selected scenario for play modal
  const selectedScenario = scenariosStore.getSelectedScenario();

  return (
    <box flexDirection="column" width="100%" height="100%">
      {/* Header */}
      <box
        border
        borderStyle="single"
        height={3}
        justifyContent="center"
        alignItems="center"
      >
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#00FFFF">macOS Smart Sequencer</text>
      </box>

      {/* Main content - 3 columns */}
      <box flexDirection="row" flexGrow={1}>
        {/* Scenarios column */}
        <box
          title="Scenarios"
          border
          borderStyle="single"
          borderColor={nav.column === 0 ? "#FFFF00" : "#666666"}
          width="25%"
          flexDirection="column"
        >
          <ScenarioList focused={nav.column === 0} />
        </box>

        {/* Steps column */}
        <box
          title={nav.isInSubScenario ? "Steps (sub)" : "Steps"}
          border
          borderStyle="single"
          borderColor={nav.column === 1 ? "#FFFF00" : "#666666"}
          width="35%"
          flexDirection="column"
        >
          <StepsViewer focused={nav.column === 1} isInSubScenario={nav.isInSubScenario} />
        </box>

        {/* Preview column */}
        <box
          title="Preview"
          border
          borderStyle="single"
          borderColor={nav.column === 2 ? "#FFFF00" : "#666666"}
          flexGrow={1}
          flexDirection="column"
        >
          <StepPreview focused={nav.column === 2} />
        </box>
      </box>

      {/* Status bar */}
      <StatusBar column={nav.column} isExecuting={showPlayModal} />

      {/* Play modal overlay */}
      {showPlayModal && selectedScenario && (
        <PlayModal
          scenario={selectedScenario}
          onClose={() => setShowPlayModal(false)}
        />
      )}
    </box>
  );
}
