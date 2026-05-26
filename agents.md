# Scale Agents

This document defines the specialized agents and skills available within the Scale repository.

## Core Agents

### System Agent
The primary agent responsible for general development, architectural guidance, and project orchestration.

## Specialized Skills

The following skills provide procedural knowledge and tools for specific domains. Each skill is located in the `skills/` directory.

- **SwiftUI**: Guide for designing, implementing, and optimizing iOS user interfaces using SwiftUI. SwiftUI is the default and required framework for constructing all UI in this project.
  - Path: `skills/swiftui/SKILL.md`
  - Capability: Standard SwiftUI development, state management, layouts, and toolbar customizations. Includes integration guidelines for Liquid Glass.
- **Liquid Glass**: iOS 26 Liquid Glass expert for modern glass-style UI components, morphing animations, and HIG compliance.
  - Path: `skills/liquid-glass/SKILL.md`
  - Capability: Specialized iOS 26 styling, glass modifiers, morphing transition effects, and glass container systems.
- **Test Coverage**: Manage and analyze unit test coverage for the Scale application.
  - Path: `skills/test-coverage/SKILL.md`
  - Capability: Runs tests with coverage and calculates line coverage percentages for Scale.app.
- **Emulator**: Build, run, and verify the Scale app on the iOS Simulator.
  - Path: `skills/emulator/SKILL.md`
  - Capability: Standard simulator builds, testing, and runtime verification.

## Integration Guidelines

When tasking a specialized agent or invoking a skill:
1. Reference the skill by its name (e.g., "Use the Test Coverage skill", "Use the SwiftUI skill", or "Use the Emulator skill").
2. Ensure the environment has the necessary dependencies (e.g., Xcode for test coverage).

### Verification post Code Changes
Always build the application for the iOS Simulator, install and open it to verify the UI, and run relevant tests/verification steps after making a set of code changes. This ensures that compilation succeeds, UI layouts are verified, and no regressions are introduced. Refer to the **Emulator** skill for exact build, test, and launch commands.

> [!IMPORTANT]
> When locating the built `Scale.app` bundle in `DerivedData`, always exclude indexing paths like `Index.noindex` (for example, by using `grep -v "Index.noindex"`) to avoid installing incomplete indexing bundles that lack a valid bundle identifier.



