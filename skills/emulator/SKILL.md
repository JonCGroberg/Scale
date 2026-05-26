---
name: emulator
description: Guidelines and commands to build, run, and test the Scale application on the iOS Simulator (emulator).
---

# Emulator Skill

This skill provides instructions for building, running, and verifying the Scale application on the iOS Simulator.

## Verification Workflow

Whenever code changes are made to the codebase, the agent must build the project for the simulator to verify that there are no compilation errors or UI layout issues.

### 1. Build the App for iOS Simulator
To verify that the application compiles successfully for the iOS Simulator:

```bash
xcodebuild build \
  -scheme Scale \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

### 2. Run Unit and UI Tests
To execute the suite of tests on the simulator:

```bash
xcodebuild test \
  -scheme Scale \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

### 3. Open the App in the iOS Simulator
To boot the simulator, install the latest built `.app` bundle, and launch it:

```bash
# Open the iOS Simulator application
open -a Simulator

# Boot the iPhone 17 simulator device
xcrun simctl boot "iPhone 17"

# Install the built Scale.app bundle from DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Scale.app" -type d | grep -v "Index.noindex" | head -n 1)
xcrun simctl install booted "$APP_PATH"

# Launch the app using its bundle identifier
xcrun simctl launch booted groberg.Scale
```

