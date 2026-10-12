# Branding, daily usage and Reel sound

The approved border-free icon is installed in `Achaar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and reused by `BrandIcon.imageset` for launch/loading/recovery. It was edited using the built-in image generator, then resized to an opaque 1024 × 1024 icon asset.

Edit prompt: preserve the supplied pickle jar, cloth lid, rope bow, pickles, colors and photorealistic illustration; enlarge the jar to about 92% of image height while keeping it and the bow in frame; remove the ivory outer edge and pre-rounded tile boundary; extend the warm pale golden cream background to every square edge and corner; no border, frame or text. The user approved the displayed preview before these assets were replaced.

The system launch screen shows the icon and Achaar name. Once app code starts, a native branded screen also shows local foreground usage. The same screen hosts loading, clearing, lock and recovery states, retaining Retry/Safari/Unlock actions where appropriate. A terminated app cannot draw a screen during a fatal crash; the branded recovery UI appears when it opens again.

Usage starts with this update. A usage day runs from 3 AM to the next 3 AM in the phone's local calendar, rather than a rolling 24-hour window. Foreground intervals are checkpointed every five seconds and on deactivation; a fatal termination may lose the last unsaved interval. Background time and the gap before relaunch are excluded. Only a day boundary and elapsed seconds are stored in local preferences; no website content is tracked.

Reels has a native glass Mute/Unmute button. The chosen preference is saved locally. The adapter applies it to the largest visible Reel, mutes offscreen videos, and reapplies it when Instagram changes mute state or a new video appears. New visible Reels attempt playback; ordinary pause of the same Reel is preserved. WebKit is configured to permit audio autoplay. Actual audible playback, speaker/headphone behavior and long scrolling remain for the user's phone test.

Validation: signed generic iPhone build passed; 12 core tests passed, including 3 AM boundary, persistence, inactive-time and crash-gap exclusion; 59 synthetic web checks passed, including visible/offscreen audio selection and preference retention. No automated authenticated interactions were performed for this update. The app was installed on the connected iPhone without clearing its website session.

Signed build: `build/BrandSound/Products/Debug-iphoneos/Achaar.app`.
