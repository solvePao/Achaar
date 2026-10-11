# Architecture and customization

## Boundaries

`AchaarApp` owns one settings model, browser model, and lock controller. SwiftUI provides the shell and Settings; `NativeTabBar` wraps a real `UITabBar`. `PrivacyShield` covers the entire native window while inactive, including presented sheets. No remote service is added by Achaar.

`BrowserModel` owns the primary `WKWebView`, delegates, loading/history observations, popup lifetime, and pending presentation requests. The view is retained across ordinary navigation and refresh. Full session clearing stops pages, removes website data, then replaces the primary view to discard its history/page cache. The web host changes identity only for that reset.

`BrowserPresentationHost` serializes native web dialogs, outbound-link confirmations, Safari presentation, and app notices above the currently presented sheet. Dialogs retain WebKit completion handlers until answered or cancelled. Closing a popup cancels its own pending dialogs; locking or clearing the session cancels all of them.

## Routing and web enhancements

`InstagramRouting` defines supported destinations, validates secure Instagram hosts, rejects unsafe external schemes/embedded credentials, unwraps Instagram’s outbound-link shim, and removes query/fragment data from shareable page URLs. Private messaging and authentication pages are not offered for sharing.

`Navigation.js` clicks existing same-origin anchors for native tab transitions; the native model uses HTTPS routes when those anchors are missing. Profile, Create, and Activity use existing anchors/accessibility labels. Missing controls return failure so the native shell restores web navigation. Accessible-label fallbacks currently recognize English; other languages safely retain the original controls.

`Enhancements.css` makes small cosmetic changes. A web bottom navigation is hidden only after it has been identified by its position and Home/Explore/Messages routes. Headers, composers, and authentication controls are never hidden by generic guessed class names. Disabling enhancements removes the hide class without reloading.

The script observer batches DOM inspection through animation frames. The history adapter preserves the original history functions and observes client-side route changes. Rapid native tab selections invalidate older asynchronous route fallbacks.

## Privacy

The bridge accepts only a two-field tab-selection message from the primary web view’s HTTPS Instagram main frame. It forwards a fixed enum, never page data, usernames, credentials, messages, cookies, or full URLs. Native code does not call Instagram’s undocumented endpoints or build a second content database.

Cookies and web storage stay inside `WKWebsiteDataStore`. Native preferences use the app’s `UserDefaults`; the privacy manifest declares this use. No logging of sensitive web data, third-party SDKs, push entitlements, or backend is present. Instagram’s website remains responsible for its own data collection.

Tracker blocking uses compiled `WKContentRuleList` rules and has an immediate disable path. A revision check prevents an earlier asynchronous compilation from re-enabling blocking after the setting was switched off. Keep this list narrow: blocking Instagram or its media/CDN domains can break login, feed, messaging, and uploads.

## Where to tweak

| Change | Starting point |
| --- | --- |
| Tab destinations and URL policy | `Core/Web/InstagramRouting.swift` |
| Toolbar, error state, native shell | `Features/Browser/BrowserScreen.swift` |
| Native tab component and modal handling | `Features/Browser/WebViewHost.swift` |
| New preference and default | `App/AppSettings.swift`, then `Features/Settings/SettingsScreen.swift` |
| Website controls and cosmetic styling | `Resources/Web/Navigation.js`, `Resources/Web/Enhancements.css` |
| Optional tracker domains | `Resources/Web/TrackerRules.json` |
| Device lock and window obscuring | `Core/Privacy/AppLock.swift` |

Add new Swift files to the appropriate Xcode group and Achaar target. Shared privacy/routing files used by Mac tests also need AchaarCoreTests target membership. Put additional web resources in the app’s Copy Bundle Resources phase. No project-generation tool is required.
