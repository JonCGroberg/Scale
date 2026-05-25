# Scale

A lightweight, high-precision iOS app for tracking daily weight, designed to remove friction through Apple Health sync, Live Text scale scanning, and motivational streak tracking.

[![CI](https://github.com/JonCGroberg/Scale/actions/workflows/ci.yml/badge.svg)](https://github.com/JonCGroberg/Scale/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.0-orange)

---

## Features

- **📊 High-Precision Logging** — Manual entry via a dedicated stepper with ±0.1 lb precision for absolute accuracy.
- **📷 Live Text Scanning** — Leverages VisionKit's `DataScanner` to automatically read digital scale displays, eliminating manual entry.
- **🏥 Bidirectional Health Sync** — Deep integration with Apple Health via HealthKit. Supports full import/export and an optional `autoSync` mode to keep local data aligned with the system source of truth.
- **📈 Trend Analysis** — Interactive data visualization using Swift Charts with selectable time-windows (1W, 1M, 3M, 6M, 1Y).
- **🔥 Motivational Streaks** — A persistence-aware streak system that tracks consecutive logging days. Notifications use "potential streak" logic to motivate users to maintain their run.
- **🔔 Dynamic Reminders** — Multiple customizable daily alerts that adapt their messaging based on the user's current streak status.
- **🎨 Visual Themes** — 6 curated accent colors (Blue, Green, Orange, Pink, Lavender, Red) to personalize the experience.

---

## User Experience Flow

The app is structured as a focused loop to encourage consistency:

1. **Onboarding:** First-run experience guiding users through goal selection (Lose/Gain/Maintain), target weight setting, and HealthKit authorization.
2. **The Daily Loop:** 
   - **Trigger:** A streak-aware notification prompts the user.
   - **Action:** User logs weight via the `EntryView` (Manual or OCR scan).
   - **Feedback:** Immediate visual confirmation of goal progress and streak increment.
3. **Review:** The `LogView` provides a historical perspective, allowing users to correlate weight trends with other health metrics.

---

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 26.0+ |
| Xcode | 26.0+ |
| Swift | 5.0 |

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/JonCGroberg/Scale.git
   cd Scale
   ```
2. Open `Scale.xcodeproj` in Xcode
3. Select a target device or iOS Simulator (iPhone 16 recommended)
4. Build and run (`⌘R`)

> **Note:** HealthKit features require a physical device. The iOS Simulator will not prompt for HealthKit authorization.

---

## Architecture

Scale is built with a modern, dependency-free Apple stack.

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI** | SwiftUI | Declarative view hierarchy and state management |
| **Persistence** | SwiftData | Local storage for `WeightEntry`, `WorkoutEntry`, and `SleepEntry` |
| **Health Data** | HealthKit | Interface for system-wide health metrics and syncing |
| **Charts** | Swift Charts | High-performance weight trend visualization |
| **Camera OCR** | VisionKit | Live Text parsing for digital scale displays |
| **Notifications** | UserNotifications | Scheduling and delivering streak-aware reminders |

### Key Implementation Details
- `ScaleApp.swift` — App entry point; configures the SwiftData `ModelContainer`.
- `WeightCalculations.swift` — Pure business logic layer for streaks, averages, and percentage changes.
- `HealthKitManager.swift` — Manages the complex bridge between SwiftData and the HealthKit store.
- `NotificationManager.swift` — Handles the lifecycle of `UNCalendarNotificationTrigger` and dynamic body generation.
- `RootView.swift` — Primary navigation hub (Log, History, and Settings).

---

## Running Tests

The project maintains high confidence through a suite of 60+ tests covering OCR parsing, streak edge cases, and data migration.

```bash
xcodebuild test \
  -scheme Scale \
  -testPlan Scale \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.
