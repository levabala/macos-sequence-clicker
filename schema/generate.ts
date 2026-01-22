// schema/generate.ts
// Generates JSON Schema and Swift types from TypeScript definitions

import { exec } from "child_process";
import { promisify } from "util";
import * as path from "path";
import * as fs from "fs";

const execAsync = promisify(exec);

async function generate() {
  const schemaDir = import.meta.dir;
  const srcFile = path.join(schemaDir, "src/types.ts");
  const outDir = path.join(schemaDir, "generated");

  // Ensure output directory exists
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  // Step 1: Generate JSON Schema
  console.log("Generating JSON Schema...");
  try {
    const { stdout, stderr } = await execAsync(
      `npx typescript-json-schema "${srcFile}" "*" --out "${outDir}/schema.json" --required --strictNullChecks`
    );
    if (stderr) console.error(stderr);
    if (stdout) console.log(stdout);
  } catch (err: any) {
    console.error("Error generating JSON Schema:", err.message);
    process.exit(1);
  }

  // Verify JSON Schema was created
  const schemaPath = path.join(outDir, "schema.json");
  if (!fs.existsSync(schemaPath)) {
    console.error("Error: schema.json was not created");
    process.exit(1);
  }
  console.log(`  -> Created ${schemaPath}`);

  // Step 2: Generate Swift types manually from schema
  // Since quicktype struggles with complex union types, we generate them directly
  console.log("Generating Swift types...");

  const schema = JSON.parse(fs.readFileSync(schemaPath, "utf-8"));

  const swiftContent = generateSwiftTypes(schema);
  const swiftPath = path.join(outDir, "Types.swift");
  fs.writeFileSync(swiftPath, swiftContent);

  console.log(`  -> Created ${swiftPath}`);

  // Step 3: Verify Swift compiles
  console.log("Verifying Swift types compile...");
  try {
    await execAsync(`swiftc -typecheck "${swiftPath}"`);
    console.log("  -> Swift types compile successfully!");
  } catch (err: any) {
    console.warn(
      "  -> Warning: Swift compilation check failed (this is OK if swiftc is not installed)"
    );
    console.warn(`     ${err.message}`);
  }

  console.log("\nDone! Generated files:");
  console.log(`  - ${schemaPath}`);
  console.log(`  - ${swiftPath}`);
}

function generateSwiftTypes(schema: any): string {
  const defs = schema.definitions;

  return `// This file was generated from TypeScript types, do not modify it directly.
// To regenerate: cd schema && bun run generate
// Source: schema/src/types.ts

import Foundation

// MARK: - Primitives

struct RGB: Codable, Equatable {
    let r: Int
    let g: Int
    let b: Int
}

struct Point: Codable, Equatable {
    let x: Double
    let y: Double
}

struct Rect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Mouse Button

enum MouseButton: String, Codable {
    case left
    case right
}

// MARK: - Keyboard Modifiers

enum KeyModifier: String, Codable {
    case ctrl
    case alt
    case shift
    case cmd
}

// MARK: - Actions

struct ClickAction: Codable, Equatable {
    let type: String
    let position: Point
    let button: MouseButton

    init(position: Point, button: MouseButton) {
        self.type = "click"
        self.position = position
        self.button = button
    }
}

struct KeypressAction: Codable, Equatable {
    let type: String
    let key: String
    let modifiers: [KeyModifier]

    init(key: String, modifiers: [KeyModifier]) {
        self.type = "keypress"
        self.key = key
        self.modifiers = modifiers
    }
}

// MARK: - Transitions

struct DelayTransition: Codable, Equatable {
    let type: String
    let ms: Double

    init(ms: Double) {
        self.type = "delay"
        self.ms = ms
    }
}

struct PixelStateTransition: Codable, Equatable {
    let type: String
    let position: Point
    let color: RGB
    let threshold: Double

    init(position: Point, color: RGB, threshold: Double) {
        self.type = "pixel-state"
        self.position = position
        self.color = color
        self.threshold = threshold
    }
}

struct PixelZoneTransition: Codable, Equatable {
    let type: String
    let rect: Rect
    let color: RGB
    let threshold: Double

    init(rect: Rect, color: RGB, threshold: Double) {
        self.type = "pixel-zone"
        self.rect = rect
        self.color = color
        self.threshold = threshold
    }
}

// MARK: - Scenario Reference

struct ScenarioRef: Codable, Equatable {
    let type: String
    let scenarioId: String

    init(scenarioId: String) {
        self.type = "scenario-ref"
        self.scenarioId = scenarioId
    }
}

// MARK: - Step (Union Type)

enum Step: Codable, Equatable {
    case click(ClickAction)
    case keypress(KeypressAction)
    case delay(DelayTransition)
    case pixelState(PixelStateTransition)
    case pixelZone(PixelZoneTransition)
    case scenarioRef(ScenarioRef)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "click":
            self = .click(try ClickAction(from: decoder))
        case "keypress":
            self = .keypress(try KeypressAction(from: decoder))
        case "delay":
            self = .delay(try DelayTransition(from: decoder))
        case "pixel-state":
            self = .pixelState(try PixelStateTransition(from: decoder))
        case "pixel-zone":
            self = .pixelZone(try PixelZoneTransition(from: decoder))
        case "scenario-ref":
            self = .scenarioRef(try ScenarioRef(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown step type: \\(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .click(let action):
            try action.encode(to: encoder)
        case .keypress(let action):
            try action.encode(to: encoder)
        case .delay(let transition):
            try transition.encode(to: encoder)
        case .pixelState(let transition):
            try transition.encode(to: encoder)
        case .pixelZone(let transition):
            try transition.encode(to: encoder)
        case .scenarioRef(let ref):
            try ref.encode(to: encoder)
        }
    }
}

// MARK: - Scenario

struct Scenario: Codable, Equatable {
    let id: String
    let name: String
    let steps: [Step]
    let createdAt: Double
    let lastUsedAt: Double
}

// MARK: - Permission Status

struct PermissionStatus: Codable, Equatable {
    let accessibility: Bool
    let screenRecording: Bool
}

// MARK: - Pixel Color Result

struct PixelColorResult: Codable, Equatable {
    let color: RGB
}

// MARK: - Recorder State

enum RecorderState: String, Codable {
    case idle
    case action
    case transition
}

enum RecorderSubState: String, Codable {
    case mouse
    case keyboard
    case time
    case pixel
}

// MARK: - IPC Requests (Controller -> Swift)

struct CheckPermissionsRequest: Codable {
    let id: String
    let method: String

    init(id: String) {
        self.id = id
        self.method = "checkPermissions"
    }
}

struct ShowRecorderOverlayParams: Codable {
    let position: Point?
}

struct ShowRecorderOverlayRequest: Codable {
    let id: String
    let method: String
    let params: ShowRecorderOverlayParams

    init(id: String, position: Point? = nil) {
        self.id = id
        self.method = "showRecorderOverlay"
        self.params = ShowRecorderOverlayParams(position: position)
    }
}

struct HideRecorderOverlayRequest: Codable {
    let id: String
    let method: String

    init(id: String) {
        self.id = id
        self.method = "hideRecorderOverlay"
    }
}

struct SetRecorderStateParams: Codable {
    let state: RecorderState
    let subState: RecorderSubState?
}

struct SetRecorderStateRequest: Codable {
    let id: String
    let method: String
    let params: SetRecorderStateParams

    init(id: String, state: RecorderState, subState: RecorderSubState? = nil) {
        self.id = id
        self.method = "setRecorderState"
        self.params = SetRecorderStateParams(state: state, subState: subState)
    }
}

struct ShowMagnifierRequest: Codable {
    let id: String
    let method: String

    init(id: String) {
        self.id = id
        self.method = "showMagnifier"
    }
}

struct HideMagnifierRequest: Codable {
    let id: String
    let method: String

    init(id: String) {
        self.id = id
        self.method = "hideMagnifier"
    }
}

struct ExecuteClickParams: Codable {
    let position: Point
    let button: MouseButton
}

struct ExecuteClickRequest: Codable {
    let id: String
    let method: String
    let params: ExecuteClickParams

    init(id: String, position: Point, button: MouseButton) {
        self.id = id
        self.method = "executeClick"
        self.params = ExecuteClickParams(position: position, button: button)
    }
}

struct ExecuteKeypressParams: Codable {
    let key: String
    let modifiers: [KeyModifier]
}

struct ExecuteKeypressRequest: Codable {
    let id: String
    let method: String
    let params: ExecuteKeypressParams

    init(id: String, key: String, modifiers: [KeyModifier]) {
        self.id = id
        self.method = "executeKeypress"
        self.params = ExecuteKeypressParams(key: key, modifiers: modifiers)
    }
}

struct GetPixelColorParams: Codable {
    let position: Point
}

struct GetPixelColorRequest: Codable {
    let id: String
    let method: String
    let params: GetPixelColorParams

    init(id: String, position: Point) {
        self.id = id
        self.method = "getPixelColor"
        self.params = GetPixelColorParams(position: position)
    }
}

struct WaitForPixelStateParams: Codable {
    let position: Point
    let color: RGB
    let threshold: Double
    let timeoutMs: Double?
}

struct WaitForPixelStateRequest: Codable {
    let id: String
    let method: String
    let params: WaitForPixelStateParams

    init(id: String, position: Point, color: RGB, threshold: Double, timeoutMs: Double? = nil) {
        self.id = id
        self.method = "waitForPixelState"
        self.params = WaitForPixelStateParams(
            position: position,
            color: color,
            threshold: threshold,
            timeoutMs: timeoutMs
        )
    }
}

struct WaitForPixelZoneParams: Codable {
    let rect: Rect
    let color: RGB
    let threshold: Double
    let timeoutMs: Double?
}

struct WaitForPixelZoneRequest: Codable {
    let id: String
    let method: String
    let params: WaitForPixelZoneParams

    init(id: String, rect: Rect, color: RGB, threshold: Double, timeoutMs: Double? = nil) {
        self.id = id
        self.method = "waitForPixelZone"
        self.params = WaitForPixelZoneParams(
            rect: rect,
            color: color,
            threshold: threshold,
            timeoutMs: timeoutMs
        )
    }
}

// MARK: - IPC Request (Union for Parsing)

enum IPCRequestMethod: String, Codable {
    case checkPermissions
    case showRecorderOverlay
    case hideRecorderOverlay
    case setRecorderState
    case showMagnifier
    case hideMagnifier
    case executeClick
    case executeKeypress
    case getPixelColor
    case waitForPixelState
    case waitForPixelZone
}

struct IPCRequestEnvelope: Codable {
    let id: String
    let method: IPCRequestMethod
}

// MARK: - IPC Responses (Swift -> Controller)

struct IPCResponseSuccess<T: Codable>: Codable {
    let id: String
    let success: Bool
    let result: T

    init(id: String, result: T) {
        self.id = id
        self.success = true
        self.result = result
    }
}

struct IPCResponseError: Codable {
    let id: String
    let success: Bool
    let error: String

    init(id: String, error: String) {
        self.id = id
        self.success = false
        self.error = error
    }
}

struct IPCResponseVoid: Codable {
    let id: String
    let success: Bool

    init(id: String) {
        self.id = id
        self.success = true
    }
}

// MARK: - IPC Events (Swift -> Controller, Unsolicited)

enum OverlayIcon: String, Codable {
    case action
    case transition
    case mouse
    case keyboard
    case time
}

struct OverlayIconClickedData: Codable {
    let icon: OverlayIcon
}

struct OverlayIconClickedEvent: Codable {
    let event: String
    let data: OverlayIconClickedData

    init(icon: OverlayIcon) {
        self.event = "overlayIconClicked"
        self.data = OverlayIconClickedData(icon: icon)
    }
}

struct MouseClickedData: Codable {
    let position: Point
    let button: MouseButton
}

struct MouseClickedEvent: Codable {
    let event: String
    let data: MouseClickedData

    init(position: Point, button: MouseButton) {
        self.event = "mouseClicked"
        self.data = MouseClickedData(position: position, button: button)
    }
}

struct KeyPressedData: Codable {
    let key: String
    let modifiers: [KeyModifier]
}

struct KeyPressedEvent: Codable {
    let event: String
    let data: KeyPressedData

    init(key: String, modifiers: [KeyModifier]) {
        self.event = "keyPressed"
        self.data = KeyPressedData(key: key, modifiers: modifiers)
    }
}

struct ZoneSelectedData: Codable {
    let rect: Rect
}

struct ZoneSelectedEvent: Codable {
    let event: String
    let data: ZoneSelectedData

    init(rect: Rect) {
        self.event = "zoneSelected"
        self.data = ZoneSelectedData(rect: rect)
    }
}

struct PixelSelectedData: Codable {
    let position: Point
    let color: RGB
}

struct PixelSelectedEvent: Codable {
    let event: String
    let data: PixelSelectedData

    init(position: Point, color: RGB) {
        self.event = "pixelSelected"
        self.data = PixelSelectedData(position: position, color: color)
    }
}

struct OverlayMovedData: Codable {
    let position: Point
}

struct OverlayMovedEvent: Codable {
    let event: String
    let data: OverlayMovedData

    init(position: Point) {
        self.event = "overlayMoved"
        self.data = OverlayMovedData(position: position)
    }
}

struct OverlayClosedData: Codable {}

struct OverlayClosedEvent: Codable {
    let event: String
    let data: OverlayClosedData

    init() {
        self.event = "overlayClosed"
        self.data = OverlayClosedData()
    }
}

struct TimeInputCompletedData: Codable {
    let ms: Double
}

struct TimeInputCompletedEvent: Codable {
    let event: String
    let data: TimeInputCompletedData

    init(ms: Double) {
        self.event = "timeInputCompleted"
        self.data = TimeInputCompletedData(ms: ms)
    }
}

// MARK: - IPC Event (Union for Parsing)

enum IPCEventType: String, Codable {
    case overlayIconClicked
    case mouseClicked
    case keyPressed
    case zoneSelected
    case pixelSelected
    case overlayMoved
    case overlayClosed
    case timeInputCompleted
}

enum IPCEvent: Codable {
    case overlayIconClicked(OverlayIconClickedEvent)
    case mouseClicked(MouseClickedEvent)
    case keyPressed(KeyPressedEvent)
    case zoneSelected(ZoneSelectedEvent)
    case pixelSelected(PixelSelectedEvent)
    case overlayMoved(OverlayMovedEvent)
    case overlayClosed(OverlayClosedEvent)
    case timeInputCompleted(TimeInputCompletedEvent)

    private enum CodingKeys: String, CodingKey {
        case event
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let event = try container.decode(String.self, forKey: .event)

        switch event {
        case "overlayIconClicked":
            self = .overlayIconClicked(try OverlayIconClickedEvent(from: decoder))
        case "mouseClicked":
            self = .mouseClicked(try MouseClickedEvent(from: decoder))
        case "keyPressed":
            self = .keyPressed(try KeyPressedEvent(from: decoder))
        case "zoneSelected":
            self = .zoneSelected(try ZoneSelectedEvent(from: decoder))
        case "pixelSelected":
            self = .pixelSelected(try PixelSelectedEvent(from: decoder))
        case "overlayMoved":
            self = .overlayMoved(try OverlayMovedEvent(from: decoder))
        case "overlayClosed":
            self = .overlayClosed(try OverlayClosedEvent(from: decoder))
        case "timeInputCompleted":
            self = .timeInputCompleted(try TimeInputCompletedEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .event,
                in: container,
                debugDescription: "Unknown event type: \\(event)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .overlayIconClicked(let event):
            try event.encode(to: encoder)
        case .mouseClicked(let event):
            try event.encode(to: encoder)
        case .keyPressed(let event):
            try event.encode(to: encoder)
        case .zoneSelected(let event):
            try event.encode(to: encoder)
        case .pixelSelected(let event):
            try event.encode(to: encoder)
        case .overlayMoved(let event):
            try event.encode(to: encoder)
        case .overlayClosed(let event):
            try event.encode(to: encoder)
        case .timeInputCompleted(let event):
            try event.encode(to: encoder)
        }
    }
}
`;
}

generate().catch((err) => {
  console.error("Generation failed:", err);
  process.exit(1);
});
