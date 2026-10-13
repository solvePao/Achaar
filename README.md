# Achaar

A personal iPhone wrapper for Instagram’s website, with a UIKit browsing screen, native settings and tabs, local privacy controls, and a persistent WebKit session.

- **Minimum iOS:** 26.0
- **Bundle identifier:** `com.solvepao.achaar`
- **App name:** Achaar
- **Dependencies:** Apple frameworks only; no packages, backend, analytics, or Meta developer registration.

Instagram renders the content and handles login, messages, interactions, and publishing. Achaar improves navigation and adds native controls; it does not reproduce features that Instagram withholds from its website. Actual signed-in feature availability still requires testing on your account.

## Open and install on your iPhone

1. Open **Achaar.xcodeproj** in Xcode 26 or newer. This repository was built with Xcode 27.
2. Choose the **Achaar** scheme and the **Achaar** app target.
3. Open **Signing & Capabilities**, keep **Automatically manage signing** enabled, and select your Apple development team. Use your own team if this checkout retains another local team selection.
4. Connect your iPhone running iOS 26 or later, enable Developer Mode if prompted, and select it as the run destination.
5. Press **Run**. Follow any signing/trust prompts shown by Xcode or your phone.
6. Sign into your existing Instagram account inside the website. Enter credentials only into Instagram’s login page; the native app does not collect them.

A free Apple Personal Team normally requires rebuilding and reinstalling after seven days. If Xcode reports that this bundle identifier is already owned by another team, it must be signed by the owning team or changed to an available identifier. No Instagram/Meta app registration or app review is involved.

If you use the Simulator, first install an iOS 26+ runtime in Xcode’s Settings. An unsigned build alone cannot be installed on a physical iPhone.

## Using Achaar

The native icon tabs open Home, Reels, Messages, Search, and Profile. The wrapper’s title/back toolbar is removed; Instagram’s content headers remain. Layout uses device safe areas rather than fixed phone dimensions. Where possible, Achaar clicks Instagram’s existing links to keep its own page navigation working; fixed web routes provide a fallback for the first four tabs. Profile and Activity use recognized web controls. If they cannot be found, Achaar restores the original web interface and explains how to continue there. Web labels can vary by language or account rollout.

Long-press the native Profile button to open the Apple context menu. It offers Activity, Search, visible-post shortcuts (Like/Unlike, Save/Unsave, Comments, Share), inbox shortcuts (Inbox, New message and Requests), profile shortcuts (Saved, Archive and Instagram settings), Back, refresh, sharing, recovery and Achaar Settings. Home also has native plus and Activity buttons mapped to the website. Edit Profile remains available through the original website. Shortcuts click recognized website controls; unavailable controls restore the original interface. Labels currently support English. Compatibility scrolling is enabled by default and disables swipe-back and link previews; use Back in More. The glass bottom bar hides for the keyboard, story viewers, and message conversations, keeping reply controls clear. A More button is available when the original web interface is active.

If WebKit stops, Retry and Safari recovery are available. After two consecutive interrupted launches, Achaar offers recovery before loading the website. An interrupted launch can also be caused by iOS terminating the app; it is not a crash diagnosis. A fatal iOS gesture exception cannot be safely caught within the process. The new UIKit browser removes the prior SwiftUI hosting layer, but real finger scrolling must be confirmed on the phone. Safari has a separate login session.

**Keep Messages ready** retains an inbox web view after its first visit, separate from the main browsing view. Returning to Messages preserves its website state and avoids rebuilding the loaded page. Both use WebKit’s persistent store and ordinary HTTP caching; there is no native message database, speculative inbox download or offline-delivery queue. Inactive media and capture are suspended. Memory pressure, disabling the option and local-session clearing release retained pages. A relaunch still depends on Instagram’s own cache policies and network.

Uploads use WebKit’s standard iOS file-input pickers, matching Safari’s behavior. Camera, microphone, and photo access are requested only when a web feature needs them. Web dialogs use native alerts, and Instagram popup windows share the same website data store. External links open in Safari or an appropriate installed app, with confirmation enabled by default.

Use Instagram’s username/password/2FA login. External sign-in providers open separately, and their Safari session is not transferred into Achaar. Achaar does not copy browser cookies or bypass authentication challenges.

## Customize and protect your session

Settings include appearance, startup tab, navigation haptics, reversible web enhancements, Keep Messages ready and a cached-files cleanup budget. Privacy controls include optional Face ID/device-passcode lock, app-switcher obscuring, external-link confirmation, and separate cache/session clearing.

App lock requires device authentication both to enable and disable it. It locks when the app enters the background; unlocking restores the session. For privacy, enabling app lock also obscures the app-switcher preview. Additional web windows close when the app locks. Media playback and active camera/microphone capture are paused while the app is inactive or locked; previously active capture is resumed only when the session is accessible again.

Tracker blocking is **off by default**. It blocks a small conservative list of third-party Google Analytics and DoubleClick requests. It does not prevent Instagram’s own tracking or remove ads. Changing protection reloads the website and may discard unsaved work. Disable it if something breaks.

**Cached files budget** offers 64 MB–1 GB, or cache cleanup on background. The app measures cache-folder file metadata and checks the budget at launch, background and on demand. Exceeding it removes disposable WebKit caches without reloading the current form. This is a cleanup threshold, not a hard maximum on WebKit’s total storage or memory: public WebKit APIs expose neither a total byte count nor a storage quota. Cookies, IndexedDB and local storage are excluded. **Clear cached files** preserves login cookies and web storage. **Clear local session & sign out** removes website data only from Achaar, clears browser history, and opens Instagram’s login page. Neither operation signs out your other devices; unsaved local drafts may be lost.

<<<<<<< Updated upstream
## Folder structure
=======
If an enhancement breaks a page, enable **Original web interface** in Settings. If the website stops loading, use **Retry** to reload it.

See the [usage and privacy guide](docs/Usage.md) for message reactions, cache behavior, app lock, permissions, and recovery details.

## Privacy and boundaries

Credentials are entered into Instagram’s own page. Login cookies and website storage remain in WebKit’s persistent data store; Achaar does not copy them into its own session database. Settings and usage counters stay locally on the device.

There is no Achaar backend or analytics. Instagram’s own data collection still applies. Optional conservative tracker blocking is **off by default** and can affect website features; it cannot stop Instagram’s own tracking.

The app uses public Apple APIs and recognized website controls. It does not call private Instagram endpoints or extract a parallel native feed or message database. JavaScript bridge messages are validated against the active Instagram main frame; private content and credentials are not transmitted through that bridge.

The cache budget is a **cleanup threshold**, not a hard limit on all WebKit storage or memory. Keeping Messages ready retains a page; it does not provide offline messaging or background delivery.

Reliable background Instagram notifications are not implemented. Calls, advanced creation, uploads, and specialized message features depend on Instagram Web and remain unverified where noted. A fatal app termination cannot be caught and continued; recovery is available on a subsequent launch. Manual scrolling stability remains an acceptance check.

## Project structure
>>>>>>> Stashed changes

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
AchaarUITests/           Login, signed-in scrolling and native navigation checks
Scripts/                 Dependency-free web-adapter checks
docs/                   Architecture and feature/device-validation notes
```

Start with [the architecture notes](docs/Architecture.md) for changes and [the feature checklist](docs/FeatureStatus.md) for what still needs phone testing. Keep website-specific selectors in the bundled scripts; never put Instagram credentials, page contents, or session cookies into native models or logs.

## Build and verify

Push beta changes to **`testflight`** to trigger the configured Xcode Cloud archive and TestFlight workflow. See [Xcode Cloud instructions](docs/XcodeCloud.md) for commands, tester setup and build diagnostics.

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

For the login crash regression, select **AchaarLoginUITests** and use **Product → Test** with a connected, unlocked iPhone. Set the UI test target's signing team to the same team as the app if prompted. This test requires a signed-out Instagram session in English, taps Log in, checks the password form, and focuses the username field. It does not enter credentials, clear your session, or submit the login form.

The same UI test scheme includes signed-in scrolling/tab, Activity and blank-composer mapping tests. Run only the signed-in methods when using an existing session. They scroll the feed, open destinations and a blank message composer, and do not send messages, choose files, or publish. Navigation now initializes before the website is shown; the upgraded integration enables enhancements once. Original-interface recovery replaces the native bottom bar rather than stacking two bars.

### Conversation controls

Opening an existing conversation hides the inbox rail and both bottom navigation bars. Use the native glass Back button to return to Messages. Tap the native smile button beside the visible message, or hold that message without moving, to open Instagram’s own reaction picker. Pick an emoji or use its “+” option for more choices. Availability follows Instagram Web; voice/video calls and official-app-only controls are not added when the website does not provide them. Original web interface in Settings restores the unmodified layout.

For the existing-conversation layout/reaction UI test, set `ACHAAR_TEST_THREAD` in the UI test runner environment to the display name of a conversation in your signed-in test account. The test skips when this value is absent; private conversation names are not hard-coded into the repository. It opens controls without sending messages or selecting reactions.
