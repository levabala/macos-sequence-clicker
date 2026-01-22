# Phase 3: Controller IPC Bridge

## Goal
Create Bun controller that spawns Swift helper and communicates via typed IPC.

## Prerequisites
- Phase 2 complete (Swift helper responds to requests)

## Deliverables
- [ ] Controller package initialized with dependencies
- [ ] IPC bridge spawns Swift helper subprocess
- [ ] Request/response round-trip working
- [ ] Event emission from Swift helper received
- [ ] Typed protocol helpers for all IPC methods

---

## Tasks

### 3.1 Initialize Controller Package
```bash
mkdir -p controller/src
cd controller
bun init -y
bun add @opentui/core @opentui/react react nanoid
bun add -d @types/react typescript
```

Create `controller/tsconfig.json`:
```json
{
  "compilerOptions": {
    "lib": ["ESNext", "DOM"],
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "jsxImportSource": "@opentui/react",
    "strict": true,
    "skipLibCheck": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*"]
}
```

### 3.2 Import Schema Types
Create `controller/src/types/index.ts`:
- Re-export all types from schema package
- Add controller-specific types if needed

Option A - npm workspace:
```json
// root package.json
{ "workspaces": ["schema", "controller"] }
```

Option B - direct import:
```typescript
// Copy or reference schema/src/types.ts
export * from '../../../schema/src/types';
```

### 3.3 Implement IPC Bridge
Create `controller/src/ipc/bridge.ts`:
- `SwiftBridge` class extending `EventEmitter`
- `start()`: Spawn Swift helper with `Bun.spawn`
- `readLoop()`: Parse stdout lines, handle responses/events
- `request<T>()`: Send request, return Promise for response
- `stop()`: Kill subprocess, clean up
- Singleton export

Key implementation details:
- Line buffering for JSON messages
- Pending request map with timeout
- Event emission for unsolicited messages

### 3.4 Implement Typed Protocol
Create `controller/src/ipc/protocol.ts`:
- Typed wrapper functions for each IPC method
- `checkPermissions()`: Returns `Promise<PermissionStatus>`
- `showRecorderOverlay()`: Returns `Promise<void>`
- etc.

### 3.5 Create Test Entry Point
Create `controller/src/index.tsx`:
```typescript
import { swiftBridge } from './ipc/bridge';
import { ipc } from './ipc/protocol';

async function main() {
  await swiftBridge.start();
  
  const permissions = await ipc.checkPermissions();
  console.log('Permissions:', permissions);
  
  swiftBridge.stop();
}

main();
```

### 3.6 Test IPC Communication
```bash
cd controller
bun run src/index.tsx
```

Expected: Permissions object logged, clean exit.

---

## Acceptance Criteria
- [ ] Controller starts without errors
- [ ] Swift helper is spawned as subprocess
- [ ] `checkPermissions()` returns typed response
- [ ] Request timeout works (test with unimplemented method)
- [ ] Multiple concurrent requests work correctly
- [ ] Swift helper exits when controller exits
- [ ] Events from Swift are emitted (test with mock)

---

## Files Created
```
controller/
├── package.json
├── tsconfig.json
└── src/
    ├── index.tsx
    ├── types/
    │   └── index.ts
    └── ipc/
        ├── bridge.ts
        └── protocol.ts
```

## Estimated Time: 3-4 hours
