# Architecture and customization

## Boundaries

`AchaarApp` and `AchaarSceneDelegate` own the UIKit application/window lifecycle. `BrowserViewController` embeds WebKit directly under a UIKit root; SwiftUI is confined to the Settings sheet. No SwiftUI hosting gesture recognizers sit above the browsing surface. A UIKit `UIStackView` of `UIButton`s inside Apple’s `UIGlassEffect` provides icon-only Home/Reels/Messages/Search/Profile destinations and VoiceOver labels. There is no app title bar. Long-pressing Profile opens an Apple context menu for consumption and messaging shortcuts; a More button is available in original-interface/recovery mode. Navigation hides for the keyboard, stories and message conversations. `PrivacyShield` covers the entire native window while inactive, including presented sheets. No remote service is added by Achaar.

`BrowserModel` owns the primary `WKWebView`, delegates, loading/history observations, popup lifetime, and pending presentation requests. The main view is retained across ordinary navigation and refresh. With Keep Messages ready enabled, a second view is created lazily on the first inbox visit and retained for subsequent switches. Both share the persistent website store and script controller; bridge messages are accepted only from the active view. Inactive views suspend media/capture and are released under memory pressure, when caching is disabled, and before data clearing. Full session clearing stops pages, removes website data, then replaces the primary view to discard its history/page cache. The web host changes identity only for that reset.

The previous SwiftUI browser and hit-test gesture-delay workarounds did not prevent the user's real finger-scrolling crash. The current implementation removes that hosting layer and the runtime hit-test mutations. Compatibility scrolling defaults on and disables WebKit link previews and swipe-back gestures; Back remains in More. Standard public scroll-view touch-delay flags remain configured. The recorded fatal exception originated in UIKit's gesture event queue on iOS 27.0.1. Synthetic swipe tests cannot establish that real finger scrolling is fixed.

WebKit content-process termination presents a Retry/Safari surface rather than silently reloading in a loop. UIKit fatal process aborts cannot safely be caught and continued. A local foreground lifecycle marker detects two consecutive interrupted launches and presents recovery before loading Instagram. This marker cannot distinguish a crash from an OS termination. A normal inactive transition resets it. Safari recovery opens Instagram separately and does not transfer Achaar's session cookies.

`BrowserPresentationHost` serializes native web dialogs, outbound-link confirmations, Safari presentation, and app notices above the currently presented sheet. Dialogs retain WebKit completion handlers until answered or cancelled. Closing a popup cancels its own pending dialogs; locking or clearing the session cancels all of them.

## Routing and web enhancements

`InstagramRouting` defines supported destinations, validates secure Instagram hosts, rejects unsafe external schemes/embedded credentials, unwraps Instagram’s outbound-link shim, and removes query/fragment data from shareable page URLs. Private messaging and authentication pages are not offered for sharing.

`Navigation.js` prefers existing same-origin controls in the verified navigation strip for native tab transitions; the native model uses HTTPS routes when those anchors are missing. Profile uses the verified strip’s account-avatar link; Activity uses existing anchors/accessibility labels, including the Notifications route. Home reselect dispatches through Instagram before falling back to native scrolling. Missing controls return failure so the native shell restores web navigation. Accessible-label fallbacks currently recognize English; other languages safely retain the original controls.

`Enhancements.css` makes small cosmetic changes. A web bottom navigation is hidden only after its geometry and Home, Explore/Reels, and Messages/Profile controls have been identified. Semantic navigation strips and fixed/sticky div-based mobile strips are supported; generic containers also require at least four distinct destinations. Headers, composers, and authentication controls are never hidden by generic guessed class names. Enhancements initialize at document start. The native shell keeps the website behind a loading surface until the script confirms that duplicate navigation has been removed. If verification fails, the shell displays the original web interface and removes its own bar, keeping one navigation bar visible. Disabling enhancements removes the hide class without reloading. The upgraded integration re-enables enhancements once; subsequent use of the Original web interface recovery switch is retained.

Before the first Instagram request, Achaar derives a Safari-compatible mobile user agent from the running WebKit view. It preserves WebKit's platform and engine tokens, adds Safari browser tokens using the current system version, and applies that identity to content pages, replacement views and their popups. Messages keeps its existing WebKit identity to preserve the inbox renderer. With message retention disabled, switching between Messages and content reloads the document with the appropriate identity. Instagram otherwise serves an embedded-browser post preview whose comment column is hidden at phone widths. The mobile identity lets Instagram render its own full Comments screen, composer and Back behavior without custom comment routes or private endpoints. Mobile bottom navigation has more nested wrappers than the desktop variant, so discovery searches up to sixteen ancestors while retaining the same geometry, route and fixed-position checks. Instagram can keep the Home URL while rendering Comments; a visible Comments heading and editor identify that screen so native feed actions and tabs do not overlap its Back control or composer. Closing Comments restores native navigation.

The script observer batches DOM inspection through animation frames. The history adapter preserves the original history functions and observes client-side route changes. Rapid native tab selections invalidate older asynchronous route fallbacks.

Instagram can render the New post menu inside its bottom navigation. The hide rule retains layout, and the adapter reveals menu links geometrically above the verified strip so native Create does not hide the website's next step. Reused links lose this exception when they return to the strip. The adapter preserves Instagram's original menu; the consumption-focused native menu omits Create and Edit Profile.

## Privacy

The bridge accepts only two-field tab-selection, navigation-readiness, or fixed `messageControls: changed` messages from the active web view’s HTTPS Instagram main frame. It forwards fixed tab/readiness enums, never page data, usernames, credentials, messages, cookies, or full URLs. Native code does not call Instagram’s undocumented endpoints or build a second content database.

Cookies and web storage stay inside `WKWebsiteDataStore`. Native preferences use the app’s `UserDefaults`; the privacy manifest declares this use. No logging of sensitive web data, third-party SDKs, push entitlements, or backend is present. Instagram’s website remains responsible for its own data collection.

Tracker blocking uses compiled `WKContentRuleList` rules and has an immediate disable path. A revision check prevents an earlier asynchronous compilation from re-enabling blocking after the setting was switched off. Keep this list narrow: blocking Instagram or its media/CDN domains can break login, feed, messaging, and uploads.

## Where to tweak

| Change | Starting point |
| --- | --- |
| Tab destinations and URL policy | `Core/Web/InstagramRouting.swift` |
| Toolbar, error state, native shell | `Features/Browser/BrowserScreen.swift` |
| Native tab component and modal handling | `Features/Browser/BrowserScreen.swift` |
| New preference and default | `App/AppSettings.swift`, then `Features/Settings/SettingsScreen.swift` |
| Website controls and cosmetic styling | `Resources/Web/Navigation.js`, `Resources/Web/Enhancements.css` |
| Optional tracker domains | `Resources/Web/TrackerRules.json` |
| Device lock and window obscuring | `Core/Privacy/AppLock.swift` |

Add new Swift files to the appropriate Xcode group and Achaar target. Shared privacy/routing files used by Mac tests also need AchaarCoreTests target membership. Put additional web resources in the app’s Copy Bundle Resources phase. No project-generation tool is required.

## Cache budget

`CacheBudget` reads metadata for regular files in the app’s public caches directory, skipping symbolic links and never reading messages or cached bodies. `BrowserModel.maintainCache` checks it on launch/background and from Settings; crossing the selected cleanup threshold removes WebKit disk, memory and fetch caches through public APIs without reloading an active form. The measured folder is not a total for all WebKit website storage. The setting is explicitly a cleanup budget rather than a hard storage quota. Persistent cookies, local storage and IndexedDB are excluded. Warm page retention has a separate toggle and at most two page slots. There is no `URLCache` setting falsely claiming to control WebKit, and no private WebKit paths or APIs.

## Consumption shortcuts

The native menu can open the inbox, blank New Message composer, Requests, Activity, Search, Saved, Archive and account settings through recognized existing controls. Visible-post shortcuts locate the nearest sufficiently visible post using semantic article markup or a combined Like/Comment/Save signature, then activate its exact labeled control. They do not call private endpoints or extract a parallel native feed. Synthetic checks cover action selection and rejection of offscreen/message/removal controls; live like/save/share mutations have intentionally not been tested. Instagram still renders feed cards, stories and message bubbles. Full native rendering and exhaustive API mapping are outside the web-only architecture.

## Phone layout adaptation

The inbox temporarily requests Instagram’s expanded responsive viewport so its own renderer includes thread names and previews, then fits the verified inbox column to the phone’s visible width. The original viewport is restored for dialogs or when enhancements are disabled. Positive desktop navigation signatures and measured 40–110-point gutters are removed only around recognized inbox/search content. Story and conversation routes send a fixed `immersive` readiness enum; retained page slots preserve that state.

The native Profile button can display a 26-point snapshot of the signed-in user’s already visible story/profile avatar. The adapter supplies only its validated on-screen rectangle; public WebKit snapshot APIs capture it. This image stays in memory, is cleared during session clearing/authentication, and is never downloaded, logged or persisted separately. Feed/thread contents remain in WebKit.

## Conversation adaptation

A visible message editor and its measured sibling inbox rail identify the conversation column. Scoped styling hides that rail, expands the conversation to the phone viewport, reserves room for a native glass Back button, and removes verified website navigation while native tabs are hidden. Original web mode disables these adjustments. The website retains message bubbles, media, composer and send behavior.

A native 44-point reaction button overlays a positively recognized, visible website reaction control. The adapter returns only normalized geometry; the message identifier, content and DOM reference stay inside WebKit. Tapping the native button invokes that exact website control and opens Instagram’s emoji picker without selecting anything. A stationary 450ms hold on a recognized message opens the same picker; movement, scrolling and cancellation abandon the hold. No UIKit gesture recognizer is added over WebKit. Calls or official-app-only tools are not fabricated when absent from the website.

The native shell supplies only its current WebKit viewport height after layout and keyboard changes. The identified composer is fitted to that area; paint containment is relaxed along its ancestor chain so Instagram’s small desktop wrapper cannot clip it. Movement offsets are bounded, and these styles apply only while conversation enhancements are active.
