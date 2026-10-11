# Achaar

A personal iPhone wrapper for Instagram’s website, with SwiftUI toolbars and settings, native tabs, local privacy controls, and a persistent WebKit session.

- **Minimum iOS:** 26.0
- **Bundle identifier:** `com.solvepao.achaar`
- **App name:** Achaar
- **Dependencies:** Apple frameworks only; no packages, backend, analytics, or Meta developer registration.

Instagram renders the content and handles login, messages, interactions, and publishing. Achaar improves navigation and adds native controls; it does not reproduce features that Instagram withholds from its website. Actual signed-in feature availability still requires testing on your account.

## Open and install on your iPhone

1. Open **Achaar.xcodeproj** in Xcode 26 or newer. This repository was built with Xcode 27.
2. Choose the **Achaar** scheme and the **Achaar** app target.
3. Open **Signing & Capabilities**, keep **Automatically manage signing** enabled, and select your Apple development team. No team is hardcoded in this project.
4. Connect your iPhone running iOS 26 or later, enable Developer Mode if prompted, and select it as the run destination.
5. Press **Run**. Follow any signing/trust prompts shown by Xcode or your phone.
6. Sign into your existing Instagram account inside the website. Enter credentials only into Instagram’s login page; the native app does not collect them.

A free Apple Personal Team normally requires rebuilding and reinstalling after seven days. If Xcode reports that this bundle identifier is already owned by another team, it must be signed by the owning team or changed to an available identifier. No Instagram/Meta app registration or app review is involved.

If you use the Simulator, first install an iOS 26+ runtime in Xcode’s Settings. An unsigned build alone cannot be installed on a physical iPhone.

## Using Achaar

The native tabs open Home, Explore, Reels, Messages, and Profile. Where possible, Achaar clicks Instagram’s existing links to keep its own page navigation working; fixed web routes provide a fallback for the first four tabs. Profile, Create, and Activity use recognized web controls. If they cannot be found, Achaar restores the original web interface and explains how to continue there. Web labels can vary by language or account rollout.

The **More** menu offers refresh, sharing for eligible pages, the original web interface, and Settings. Back gestures and the native Back button use WebKit history. There is one primary web view during normal use; tabs do not maintain independent browsing histories. A full local-session wipe replaces that view to discard its history and in-memory pages.

Uploads use WebKit’s standard iOS file-input pickers, matching Safari’s behavior. Camera, microphone, and photo access are requested only when a web feature needs them. Web dialogs use native alerts, and Instagram popup windows share the same website data store. External links open in Safari or an appropriate installed app, with confirmation enabled by default.

Use Instagram’s username/password/2FA login. External sign-in providers open separately, and their Safari session is not transferred into Achaar. Achaar does not copy browser cookies or bypass authentication challenges.

## Customize and protect your session

Settings include appearance, startup tab, navigation haptics, and reversible web enhancements. Privacy controls include optional Face ID/device-passcode lock, app-switcher obscuring, external-link confirmation, and separate cache/session clearing.

App lock requires device authentication both to enable and disable it. It locks when the app enters the background; unlocking restores the session. For privacy, enabling app lock also obscures the app-switcher preview. Additional web windows close when the app locks. Media playback and active camera/microphone capture are paused while the app is inactive or locked; previously active capture is resumed only when the session is accessible again.

Tracker blocking is **off by default**. It blocks a small conservative list of third-party Google Analytics and DoubleClick requests. It does not prevent Instagram’s own tracking or remove ads. Changing protection reloads the website and may discard unsaved work. Disable it if something breaks.

**Clear cached files** preserves login cookies and web storage. **Clear local session & sign out** removes website data only from Achaar, clears browser history, and opens Instagram’s login page. Neither operation signs out your other devices; unsaved local drafts may be lost.

## Folder structure

```text
Achaar.xcodeproj/         Ready-to-open project and shared schemes
Achaar/
  App/                   App lifecycle and persisted preferences
  Features/Browser/      Native shell, persistent web host, presentation handling
  Features/Settings/     Native settings and data-clearing controls
  Core/Web/              WebKit lifecycle, origin policy, routes and script bridge
  Core/Privacy/          App lock, snapshot cover, tracker rules and data removal
  Resources/Web/         Editable navigation JavaScript, cosmetic CSS, tracker JSON
  Resources/             App icon, accent color, permissions and privacy manifest
AchaarTests/             Routing, security, settings and WebKit privacy tests
Scripts/                 Dependency-free web-adapter checks
docs/                   Architecture and feature/device-validation notes
```

Start with [the architecture notes](docs/Architecture.md) for changes and [the feature checklist](docs/FeatureStatus.md) for what still needs phone testing. Keep website-specific selectors in the bundled scripts; never put Instagram credentials, page contents, or session cookies into native models or logs.

## Build and verify

```sh
# Compile an unsigned iPhone build.
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Execute shared routing/settings/WebKit privacy tests on the Mac.
xcodebuild -project Achaar.xcodeproj -scheme AchaarCoreTests \
  -destination 'platform=macOS' test

# Compile the complete iOS test bundle without an installed simulator runtime.
xcodebuild -project Achaar.xcodeproj -scheme Achaar \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing

# Check the real web adapter using synthetic DOM fixtures; requires Node.
node Scripts/verify-web.mjs
```

In Xcode, select **Achaar** and use **Product → Test** on an iOS 26+ simulator/device to execute the hosted iOS tests, including primary-view replacement during a session wipe. The **AchaarCoreTests** scheme runs shared logic and real WebKit cookie/rule-list checks on macOS; it does not render the iPhone UI or authenticate to Instagram.
