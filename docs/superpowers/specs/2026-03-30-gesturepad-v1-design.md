# GesturePad v1 — Custom Trackpad Gesture App

A native macOS menu bar app that detects 3-finger trackpad gestures and maps them to system actions. Inspired by BetterTouchTool, scoped to a focused first version.

## Target Platform

- macOS 15+ (Sequoia)
- Swift 6, SwiftUI
- SwiftPM-based project (no Xcode project file)

## Scope — v1 Gestures

Three gestures, each with a default action:

| Gesture | Default Action | Mechanism |
|---------|---------------|-----------|
| 3-finger tap | Middle mouse click | CGEvent post (button 2 down+up at cursor position) |
| 3-finger swipe right | ⌘+Tab (next app) | CGEvent post (keyDown/keyUp with Cmd modifier) |
| 3-finger swipe left | ⌘+Shift+Tab (previous app) | CGEvent post (keyDown/keyUp with Cmd+Shift modifiers) |

Users can remap each gesture to a different keyboard shortcut or middle click via the settings window.

## Architecture

Six components with clear boundaries:

```
Trackpad Hardware
      │
      ▼
┌─────────────────────────────────────────┐
│ TouchDetector                           │
│ MultitouchSupport.framework (private)   │
│ Only private API boundary               │
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
│ lookup               │  │ (public API)          │
│ Reads ConfigStore    │  │ Middle click, key     │
│                      │  │ combos                │
└──────────────────────┘  └───────────────────────┘
         │
         │ reads
         ▼
┌──────────────────────┐  ┌───────────────────────┐
│ ConfigStore          │  │ MenuBarApp            │
│ UserDefaults         │  │ SwiftUI MenuBarExtra  │
│ Gesture ↔ Action     │  │ Toggle + Settings     │
│ mappings (Codable)   │  │ window                │
└──────────────────────┘  └───────────────────────┘
```

### Component Responsibilities

**TouchDetector** — The only component touching private API. Loads `MultitouchSupport.framework` at runtime via `dlopen`. Registers a callback to receive raw multitouch data (finger count, positions, timestamps). Publishes a stream of `TouchEvent` values. If the framework is unavailable, it fails gracefully and reports the error.

**GestureRecognizer** — Pure logic layer with no system dependencies. Contains two sub-recognizers:

- `TapRecognizer`: detects 3 fingers touching down and lifting within ~200ms with < 5px displacement. State machine: `idle → fingersDown → tap | cancelled`.
- `SwipeRecognizer`: detects 3 fingers moving horizontally > ~50px threshold. Fires when threshold is crossed (not on finger lift). State machine: `idle → tracking → swiped(direction) | cancelled`.
- Debouncing: ~300ms cooldown after any gesture fires. Swipe suppresses tap while fingers are moving.

**ActionMapper** — Looks up the configured action for a recognized gesture by reading from ConfigStore. Returns an `Action` value.

**ActionExecutor** — Posts CGEvents to the system. Two action types:
- Middle click: creates `mouseDown`/`mouseUp` events for button 2 at the current cursor position.
- Keyboard shortcut: creates `keyDown`/`keyUp` events with the configured modifier flags and virtual key code.

**ConfigStore** — Persists gesture-to-action mappings in UserDefaults. Data model:
- `GestureType` enum: `.threeFingerTap`, `.threeFingerSwipeLeft`, `.threeFingerSwipeRight`
- `ActionType` enum: `.middleClick`, `.keyboardShortcut(modifiers: CGEventFlags, keyCode: UInt16)`
- Both are `Codable`. Stored as a `[GestureType: ActionType]` dictionary.

**MenuBarApp** — SwiftUI app using `MenuBarExtra`. Provides:
- Menu bar icon (🤚 or SF Symbol)
- Dropdown with: enable/disable toggle, "Settings…" to open the settings window, "Quit"
- Settings window opened via `openWindow` environment action

## Settings UI

macOS System Settings-style layout with Apple HIG dark mode colors.

### Settings Window
- Grouped rows in a rounded container (#2c2c2e on #1c1c1e background)
- "Gesture Mappings" section: one row per gesture showing name and a dropdown picker for the action
- "General" section: "Enable Gestures" toggle, "Launch at Login" toggle
- Uses SwiftUI `List` with `.insetGrouped` style
- Search bar auto-appears when gesture count ≥ 6 (future-proofing, not needed in v1)

### Menu Bar Dropdown
- App name and status ("3 gestures active")
- Enable/disable toggle
- "Settings…" menu item
- Separator
- "Quit" menu item

### Action Picker
When the user clicks the action dropdown for a gesture, they see preset options:
- Middle Click
- Keyboard Shortcut → opens an inline key recorder: a text field that says "Press shortcut…", captures the next physical key combination (via `NSEvent.addLocalMonitorForEvents`), displays it as a human-readable string (e.g., "⌘⇧Z"), and stores the `CGEventFlags` + `CGKeyCode`
- Disabled (no action)

## Permissions & Onboarding

### Accessibility Permission
Required for CGEvent posting. First launch flow:
1. Check `AXIsProcessTrusted()`
2. If not trusted: show an alert explaining why, with a button to open System Settings > Privacy & Security > Accessibility
3. Poll `AXIsProcessTrusted()` every 2 seconds until granted
4. Once granted: dismiss alert, start gesture detection

### Launch at Login
Use `SMAppService.mainApp` to register/unregister login item. Toggled via the settings window.

## Error Handling

| Scenario | Response |
|----------|----------|
| MultitouchSupport framework unavailable | Alert to user, disable gesture detection, keep settings accessible |
| Accessibility permission not granted | Onboarding flow (see above) |
| CGEvent posting fails | Log silently, don't interrupt user |
| No trackpad detected | Subtle indicator in menu bar dropdown: "No trackpad found" |

## Project Structure

```
GesturePad/
├── Package.swift
├── Sources/
│   └── GesturePad/
│       ├── App/
│       │   ├── GesturePadApp.swift          # @main, MenuBarExtra
│       │   └── AppDelegate.swift            # Accessibility check, lifecycle
│       ├── Detection/
│       │   ├── TouchDetector.swift           # MultitouchSupport wrapper
│       │   └── MultitouchBridge.swift        # C bridging for dlopen/callbacks
│       ├── Recognition/
│       │   ├── GestureRecognizer.swift       # Coordinator for sub-recognizers
│       │   ├── TapRecognizer.swift           # 3-finger tap state machine
│       │   └── SwipeRecognizer.swift         # 3-finger swipe state machine
│       ├── Actions/
│       │   ├── ActionMapper.swift            # Gesture → Action lookup
│       │   └── ActionExecutor.swift          # CGEvent posting
│       ├── Config/
│       │   ├── ConfigStore.swift             # UserDefaults persistence
│       │   ├── GestureType.swift             # Gesture enum
│       │   └── ActionType.swift              # Action enum
│       └── UI/
│           ├── MenuBarView.swift             # Menu bar dropdown content
│           ├── SettingsView.swift            # Settings window
│           ├── GestureRowView.swift          # Single gesture row
│           └── KeyRecorderView.swift         # Keyboard shortcut recorder
└── Tests/
    └── GesturePadTests/
        ├── TapRecognizerTests.swift
        ├── SwipeRecognizerTests.swift
        ├── ActionMapperTests.swift
        └── ConfigStoreTests.swift
```

## Testing Strategy

### Unit Testable (no system dependencies)
- **TapRecognizer / SwipeRecognizer**: feed synthetic touch events, assert correct gesture detection. Test edge cases: too slow, too much movement, wrong finger count, debouncing.
- **ActionMapper**: given a config and a gesture, assert correct action returned.
- **ConfigStore**: round-trip serialization of gesture-action mappings.

### Manual Testing Required
- **TouchDetector**: requires a physical trackpad — verify touch events stream correctly.
- **ActionExecutor**: requires Accessibility permissions — verify middle click and key combos post correctly.
- **End-to-end**: perform gestures on trackpad, verify correct actions fire.

## Out of Scope for v1

- Per-app gesture profiles
- More than 3 gesture types
- Window snapping/tiling actions
- Custom drawing gestures
- App Store distribution
- Pinch/spread gestures
