# Feature status and device checklist

Verification uses no Instagram account credentials and does not publish posts or send messages. A successful compile is not evidence that a signed-in Instagram workflow works.

## Validation status

| Area | Status |
| --- | --- |
| Unsigned iPhone app build, bundle identifier and iOS minimum | Build verified with installed Xcode 27 |
| Shared routing, secure origin policy, bridge origin checks, external links, safe sharing, settings persistence | Automated tests passed on macOS |
| Actual WebKit tracker-rule compilation and disabling | Automated test passed on macOS |
| Actual WebKit cache-only removal preserves cookie; session removal deletes cookie | Automated test passed on macOS |
| Web navigation identification, restoration, missing-action fallback, fixed bridge payload and SPA link adapter | Synthetic web-adapter tests passed |
| Complete iOS test bundle | Compilation verified; hosted execution requires a supported simulator/device |
| iOS 26 native layout, rotation, accessibility, keyboard, app-switcher cover and Face ID | Implemented; device validation pending |
| Persistent authenticated login, logout, 2FA and challenges | Web workflow preserved; account/device validation pending |
| Feed, stories, search, Explore, profiles and Reels | Web workflow preserved; account/device validation pending |
| Likes, comments, saves, follows and account settings | Web workflow preserved; account/device validation pending |
| Direct messages and attachments | Web workflow preserved; account/device validation pending |
| Photo/video uploads and any web-provided publishing editor | Standard iOS WebKit picker support implemented; device validation pending |
| Web calls, Live, advanced creation, music/effects and specialized message types | Unverified; unavailable whenever Instagram does not expose them on web |
| Reliable background Instagram notifications | Not implemented under this web-only architecture |
| Transferring external-provider/Safari login into Achaar | Not implemented; use Instagram’s embedded username/password login |

The current Mac has iOS 18.6 simulator devices but no usable iOS 26+ runtime. Xcode did not permit running this project on those older devices. No iPhone installation or signed-in UI testing was performed.

## Phone acceptance checks

- [ ] Select your signing team, build, and launch on an iOS 26+ iPhone.
- [ ] Sign in through Instagram’s page; complete 2FA/challenges; confirm no credentials appear in native UI.
- [ ] Relaunch and verify the session persists. Log out through Instagram and verify the signed-out state.
- [ ] Open every native tab, switch rapidly, use Back, and return from a deep profile/post/message.
- [ ] Open Profile, Create, and Activity. When unavailable, confirm the original web controls return and still work.
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
