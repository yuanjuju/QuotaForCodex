# Quota for Codex Engineering Guide

## Project Overview

Quota for Codex is a macOS 14+ menu bar app and WidgetKit extension that displays the remaining Codex quota and a seven-day token-usage trend.

The core flow is:

`installed Codex executable -> codex app-server JSON-RPC -> normalized snapshot -> App Group JSON -> menu bar + systemSmall/systemMedium widgets`

The app is single-user and reads the Codex account that is already signed in on the current Mac. It never reads or stores Codex authentication credentials. Its value is a glanceable, system-native view of quota health without opening Codex.

## Technical Architecture

```text
┌──────────────────────────┐
│ Installed Codex binary   │
│ ChatGPT/Codex/CLI        │
└────────────┬─────────────┘
             │ stdio JSON-RPC
             ▼
┌──────────────────────────┐
│ QuotaForCodex menu app   │
│ - executable discovery   │
│ - app-server lifecycle   │
│ - polling + notifications│
└────────────┬─────────────┘
             │ atomic Codable JSON
             ▼
┌──────────────────────────┐
│ App Group snapshot store │
└──────────┬───────────────┘
           │
      ┌────┴───────────────┐
      ▼                    ▼
┌───────────────┐  ┌──────────────────┐
│ MenuBarExtra  │  │ Widget extension │
│ + Settings    │  │ small + medium   │
└───────────────┘  └──────────────────┘
```

| Decision | Choice | Rationale |
| --- | --- | --- |
| UI stack | SwiftUI, WidgetKit, Swift Charts | Native adaptive macOS widgets |
| Minimum OS | macOS 14 | Desktop WidgetKit support |
| Data source | Codex app-server stable account methods | Reuses the local signed-in account without credentials |
| IPC | Line-delimited JSON-RPC over stdio | Matches the Codex app-server transport |
| Persistence | Atomic Codable JSON in an App Group | Safe sharing between the host app and widget |
| Background lifecycle | MenuBarExtra plus `SMAppService.mainApp` | Near-real-time host updates and launch at login |
| Distribution | Universal 2 Developer ID DMG | Supports direct distribution and external-process access |
| Project generation | XcodeGen plus Swift Package core | Reproducible Xcode project and command-line core tests |

## Data Model

There is no database. The shared snapshot has this conceptual shape:

```json
{
  "schemaVersion": 1,
  "fetchedAt": "2026-07-29T11:46:02Z",
  "sourceVersion": "codex-cli 0.146.0",
  "windows": [
    {
      "id": "codex-10080-primary",
      "durationMinutes": 10080,
      "usedPercent": 15,
      "resetsAt": "2026-08-05T04:18:23Z"
    }
  ],
  "dailyUsage": [
    { "date": "2026-07-29", "tokens": 12500000 }
  ],
  "status": "ready",
  "statusMessage": null
}
```

`remainingPercent` is derived as `clamp(100 - usedPercent, 0...100)` and is not persisted independently.

## API / Service Conventions

| Method | Request params | Response data used | Failure handling |
| --- | --- | --- | --- |
| `initialize` | client name, title, version | app-server user agent | Mark incompatible if negotiation fails |
| `initialized` | notification only | none | Sent after successful initialize |
| `account/rateLimits/read` | `null` | overall `codex` primary/secondary windows | Keep last good data and expose status |
| `account/usage/read` | `null` | daily token buckets | Preserve last chart if quota refresh succeeds |
| `account/rateLimits/updated` | server notification | no sparse merge | Refetch the complete rate-limit snapshot |

The client assigns monotonically increasing integer request IDs, applies a 15-second request timeout, and maps JSON-RPC errors to typed Swift errors. It never logs response payloads containing account metadata.

## File Directory Structure

```text
.
├── agents.md
├── project.yml
├── Package.swift
├── Config/
│   ├── App-Info.plist
│   ├── App.entitlements
│   ├── Widget-Info.plist
│   └── Widget.entitlements
├── Sources/
│   ├── QuotaCore/
│   ├── QuotaApp/
│   └── QuotaWidget/
├── Tests/
│   └── QuotaCoreTests/
├── scripts/
│   ├── bootstrap.sh
│   └── release.sh
└── specs/
    ├── 01-project-shell.md
    ├── 02-codex-data-layer.md
    ├── 03-app-and-widgets.md
    └── 04-test-and-release.md
```

## Phase Overview

| Phase | Name | Dependencies | Deliverable |
| --- | --- | --- | --- |
| 01 | Project shell | None | Buildable targets, entitlements, shared model contract |
| 02 | Codex data layer | Phase 01 | Discovery, app-server client, normalization, persistence |
| 03 | App and widgets | Phases 01–02 | Menu app, settings, small and medium widgets |
| 04 | Test and release | Phases 01–03 | Automated tests, DMG pipeline, operator documentation |
