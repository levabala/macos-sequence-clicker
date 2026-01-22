// controller/src/store/persistence.ts
// Persistence layer for scenarios and settings

import { homedir } from "os";
import { join } from "path";
import type { Scenario, Point } from "../types";

const CONFIG_DIR = join(homedir(), ".config", "macos-sequencer");
const SCENARIOS_FILE = "scenarios.json";
const SETTINGS_FILE = "settings.json";

export interface Settings {
  lastOverlayPosition?: Point;
  defaultThreshold: number;
  pollIntervalMs: number;
}

export const DEFAULT_SETTINGS: Settings = {
  defaultThreshold: 15,
  pollIntervalMs: 50,
};

/**
 * Ensures the config directory exists
 */
async function ensureConfigDir(): Promise<void> {
  const dir = Bun.file(CONFIG_DIR);
  // Check if directory exists by trying to access it
  try {
    await Bun.spawn(["mkdir", "-p", CONFIG_DIR]).exited;
  } catch {
    // Directory might already exist, that's fine
  }
}

/**
 * Load scenarios from disk
 * Returns empty array if file doesn't exist
 */
export async function loadScenarios(): Promise<Scenario[]> {
  const filePath = join(CONFIG_DIR, SCENARIOS_FILE);
  const file = Bun.file(filePath);

  try {
    if (!(await file.exists())) {
      return [];
    }
    const content = await file.text();
    const scenarios = JSON.parse(content) as Scenario[];
    return scenarios;
  } catch (error) {
    console.error("Failed to load scenarios:", error);
    return [];
  }
}

/**
 * Save scenarios to disk
 * Pretty-prints JSON for readability
 */
export async function saveScenarios(scenarios: Scenario[]): Promise<void> {
  await ensureConfigDir();
  const filePath = join(CONFIG_DIR, SCENARIOS_FILE);
  const content = JSON.stringify(scenarios, null, 2);
  await Bun.write(filePath, content);
}

/**
 * Load settings from disk
 * Returns defaults if file doesn't exist
 */
export async function loadSettings(): Promise<Settings> {
  const filePath = join(CONFIG_DIR, SETTINGS_FILE);
  const file = Bun.file(filePath);

  try {
    if (!(await file.exists())) {
      return { ...DEFAULT_SETTINGS };
    }
    const content = await file.text();
    const settings = JSON.parse(content) as Partial<Settings>;
    // Merge with defaults to ensure all fields exist
    return { ...DEFAULT_SETTINGS, ...settings };
  } catch (error) {
    console.error("Failed to load settings:", error);
    return { ...DEFAULT_SETTINGS };
  }
}

/**
 * Save settings to disk
 * Pretty-prints JSON for readability
 */
export async function saveSettings(settings: Settings): Promise<void> {
  await ensureConfigDir();
  const filePath = join(CONFIG_DIR, SETTINGS_FILE);
  const content = JSON.stringify(settings, null, 2);
  await Bun.write(filePath, content);
}

/**
 * Get the config directory path (for display purposes)
 */
export function getConfigDir(): string {
  return CONFIG_DIR;
}
