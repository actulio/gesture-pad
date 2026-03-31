# GesturePad

A native macOS menu bar app that detects multi-finger trackpad gestures and maps them to system actions. Lightweight, configurable, and built with Swift 6 + SwiftUI.

## Features

- **3-Finger Tap** → Middle mouse click
- **3-Finger Swipe Right** → ⌘Tab (next app)
- **3-Finger Swipe Left** → ⌘⇧Tab (previous app)
- Fully **remappable** — assign any keyboard shortcut to any gesture
- Lives in the **menu bar** — zero dock clutter
- **Settings window** with macOS-native look and feel
- Launch at login support

## Requirements

- macOS 15+ (Sequoia)
- Swift 6 toolchain (Xcode 16+ or standalone)
- Accessibility permission (for posting system events)

## Build & Run

This is a SwiftPM project — no Xcode project file needed.

### Quick start (dev)

```bash
# Build, package the .app bundle, and launch
Scripts/compile_and_run.sh
```

### Manual build

```bash
swift build -c release
Scripts/package_app.sh release
open GesturePad.app
```

### Run tests

```bash
swift test
```

## Install

After building, copy the `.app` bundle to your Applications folder:

```bash
cp -R GesturePad.app /Applications/
```

You can then launch it from Spotlight or Launchpad.

> **Note:** After rebuilding, re-run the `cp -R` command to update the installed copy.

## Permissions

On first launch, GesturePad will request **Accessibility** permission. This is required to post system events (middle clicks, keyboard shortcuts).

1. macOS will prompt you to grant access in **System Settings → Privacy & Security → Accessibility**
2. Toggle GesturePad **on**
3. The app will detect the change automatically and start processing gestures

Touch detection via the trackpad works immediately — Accessibility is only needed for *executing* the mapped actions.

## Architecture

```
Trackpad Hardware
      │
      ▼
┌─────────────────────────────────────────┐
│ TouchDetector                           │
│ MultitouchSupport.framework (private)   │
│ Emits: TouchEvent stream                │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ GestureRecognizer                       │
│ Pure logic — no system dependencies     │
│ Sub-recognizers: TapRecognizer,         │
│                  SwipeRecognizer        │
│ Emits: Gesture events                   │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌──────────────────────┐  ┌───────────────────────┐
│ ActionMapper         │→ │ ActionExecutor        │
│ Gesture → Action     │  │ CGEvent posting       │
│ lookup               │  │ Middle click, key     │
│ Reads ConfigStore    │  │ combos                │
└──────────────────────┘  └───────────────────────┘
         │
         ▼
┌──────────────────────┐  ┌───────────────────────┐
│ ConfigStore          │  │ MenuBarApp            │
│ UserDefaults         │  │ SwiftUI MenuBarExtra  │
│ Gesture ↔ Action     │  │ Toggle + Settings     │
│ mappings (Codable)   │  │ window                │
└──────────────────────┘  └───────────────────────┘
```

## Project Structure

```
GesturePad/
├── Package.swift
├── Scripts/
│   ├── compile_and_run.sh      # Dev loop: build, package, launch
│   └── package_app.sh          # .app bundle assembly + code signing
├── Sources/GesturePad/
│   ├── App/                    # App entry point, lifecycle, accessibility
│   ├── Detection/              # MultitouchSupport bridge + touch events
│   ├── Recognition/            # Gesture state machines (tap, swipe)
│   ├── Actions/                # Gesture→action mapping + CGEvent execution
│   ├── Config/                 # Persistence, gesture/action type definitions
│   └── UI/                     # Menu bar view, settings, key recorder
├── Tests/GesturePadTests/      # Unit tests for recognizers, mapper, config
└── version.env                 # Version + build number for packaging
```

## License

MIT
