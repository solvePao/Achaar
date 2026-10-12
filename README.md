<p align="center">
  <img src="Achaar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="144" height="144" alt="Achaar app icon: a jar of colorful pickles" />
</p>

<h1 align="center">Achaar</h1>

<p align="center">Instagram Web, with an iPhone-native shell you can make your own.</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="#features">Features</a> ·
  <a href="docs/Architecture.md">Architecture</a> ·
  <a href="#contributing">Contributing</a>
</p>

Achaar wraps Instagram’s website in a persistent `WKWebView` and adds native navigation, Liquid Glass controls, settings, and local privacy tools. It focuses on browsing and messaging while keeping Instagram responsible for content and authentication.

Built with **Swift, UIKit, SwiftUI, and WebKit**. No third-party packages, backend, analytics SDKs, Instagram API integration, or Meta developer registration.

**Status: experimental.** Selected device workflows and automated checks have passed, but full Instagram parity and reliable crash-free scrolling are not established. See the [feature status and device checklist](docs/FeatureStatus.md) for evidence and outstanding checks. Achaar is an independent project, unaffiliated with Instagram or Meta.

> **Contributors welcome!** Achaar is a work in progress, and contributions are open. Help with iOS development, WebKit debugging, UI polish, accessibility, device testing, or documentation is welcome. You do not need to write code to contribute—clear bug reports and testing feedback help too. See [where help is needed](#where-help-is-needed) or [open an issue](https://github.com/solvePao/Achaar/issues) to discuss an idea.

## Features

| Area | What Achaar adds |
| --- | --- |
| Native navigation | Home, Reels, Messages, Search, and Profile, with safe-area-aware glass controls. |
| Web integration | Native shortcuts activate recognized Instagram controls, with routes or the original web interface as fallbacks. |
| Conversations | A full-width web conversation with native Back and reaction controls that open Instagram’s own emoji picker. |
| Faster return to Messages | Optional retention of the inbox page after its first visit, sharing the persistent WebKit session. |
| Reel sound | A native Mute/Unmute control with a saved preference; audio continuity still needs device testing. |
| Appearance | System, light, and dark modes, startup tab, and optional navigation haptics. |
| Local privacy | Optional Face ID/passcode lock, app-switcher obscuring, and external-link confirmation. |
| Cache controls | Clear cached files or the full local session; choose a cache cleanup budget from 64 MB to 1 GB. |
| Branded recovery | Launch, loading, and recovery screens, with foreground usage for the local day beginning at 3 AM. |

Instagram still renders feed cards, stories, Reels, message bubbles, and account screens. Availability varies by account, language, and website changes. Native controls do not make unavailable web features available.

## Get started

### Requirements

- A Mac with **Xcode 26 or newer**; current development and cloud builds use Xcode 27.
- An **iPhone running iOS 26+**, or an installed iOS 26+ simulator runtime.
- An Apple development team for installation on a physical device.
- An existing Instagram account and an internet connection.

### Build and install

```sh
git clone https://github.com/solvePao/Achaar.git
cd Achaar
open Achaar.xcodeproj
```

1. Select the **Achaar** scheme and app target.
2. In **Signing & Capabilities**, keep automatic signing enabled and select **your Apple development team**.
3. The project uses `com.solvepao.achaar`. If that identifier is unavailable to your team, replace it with your own unique bundle identifier.
4. Connect your iPhone, enable Developer Mode if prompted, and choose it as the run destination.
5. Press **Run** and follow Xcode’s signing and device-trust prompts.
6. Sign in through Instagram’s embedded website using its username/password and 2FA flow.

Personal Team provisioning expires periodically and may require rebuilding and reinstalling. An unsigned build cannot be installed on an iPhone. Instagram/Meta app registration is not required.

### Everyday use

Use the native tabs to browse. Long-press **Profile** to open shortcuts and **Achaar Settings**. Navigation hides in conversations, story viewers, and while the keyboard is visible to keep web controls accessible.

If an enhancement breaks a page, enable **Original web interface** in Settings. If the website stops loading, use **Retry** or open Instagram in Safari. Safari keeps a separate login session.

See the [usage and privacy guide](docs/Usage.md) for message reactions, cache behavior, app lock, permissions, and recovery details.

## Privacy and boundaries

Credentials are entered into Instagram’s own page. Login cookies and website storage remain in WebKit’s persistent data store; Achaar does not copy them into its own session database. Settings and usage counters stay locally on the device.

There is no Achaar backend or analytics. Instagram’s own data collection still applies. Optional conservative tracker blocking is **off by default** and can affect website features; it cannot stop Instagram’s own tracking.

The app uses public Apple APIs and recognized website controls. It does not call private Instagram endpoints or extract a parallel native feed or message database. JavaScript bridge messages are validated against the active Instagram main frame; private content and credentials are not transmitted through that bridge.

The cache budget is a **cleanup threshold**, not a hard limit on all WebKit storage or memory. Keeping Messages ready retains a page; it does not provide offline messaging or background delivery.

Reliable background Instagram notifications are not implemented. Calls, advanced creation, uploads, and specialized message features depend on Instagram Web and remain unverified where noted. A fatal app termination cannot be caught and continued; recovery is available on a subsequent launch. Manual scrolling stability remains an acceptance check.

## Project structure

```text
Achaar.xcodeproj/          Xcode project, shared schemes, Cloud manifest
Achaar/
  App/                    App lifecycle and preferences
  Features/Browser/       UIKit shell, native navigation and web presentation
  Features/Settings/      SwiftUI settings
  Core/Web/               Routing, WebKit lifecycle and script bridge
  Core/Privacy/           App lock, website data, tracking rules and usage
  Resources/Web/          Navigation JavaScript, cosmetic CSS and tracker rules
  Resources/              Icon assets, launch screen and privacy manifest
AchaarTests/              Routing, settings and WebKit privacy checks
AchaarUITests/            Device login, navigation and conversation checks
Scripts/                  Dependency-free web-adapter fixture checks
docs/                     Architecture, usage and validation notes
```

Start with [Architecture](docs/Architecture.md) to find where routing, styling, settings, caching, and browser behavior live. New source files must be added to the correct Xcode targets; additional web resources must be included in Copy Bundle Resources.

## Build and test

```sh
# Compile an unsigned iPhone build.
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Run shared logic and WebKit privacy tests on macOS.
xcodebuild -project Achaar.xcodeproj -scheme AchaarCoreTests \
  -destination 'platform=macOS' test

# Compile the iOS test bundle.
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing

# Verify the web adapter against synthetic DOM fixtures; requires Node.js.
node Scripts/verify-web.mjs
```

Use **Product → Test** with the Achaar scheme on a supported simulator/device for hosted iOS tests. The **AchaarLoginUITests** scheme also contains device checks for login, scrolling, tabs, and conversation controls. Tests requiring an authenticated session need a suitable test account; a successful build is not proof that those workflows work.

For conversation tests, set `ACHAAR_TEST_THREAD` in the test runner’s environment to a conversation display name in your test account. The test skips when unset. Never commit account credentials or private conversation names.

The latest recorded checks include **12 core tests and 59 web-adapter assertions**. Full evidence and remaining manual checks are in [Feature Status](docs/FeatureStatus.md).

## TestFlight workflow

The maintainer’s Xcode Cloud workflow starts when code reaches **`testflight`**. It archives and signs Achaar, uploads it to App Store Connect, and assigns successful builds to **Achaar Internal**. Build **1.0 (2)** completed this path on October 12, 2026.

Beta changes should be reviewed through a **pull request into `testflight`** before merging. The workflow is stored in Apple’s account and is not automatically available to forks. Configure your own repository connection and signing team if you want Cloud builds for a fork.

See [Xcode Cloud setup](docs/XcodeCloud.md) for build numbering, distribution, and diagnostics. There is currently no public TestFlight invitation link.

## Contributing

**We’re looking for contributors.** First-time contributors and experienced developers are both welcome. Achaar is still being worked on: some features are implemented but need broader testing, and Instagram’s changing website can break integrations. Small, focused improvements are especially helpful.

### Where help is needed

| Area | Useful contributions |
| --- | --- |
| Scrolling stability | Reproduce and investigate reported crashes during real finger scrolling; verify fixes on physical devices. |
| Messages and reactions | Test conversation layouts, keyboard clearance, reaction submission, and attachments using accounts you control. |
| Reels and audio | Verify sound across consecutive Reels, pause/play behavior, and speaker/headphone switching. |
| Responsive layout and accessibility | Improve safe areas, rotation, Dynamic Type, VoiceOver, and controls across iPhone sizes. |
| Web compatibility | Improve control recognition and fallbacks when Instagram changes its layout or uses a different language. |
| Privacy and recovery | Test app lock, cache/session clearing, denied permissions, network failures, and interrupted launches. |
| Documentation and onboarding | Clarify setup steps, document reproducible bugs, and keep feature status accurate. |

These are areas for contribution, not promises of completed or scheduled features. Check the [device acceptance checklist](docs/FeatureStatus.md) for specific gaps. Discuss larger changes in an issue before implementation so their scope fits the web-only architecture.

### Your first contribution

Try a documentation correction, a reproducible bug report, a device checklist entry, or a focused fix with validation. If you are unsure where to begin, open an issue describing your interests and the devices you can test on.

### Sending a pull request

1. Check [existing issues](https://github.com/solvePao/Achaar/issues) and the [feature checklist](docs/FeatureStatus.md).
2. Fork the repository and create a branch for your change. Open development PRs against **`main`**; `testflight` is the beta distribution branch.
3. Keep website-specific selectors and styling in the bundled web resources. Prefer public APIs, preserve the original-interface fallback, and avoid private endpoints or extra content storage.
4. Run checks relevant to your change. Include the result, device/iOS version, account language, and any untested behavior in your PR.

For UI bugs, include steps to reproduce, the affected tab, whether web enhancements are enabled, and a redacted screenshot if useful. For crashes, include a redacted crash report and the app/build version. Remove private messages, usernames where unnecessary, cookies, tokens, and authentication URLs before posting anything publicly.

For a security issue, avoid publishing credentials, exploit details, or private data in a public issue. Use GitHub’s private vulnerability reporting if it is enabled; otherwise arrange a private contact with the maintainer before sharing sensitive details.

## Documentation

- [Usage and privacy](docs/Usage.md)
- [Architecture and customization](docs/Architecture.md)
- [Feature status and device testing](docs/FeatureStatus.md)
- [Branding, daily usage, and Reel sound](docs/BrandingUsageSound.md)
- [Xcode Cloud and TestFlight](docs/XcodeCloud.md)

## License

This repository does not yet include a license. A license must be selected and added before the project can be presented as licensed open-source software. Instagram and Meta names belong to their respective owners.
