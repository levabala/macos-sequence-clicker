// Typed protocol wrappers for IPC methods

import { swiftBridge } from "./bridge.ts";
import type {
  PermissionStatus,
  PixelColorResult,
  Point,
  Rect,
  RGB,
} from "../types/index.ts";

/**
 * IPC Protocol - Typed wrappers for all Swift helper methods
 */
export const ipc = {
  /**
   * Check macOS permissions (Accessibility and Screen Recording)
   */
  async checkPermissions(): Promise<PermissionStatus> {
    return swiftBridge.request<PermissionStatus>({
      method: "checkPermissions",
    });
  },

  /**
   * Show the recorder overlay window
   * @param position Optional position to place the overlay
   */
  async showRecorderOverlay(position?: Point): Promise<void> {
    await swiftBridge.request<void>({
      method: "showRecorderOverlay",
      params: { position },
    });
  },

  /**
   * Hide the recorder overlay window
   */
  async hideRecorderOverlay(): Promise<void> {
    await swiftBridge.request<void>({
      method: "hideRecorderOverlay",
    });
  },

  /**
   * Set the recorder state (affects UI display)
   * @param state Main state: idle, action, or transition
   * @param subState Sub-state within action/transition
   */
  async setRecorderState(
    state: "idle" | "action" | "transition",
    subState?: "mouse" | "keyboard" | "time" | "pixel"
  ): Promise<void> {
    await swiftBridge.request<void>({
      method: "setRecorderState",
      params: { state, subState },
    });
  },

  /**
   * Show the magnifier for pixel selection
   */
  async showMagnifier(): Promise<void> {
    await swiftBridge.request<void>({
      method: "showMagnifier",
    });
  },

  /**
   * Hide the magnifier
   */
  async hideMagnifier(): Promise<void> {
    await swiftBridge.request<void>({
      method: "hideMagnifier",
    });
  },

  /**
   * Execute a mouse click
   * @param position Screen coordinates to click
   * @param button Left or right mouse button
   */
  async executeClick(
    position: Point,
    button: "left" | "right" = "left"
  ): Promise<void> {
    await swiftBridge.request<void>({
      method: "executeClick",
      params: { position, button },
    });
  },

  /**
   * Execute a keypress
   * @param key The key to press
   * @param modifiers Array of modifier keys
   */
  async executeKeypress(
    key: string,
    modifiers: ("ctrl" | "alt" | "shift" | "cmd")[] = []
  ): Promise<void> {
    await swiftBridge.request<void>({
      method: "executeKeypress",
      params: { key, modifiers },
    });
  },

  /**
   * Get the color of a pixel at a specific position
   * @param position Screen coordinates
   */
  async getPixelColor(position: Point): Promise<PixelColorResult> {
    return swiftBridge.request<PixelColorResult>({
      method: "getPixelColor",
      params: { position },
    });
  },

  /**
   * Wait until a pixel matches a specific color
   * @param position Screen coordinates
   * @param color Target color to match
   * @param threshold Euclidean RGB distance threshold (0-441)
   * @param timeoutMs Optional timeout in milliseconds
   * @returns Whether the condition was matched (false if timed out)
   */
  async waitForPixelState(
    position: Point,
    color: RGB,
    threshold: number,
    timeoutMs?: number
  ): Promise<boolean> {
    const result = await swiftBridge.request<{ matched: boolean }>(
      {
        method: "waitForPixelState",
        params: { position, color, threshold, timeoutMs },
      },
      timeoutMs ? timeoutMs + 5000 : undefined // Add buffer to IPC timeout
    );
    return result.matched;
  },

  /**
   * Wait until any pixel in a zone matches a specific color
   * @param rect Rectangle defining the zone
   * @param color Target color to match
   * @param threshold Euclidean RGB distance threshold (0-441)
   * @param timeoutMs Optional timeout in milliseconds
   * @returns Whether the condition was matched (false if timed out)
   */
  async waitForPixelZone(
    rect: Rect,
    color: RGB,
    threshold: number,
    timeoutMs?: number
  ): Promise<boolean> {
    const result = await swiftBridge.request<{ matched: boolean }>(
      {
        method: "waitForPixelZone",
        params: { rect, color, threshold, timeoutMs },
      },
      timeoutMs ? timeoutMs + 5000 : undefined // Add buffer to IPC timeout
    );
    return result.matched;
  },
};

// Re-export bridge for direct access if needed
export { swiftBridge } from "./bridge.ts";
