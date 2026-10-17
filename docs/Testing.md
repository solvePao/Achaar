# Testing and coverage

## One-command verification

Requirements: macOS, Xcode 26+ selected through `xcode-select`, and Node.js 22+.
No package installation or Instagram account is needed.

```sh
bash Scripts/test-coverage.sh
```

The script runs `AchaarCoreTests` with coverage, exports Apple's xccov JSON, checks
production-source coverage and executes the real navigation adapter with synthetic
DOM fixtures. Each run creates a unique ignored `build/coverage.*/` directory with
`Tests.xcresult` and `coverage.json`. Open the result bundle in Xcode to inspect
uncovered lines. The shared scheme also enables coverage for Product → Test.

`Scripts/check-coverage.mjs` requires **strictly above 90% executable-line coverage**
for every production file reported by AchaarCoreTests and for their weighted total.
It excludes test sources from both numerator and denominator, rejects missing
required production files and includes newly reported production sources.
GitHub Actions runs the same command for pushes and PRs to `main` and `testflight`
and uploads the result bundle even when checks fail.

## What the percentage measures

The Mac target directly compiles these five shared production sources:

- `AppSettings.swift`: safe defaults, all persisted preferences, enum metadata,
  migration once to navigation integration v2, interrupted-launch recovery.
- `InstagramRouting.swift`: origin/frame policy, mobile Safari identity, tab/action
  contracts, private-route sharing restrictions and outbound link validation.
- `UsageTracker.swift`: local 03:00 reset, DST, multi-day splitting, checkpoint
  ordering, inactive/relaunch behavior, migration/corrupt state and projections.
- `WebsiteDataCleaner.swift`: real WebKit cookie-preserving cache cleanup and full
  session clearing; file metadata, symlinks, empty/missing/nested cache directories.
- `TrackerProtection.swift`: real WebKit compilation, disable/reapply, missing and
  invalid rules, and disable while compilation is pending.

This is **shared-core Swift line coverage**, not whole-app, branch, JavaScript,
or UI coverage. XCTest code is compiled into the same target, so Xcode's headline
percentage includes the tests themselves; use the script's production-only result.
The Node fixtures separately exercise `Navigation.js` without claiming a JS coverage
percentage. Do not remove production files or add blanket exclusions to pass the gate.

## Verified baseline

On October 18, 2026, Xcode 27 ran 26 shared XCTest cases successfully. Production
line coverage improved from 259/330 lines (78.48%) to **325/330 (98.48%)**:

| Source | Covered / executable | Line coverage |
| --- | --- | --- |
| AppSettings.swift | 52 / 52 | 100.00% |
| InstagramRouting.swift | 119 / 122 | 97.54% |
| UsageTracker.swift | 95 / 95 | 100.00% |
| WebsiteDataCleaner.swift | 19 / 20 | 95.00% |
| TrackerProtection.swift | 40 / 41 | 97.56% |

The coverage-gate regression checks and Node web-adapter fixtures also passed.
These numbers are a recorded baseline; rerun the script for current measurements.

## iOS checks

Compile production iOS code without signing:

```sh
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Compile the complete hosted test bundle without an installed simulator runtime:

```sh
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```

To execute hosted tests, use Product → Test with the Achaar scheme and an iOS 26+
simulator or device. These additionally exercise BrowserModel's cache/session reset
and primary-view replacement. Mac tests do not exercise BrowserModel, AppLock,
application lifecycle, Settings UI, native presentation or the UIKit browsing shell.
Changes in those files need appropriate hosted/device validation; their coverage
has not been established by the shared-core gate.

The AchaarLoginUITests scheme contains a signed-out English login smoke test and
separate signed-in navigation/scrolling tests. Select only tests matching the
account state. Set `ACHAAR_TEST_THREAD` to a test conversation display name for
conversation checks. Tests must not store account information or submit content.
Real finger scrolling, authentication, uploads, keyboard layout and live Instagram
rollouts remain phone acceptance checks; see `FeatureStatus.md` and `Usage.md`.
