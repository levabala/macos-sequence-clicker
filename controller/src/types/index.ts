// Re-export all types from schema package
// Using direct import since we're in the same monorepo

export type {
  // Primitives
  RGB,
  Point,
  Rect,

  // Actions
  ClickAction,
  KeypressAction,
  Action,

  // Transitions
  DelayTransition,
  PixelStateTransition,
  PixelZoneTransition,
  Transition,

  // Scenario
  ScenarioRef,
  Step,
  Scenario,

  // IPC Requests
  CheckPermissionsRequest,
  ShowRecorderOverlayRequest,
  HideRecorderOverlayRequest,
  SetRecorderStateRequest,
  ShowMagnifierRequest,
  HideMagnifierRequest,
  ExecuteClickRequest,
  ExecuteKeypressRequest,
  GetPixelColorRequest,
  WaitForPixelStateRequest,
  WaitForPixelZoneRequest,
  IPCRequestBody,
  IPCRequest,

  // IPC Responses
  IPCResponseSuccess,
  IPCResponseError,
  IPCResponse,
  PermissionStatus,
  PixelColorResult,

  // IPC Events
  OverlayIconClickedEvent,
  MouseClickedEvent,
  KeyPressedEvent,
  ZoneSelectedEvent,
  PixelSelectedEvent,
  OverlayMovedEvent,
  OverlayClosedEvent,
  TimeInputCompletedEvent,
  IPCEvent,

  // Union
  IPCMessage,
} from "../../../schema/src/types.ts";
