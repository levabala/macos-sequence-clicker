// controller/src/store/settings.ts
// Settings store for user preferences

import type { Point } from "../types";
import {
  loadSettings as loadSettingsFromDisk,
  saveSettings as saveSettingsToDisk,
  DEFAULT_SETTINGS,
  type Settings,
} from "./persistence";

type Listener = () => void;

export type { Settings };
export { DEFAULT_SETTINGS };

export interface SettingsStore {
  getState(): Settings;
  subscribe(listener: Listener): () => void;

  /**
   * Load settings from disk
   */
  load(): Promise<void>;

  /**
   * Save current settings to disk
   */
  save(): Promise<void>;

  /**
   * Update a single setting
   */
  set<K extends keyof Settings>(key: K, value: Settings[K]): void;

  /**
   * Update multiple settings at once
   */
  update(partial: Partial<Settings>): void;

  /**
   * Reset settings to defaults
   */
  reset(): void;

  /**
   * Get the last overlay position (convenience method)
   */
  getLastOverlayPosition(): Point | undefined;

  /**
   * Set the last overlay position (convenience method)
   */
  setLastOverlayPosition(position: Point): void;
}

export function createSettingsStore(): SettingsStore {
  let state: Settings = { ...DEFAULT_SETTINGS };

  const listeners = new Set<Listener>();

  function notify(): void {
    for (const listener of listeners) {
      listener();
    }
  }

  function setState(newState: Settings): void {
    state = newState;
    notify();
  }

  async function autoSave(): Promise<void> {
    await saveSettingsToDisk(state);
  }

  return {
    getState(): Settings {
      return state;
    },

    subscribe(listener: Listener): () => void {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    async load(): Promise<void> {
      const settings = await loadSettingsFromDisk();
      setState(settings);
    },

    async save(): Promise<void> {
      await autoSave();
    },

    set<K extends keyof Settings>(key: K, value: Settings[K]): void {
      setState({ ...state, [key]: value });
      autoSave();
    },

    update(partial: Partial<Settings>): void {
      setState({ ...state, ...partial });
      autoSave();
    },

    reset(): void {
      setState({ ...DEFAULT_SETTINGS });
      autoSave();
    },

    getLastOverlayPosition(): Point | undefined {
      return state.lastOverlayPosition;
    },

    setLastOverlayPosition(position: Point): void {
      setState({ ...state, lastOverlayPosition: position });
      autoSave();
    },
  };
}

// Singleton instance
export const settingsStore = createSettingsStore();
