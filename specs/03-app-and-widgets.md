# Phase 03: App and Widgets

## Overview

Build the menu bar experience, settings, launch-at-login control, and adaptive small/medium desktop widgets. Depends on Phases 01 and 02.

## Task List

### 3.1 Coordinate refreshes
**Files:** `Sources/QuotaApp/AppModel.swift`

Refresh quota every 60 seconds and usage every 15 minutes, respond to wake/manual refresh/notifications, use bounded reconnect backoff, persist updates, and request WidgetKit timeline reloads only when data changes.

### 3.2 Build menu bar and settings
**Files:** `Sources/QuotaApp/*.swift`

Show both quota windows, status, last update, refresh, Codex executable selection, login-item state, and the third-party disclaimer.

### 3.3 Build WidgetKit views
**Files:** `Sources/QuotaWidget/*.swift`

Use `systemSmall` for quota-only content and `systemMedium` for quota plus a Swift Charts seven-day trend. Support light, dark, accented, vibrant, loading, missing, error, and stale states.

## State Management

| State | Behavior |
| --- | --- |
| Loading | Redacted placeholder |
| Empty | “Open Quota for Codex to finish setup” |
| Error | Compact status label, cached data retained |
| Normal | Adaptive gauges and chart |
| Edge | Missing window shows an em dash and “No data” |

## Acceptance Criteria

- [ ] Small and medium widgets match the agreed information hierarchy.
- [ ] Remaining quota controls semantic green/orange/red tint.
- [ ] Host requests a widget reload within five seconds of a data change.
- [ ] Launch-at-login can be enabled and disabled from Settings.

## Notes

Actual widget render timing remains controlled by WidgetKit.
