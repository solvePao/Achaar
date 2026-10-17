#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
run_dir=$(mktemp -d "$PWD/build/coverage.XXXXXX")
xcodebuild -project Achaar.xcodeproj -scheme AchaarCoreTests \
  -destination 'platform=macOS' -enableCodeCoverage YES \
  -resultBundlePath "$run_dir/Tests.xcresult" test
xcrun xccov view --report --json "$run_dir/Tests.xcresult" > "$run_dir/coverage.json"
node --test Scripts/check-coverage.test.mjs
node Scripts/check-coverage.mjs "$run_dir/coverage.json"
node Scripts/verify-web.mjs
printf 'Coverage artifacts: %s\n' "$run_dir"
