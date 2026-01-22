// controller/src/index.tsx
// Entry point - Terminal UI with Swift helper integration

import { createCliRenderer } from "@opentui/core";
import { createRoot } from "@opentui/react";
import { App } from "./components/App";
import { swiftBridge, ipc } from "./ipc/protocol";
import { scenariosStore } from "./store/scenarios";

async function main() {
  console.log("Starting macOS Smart Sequencer...");

  try {
    // Start the Swift helper
    console.log("Spawning Swift helper...");
    await swiftBridge.start();
    console.log("Swift helper started");

    // Register event listeners for Swift helper (cast to avoid TS2590 union complexity)
    const bridge = swiftBridge as {
      on: (event: string, cb: (data: unknown) => void) => void;
    };
    bridge.on("error", (error: unknown) => {
      console.error("Swift helper error:", error);
    });

    bridge.on("exit", (code: unknown) => {
      console.log("Swift helper exited with code:", code);
      process.exit((code as number | null) ?? 1);
    });

    // Check permissions
    console.log("Checking permissions...");
    const permissions = await ipc.checkPermissions();

    if (!permissions.accessibility) {
      console.error("\nAccessibility permission not granted.");
      console.error("Please enable in: System Settings > Privacy & Security > Accessibility");
      console.error("Add this terminal app to the list.\n");
    }

    if (!permissions.screenRecording) {
      console.error("\nScreen Recording permission not granted.");
      console.error("Please enable in: System Settings > Privacy & Security > Screen Recording");
      console.error("Add this terminal app to the list.\n");
    }

    if (!permissions.accessibility || !permissions.screenRecording) {
      console.error("Some features may not work without required permissions.\n");
      console.log("Press Enter to continue anyway, or Ctrl+C to exit...");
      await new Promise<void>((resolve) => {
        const handler = () => {
          process.stdin.removeListener("data", handler);
          resolve();
        };
        process.stdin.once("data", handler);
      });
    }

    // Load scenarios from disk
    console.log("Loading scenarios...");
    await scenariosStore.load();
    const state = scenariosStore.getState();
    console.log(`Loaded ${state.scenarios.length} scenario(s)`);

    // Clear screen before starting UI
    console.clear();

    // Start the terminal UI
    const renderer = await createCliRenderer({
      // Don't exit on Ctrl+C, let the app handle it
    });

    createRoot(renderer).render(<App />);

    // Keep the process alive
    process.on("SIGINT", () => {
      renderer.destroy();
      swiftBridge.stop();
      process.exit(0);
    });

    process.on("SIGTERM", () => {
      renderer.destroy();
      swiftBridge.stop();
      process.exit(0);
    });
  } catch (error) {
    console.error("Failed to start:", error);
    swiftBridge.stop();
    process.exit(1);
  }
}

main();
