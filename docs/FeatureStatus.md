# Feature status and device checklist

Verification uses no Instagram account credentials and does not publish posts or send messages. A successful compile is not evidence that a signed-in Instagram workflow works.

## Validation status

| Area | Status |
| --- | --- |
| Unsigned iPhone app build, bundle identifier and iOS minimum | Build verified with installed Xcode 27 |
| Shared routing, secure origin policy, bridge origin checks, external links, safe sharing, settings persistence | Automated tests passed on macOS |
| Actual WebKit tracker-rule compilation and disabling | Automated test passed on macOS |
| Actual WebKit cache-only removal preserves cookie; session removal deletes cookie | Automated test passed on macOS |
| Web navigation identification, restoration, missing-action fallback, fixed bridge payload and SPA link adapter | 52 synthetic web-adapter assertions passed, including div-based mobile navigation and restoration |
| Complete iOS test bundle | Compilation verified; hosted execution requires a supported simulator/device |
| Signed-out landing page → Log in → username field and keyboard | UI test passed on iPhone 16, iOS 27.0.1, English web interface, 2026-10-11; no credentials entered |
| Compact icon navigation, removed wrapper title bar, and iPhone 16 portrait safe areas | Device UI check passed on iOS 27.0.1; rotation, large text, VoiceOver, app lock and broader keyboard checks remain pending |
| Signed-in scrolling, Liquid Glass navigation, and five native tabs | Device test passed on iPhone 16 / iOS 27.0.1 using the existing session; manual finger scrolling still crashed on the previous build; that workaround also failed. The pure UIKit browser root passed automated swipes, slow drag, five tabs and warm inbox switching on 2026-10-11; manual finger scrolling still awaits confirmation |
| Historical Activity and Create mapping | Device UI test passed on the existing session, 2026-10-11: Activity opens Notifications; Create opens the usable Instagram Post menu with web navigation hidden. Media selection and publishing remain unverified. Create is now omitted from the native consumption menu |
| Retained Messages page and repeated native inbox/feed switching | Device UI test passed using the existing session; no offline message delivery or disk message database |
| Historical Edit Profile and New Message shortcuts | Device UI test passed, 2026-10-11: profile form and blank message composer open; no edits, recipients or sends. Edit Profile is now omitted from the native consumption menu |
| Requests, Saved, Archive and Instagram settings shortcuts | Implemented through recognized web controls; individual account/device validation pending; missing actions restore original controls |
| Cached-files cleanup budget, file measurement and preference persistence | 10 macOS tests passed including budget threshold, symlink exclusion and preference persistence; controls verified on phone. This is a soft cleanup budget, not a total WebKit storage quota |
| Pure UIKit browser root and keyboard-aware native navigation | Signed build verified; native Settings, blank New Message composer, keyboard hiding/restoration, five tabs and Profile selection passed on iPhone 16 / iOS 27.0.1, 2026-10-11 |
| Repeated interrupted-launch recovery | Isolated lifecycle test passed; two interrupted starts offer Retry/Safari. Device recovery check passed on iPhone 16 / iOS 27.0.1, 2026-10-11; Retry/Safari appear with website and inactive tabs hidden. Cannot catch fatal UIKit aborts |
| Current native Activity mapping | Device UI check passed, 2026-10-11, opens Notifications |
| Native visible-post Like/Save/Comments/Share shortcuts | Synthetic checks passed; live mutations intentionally untested, available via recognized web controls only |
| Fully native feed cards/message bubbles and exhaustive Instagram API mapping | Unavailable within the web-only constraint; Instagram renders these workflows |
| Persistent authenticated login, logout, 2FA and challenges | Web workflow preserved; account/device validation pending |
| Feed, stories, search, Explore, profiles and Reels | Web workflow preserved; account/device validation pending |
| Home-feed comments | Verified on iPhone 16 / iOS 27.0.1, 2026-10-15: mobile Comments screen, repeated open/Back, keyboard and unobscured composer. No comments typed or posted. Safari-compatible browser identity replaces the broken embedded-browser post preview. |
| Likes, saves, follows and account settings | Web workflow preserved; account/device validation pending |
| Story viewer reply/send controls and closing the viewer | Device UI test passed on iPhone 16, iOS 27.0.1, 2026-10-11; native tabs and More hide, then tabs return on close; nothing sent |
| Inbox and Search phone-width layout | Device captures confirm the desktop gutter is removed and Requests remains visible; search result workflows remain web-controlled |
| Reels phone-width media and author layout | Device capture verified; existing web interaction controls remain active; interaction mutations not tested |
| Profile selection after Reels and counter layout | Device check passed after fixing stale SPA route handling; no private endpoint or profile data bridge |
| Explore thumbnail loading | Several website thumbnails were still loading at capture time; complete loading/performance remains unverified |
| Conversation layout, native Back and reaction control | Verified on signed-in iPhone 16 / iOS 27.0.1, 2026-10-12: full-width conversation, hidden inbox rail and bottom tabs, native glass Back/React controls |
| Message reaction picker | Native tap and stationary message hold open Instagram’s six-emoji picker and its “+” control; device screenshots verified. No reaction was selected; submission remains untested |
| Conversation composer and attachments | Keyboard appearance/dismissal and return to inbox tested; sending messages/attachments remains untested |
| Photo/video uploads and any web-provided publishing editor | Standard iOS WebKit picker support implemented; device validation pending |
| Web calls, Live, advanced creation, music/effects and specialized message types | Unverified; unavailable whenever Instagram does not expose them on web |
| Reliable background Instagram notifications | Not implemented under this web-only architecture |
| Transferring external-provider/Safari login into Achaar | Not implemented; use Instagram’s embedded username/password login |

The current Mac has iOS 18.6 simulator devices but no usable iOS 26+ runtime. Xcode did not permit running this project on those older devices. The login navigation smoke test was run on a connected iPhone; the existing signed-in session was also used for navigation and scrolling checks. No messages were sent and no media was uploaded. Login persistence, logout, and 2FA still need separate acceptance checks.

Final diagnostic-free build installed on the connected iPhone on 2026-10-11. Reference captures, interrupted-launch recovery and signed-in synthetic scrolling/five-tab/warm-inbox navigation passed in `build/FinalNativePhoneUI.xcresult`. Story close and blank message composer/keyboard checks passed in the preceding device runs. This does not replace real-finger crash acceptance.

## Phone acceptance checks

- [ ] Select your signing team, build, and launch on an iOS 26+ iPhone.
- [ ] Sign in through Instagram’s page; complete 2FA/challenges; confirm no credentials appear in native UI.
- [ ] Relaunch and verify the session persists. Log out through Instagram and verify the signed-out state.
- [ ] Open every native tab, switch rapidly, use Back, and return from a deep profile/post/message.
- [ ] Open Profile, Activity, inbox and message shortcuts. When unavailable, confirm the original web controls return and still work.
- [ ] Turn enhancements off and on. Confirm composers, auth controls, menus, and dialogs remain usable.
- [ ] Browse feed/stories/Reels; search; view profiles; like/comment/save/follow using the website.
- [ ] Send a test DM and attachment to an account you control; verify keyboard layout, reply UI, and navigation.
- [ ] Choose upload media; cancel the picker; deny camera/microphone/photos permission; retry after enabling permission in iOS Settings.
- [ ] Validate a publishing flow using a draft or a test account; confirm the actual result before marking uploads verified.
- [ ] Confirm inline/full-screen video, audio after user interaction, and suspension when backgrounded/locked.
- [ ] Exercise an Instagram popup and native web alert/confirm/prompt; cancel/close and verify no stuck interaction.
- [ ] Open an external link from the main page and a popup. Confirm it opens separately, and cancellation leaves Instagram usable.
- [ ] Disconnect the network, refresh, and verify Retry. Reconnect and recover without creating another persistent primary view.
- [ ] Enable app lock, authenticate, background, return and unlock. Cancel authentication and verify content stays protected.
- [ ] Background while Settings or a popup is open; verify the app-switcher preview contains only the privacy cover.
- [ ] Toggle optional blocking in both directions. Verify login, media and messages still work; disable if necessary.
- [ ] Clear cache and confirm login persists. Clear the local session and verify login, cookies, history and old page access are removed.
- [ ] Check VoiceOver labels, large text, light/dark appearance, portrait/landscape, keyboard dismissal, and device safe areas.

Record the iOS version, account language, verification date, and observed web feature availability when marking a row verified. Never attach passwords, session cookies, private messages, or token-bearing URLs to reports.

Conversation follow-up, 2026-10-12: the diagnostic-free signed-in device check passed in `build/FinalConversationPhone.xcresult`. Native reaction tap, stationary hold, Back to inbox, empty composer focus, keyboard clearance and keyboard dismissal passed; final screenshots confirm a full-width composer without clipping. Generic unsigned compilation, 10 core tests and 52 web-adapter assertions passed. Actual reaction submission, sending attachments, phone/video calls and the earlier manual scrolling-crash acceptance remain unverified.

Branding/audio follow-up: approved full-bleed icon, static branded launch and runtime loading/recovery screens installed. Foreground usage resets at local 3 AM and starts tracking with this version; 12 core tests and 59 synthetic web checks passed. Native Reel mute preference and visible-video enforcement compiled and installed; actual audio continuity awaits the user's manual test. See `BrandingUsageSound.md` for boundaries and build location.
