# Phase 1: Schema & Types

## Goal
Define all shared types in TypeScript and set up codegen pipeline to generate Swift Codable types.

## Prerequisites
- None (this is the first phase)

## Deliverables
- [ ] `schema/` package with TypeScript type definitions
- [ ] Working codegen: TS → JSON Schema → Swift
- [ ] Generated `Types.swift` ready for Swift helper

---

## Tasks

### 1.1 Initialize Schema Package
```bash
mkdir -p schema/src schema/generated
cd schema
bun init -y
```

Create `schema/package.json`:
```json
{
  "name": "@sequencer/schema",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "generate": "bun run generate.ts"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "typescript-json-schema": "^0.62.0"
  }
}
```

Create `schema/tsconfig.json`:
```json
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

### 1.2 Define Core Types
Create `schema/src/types.ts` with:
- Primitives: `RGB`, `Point`, `Rect`
- Actions: `ClickAction`, `KeypressAction`
- Transitions: `DelayTransition`, `PixelStateTransition`, `PixelZoneTransition`
- Scenario: `Step`, `Scenario`, `ScenarioRef`
- IPC Requests: All `*Request` types
- IPC Responses: `IPCResponse`, result types
- IPC Events: All `*Event` types

### 1.3 Create Codegen Script
Create `schema/generate.ts`:
1. Use `typescript-json-schema` to generate JSON Schema
2. Use `quicktype` CLI to generate Swift from JSON Schema
3. Output to `schema/generated/`

### 1.4 Run Codegen & Verify
```bash
cd schema
bun install
bun run generate
```

Verify:
- `schema/generated/schema.json` exists and is valid
- `schema/generated/Types.swift` exists and compiles

---

## Acceptance Criteria
- [ ] `bun run generate` completes without errors
- [ ] JSON Schema contains all type definitions
- [ ] Swift types compile (test with `swiftc -typecheck Types.swift`)
- [ ] Types match between TS and Swift (manual review)

---

## Files Created
```
schema/
├── package.json
├── tsconfig.json
├── generate.ts
├── src/
│   └── types.ts
└── generated/
    ├── schema.json
    └── Types.swift
```

## Estimated Time: 2-3 hours
