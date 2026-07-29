# Phase 04: Test and Release

## Overview

Verify mapping, persistence, JSON-RPC behavior, failure recovery, widget states, and the signed/notarized DMG workflow. Depends on Phases 01–03.

## Task List

### 4.1 Add automated tests
**Files:** `Tests/QuotaCoreTests/*.swift`

Cover quota parsing, multi-bucket selection, missing windows, clamping, seven-day zero fill, timezone behavior, atomic persistence, protocol handshake, notifications, and process exit.

### 4.2 Add operator scripts
**Files:** `scripts/bootstrap.sh`, `scripts/release.sh`

Generate the Xcode project, run tests, create a Universal 2 archive, export with Developer ID, notarize, staple, verify, and package a DMG.

### 4.3 Document setup and release
**Files:** `README.md`

Explain prerequisites, local development, first-run setup, supported Codex installations, known WidgetKit timing limits, signing variables, and troubleshooting.

## State Management

| State | Verification |
| --- | --- |
| Loading | First-run and preview fixtures |
| Empty | No stored snapshot |
| Error | Missing binary, logout, incompatible protocol, child exit |
| Normal | Live signed-in Codex response |
| Edge | Weekly-only quota, midnight rollover, stale cache |

## Acceptance Criteria

- [ ] Core tests pass without a real Codex account.
- [ ] Xcode project generation is deterministic.
- [ ] Release script refuses missing signing/notarization inputs.
- [ ] Final app passes `codesign`, `spctl`, and notarization checks.

## Notes

The current machine needs full Xcode and a Developer ID identity before archive and notarization can run.
