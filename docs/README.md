# Documentation

## Architecture Documentation

Detailed technical documentation for each component:

| Document | Description |
|----------|-------------|
| [Part 1: Overview](PART_01_OVERVIEW.md) | Architecture, tech choices, project structure |
| [Part 2: Schema](PART_02_SCHEMA.md) | Type definitions, JSON Schema codegen |
| [Part 3: Swift Helper](PART_03_SWIFT_HELPER.md) | IPC, permissions, action controllers |
| [Part 4: Controller](PART_04_CONTROLLER.md) | IPC bridge, state stores, execution |
| [Part 5: Terminal UI](PART_05_UI.md) | OpenTUI components, vim navigation |
| [Part 6: Swift UI](PART_06_SWIFT_UI.md) | Recorder overlay, magnifier, zone selector |
| [Part 7: Implementation](PART_07_IMPLEMENTATION.md) | Original step-by-step build plan |

## Build Phases

Actionable implementation phases with tasks and acceptance criteria:

| Phase | Name | Est. Time |
|-------|------|-----------|
| [Phase 1](build-phases/PHASE_01_SCHEMA.md) | Schema & Types | 2-3 hrs |
| [Phase 2](build-phases/PHASE_02_SWIFT_CORE.md) | Swift Core | 3-4 hrs |
| [Phase 3](build-phases/PHASE_03_CONTROLLER_BRIDGE.md) | Controller Bridge | 3-4 hrs |
| [Phase 4](build-phases/PHASE_04_SWIFT_ACTIONS.md) | Swift Actions | 4-5 hrs |
| [Phase 5](build-phases/PHASE_05_CONTROLLER_STATE.md) | Controller State | 3-4 hrs |
| [Phase 6](build-phases/PHASE_06_TERMINAL_UI.md) | Terminal UI | 5-6 hrs |
| [Phase 7](build-phases/PHASE_07_SWIFT_OVERLAY.md) | Swift Overlay | 8-10 hrs |
| [Phase 8](build-phases/PHASE_08_RECORDING.md) | Recording Integration | 5-6 hrs |
| [Phase 9](build-phases/PHASE_09_EXECUTION.md) | Execution | 4-5 hrs |
| [Phase 10](build-phases/PHASE_10_PREVIEW_POLISH.md) | Preview & Polish | 5-6 hrs |

See [build-phases/README.md](build-phases/README.md) for the full overview and dependency graph.

## Quick Links

- [Project README](../README.md)
- [Build Phases Index](build-phases/README.md)
