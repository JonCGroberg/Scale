---
name: test-coverage
description: Manage and analyze unit test coverage for the Scale application. Use this skill when the user wants to run tests with coverage, check the current line coverage percentage for Scale.app, or generate coverage reports.
---

# Test Coverage Skill

This skill provides utilities to execute tests and measure the code coverage of the Scale app.

## Bundled Resources

### Scripts
- `scripts/test-with-coverage.sh`: Runs unit tests using `xcodebuild` and generates an `.xcresult` bundle containing coverage data.
- `scripts/coverage-app-percent.sh`: Processes an `.xcresult` bundle to output the specific line coverage percentage for the `Scale.app` target.

## Workflow

1. **Generate Coverage Data**: Run `./skills/test-coverage/scripts/test-with-coverage.sh`. This will produce a `TestResults.xcresult` bundle in the repository root.
2. **Analyze Coverage**: Run `./skills/test-coverage/scripts/coverage-app-percent.sh` to get the summary percentage.
3. **Detailed Review**: The `.xcresult` bundle can be opened directly in Xcode (Report navigator $\rightarrow$ Coverage) for a file-by-file breakdown.

## Implementation Details
- The scripts rely on `xcodebuild` and `xccov`.
- Default simulator target is iPhone 17. This can be overridden using the `DESTINATION` environment variable.
