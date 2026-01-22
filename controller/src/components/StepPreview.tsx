// controller/src/components/StepPreview.tsx
// Detailed preview of the selected step

import type { Step } from "../types";
import { scenariosStore } from "../store/scenarios";
import { useStoreSubscription } from "../hooks/useStoreSubscription";

interface StepPreviewProps {
  focused: boolean;
}

// Constants for screen diagram
const SCREEN_W = 1920;
const SCREEN_H = 1080;
const DIAG_W = 28;
const DIAG_H = 12;

/**
 * ASCII diagram showing a point position on a screen
 */
function ScreenPositionDiagram({ x, y, color }: { x: number; y: number; color?: string }) {
  const px = Math.max(0, Math.min(DIAG_W - 1, Math.round((x / SCREEN_W) * (DIAG_W - 1))));
  const py = Math.max(0, Math.min(DIAG_H - 1, Math.round((y / SCREEN_H) * (DIAG_H - 1))));

  const lines: string[] = [];
  lines.push("\u250C" + "\u2500".repeat(DIAG_W) + "\u2510");

  for (let row = 0; row < DIAG_H; row++) {
    let line = "\u2502";
    for (let col = 0; col < DIAG_W; col++) {
      if (row === py && col === px) {
        line += "\u00D7"; // × marker for position
      } else {
        line += " ";
      }
    }
    line += "\u2502";
    lines.push(line);
  }

  lines.push("\u2514" + "\u2500".repeat(DIAG_W) + "\u2518");

  return (
    <box flexDirection="column">
      {lines.map((line, i) => (
        // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
        <text key={i} fg="#666666">{line}</text>
      ))}
      {color && (
        <text>
          {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
          Target: <text fg={color}>{"\u2588\u2588\u2588\u2588"}</text> {color}
        </text>
      )}
    </box>
  );
}

/**
 * ASCII diagram showing a rectangular zone on a screen
 */
function ScreenZoneDiagram({ x, y, width, height, color }: { 
  x: number; y: number; width: number; height: number; color: string 
}) {
  // Scale zone to diagram coordinates
  const zx1 = Math.max(0, Math.round((x / SCREEN_W) * (DIAG_W - 1)));
  const zy1 = Math.max(0, Math.round((y / SCREEN_H) * (DIAG_H - 1)));
  const zx2 = Math.min(DIAG_W - 1, Math.round(((x + width) / SCREEN_W) * (DIAG_W - 1)));
  const zy2 = Math.min(DIAG_H - 1, Math.round(((y + height) / SCREEN_H) * (DIAG_H - 1)));

  const lines: string[] = [];
  lines.push("\u250C" + "\u2500".repeat(DIAG_W) + "\u2510");

  for (let row = 0; row < DIAG_H; row++) {
    let line = "\u2502";
    for (let col = 0; col < DIAG_W; col++) {
      const inZone = col >= zx1 && col <= zx2 && row >= zy1 && row <= zy2;
      line += inZone ? "\u2592" : " "; // ░ for zone area
    }
    line += "\u2502";
    lines.push(line);
  }

  lines.push("\u2514" + "\u2500".repeat(DIAG_W) + "\u2518");

  return (
    <box flexDirection="column">
      {lines.map((line, i) => (
        // @ts-expect-error -- OpenTUI text element conflicts with React SVG text type
        <text key={i} fg="#666666">{line}</text>
      ))}
      <text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        Target: <text fg={color}>{"\u2588\u2588\u2588\u2588"}</text> {color}
      </text>
    </box>
  );
}

interface ClickPreviewProps {
  step: Extract<Step, { type: "click" }>;
}

function ClickPreview({ step }: ClickPreviewProps) {
  const buttonLabel = step.button === "left" ? "Left" : "Right";
  
  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#88CCFF">Click Action</text>
      <text>Button: {buttonLabel}</text>
      <text>Position: ({step.position.x}, {step.position.y})</text>
      <ScreenPositionDiagram x={step.position.x} y={step.position.y} />
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Simulates a {step.button} mouse click at the specified coordinates.
      </text>
    </box>
  );
}

interface KeypressPreviewProps {
  step: Extract<Step, { type: "keypress" }>;
}

function KeypressPreview({ step }: KeypressPreviewProps) {
  const modSymbols = step.modifiers.map((m) => {
    switch (m) {
      case "cmd": return "\u2318 Command";
      case "ctrl": return "\u2303 Control";
      case "alt": return "\u2325 Option";
      case "shift": return "\u21E7 Shift";
      default: return m;
    }
  });

  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#FFCC88">Keypress Action</text>
      <text>Key: {step.key.toUpperCase()}</text>
      {modSymbols.length > 0 && (
        <text>Modifiers: {modSymbols.join(", ")}</text>
      )}
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Simulates pressing the {step.key} key
        {modSymbols.length > 0 ? ` with ${modSymbols.join(" + ")}` : ""}.
      </text>
    </box>
  );
}

interface DelayPreviewProps {
  step: Extract<Step, { type: "delay" }>;
}

function DelayPreview({ step }: DelayPreviewProps) {
  const seconds = (step.ms / 1000).toFixed(1);
  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#88FF88">Delay Transition</text>
      <text>Duration: {step.ms}ms ({seconds}s)</text>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Waits for {step.ms} milliseconds before proceeding to the next step.
      </text>
    </box>
  );
}

interface PixelStatePreviewProps {
  step: Extract<Step, { type: "pixel-state" }>;
}

function PixelStatePreview({ step }: PixelStatePreviewProps) {
  const { r, g, b } = step.color;
  const hexColor = `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`.toUpperCase();

  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#FF88FF">Pixel State Transition</text>
      <text>Position: ({step.position.x}, {step.position.y})</text>
      <text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        Color: <text fg={hexColor}>{"\u2588\u2588\u2588\u2588"}</text> {hexColor} (RGB: {r}, {g}, {b})
      </text>
      <text>Threshold: {step.threshold}</text>
      <ScreenPositionDiagram x={step.position.x} y={step.position.y} color={hexColor} />
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Waits until the pixel at ({step.position.x}, {step.position.y}) matches
        the target color within threshold {step.threshold}.
      </text>
    </box>
  );
}

interface PixelZonePreviewProps {
  step: Extract<Step, { type: "pixel-zone" }>;
}

function PixelZonePreview({ step }: PixelZonePreviewProps) {
  const { r, g, b } = step.color;
  const hexColor = `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`.toUpperCase();
  const { x, y, width, height } = step.rect;

  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#FF88FF">Pixel Zone Transition</text>
      <text>Rectangle: ({x}, {y}) {width}x{height}</text>
      <text>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        Color: <text fg={hexColor}>{"\u2588\u2588\u2588\u2588"}</text> {hexColor} (RGB: {r}, {g}, {b})
      </text>
      <text>Threshold: {step.threshold}</text>
      <ScreenZoneDiagram x={x} y={y} width={width} height={height} color={hexColor} />
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Waits until any pixel in the zone matches the target color.
      </text>
    </box>
  );
}

interface ScenarioRefPreviewProps {
  step: Extract<Step, { type: "scenario-ref" }>;
}

function ScenarioRefPreview({ step }: ScenarioRefPreviewProps) {
  const referencedScenario = scenariosStore.getScenarioById(step.scenarioId);

  return (
    <box flexDirection="column" gap={1}>
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#FFFF88">Scenario Reference</text>
      {referencedScenario ? (
        <>
          <text>Name: {referencedScenario.name}</text>
          <text>Steps: {referencedScenario.steps.length}</text>
          {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
          <text fg="#88FF88">Press Ctrl+L to enter sub-scenario</text>
        </>
      ) : (
        <>
          <text>ID: {step.scenarioId}</text>
          {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
          <text fg="#FF6666">Warning: Scenario not found!</text>
        </>
      )}
      {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
      <text fg="#666666">
        Executes another scenario as a sub-routine.
      </text>
    </box>
  );
}

export function StepPreview({ focused }: StepPreviewProps) {
  const state = useStoreSubscription(scenariosStore);
  const scenario = scenariosStore.getSelectedScenario();
  const { selectedStepIndex } = state;

  if (!scenario || selectedStepIndex === null) {
    return (
      <box flexDirection="column" padding={1}>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">Select a step to preview</text>
      </box>
    );
  }

  const step = scenario.steps[selectedStepIndex];
  if (!step) {
    return (
      <box flexDirection="column" padding={1}>
        {/* @ts-expect-error -- OpenTUI text element conflicts with React SVG text type */}
        <text fg="#666666">Invalid step index</text>
      </box>
    );
  }

  return (
    <box flexDirection="column" padding={1}>
      {step.type === "click" && <ClickPreview step={step} />}
      {step.type === "keypress" && <KeypressPreview step={step} />}
      {step.type === "delay" && <DelayPreview step={step} />}
      {step.type === "pixel-state" && <PixelStatePreview step={step} />}
      {step.type === "pixel-zone" && <PixelZonePreview step={step} />}
      {step.type === "scenario-ref" && <ScenarioRefPreview step={step} />}
    </box>
  );
}
