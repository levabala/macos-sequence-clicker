// controller/src/store/recorder.ts
// State machine for recording mode

type Listener = () => void;

export type RecorderStatus = "idle" | "recording" | "naming";

export type RecorderState =
  | { status: "idle" }
  | { status: "recording"; scenarioId: string; insertAfterIndex: number | null }
  | { status: "naming"; scenarioId: string; name: string };

export interface RecorderStore {
  getState(): RecorderState;
  subscribe(listener: Listener): () => void;

  /**
   * Start recording into a scenario
   * @param scenarioId - The scenario to record into
   * @param insertAfterIndex - Insert new steps after this index, or null to append
   */
  startRecording(scenarioId: string, insertAfterIndex: number | null): void;

  /**
   * Stop recording and return to idle
   */
  stopRecording(): void;

  /**
   * Start naming a scenario (used when creating new scenarios or renaming)
   * @param scenarioId - The scenario to name
   * @param initialName - Optional initial name (for renaming existing scenarios)
   */
  startNaming(scenarioId: string, initialName?: string): void;

  /**
   * Append a character to the name being edited
   */
  appendToName(char: string): void;

  /**
   * Remove the last character from the name being edited
   */
  backspaceName(): void;

  /**
   * Finish naming and return the final name
   * Returns null if not in naming state
   */
  finishNaming(): string | null;

  /**
   * Cancel naming and return to idle
   */
  cancelNaming(): void;

  /**
   * Check if currently recording
   */
  isRecording(): boolean;

  /**
   * Check if currently naming
   */
  isNaming(): boolean;

  /**
   * Get the current scenario ID being recorded/named
   */
  getCurrentScenarioId(): string | null;
}

export function createRecorderStore(): RecorderStore {
  let state: RecorderState = { status: "idle" };

  const listeners = new Set<Listener>();

  function notify(): void {
    for (const listener of listeners) {
      listener();
    }
  }

  function setState(newState: RecorderState): void {
    state = newState;
    notify();
  }

  return {
    getState(): RecorderState {
      return state;
    },

    subscribe(listener: Listener): () => void {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    startRecording(scenarioId: string, insertAfterIndex: number | null): void {
      if (state.status !== "idle") {
        console.warn(
          `Cannot start recording: already in ${state.status} state`
        );
        return;
      }

      setState({
        status: "recording",
        scenarioId,
        insertAfterIndex,
      });
    },

    stopRecording(): void {
      if (state.status !== "recording") {
        console.warn("Cannot stop recording: not currently recording");
        return;
      }

      setState({ status: "idle" });
    },

    startNaming(scenarioId: string, initialName?: string): void {
      if (state.status !== "idle") {
        console.warn(`Cannot start naming: already in ${state.status} state`);
        return;
      }

      setState({
        status: "naming",
        scenarioId,
        name: initialName ?? "",
      });
    },

    appendToName(char: string): void {
      if (state.status !== "naming") return;

      setState({
        ...state,
        name: state.name + char,
      });
    },

    backspaceName(): void {
      if (state.status !== "naming") return;

      setState({
        ...state,
        name: state.name.slice(0, -1),
      });
    },

    finishNaming(): string | null {
      if (state.status !== "naming") return null;

      const name = state.name.trim() || "Untitled Scenario";
      setState({ status: "idle" });
      return name;
    },

    cancelNaming(): void {
      if (state.status !== "naming") return;
      setState({ status: "idle" });
    },

    isRecording(): boolean {
      return state.status === "recording";
    },

    isNaming(): boolean {
      return state.status === "naming";
    },

    getCurrentScenarioId(): string | null {
      if (state.status === "idle") return null;
      return state.scenarioId;
    },
  };
}

// Singleton instance
export const recorderStore = createRecorderStore();
