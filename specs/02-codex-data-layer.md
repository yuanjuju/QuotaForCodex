# Phase 02: Codex Data Layer

## Overview

Discover a local Codex executable, maintain an app-server connection, read stable account quota/usage methods, normalize responses, and persist the latest snapshot. Depends on Phase 01.

## Task List

### 2.1 Discover and validate Codex
**Files:** `Sources/QuotaCore/CodexExecutableLocator.swift`

Check bundled desktop paths, Homebrew paths, inherited PATH, and an optional user-selected path. Validate executability and probe the protocol rather than enforcing a fixed version string.

### 2.2 Implement JSON-RPC
**Files:** `Sources/QuotaCore/CodexAppServerClient.swift`, `Sources/QuotaCore/CodexProtocol.swift`

Start `codex app-server --listen stdio://`, complete initialization, correlate responses by ID, enforce timeouts, publish rate-limit notifications, and reconnect after termination.

### 2.3 Normalize and persist
**Files:** `Sources/QuotaCore/QuotaMapper.swift`, `Sources/QuotaCore/SnapshotStore.swift`

Prefer the overall `codex` bucket, map primary/secondary windows, clamp remaining percent, fill missing dates for the last seven local days, and atomically save Codable JSON.

## State Management

| State | Behavior |
| --- | --- |
| Loading | Connect and request both account methods |
| Empty | Missing account data produces explicit placeholders |
| Error | Map not installed, not logged in, incompatible, offline |
| Normal | Publish and persist a ready snapshot |
| Edge | Keep last chart when only usage refresh fails |

## Acceptance Criteria

- [ ] First successful snapshot can complete in under five seconds.
- [ ] Missing five-hour data never becomes a fake 100%.
- [ ] A sparse update notification triggers a full quota refetch.
- [ ] No code reads `~/.codex/auth.json` or session logs.

## Notes

Model-specific rate-limit buckets are intentionally ignored in v1.
