// controller/src/components/PlayModal.tsx
// Modal for scenario execution with hotkey capture and progress display

import { useState, useRef, useEffect } from "react";
import { useKeyboard } from "@opentui/react";
import { ProgressBar } from "./ProgressBar";
import { executeScenario, describeStep } from "../execution/executor";
import { ipc } from "../ipc/protocol";
import type { Scenario } from "../types";
import type { ExecutionProgress } from "../execution/executor";

interface KeyEvent {
  name: string;
  sequence?: string;
  ctrl: boolean;
  meta: boolean;
  shift: boolean;
  alt?: boolean;
}

interface PlayModalProps {
  scenario: Scenario;
  onClose: () => void;
}

type ModalPhase =
  | { phase: "capture" }
  | { phase: "ready"; hotkey: string; keyEvent: KeyEvent }
  | { phase: "executing"; progress: ExecutionProgress }
  | { phase: "done"; error?: string };

/**
 * Format a key event as a displayable hotkey string
 */
function formatHotkey(key: KeyEvent): string {
  const parts: string[] = [];
  if (key.ctrl) parts.push("Ctrl");
  if (key.alt) parts.push("Alt");
  if (key.shift) parts.push("Shift");
  if (key.meta) parts.push("Cmd");

  // Handle special key names
  let keyName = key.name;
  if (keyName === " " || keyName === "space") keyName = "Space";
  if (keyName === "return") keyName = "Enter";
  if (keyName === "tab") keyName = "Tab";

  // Capitalize the key name
  parts.push(keyName.charAt(0).toUpperCase() + keyName.slice(1));
  return parts.join("+");
}

/**
 * Compare two key events for equality
 */
function keysMatch(a: KeyEvent, b: KeyEvent): boolean {
  return (
    a.name === b.name &&
    a.ctrl === b.ctrl &&
    a.meta === b.meta &&
    a.shift === b.shift &&
    (a.alt ?? false) === (b.alt ?? false)
  );
}

export function PlayModal({ scenario, onClose }: PlayModalProps) {
  const [state, setState] = useState<ModalPhase>({ phase: "capture" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const autoCloseTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (autoCloseTimeoutRef.current) {
        clearTimeout(autoCloseTimeoutRef.current);
      }
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, []);

  async function startExecution() {
    // Hide recorder overlay if visible
    try {
      await ipc.hideRecorderOverlay();
    } catch {
      // Ignore errors if overlay wasn't showing
    }

    abortControllerRef.current = new AbortController();
    
    const initialProgress: ExecutionProgress = {
      currentStep: 0,
      totalSteps: scenario.steps.length,
      status: "running",
    };
    setState({ phase: "executing", progress: initialProgress });

    try {
      await executeScenario(
        scenario,
        abortControllerRef.current.signal,
        (progress) => setState({ phase: "executing", progress })
      );
      setState({ phase: "done" });
      
      // Auto-close after success
      autoCloseTimeoutRef.current = setTimeout(onClose, 1500);
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        setState({ phase: "done", error: "Aborted by user" });
      } else {
        setState({ phase: "done", error: String(e) });
      }
    }
  }

  useKeyboard((key: KeyEvent) => {
    // ESC always closes/aborts
    if (key.name === "escape") {
      if (state.phase === "executing") {
        abortControllerRef.current?.abort();
      }
      if (autoCloseTimeoutRef.current) {
        clearTimeout(autoCloseTimeoutRef.current);
      }
      onClose();
      return;
    }

    // Phase: capture hotkey
    if (state.phase === "capture") {
      const hotkey = formatHotkey(key);
      setState({ phase: "ready", hotkey, keyEvent: key });
      return;
    }

    // Phase: ready - check if hotkey matches
    if (state.phase === "ready") {
      if (keysMatch(key, state.keyEvent)) {
        startExecution();
      }
      return;
    }

    // During execution, only ESC works (handled above)
  });

  // Modal content based on phase
  const renderContent = () => {
    switch (state.phase) {
      case "capture":
        return (
          <box flexDirection="column" alignItems="center" padding={1}>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#FFFFFF">Press a key combination to trigger execution</text>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#666666">(ESC to cancel)</text>
          </box>
        );

      case "ready":
        return (
          <box flexDirection="column" alignItems="center" padding={1}>
            <box flexDirection="row">
              {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
              <text fg="#FFFFFF">Press </text>
              {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
              <text fg="#FFFF00">{state.hotkey}</text>
              {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
              <text fg="#FFFFFF"> to execute</text>
            </box>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#888888">"{scenario.name}"</text>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#666666">(ESC to cancel)</text>
          </box>
        );

      case "executing":
        return (
          <box flexDirection="column" alignItems="center" padding={1}>
            <box flexDirection="row">
              {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
              <text fg="#00FFFF">Executing: </text>
              {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
              <text fg="#FFFFFF">{scenario.name}</text>
            </box>
            <box marginTop={1}>
              <ProgressBar
                current={state.progress.currentStep}
                total={state.progress.totalSteps}
              />
            </box>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#888888">
              {state.progress.status === "waiting"
                ? "Waiting for condition..."
                : state.progress.currentStepDescription ?? "Running..."}
            </text>
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#666666">(ESC to abort)</text>
          </box>
        );

      case "done":
        return (
          <box flexDirection="column" alignItems="center" padding={1}>
            {state.error ? (
              // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
              <text fg="#FF4444">Error: {state.error}</text>
            ) : (
              // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
              <text fg="#00FF00">Completed successfully!</text>
            )}
            {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
            <text fg="#666666">(Press any key to close)</text>
          </box>
        );
    }
  };

  return (
    <box
      position="absolute"
      top="50%"
      left="50%"
      width={50}
      height={10}
      border
      borderStyle="double"
      borderColor={
        state.phase === "executing"
          ? "#00FFFF"
          : state.phase === "done" && !state.error
            ? "#00FF00"
            : state.phase === "done" && state.error
              ? "#FF4444"
              : "#FFFF00"
      }
      bg="#1a1a1a"
      flexDirection="column"
      justifyContent="center"
      alignItems="center"
    >
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#FFFFFF" bold>
        {state.phase === "capture"
          ? "Set Trigger Key"
          : state.phase === "ready"
            ? "Ready to Execute"
            : state.phase === "executing"
              ? "Executing..."
              : state.error
                ? "Execution Failed"
                : "Done"}
      </text>
      {renderContent()}
    </box>
  );
}
