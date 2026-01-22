# Part 2: Schema & Type Definitions

## Overview

All IPC message types are defined in TypeScript as the **single source of truth**. A codegen pipeline generates:
1. JSON Schema (for validation)
2. Swift Codable structs (for type-safe parsing)

## Codegen Pipeline

```
┌─────────────────┐     typescript-json-schema     ┌─────────────────┐
│  schema/src/    │ ─────────────────────────────▶ │  schema.json    │
│  types.ts       │                                │                 │
└─────────────────┘                                └────────┬────────┘
                                                           │
                                                   quicktype
                                                           │
                                                           ▼
                                                   ┌─────────────────┐
                                                   │  Types.swift    │
                                                   │  (Codable)      │
                                                   └─────────────────┘
```

## Schema Package Structure

```
schema/
├── src/
│   └── types.ts           # TypeScript type definitions
├── generated/
│   ├── schema.json        # JSON Schema output
│   └── Types.swift        # Swift Codable output
├── package.json
├── tsconfig.json
└── generate.ts            # Build script
```

## Type Definitions

### Core Types

```typescript
// schema/src/types.ts

// ============ PRIMITIVES ============

export interface RGB {
  r: number;  // 0-255
  g: number;  // 0-255
  b: number;  // 0-255
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
```

### Actions

```typescript
// ============ ACTIONS ============

export interface ClickAction {
  type: 'click';
  position: Point;
  button: 'left' | 'right';
}

export interface KeypressAction {
  type: 'keypress';
  key: string;
  modifiers: ('ctrl' | 'alt' | 'shift' | 'cmd')[];
}

export type Action = ClickAction | KeypressAction;
```

### Transitions

```typescript
// ============ TRANSITIONS ============

export interface DelayTransition {
  type: 'delay';
  ms: number;
}

export interface PixelStateTransition {
  type: 'pixel-state';
  position: Point;
  color: RGB;
  threshold: number;  // Euclidean RGB distance (0-441)
}

export interface PixelZoneTransition {
  type: 'pixel-zone';
  rect: Rect;
  color: RGB;
  threshold: number;
}

export type Transition = DelayTransition | PixelStateTransition | PixelZoneTransition;
```

### Scenario

```typescript
// ============ SCENARIO ============

export interface ScenarioRef {
  type: 'scenario-ref';
  scenarioId: string;
}

export type Step = Action | Transition | ScenarioRef;

export interface Scenario {
  id: string;
  name: string;
  steps: Step[];
  createdAt: number;   // Unix timestamp ms
  lastUsedAt: number;  // Unix timestamp ms
}
```

### IPC Requests (Controller → Swift)

```typescript
// ============ IPC REQUESTS ============

export interface CheckPermissionsRequest {
  method: 'checkPermissions';
}

export interface ShowRecorderOverlayRequest {
  method: 'showRecorderOverlay';
  params: { position?: Point };
}

export interface HideRecorderOverlayRequest {
  method: 'hideRecorderOverlay';
}

export interface SetRecorderStateRequest {
  method: 'setRecorderState';
  params: {
    state: 'idle' | 'action' | 'transition';
    subState?: 'mouse' | 'keyboard' | 'time' | 'pixel';
  };
}

export interface ShowMagnifierRequest {
  method: 'showMagnifier';
}

export interface HideMagnifierRequest {
  method: 'hideMagnifier';
}

export interface ExecuteClickRequest {
  method: 'executeClick';
  params: {
    position: Point;
    button: 'left' | 'right';
  };
}

export interface ExecuteKeypressRequest {
  method: 'executeKeypress';
  params: {
    key: string;
    modifiers: ('ctrl' | 'alt' | 'shift' | 'cmd')[];
  };
}

export interface GetPixelColorRequest {
  method: 'getPixelColor';
  params: { position: Point };
}

export interface WaitForPixelStateRequest {
  method: 'waitForPixelState';
  params: {
    position: Point;
    color: RGB;
    threshold: number;
    timeoutMs?: number;
  };
}

export interface WaitForPixelZoneRequest {
  method: 'waitForPixelZone';
  params: {
    rect: Rect;
    color: RGB;
    threshold: number;
    timeoutMs?: number;
  };
}

// Union of all requests with ID
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

export type IPCRequest = { id: string } & IPCRequestBody;
```

### IPC Responses (Swift → Controller)

```typescript
// ============ IPC RESPONSES ============

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
```

### IPC Events (Swift → Controller, unsolicited)

```typescript
// ============ IPC EVENTS ============

export interface OverlayIconClickedEvent {
  event: 'overlayIconClicked';
  data: { icon: 'action' | 'transition' | 'mouse' | 'keyboard' | 'time' };
}

export interface MouseClickedEvent {
  event: 'mouseClicked';
  data: { position: Point; button: 'left' | 'right' };
}

export interface KeyPressedEvent {
  event: 'keyPressed';
  data: { key: string; modifiers: ('ctrl' | 'alt' | 'shift' | 'cmd')[] };
}

export interface ZoneSelectedEvent {
  event: 'zoneSelected';
  data: { rect: Rect };
}

export interface PixelSelectedEvent {
  event: 'pixelSelected';
  data: { position: Point; color: RGB };
}

export interface OverlayMovedEvent {
  event: 'overlayMoved';
  data: { position: Point };
}

export interface OverlayClosedEvent {
  event: 'overlayClosed';
  data: {};
}

export interface TimeInputCompletedEvent {
  event: 'timeInputCompleted';
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
```

## Codegen Script

```typescript
// schema/generate.ts
import { exec } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';

const execAsync = promisify(exec);

async function generate() {
  const schemaDir = __dirname;
  const srcFile = path.join(schemaDir, 'src/types.ts');
  const outDir = path.join(schemaDir, 'generated');
  
  // Step 1: Generate JSON Schema
  console.log('Generating JSON Schema...');
  await execAsync(
    `npx typescript-json-schema ${srcFile} "*" --out ${outDir}/schema.json --required --strictNullChecks`
  );
  
  // Step 2: Generate Swift from JSON Schema
  console.log('Generating Swift types...');
  await execAsync(
    `npx quicktype --src ${outDir}/schema.json --src-lang schema --out ${outDir}/Types.swift --lang swift --struct-or-class struct`
  );
  
  console.log('Done!');
}

generate().catch(console.error);
```

## Package Configuration

```json
// schema/package.json
{
  "name": "@sequencer/schema",
  "version": "1.0.0",
  "scripts": {
    "generate": "bun run generate.ts",
    "watch": "bun run generate.ts --watch"
  },
  "devDependencies": {
    "typescript-json-schema": "^0.62.0",
    "quicktype": "^23.0.0",
    "typescript": "^5.3.0"
  }
}
```

```json
// schema/tsconfig.json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "declaration": true,
    "outDir": "./dist"
  },
  "include": ["src/**/*"]
}
```

## Generated Swift Example

The generated `Types.swift` will look approximately like:

```swift
// Generated by quicktype - DO NOT EDIT

import Foundation

// MARK: - Core Types

struct RGB: Codable {
    let r: Int
    let g: Int
    let b: Int
}

struct Point: Codable {
    let x: Double
    let y: Double
}

struct Rect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Actions

enum Action: Codable {
    case click(ClickAction)
    case keypress(KeypressAction)
    
    // Custom encoding/decoding for tagged union
}

struct ClickAction: Codable {
    let type: String  // "click"
    let position: Point
    let button: String  // "left" | "right"
}

// ... etc
```

## Usage

### In Controller (TypeScript)

```typescript
import type { 
  IPCRequest, 
  IPCResponse, 
  IPCEvent,
  Scenario,
  Step 
} from '@sequencer/schema';

// Types are used directly
const request: IPCRequest = {
  id: 'req-1',
  method: 'executeClick',
  params: { position: { x: 100, y: 200 }, button: 'left' }
};
```

### In Swift Helper

```swift
import Foundation

// Parse incoming request
let decoder = JSONDecoder()
let request = try decoder.decode(IPCRequest.self, from: jsonData)

switch request.method {
case "executeClick":
    let params = request.params as! ExecuteClickParams
    MouseController.click(at: params.position, button: params.button)
    // ...
}
```

## Validation

Both sides validate messages:

- **Controller**: TypeScript compiler + optional runtime Zod validation
- **Swift**: Codable decoding fails on invalid JSON structure

## Adding New Message Types

1. Add type definition to `schema/src/types.ts`
2. Run `bun run generate` in schema directory
3. Copy/symlink `Types.swift` to Swift helper
4. Implement handler in both controller and Swift helper
