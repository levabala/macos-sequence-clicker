// controller/src/hooks/useRecording.ts
// Hook for managing recording state and event handling

import { useEffect, useCallback, useRef } from "react";
import { swiftBridge } from "../ipc/bridge";
import { ipc } from "../ipc/protocol";
import { scenariosStore } from "../store/scenarios";
import { recorderStore } from "../store/recorder";
import { settingsStore, DEFAULT_SETTINGS } from "../store/settings";
import { useStoreSubscription } from "./useStoreSubscription";
import type {
  Step,
  Rect,
  IPCEvent,
  ClickAction,
  KeypressAction,
  DelayTransition,
  PixelStateTransition,
  PixelZoneTransition,
} from "../types";

// Default threshold for pixel detection
const DEFAULT_THRESHOLD = DEFAULT_SETTINGS.defaultThreshold;

export interface UseRecordingReturn {
  /** Start or stop recording */
  toggleRecording: () => Promise<void>;
  /** Finish naming a new scenario and start recording */
  finishNaming: () => Promise<void>;
  /** Cancel naming mode */
  cancelNaming: () => void;
  /** Whether currently recording */
  isRecording: boolean;
  /** Whether currently naming a new scenario */
  isNaming: boolean;
  /** The name being typed during naming mode */
  namingValue: string;
}

export function useRecording(): UseRecordingReturn {
  const recorderState = useStoreSubscription(recorderStore);
  
  // Track pending zone selection for pixel-zone creation
  const pendingZoneRef = useRef<Rect | null>(null);
  
  // Track current recorder state for overlay sync
  const overlayStateRef = useRef<{
    state: "idle" | "action" | "transition";
    subState?: "mouse" | "keyboard" | "time" | "pixel";
  }>({ state: "idle" });

  /**
   * Add a step to the current recording scenario
   */
  const addStep = useCallback((step: Step) => {
    const state = recorderStore.getState();
    if (state.status !== "recording") return;

    const { scenarioId, insertAfterIndex } = state;
    scenariosStore.addStep(scenarioId, step, insertAfterIndex ?? undefined);

    // Update insertAfterIndex to point to the newly added step
    const scenario = scenariosStore.getScenarioById(scenarioId);
    if (scenario) {
      const newIndex = insertAfterIndex !== null 
        ? insertAfterIndex + 1 
        : scenario.steps.length - 1;
      
      // Re-enter recording state with updated index
      recorderStore.stopRecording();
      recorderStore.startRecording(scenarioId, newIndex);
    }
  }, []);

  /**
   * Handle IPC events during recording
   */
  useEffect(() => {
    if (recorderState.status !== "recording") return;

    const handleMouseClicked = (event: IPCEvent & { event: "mouseClicked" }) => {
      // Only capture clicks when in action/mouse mode
      if (overlayStateRef.current.state !== "action") return;
      if (overlayStateRef.current.subState !== "mouse") return;

      const step: ClickAction = {
        type: "click",
        position: event.data.position,
        button: event.data.button,
      };
      addStep(step);
    };

    const handleKeyPressed = (event: IPCEvent & { event: "keyPressed" }) => {
      // Only capture keypresses when in action/keyboard mode
      if (overlayStateRef.current.state !== "action") return;
      if (overlayStateRef.current.subState !== "keyboard") return;

      const step: KeypressAction = {
        type: "keypress",
        key: event.data.key,
        modifiers: event.data.modifiers,
      };
      addStep(step);
    };

    const handlePixelSelected = (event: IPCEvent & { event: "pixelSelected" }) => {
      const { position, color } = event.data;

      if (pendingZoneRef.current) {
        // Create pixel-zone step (zone was already selected)
        const step: PixelZoneTransition = {
          type: "pixel-zone",
          rect: pendingZoneRef.current,
          color,
          threshold: settingsStore.getState().defaultThreshold ?? DEFAULT_THRESHOLD,
        };
        addStep(step);
        pendingZoneRef.current = null;
        
        // Hide magnifier after selection
        ipc.hideMagnifier();
      } else {
        // Create pixel-state step
        const step: PixelStateTransition = {
          type: "pixel-state",
          position,
          color,
          threshold: settingsStore.getState().defaultThreshold ?? DEFAULT_THRESHOLD,
        };
        addStep(step);
        
        // Hide magnifier after selection
        ipc.hideMagnifier();
      }
    };

    const handleZoneSelected = (event: IPCEvent & { event: "zoneSelected" }) => {
      // Store the zone and show magnifier for color selection
      pendingZoneRef.current = event.data.rect;
      ipc.showMagnifier();
    };

    const handleTimeInputCompleted = (event: IPCEvent & { event: "timeInputCompleted" }) => {
      const step: DelayTransition = {
        type: "delay",
        ms: event.data.ms,
      };
      addStep(step);
    };

    const handleOverlayClosed = () => {
      // User closed the overlay, stop recording
      recorderStore.stopRecording();
      pendingZoneRef.current = null;
    };

    const handleOverlayMoved = (event: IPCEvent & { event: "overlayMoved" }) => {
      // Save overlay position for next time
      settingsStore.setLastOverlayPosition(event.data.position);
    };

    const handleOverlayIconClicked = async (event: IPCEvent & { event: "overlayIconClicked" }) => {
      const { icon } = event.data;

      switch (icon) {
        case "action":
          // Enter action mode, default to mouse
          overlayStateRef.current = { state: "action", subState: "mouse" };
          await ipc.setRecorderState("action", "mouse");
          break;

        case "transition":
          // Enter transition mode, default to pixel
          overlayStateRef.current = { state: "transition", subState: "pixel" };
          await ipc.setRecorderState("transition", "pixel");
          break;

        case "mouse":
          if (overlayStateRef.current.state === "action") {
            // In action mode: mouse means click capture
            overlayStateRef.current.subState = "mouse";
            await ipc.setRecorderState("action", "mouse");
          } else if (overlayStateRef.current.state === "transition") {
            // In transition mode: mouse means pixel selection
            overlayStateRef.current.subState = "pixel";
            await ipc.setRecorderState("transition", "pixel");
            await ipc.showMagnifier();
          }
          break;

        case "keyboard":
          // Keyboard only makes sense in action mode
          overlayStateRef.current = { state: "action", subState: "keyboard" };
          await ipc.setRecorderState("action", "keyboard");
          break;

        case "time":
          // Time input - transition mode
          overlayStateRef.current = { state: "transition", subState: "time" };
          await ipc.setRecorderState("transition", "time");
          break;
      }
    };

    // Register event listeners (cast to any to avoid TS2590 union complexity error)
    const bridge = swiftBridge as {
      on: (event: string, cb: (data: unknown) => void) => void;
      off: (event: string, cb: (data: unknown) => void) => void;
    };
    bridge.on("mouseClicked", handleMouseClicked as (data: unknown) => void);
    bridge.on("keyPressed", handleKeyPressed as (data: unknown) => void);
    bridge.on("pixelSelected", handlePixelSelected as (data: unknown) => void);
    bridge.on("zoneSelected", handleZoneSelected as (data: unknown) => void);
    bridge.on("timeInputCompleted", handleTimeInputCompleted as (data: unknown) => void);
    bridge.on("overlayClosed", handleOverlayClosed as (data: unknown) => void);
    bridge.on("overlayMoved", handleOverlayMoved as (data: unknown) => void);
    bridge.on("overlayIconClicked", handleOverlayIconClicked as (data: unknown) => void);

    return () => {
      // Cleanup listeners
      bridge.off("mouseClicked", handleMouseClicked as (data: unknown) => void);
      bridge.off("keyPressed", handleKeyPressed as (data: unknown) => void);
      bridge.off("pixelSelected", handlePixelSelected as (data: unknown) => void);
      bridge.off("zoneSelected", handleZoneSelected as (data: unknown) => void);
      bridge.off("timeInputCompleted", handleTimeInputCompleted as (data: unknown) => void);
      bridge.off("overlayClosed", handleOverlayClosed as (data: unknown) => void);
      bridge.off("overlayMoved", handleOverlayMoved as (data: unknown) => void);
      bridge.off("overlayIconClicked", handleOverlayIconClicked as (data: unknown) => void);
    };
  }, [recorderState.status, addStep]);

  /**
   * Toggle recording on/off
   */
  const toggleRecording = useCallback(async () => {
    const state = recorderStore.getState();

    if (state.status === "recording") {
      // Stop recording
      await ipc.hideRecorderOverlay();
      recorderStore.stopRecording();
      overlayStateRef.current = { state: "idle" };
      pendingZoneRef.current = null;
    } else if (state.status === "idle") {
      // Check if we have a selected scenario
      const selectedScenario = scenariosStore.getSelectedScenario();
      const scenariosState = scenariosStore.getState();

      if (selectedScenario) {
        // Start recording into existing scenario
        const insertAfterIndex = scenariosState.selectedStepIndex;
        recorderStore.startRecording(selectedScenario.id, insertAfterIndex);
        
        // Show overlay
        const position = settingsStore.getLastOverlayPosition();
        await ipc.showRecorderOverlay(position);
        overlayStateRef.current = { state: "idle" };
      } else {
        // No scenario selected - create new one and enter naming mode
        const newScenario = scenariosStore.createScenario("New Scenario");
        recorderStore.startNaming(newScenario.id);
      }
    }
    // If in naming state, do nothing (user needs to finish/cancel naming first)
  }, []);

  /**
   * Finish naming and start recording
   */
  const finishNaming = useCallback(async () => {
    const state = recorderStore.getState();
    if (state.status !== "naming") return;

    const name = recorderStore.finishNaming();
    if (name) {
      scenariosStore.updateScenarioName(state.scenarioId, name);
    }

    // Now start recording
    recorderStore.startRecording(state.scenarioId, null);
    
    // Show overlay
    const position = settingsStore.getLastOverlayPosition();
    await ipc.showRecorderOverlay(position);
    overlayStateRef.current = { state: "idle" };
  }, []);

  /**
   * Cancel naming mode
   */
  const cancelNaming = useCallback(() => {
    const state = recorderStore.getState();
    if (state.status !== "naming") return;

    // Delete the empty scenario we created
    scenariosStore.deleteScenario(state.scenarioId);
    recorderStore.cancelNaming();
  }, []);

  return {
    toggleRecording,
    finishNaming,
    cancelNaming,
    isRecording: recorderState.status === "recording",
    isNaming: recorderState.status === "naming",
    namingValue: recorderState.status === "naming" ? recorderState.name : "",
  };
}
