---
name: scale-local-code-coverage
description: >-
  Runs Scale iOS tests with Xcode code coverage and an .xcresult bundle via
  scripts/test-with-coverage.sh, without using GitHub Actions. Use when the user
  asks about code coverage, xcresult, local test coverage, or running xcodebuild
  with coverage for the Scale project.
---

# Scale: local code coverage (no CI)

## Default workflow

From the repo root:

```bash
./scripts/test-with-coverage.sh
```

This runs `xcodebuild test` with `-enableCodeCoverage YES` and writes **`TestResults.xcresult`** at the repo root (gitignored). The script removes any existing bundle at that path before each run.

## View results in Xcode

After a successful run:

```bash
open TestResults.xcresult
```

Or **File → Open** the bundle. Use the **Report navigator** on the latest test action, then the **Coverage** tab for per-target / per-file line coverage.

## Environment overrides

| Variable        | Purpose |
|----------------|---------|
| `DESTINATION`  | `-destination` string for `xcodebuild`. Default: `platform=iOS Simulator,name=iPhone 17` (common on Xcode 26; **CI** in `.github/workflows/ci.yml` uses **iPhone 16**). |
| `RESULT_BUNDLE`| Absolute or repo-root-relative path for the `.xcresult` bundle. Default: `$REPO_ROOT/TestResults.xcresult`. |

Examples:

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 16' ./scripts/test-with-coverage.sh
RESULT_BUNDLE=/tmp/Scale-coverage.xcresult ./scripts/test-with-coverage.sh
```

## If `xcodebuild` cannot find the simulator

List destinations for this scheme:

```bash
xcodebuild -scheme Scale -showdestinations
```

Pick an available **iOS Simulator** line and set `DESTINATION` to match, e.g. `platform=iOS Simulator,name=iPhone 16e`.

## Agent notes

- Do not commit **`TestResults.xcresult`**; it is listed in `.gitignore`.
- To change defaults for everyone, edit `scripts/test-with-coverage.sh` (scheme **Scale**, test plan **Scale**, signing overrides match CI).
- This does not replace CI; it only reproduces **local** coverage and an **.xcresult** artifact for inspection.
