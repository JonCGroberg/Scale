#!/usr/bin/env bash
# Print Scale.app line coverage from an existing .xcresult bundle (primary KPI).
# Run ./scripts/test-with-coverage.sh first, or pass a bundle path:
#   ./scripts/coverage-app-percent.sh /path/to/TestResults.xcresult
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="${1:-$ROOT/TestResults.xcresult}"

if [[ ! -d "$BUNDLE" ]]; then
  echo "No result bundle at: $BUNDLE" >&2
  echo "Run: ./scripts/test-with-coverage.sh" >&2
  exit 1
fi

xcrun xccov view --report --json "$BUNDLE" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
app = None
for t in data.get('targets', []):
    path = t.get('buildProductPath') or ''
    if 'ScaleTests' in path or 'ScaleWidget' in path:
        continue
    if '/Scale.app/' in path or path.endswith('/Scale.app/Scale'):
        app = t
        break
if app is None:
    for t in data.get('targets', []):
        path = t.get('buildProductPath') or ''
        if 'Scale.app' in path and 'Test' not in path and 'Widget' not in path:
            app = t
            break
if app is None:
    print('Could not find Scale.app target in xccov JSON', file=sys.stderr)
    sys.exit(2)
cov = app.get('lineCoverage', 0) * 100
covered = app.get('coveredLines', 0)
exe = app.get('executableLines', 0)
print(f'Scale.app line coverage: {cov:.1f}% ({covered}/{exe} lines)')
"
