// schema/src/types.ts
// Single source of truth for all IPC message types
// Generated to: JSON Schema and Swift Codable types

// ============ PRIMITIVES ============

export interface RGB {
  r: number; // 0-255
  g: number; // 0-255
  b: number; // 0-255
}

export interface Point {
  x: number;
  y: number;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

// ============ ACTIONS ============

export interface ClickAction {
  type: "click";
  position: Point;
  button: "left" | "right";
}

export interface KeypressAction {
  type: "keypress";
  key: string;
  modifiers: ("ctrl" | "alt" | "shift" | "cmd")[];
}

export type Action = ClickAction | KeypressAction;

// ============ TRANSITIONS ============

export interface DelayTransition {
  type: "delay";
  ms: number;
}

export interface PixelStateTransition {
  type: "pixel-state";
  position: Point;
  color: RGB;
  threshold: number; // Euclidean RGB distance (0-441)
}

export interface PixelZoneTransition {
  type: "pixel-zone";
  rect: Rect;
  color: RGB;
  threshold: number;
}

export type Transition =
  | DelayTransition
  | PixelStateTransition
  | PixelZoneTransition;

// ============ SCENARIO ============

export interface ScenarioRef {
  type: "scenario-ref";
  scenarioId: string;
}

export type Step = Action | Transition | ScenarioRef;

export interface Scenario {
  id: string;
  name: string;
  steps: Step[];
  createdAt: number; // Unix timestamp ms
  lastUsedAt: number; // Unix timestamp ms
}

// ============ IPC REQUESTS (Controller -> Swift) ============

export interface CheckPermissionsRequest {
  method: "checkPermissions";
}

export interface ShowRecorderOverlayRequest {
  method: "showRecorderOverlay";
  params: { position?: Point };
}

export interface HideRecorderOverlayRequest {
  method: "hideRecorderOverlay";
}

export interface SetRecorderStateRequest {
  method: "setRecorderState";
  params: {
    state: "idle" | "action" | "transition";
    subState?: "mouse" | "keyboard" | "time" | "pixel";
  };
}

export interface ShowMagnifierRequest {
  method: "showMagnifier";
}

export interface HideMagnifierRequest {
  method: "hideMagnifier";
}

export interface ExecuteClickRequest {
  method: "executeClick";
  params: {
    position: Point;
    button: "left" | "right";
  };
}

export interface ExecuteKeypressRequest {
  method: "executeKeypress";
  params: {
    key: string;
    modifiers: ("ctrl" | "alt" | "shift" | "cmd")[];
  };
}

export interface GetPixelColorRequest {
  method: "getPixelColor";
  params: { position: Point };
}

export interface WaitForPixelStateRequest {
  method: "waitForPixelState";
  params: {
    position: Point;
    color: RGB;
    threshold: number;
    timeoutMs?: number;
  };
}

export interface WaitForPixelZoneRequest {
  method: "waitForPixelZone";
  params: {
    rect: Rect;
    color: RGB;
    threshold: number;
    timeoutMs?: number;
  };
}

// Union of all request bodies
export type IPCRequestBody =
  | CheckPermissionsRequest
  | ShowRecorderOverlayRequest
  | HideRecorderOverlayRequest
  | SetRecorderStateRequest
  | ShowMagnifierRequest
  | HideMagnifierRequest
  | ExecuteClickRequest
  | ExecuteKeypressRequest
  | GetPixelColorRequest
  | WaitForPixelStateRequest
  | WaitForPixelZoneRequest;

// Full request with ID
export type IPCRequest = { id: string } & IPCRequestBody;

// ============ IPC RESPONSES (Swift -> Controller) ============

export interface IPCResponseSuccess<T = unknown> {
  id: string;
  success: true;
  result: T;
}

export interface IPCResponseError {
  id: string;
  success: false;
  error: string;
}

export type IPCResponse<T = unknown> = IPCResponseSuccess<T> | IPCResponseError;

// Specific response result types
export interface PermissionStatus {
  accessibility: boolean;
  screenRecording: boolean;
}

export interface PixelColorResult {
  color: RGB;
}

// ============ IPC EVENTS (Swift -> Controller, unsolicited) ============

export interface OverlayIconClickedEvent {
  event: "overlayIconClicked";
  data: { icon: "action" | "transition" | "mouse" | "keyboard" | "time" };
}

export interface MouseClickedEvent {
  event: "mouseClicked";
  data: { position: Point; button: "left" | "right" };
}

export interface KeyPressedEvent {
  event: "keyPressed";
  data: { key: string; modifiers: ("ctrl" | "alt" | "shift" | "cmd")[] };
}

export interface ZoneSelectedEvent {
  event: "zoneSelected";
  data: { rect: Rect };
}

export interface PixelSelectedEvent {
  event: "pixelSelected";
  data: { position: Point; color: RGB };
}

export interface OverlayMovedEvent {
  event: "overlayMoved";
  data: { position: Point };
}

export interface OverlayClosedEvent {
  event: "overlayClosed";
  data: Record<string, never>;
}

export interface TimeInputCompletedEvent {
  event: "timeInputCompleted";
  data: { ms: number };
}

export type IPCEvent =
  | OverlayIconClickedEvent
  | MouseClickedEvent
  | KeyPressedEvent
  | ZoneSelectedEvent
  | PixelSelectedEvent
  | OverlayMovedEvent
  | OverlayClosedEvent
  | TimeInputCompletedEvent;

// ============ IPC MESSAGE (Union for parsing) ============

export type IPCMessage = IPCRequest | IPCResponse | IPCEvent;
