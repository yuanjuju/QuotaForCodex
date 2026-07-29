# Phase 01: Project Shell

## Overview

Create a reproducible macOS 14+ project with a menu bar application, WidgetKit extension, shared core target, App Group entitlements, and a Swift Package entry for core tests. This phase has no dependencies.

## Task List

### 1.1 Define the project
**Files:** `project.yml`, `Package.swift`

Declare Universal 2 macOS targets, Swift 6 language mode, Hardened Runtime, the app/widget embedding relationship, and a shared test target.

### 1.2 Configure targets
**Files:** `Config/App-Info.plist`, `Config/Widget-Info.plist`, `Config/*.entitlements`

Make the host an `LSUIElement` menu bar app. Give both targets the same App Group and sandbox only the widget extension.

### 1.3 Establish shared contracts
**Files:** `Sources/QuotaCore/*.swift`

Define Sendable Codable snapshot types and protocol payloads without importing SwiftUI, AppKit, or WidgetKit.

## State Management

| State | Behavior |
| --- | --- |
| Loading | Empty snapshot with `loading` status |
| Empty | Widget prompts the user to open the app |
| Error | Typed status and optional message |
| Normal | Current quota and seven-day points |
| Edge | Stale snapshot remains visible with a stale marker |

## Acceptance Criteria

- [ ] XcodeGen can generate the project.
- [ ] `swift test` discovers the core target.
- [ ] App and widget share one App Group identifier.
- [ ] Main app is not App Sandbox enabled.

## Notes

Full app builds require a complete Xcode installation. Command Line Tools are sufficient for core Swift Package tests.
