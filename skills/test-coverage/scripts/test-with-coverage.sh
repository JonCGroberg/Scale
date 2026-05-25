#!/usr/bin/env bash
# Run unit tests and write an .xcresult bundle with code coverage data.
# Open the bundle in Xcode (Report navigator → Coverage) or: open TestResults.xcresult
#
# Optional env vars:
#   DESTINATION   Default matches a common iOS 26 simulator; CI may use another (e.g. iPhone 16).
#   RESULT_BUNDLE Path for the result bundle directory (default: repo root TestResults.xcresult)
#
# Example:
#   DESTINATION='platform=iOS Simulator,name=iPhone 16e' ./scripts/test-with-coverage.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RESULT_BUNDLE="${RESULT_BUNDLE:-$ROOT/TestResults.xcresult}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

rm -rf "$RESULT_BUNDLE"

xcodebuild test \
  -scheme Scale \
  -testPlan Scale \
  -destination "$DESTINATION" \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

echo
echo "Result bundle: $RESULT_BUNDLE"
echo "Open in Xcode: open \"$RESULT_BUNDLE\""
