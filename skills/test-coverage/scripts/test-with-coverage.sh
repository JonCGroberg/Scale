#!/usr/bin/env bash
# Run unit tests and write an .xcresult bundle with code coverage data.
set -euo pipefail

# Navigate to the project root from the script's location
# Current path: /Users/jonathangroberg/repos/Scale/skills/test-coverage/scripts/test-with-coverage.sh
# Needs to go up 3 levels to reach /Users/jonathangroberg/repos/Scale/
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
cd "$ROOT"

RESULT_BUNDLE="${RESULT_BUNDLE:-$ROOT/TestResults.xcresult}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

rm -rf "$RESULT_BUNDLE"

xcodebuild test   -scheme Scale      -destination "$DESTINATION"   -enableCodeCoverage YES   -resultBundlePath "$RESULT_BUNDLE"   CODE_SIGN_IDENTITY=""   CODE_SIGNING_REQUIRED=NO

echo
echo "Result bundle: $RESULT_BUNDLE"
echo "Open in Xcode: open \"$RESULT_BUNDLE\""
