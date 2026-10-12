# Achaar phone UI verification

final result: blocked

The four reported overlap/layout defects are visually resolved and installed in the device test build. Exact official-app visual parity and complete media loading remain unverified under the Instagram Web architecture.

## Evidence

Device: iPhone 16, iOS 27.0.1, portrait 393 × 852 points, dark appearance, existing signed-in session, 2026-10-11. The supplied images and actual device screenshots were resized to this viewport and combined in the same image for comparison. Website content changed between captures; names, timestamps, story frames and posts were not fabricated to match the reference.

Comparison files (source left, revised app right):

- `/tmp/achaar-fix-compare-story.png`
- `/tmp/achaar-fix-compare-messages.png`
- `/tmp/achaar-fix-compare-explore.png`
- `/tmp/achaar-fix-compare-reels.png`
- `/tmp/achaar-original-compare-profile.png`
- `/tmp/achaar-original-compare-home.png`
- `/tmp/achaar-original-compare-messages.png`

Device evidence: `build/ProfileRoutePhoneLayout.xcresult`; final diagnostic-free installation and navigation/recovery checks: `build/FinalNativePhoneUI.xcresult`. Unsigned generic device build passed; 10 macOS core tests and 48 web-adapter assertions passed. Temporary layout diagnostics were removed after the comparisons; they exposed only sanitized geometry and fixed layout metadata.

## Iterations and findings

1. P1: Native navigation covered the story reply field. The native shell now honors a validated fixed immersive-mode message for stories/conversations. Revised story capture shows reply, heart and send controls completely unobstructed; device test verifies closing the story restores tabs.
2. P1: Inbox retained a 72-point desktop gutter and clipped Requests. Positively identified desktop rail wrappers and measured gutters are removed. Revised capture shows full-width rows, Search and Requests. Original web mode restores the responsive viewport and styling.
3. P2: Explore Search retained an approximately 86-point horizontal offset. Correction now includes its short header ancestor. Revised capture shows the search field aligned to 8-point side margins.
4. P1: Reels had a narrow desktop card and wrapped author names. Verified single-video/control-rail layouts now fit the phone width, preserve video aspect ratio and overlay their existing action rail. Revised capture shows a single visible full-width reel and a one-line author.
5. P1: Profile displayed while Reels remained selected, so profile counters did not receive mobile styling. A positively verified own-profile header now resolves stale Instagram SPA routes. Revised capture confirms Profile selection and unwrapped counters.
6. Duplicate website navigation descendants are hidden; Apple UIKit buttons and a UIGlassEffect pill provide the only navigation on verified pages. Native Home actions use recognized live website controls.

## Remaining limits

- P2 / media readiness: Several Explore thumbnails had not loaded in captured website frames. Full grid loading and network/cache performance need additional real-use verification. Achaar does not synthesize missing media or maintain a second feed.
- The website supplies different profile actions, typography and feature availability from the official app. Full visual parity is not verified: music, Share Profile and other official-app-only controls are not invented.
- Automated gestures and navigation do not establish that the previously reported real-finger UIKit scrolling crash is resolved. Manual scrolling remains an acceptance check.
- Large text, VoiceOver, landscape and all authenticated mutations remain pending broader device validation.

No messages were sent, posts uploaded, likes changed or profile details edited during these tests.

## Conversation reference follow-up, 2026-10-12

Scope: the supplied broken Achaar conversation versus the official Instagram conversation, normalized to 393 × 852 points. The existing signed-in phone session was used; no credentials were entered or session data cleared.

- P1: The avatar inbox rail squeezed the chat to approximately 290 points. A visible editor and measured sibling rail now identify the full-width conversation, with the rail and duplicate navigation hidden.
- P1: Native tabs overlapped the conversation/composer. Both native tabs and verified website navigation stay hidden until returning to the inbox. A 44-point Apple glass Back button provides that return.
- P1: Reactions were difficult to discover on touch. A native glass reaction button and stationary message hold open the website’s real emoji picker, including its extra-emoji control. No reaction is selected automatically.
- P1: The desktop composer wrapper used paint containment and retained bottom navigation space. Its verified ancestor chain now permits the composer to fit the native visible area without clipping; keyboard resizing uses the actual WebKit bounds.

Instagram still renders bubbles, message media, conversation information and the input controls. The official app’s phone/video tools and other unavailable web capabilities are not fabricated. This addresses the reported layout and reaction-access defects, not full official-app parity or the earlier manual scrolling-crash acceptance check.

Conversation defect scope: passed. Final source-left/app-right comparison: `/tmp/achaar-conversation-final-comparison.png`. Actual chat, hold-picker and keyboard captures: `/tmp/achaar-conversation-final-chat.png`, `/tmp/achaar-conversation-final-hold.png`, `/tmp/achaar-conversation-final-keyboard.png`. The full field and its trailing controls are visible inside the rounded composer in both keyboard states.

Final diagnostic-free device test: `build/FinalConversationPhone.xcresult`, passed. It opens the existing conversation, checks hidden native tabs, opens the reaction picker by native tap and by hold, returns to inbox, focuses the empty composer, checks keyboard clearance, and dismisses the keyboard through Back. The preceding story regression passed in `build/ConversationViewportFinal.xcresult` (that earlier bundle’s composer test failed before the clipping fix). Final unsigned generic device build passed; 10 core tests and 52 web-adapter assertions passed. Temporary geometry diagnostics were removed. No messages or reactions were sent.
