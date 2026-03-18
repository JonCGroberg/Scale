# Scale

A lightweight iOS app for tracking your daily weight — with Apple Health sync, Live Text scale scanning, and streak tracking.

[![CI](https://github.com/JonCGroberg/Scale/actions/workflows/ci.yml/badge.svg)](https://github.com/JonCGroberg/Scale/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.0-orange)

---

## Features

- **📊 Weight Logging** — Enter your weight manually or via a stepper with ±0.1 lb precision
- **📷 Live Text Scanning** — Point your camera at your scale and the app reads the display automatically
- **🏥 Apple Health Sync** — Import and export weight data to/from the Health app
- **📈 History & Charts** — Interactive chart with period selectors (1W, 1M, 3M, 6M, 1Y)
- **🔥 Streak Tracking** — Tracks consecutive days you've logged your weight
- **🔔 Daily Reminders** — Set multiple custom daily reminders to stay consistent
- **🎨 Themes** — Choose from 6 accent colors (Blue, Green, Orange, Pink, Lavender, Red)

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

Scale is built with modern Apple frameworks — no external dependencies.

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Persistence | SwiftData |
| Health Data | HealthKit |
| Charts | Swift Charts |
| Camera OCR | VisionKit (DataScanner) |
| Notifications | UserNotifications |

**Key files:**
- `ScaleApp.swift` — App entry point, SwiftData container setup
- `RootView.swift` — TabView with Log, History, and Settings tabs
- `EntryView.swift` — Weight entry screen with stepper and camera scanning
- `LogView.swift` — Weight history with interactive chart
- `SettingsView.swift` — App preferences (theme, HealthKit, reminders)
- `WeightCalculations.swift` — Business logic (streaks, averages, % change)
- `HealthKitManager.swift` — HealthKit read/write/import
- `NotificationManager.swift` — Reminder scheduling

---

## Running Tests

```bash
xcodebuild test \
  -scheme Scale \
  -testPlan Scale \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

63 tests cover weight entry CRUD, calculation logic, input parsing, reminder models, and more.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
