// controller/src/test-stores.ts
// Test harness for store operations

import {
  scenariosStore,
  historyStore,
  recorderStore,
  settingsStore,
  getConfigDir,
} from "./store";

async function testPersistence() {
  console.log("\n=== Testing Persistence ===");
  console.log("Config directory:", getConfigDir());

  // Load scenarios
  await scenariosStore.load();
  console.log("Loaded scenarios:", scenariosStore.getState().scenarios.length);

  // Load settings
  await settingsStore.load();
  console.log("Loaded settings:", settingsStore.getState());
}

async function testScenariosCRUD() {
  console.log("\n=== Testing Scenarios CRUD ===");

  // Create scenario
  const scenario = scenariosStore.createScenario("Test Scenario");
  console.log("Created scenario:", scenario.id, scenario.name);

  // Verify selection
  console.log("Selected scenario:", scenariosStore.getSelectedScenario()?.name);

  // Update name
  scenariosStore.updateScenarioName(scenario.id, "Updated Scenario");
  console.log("After rename:", scenariosStore.getSelectedScenario()?.name);

  // Add steps
  scenariosStore.addStep(scenario.id, { type: "delay", ms: 1000 });
  console.log("Added delay step, steps count:", scenariosStore.getSelectedScenario()?.steps.length);

  scenariosStore.addStep(scenario.id, {
    type: "click",
    position: { x: 100, y: 200 },
    button: "left",
  });
  console.log("Added click step, steps count:", scenariosStore.getSelectedScenario()?.steps.length);

  scenariosStore.addStep(
    scenario.id,
    { type: "keypress", key: "a", modifiers: ["cmd"] },
    0 // Insert after first step
  );
  console.log("Added keypress after index 0:");
  console.log("  Steps:", scenariosStore.getSelectedScenario()?.steps.map((s) => s.type));

  // Swap steps
  scenariosStore.swapSteps(scenario.id, 0, 2);
  console.log("After swapping 0 and 2:");
  console.log("  Steps:", scenariosStore.getSelectedScenario()?.steps.map((s) => s.type));

  return scenario;
}

async function testHistoryUndo(scenario: { id: string }) {
  console.log("\n=== Testing History/Undo ===");

  const stepsBefore = scenariosStore.getSelectedScenario()?.steps.length ?? 0;
  console.log("Steps before delete:", stepsBefore);
  console.log("Steps:", scenariosStore.getSelectedScenario()?.steps.map((s) => s.type));

  // Delete step using history store (this adds to undo)
  historyStore.deleteStep(scenario.id, 1);
  console.log("After deleting index 1:");
  console.log("  Steps count:", scenariosStore.getSelectedScenario()?.steps.length);
  console.log("  Steps:", scenariosStore.getSelectedScenario()?.steps.map((s) => s.type));
  console.log("  Can undo:", historyStore.canUndo());
  console.log("  Undo description:", historyStore.getUndoDescription());

  // Undo
  const undoResult = historyStore.undo();
  console.log("Undo result:", undoResult);
  console.log("After undo:");
  console.log("  Steps count:", scenariosStore.getSelectedScenario()?.steps.length);
  console.log("  Steps:", scenariosStore.getSelectedScenario()?.steps.map((s) => s.type));
  console.log("  Can undo:", historyStore.canUndo());
}

async function testRecorderStateMachine() {
  console.log("\n=== Testing Recorder State Machine ===");

  console.log("Initial state:", recorderStore.getState());

  // Start recording
  recorderStore.startRecording("test-scenario-id", null);
  console.log("After startRecording:", recorderStore.getState());
  console.log("  isRecording:", recorderStore.isRecording());

  // Stop recording
  recorderStore.stopRecording();
  console.log("After stopRecording:", recorderStore.getState());

  // Start naming
  recorderStore.startNaming("test-scenario-id");
  console.log("After startNaming:", recorderStore.getState());
  console.log("  isNaming:", recorderStore.isNaming());

  // Type a name
  recorderStore.appendToName("M");
  recorderStore.appendToName("y");
  recorderStore.appendToName(" ");
  recorderStore.appendToName("S");
  recorderStore.appendToName("c");
  recorderStore.appendToName("e");
  recorderStore.appendToName("n");
  recorderStore.appendToName("a");
  recorderStore.appendToName("r");
  recorderStore.appendToName("i");
  recorderStore.appendToName("o");
  console.log("After typing:", recorderStore.getState());

  // Backspace
  recorderStore.backspaceName();
  recorderStore.backspaceName();
  console.log("After backspace x2:", recorderStore.getState());

  // Finish naming
  const finalName = recorderStore.finishNaming();
  console.log("Final name:", finalName);
  console.log("After finishNaming:", recorderStore.getState());
}

async function testSettingsStore() {
  console.log("\n=== Testing Settings Store ===");

  console.log("Current settings:", settingsStore.getState());

  // Update single setting
  settingsStore.set("defaultThreshold", 20);
  console.log("After setting threshold to 20:", settingsStore.getState());

  // Update multiple settings
  settingsStore.update({
    pollIntervalMs: 100,
    lastOverlayPosition: { x: 500, y: 300 },
  });
  console.log("After update:", settingsStore.getState());

  // Test convenience methods
  console.log("Last overlay position:", settingsStore.getLastOverlayPosition());

  // Reset
  settingsStore.reset();
  console.log("After reset:", settingsStore.getState());
}

async function testSubscriptions() {
  console.log("\n=== Testing Subscriptions ===");

  let callCount = 0;
  const unsubscribe = scenariosStore.subscribe(() => {
    callCount++;
    console.log(`Subscription callback #${callCount}`);
  });

  // Trigger some changes
  scenariosStore.selectStep(0);
  scenariosStore.selectStep(1);
  scenariosStore.selectStep(null);

  console.log("Total callback invocations:", callCount);

  // Unsubscribe
  unsubscribe();
  scenariosStore.selectStep(0);
  console.log("After unsubscribe, callback count:", callCount);
}

async function cleanup() {
  console.log("\n=== Cleanup ===");

  // Delete test scenarios
  const scenarios = scenariosStore.getState().scenarios;
  for (const s of scenarios) {
    if (s.name.includes("Test") || s.name.includes("Updated")) {
      scenariosStore.deleteScenario(s.id);
      console.log("Deleted:", s.name);
    }
  }

  // Clear history
  historyStore.clear();
  console.log("History cleared");

  // Save final state
  await scenariosStore.save();
  console.log("Final save complete");
}

async function main() {
  console.log("========================================");
  console.log("       Store Tests");
  console.log("========================================");

  try {
    await testPersistence();
    const scenario = await testScenariosCRUD();
    await testHistoryUndo(scenario);
    await testRecorderStateMachine();
    await testSettingsStore();
    await testSubscriptions();
    await cleanup();

    console.log("\n========================================");
    console.log("       All Tests Passed!");
    console.log("========================================\n");
  } catch (error) {
    console.error("\n========================================");
    console.error("       Test Failed!");
    console.error("========================================");
    console.error(error);
    process.exit(1);
  }
}

main();
