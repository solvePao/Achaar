# Working on Achaar

Achaar is a personal iPhone wrapper around Instagram Web. It uses Apple frameworks,
a UIKit browser shell, WebKit for account/content state, and SwiftUI only for Settings.
There are no package dependencies, backend, analytics SDKs, or native Instagram API client.
The iOS deployment target is 26.0. Open `Achaar.xcodeproj`; Xcode 26+ is required.

## Read before editing

- `README.md`: product behavior, setup, privacy boundaries, and device testing.
- `docs/Architecture.md`: ownership, WebKit lifecycle, navigation and bridge contracts.
- `docs/Testing.md`: automated checks, coverage scope, and manual acceptance criteria.
- `docs/FeatureStatus.md` and `docs/Usage.md`: verified features and limitations.
- `docs/XcodeCloud.md`: the `testflight` branch triggers Xcode Cloud distribution.

## Code map

| Area | Entry points and responsibilities |
| --- | --- |
| App lifecycle | `Achaar/App/AchaarApp.swift`: window, scene and foreground/background transitions |
| Preferences | `Achaar/App/AppSettings.swift`: defaults, migrations, appearance and interrupted-launch recovery |
| Browser model | `Achaar/Core/Web/BrowserModel.swift`: web views, delegates, trusted bridge, page retention, data clearing |
| URL policy | `Achaar/Core/Web/InstagramRouting.swift`: trusted origins, tab/action metadata, sharing and external links |
| Native UI | `Achaar/Features/Browser/BrowserScreen.swift`, `WebViewHost.swift`: UIKit shell and presentation |
| Settings UI | `Achaar/Features/Settings/SettingsScreen.swift`: SwiftUI settings sheet |
| Privacy | `Achaar/Core/Privacy/`: authentication, shield, cache/session cleanup, tracker rules, usage statistics |
| Web adapter | `Achaar/Resources/Web/Navigation.js` and `Enhancements.css`: website control discovery and layout |
| Tests | `AchaarTests/AchaarTests.swift`: shared Mac tests plus conditional hosted iOS tests; `AchaarUITests/`: device flows |

## Required checks

Run `bash Scripts/test-coverage.sh` for shared changes. This runs real macOS XCTest,
checks xccov line coverage strictly above 90% for every shared production file and
in aggregate, then runs dependency-free Node DOM fixtures. See `docs/Testing.md`
for the explicit coverage boundary; do not describe this as whole-app coverage.

For iOS source changes, also compile an unsigned iPhone build:

```sh
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Use an iOS 26+ simulator/device for hosted tests and a connected, signed-in test
phone for account-dependent UI checks. Do not use a real account to send messages,
react, publish, or change likes/saves without explicit user authorization.
Never embed credentials or private conversation names in tests. `ACHAAR_TEST_THREAD`
provides an optional conversation fixture; missing configuration skips that UI test.

## Invariants

- Instagram owns login, feed, messaging, uploads and account state. Do not add private
  endpoints or a parallel native feed/message database.
- Keep credentials, page contents and cookies out of models, logs, fixtures and Git.
  Validate bridge origin, main frame, active view and fixed payload shapes.
- Keep both web views on the same website store. Cache clearing preserves cookies and
  local storage; full session clearing also replaces views and discards history.
- Keep tracker blocking off by default. A stale asynchronous compilation must never
  re-enable protection after it was disabled.
- Usage statistics count foreground intervals only, reset their daily bucket at local
  03:00, retain seven daily buckets and persist lifetime totals independently.
- Put website selectors in the adapter. Missing website controls must allow recovery
  to the original interface. Do not guess private Instagram APIs to work around them.
- Fatal UIKit termination cannot be caught and continued. Automated swipes do not
  establish real finger-scroll stability; retain device acceptance checks.

## Editing and delivery

Use isolated UserDefaults suites, temporary files and nonpersistent WebKit stores
in tests. Clean up fixtures. Add new Swift files to the relevant Xcode build phases;
shared code also needs AchaarCoreTests membership. Add web resources to Copy Bundle
Resources. Keep the coverage gate's required-file list aligned with shared sources.

Inspect `git status` before editing and leave unrelated user changes untouched.
Follow the user's requested branch/PR workflow. Pushing or merging into `testflight`
can start a beta archive; a successful merge is not proof of TestFlight availability.
