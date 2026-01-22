// controller/src/store/index.ts
// Re-export all stores for convenient access

export {
  scenariosStore,
  createScenariosStore,
  type ScenariosState,
  type ScenariosStore,
} from "./scenarios";

export {
  historyStore,
  createHistoryStore,
  type HistoryEntry,
  type HistoryState,
  type HistoryStore,
} from "./history";

export {
  recorderStore,
  createRecorderStore,
  type RecorderState,
  type RecorderStatus,
  type RecorderStore,
} from "./recorder";

export {
  settingsStore,
  createSettingsStore,
  type Settings,
  type SettingsStore,
  DEFAULT_SETTINGS,
} from "./settings";

export {
  loadScenarios,
  saveScenarios,
  loadSettings,
  saveSettings,
  getConfigDir,
} from "./persistence";
