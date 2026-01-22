// controller/src/components/StatusBar.tsx
// Status bar with keyboard hints and current state info

import { historyStore } from "../store/history";
import { recorderStore } from "../store/recorder";
import { useStoreSubscription } from "../hooks/useStoreSubscription";
import type { Column } from "../hooks/useVimNavigation";

interface StatusBarProps {
  column: Column;
  isExecuting?: boolean;
}

export function StatusBar({ column, isExecuting = false }: StatusBarProps) {
  const historyState = useStoreSubscription(historyStore);
  const recorderState = useStoreSubscription(recorderStore);

  const canUndo = historyStore.canUndo();
  const isRecording = recorderState.status === "recording";
  const isNaming = recorderState.status === "naming";

  // Build keybinding hints based on current column
  const hints: string[] = [];

  if (isExecuting) {
    hints.push("ESC: abort/close");
    hints.push("Scenario execution in progress...");
  } else if (isRecording) {
    hints.push("r/ESC: stop recording");
    hints.push("Use overlay to capture actions");
  } else if (isNaming) {
    hints.push("Enter: confirm", "ESC: cancel", "Type scenario name...");
  } else {
    // Navigation hints
    hints.push("h/l: columns", "j/k: rows");

    // Context-specific hints
    if (column === 0) {
      hints.push("C-l: select", "c: create", "n: rename", "r: record");
    } else if (column === 1) {
      hints.push("C-h: back", "C-j/k: reorder", "d: delete", "r: record");
    } else {
      hints.push("C-h: back");
    }

    // Action hints
    hints.push("p: play");

    if (canUndo) {
      hints.push("u: undo");
    }

    hints.push("q: quit");
  }

  // Column indicator
  const columnNames = ["Scenarios", "Steps", "Preview"];
  const columnIndicator = columnNames
    .map((name, i) => (i === column ? `[${name}]` : name))
    .join(" | ");

  return (
    <box
      border
      borderStyle="single"
      height={4}
      flexDirection="column"
      padding={0}
    >
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#888888">{hints.join(" | ")}</text>
      <box flexDirection="row" justifyContent="space-between">
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">{columnIndicator}</text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        {isExecuting && <text fg="#00FFFF">▶ EXECUTING</text>}
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        {isRecording && !isExecuting && <text fg="#FF4444">● RECORDING</text>}
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        {isNaming && !isExecuting && <text fg="#00FF00">✎ NAMING</text>}
      </box>
    </box>
  );
}
