// Dependency-free fixtures for the real bundled navigation adapter.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../Achaar/Resources/Web/Navigation.js', import.meta.url), 'utf8');
function fixture({ paths = ['/', '/explore/', '/direct/inbox/'], path = '/', top = 720, label = 'Profile', semantic = true, position = 'fixed', width = 390, avatarProfile = false, videos = [] } = {}) {
    const events = [];
    let observer;
    let clicked = 0;
    const classes = new Set();
    const link = (route, aria = '') => ({
        href: new URL(route, 'https://www.instagram.com').href,
        getClientRects: () => classes.has('achaar-verified-bottom-navigation') ? [] : [{}],
        getAttribute: name => name === 'aria-label' ? aria : null,
        querySelector: () => null,
        click: () => clicked++
    });
    const links = paths.map(p => link(p));
    const profile = link('/fixture_username/', label);
    if (avatarProfile) profile.querySelector = selector => selector === 'img' ? {} : null;
    const navLinks = avatarProfile ? [...links, profile] : links;
    const nav = {
        isConnected: true,
        classList: { add: c => classes.add(c), remove: c => classes.delete(c), contains: c => classes.has(c) },
        getClientRects: () => classes.has('achaar-verified-bottom-navigation') ? [] : [{}],
        getBoundingClientRect: () => ({ top, bottom: top + 60, height: 60, width }),
        matches: () => semantic,
        querySelectorAll: () => navLinks,
        contains: n => n === profile || links.includes(n)
    };
    links.forEach(link => { link.parentElement = nav; });
    const location = { origin: 'https://www.instagram.com', pathname: path };
    const document = {
        documentElement: { dataset: {} },
        querySelectorAll: selector => {
            if (selector === "video") return videos;
            if (selector.includes('contenteditable')) return [];
            if (selector === '.achaar-verified-bottom-navigation') return classes.size ? [nav] : [];
            if (selector === "nav, [role='navigation']") return semantic ? [nav] : [];
            return [...links, profile];
        }
    };
    const window = { webkit: { messageHandlers: { achaar: { postMessage: data => events.push(data) } } } };
    window.top = window;
    vm.runInNewContext(source, {
        window, document, location, innerHeight: 800, innerWidth: 390, URL, getComputedStyle: () => ({ position }),
        history: { pushState() {}, replaceState() {} },
        MutationObserver: class { constructor(fn) { observer = fn; } observe() {} },
        addEventListener() {}, requestAnimationFrame: fn => fn()
    });
    return { window, document, nav, links, classes, events, location, mutate: records => observer(records), clicks: () => clicked };
}

const valid = fixture();
valid.window.AchaarWeb.setEnhanced(true);
assert(valid.classes.has('achaar-verified-bottom-navigation'), 'Recognized bottom nav is hidden');
assert(valid.window.AchaarWeb.action('profile'), 'Hidden verified nav remains actionable');
assert.equal(valid.clicks(), 1);
valid.window.AchaarWeb.setEnhanced(false);
assert.equal(valid.classes.size, 0, 'Original interface is restored');
assert.equal(valid.window.AchaarWeb.action('unknown'), false);
assert.equal(valid.window.AchaarWeb.action('create'), false, 'Missing actions return failure for native fallback');

const incomplete = fixture({ paths: ['/', '/explore/'] });
incomplete.window.AchaarWeb.setEnhanced(true);
assert.equal(incomplete.classes.size, 0, 'Partial navigation is never hidden');
const header = fixture({ top: 0 });
header.window.AchaarWeb.setEnhanced(true);
assert.equal(header.classes.size, 0, 'Top navigation is never hidden');
const auth = fixture({ path: '/accounts/login/' });
auth.window.AchaarWeb.setEnhanced(true);
assert.equal(auth.classes.size, 0, 'Authentication controls remain intact');
const unrecognized = fixture({ label: 'Unrecognized profile control' });
assert.equal(unrecognized.window.AchaarWeb.action('profile'), false, 'Unknown labels safely fall back');
valid.location.pathname = '/direct/t/fixture/';
valid.mutate();
assert.deepEqual(JSON.parse(JSON.stringify(valid.events.at(-1))), { type: 'tab', value: 'messages' });
assert(valid.events.every(event => Object.keys(event).sort().join(',') === 'type,value'), 'Bridge sends no page content or URLs');
assert(valid.window.AchaarWeb.navigate('explore'), 'Known anchors enable SPA navigation');
assert.equal(valid.window.AchaarWeb.navigate('reels'), false, 'Missing anchors permit a direct-route fallback');
assert.equal(valid.window.AchaarWeb.navigate('arbitrary'), false, 'Only explicit native destinations are accepted');
const mobileDiv = fixture({ semantic: false, paths: ['/', '/explore/', '/reels/', '/direct/inbox/'] });
mobileDiv.window.AchaarWeb.setEnhanced(true);
assert(mobileDiv.classes.has('achaar-verified-bottom-navigation'), 'Fixed div-based mobile navigation is hidden');
assert(mobileDiv.window.AchaarWeb.navigate('reels'), 'Hidden mobile links still navigate');
mobileDiv.window.AchaarWeb.setEnhanced(false);
assert.equal(mobileDiv.classes.size, 0, 'Div-based bar restores immediately');
const menuBar = fixture();
menuBar.window.AchaarWeb.setEnhanced(true);
const popoverClasses = new Set();
const popover = menuBar.links[0];
popover.textContent = "Post";
popover.classList = { toggle: (name, enabled) => enabled ? popoverClasses.add(name) : popoverClasses.delete(name) };
popover.getBoundingClientRect = () => ({ top: 620, bottom: 664, height: 44 });
menuBar.mutate();
assert(popoverClasses.has('achaar-navigation-popover'), 'Menus above hidden navigation stay visible');
popover.getBoundingClientRect = () => ({ top: 720, bottom: 744, height: 24 });
menuBar.mutate();
assert.equal(popoverClasses.size, 0, 'Reused controls in the strip return to hidden state');
const content = fixture({ semantic: false, position: 'static', paths: ['/', '/explore/', '/reels/', '/direct/inbox/'] });
content.window.AchaarWeb.setEnhanced(true);
assert.equal(content.classes.size, 0, 'Content link clusters are never hidden');
const sidebar = fixture({ width: 80 });
sidebar.window.AchaarWeb.setEnhanced(true);
assert.equal(sidebar.classes.size, 0, 'Narrow navigation is never hidden');
const reelsBar = fixture({ paths: ['/', '/reels/', '/direct/inbox/'] });
reelsBar.window.AchaarWeb.setEnhanced(true);
assert(reelsBar.classes.has('achaar-verified-bottom-navigation'), 'Reels-based semantic bar is recognized');
reelsBar.nav.querySelectorAll = () => [];
reelsBar.mutate();
assert.equal(reelsBar.classes.size, 0, 'Changed controls restore the web interface');
const avatarBar = fixture({ semantic: false, paths: ['/', '/explore/', '/reels/', '/direct/'], label: '', avatarProfile: true });
avatarBar.window.AchaarWeb.setEnhanced(true);
assert(avatarBar.window.AchaarWeb.action('profile'), 'Verified avatar navigation maps to Profile without copying account data');
avatarBar.location.pathname = '/fixture_username/';
avatarBar.mutate();
assert(avatarBar.events.some(event => event.type === 'tab' && event.value === 'profile'), 'Web profile navigation updates the native selection');
assert(avatarBar.window.AchaarWeb.navigate('messages'), 'Direct-root link maps to Messages');
assert(avatarBar.events.some(event => event.type === 'navigation' && event.value === 'native'), 'Native readiness follows verified navigation');
avatarBar.window.AchaarWeb.setEnhanced(false);
assert.deepEqual(JSON.parse(JSON.stringify(avatarBar.events.at(-1))), { type: 'navigation', value: 'original' }, 'Recovery removes duplicate native navigation');
const shortcuts = fixture();
let editClicks = 0;
const editButton = {
    textContent: 'Edit Profile', getAttribute: () => null, querySelector: () => null,
    getClientRects: () => [{}], click: () => editClicks++
};
const shortcutQuery = shortcuts.document.querySelectorAll;
shortcuts.document.querySelectorAll = selector => selector === "a, button, [role='button']"
    ? [editButton] : shortcutQuery(selector);
assert(shortcuts.window.AchaarWeb.action('editProfile'), 'Profile shortcuts recognize exact visible text labels');
assert.equal(editClicks, 1);
editButton.textContent = 'Edit profile and delete account';
assert.equal(shortcuts.window.AchaarWeb.action('editProfile'), false, 'Similar destructive labels are never guessed');
assert.equal(shortcuts.window.AchaarWeb.prepareAction('delete'), false, 'Only safe profile navigation can be prepared');
// Test native post shortcuts only against synthetic controls, never a live post.
const posts = fixture();
let postClicks = [];
const buttons = ['Like', 'Comment', 'Save', 'Share post'].map(label => ({
    getAttribute: name => name === 'aria-label' ? label : null,
    querySelector: () => null, getClientRects: () => [{}],
    click: () => postClicks.push(label)
}));
const article = {
    querySelectorAll: () => buttons,
    getBoundingClientRect: () => ({ top: 200, bottom: 600, height: 400, width: 390 })
};
posts.document.querySelectorAll = selector => selector === "article, [role='article']" ? [article]
    : selector === "button, [role='button'], a" ? buttons : [];
for (const action of ['like', 'save', 'comments', 'sharePost']) {
    assert(posts.window.AchaarWeb.action(action), `Recognized visible-post ${action} maps`);
}
assert.deepEqual(postClicks, ['Like', 'Save', 'Comment', 'Share post']);
posts.location.pathname = '/direct/t/fixture/';
assert.equal(posts.window.AchaarWeb.action('like'), false, 'Post actions never target message controls');
posts.location.pathname = '/';
article.getBoundingClientRect = () => ({ top: 1000, bottom: 1400, height: 400, width: 390 });
assert.equal(posts.window.AchaarWeb.action('like'), false, 'Offscreen posts are not selected');
article.getBoundingClientRect = () => ({ top: 200, bottom: 600, height: 400, width: 390 });
buttons[2].getAttribute = name => name === 'aria-label' ? 'Remove' : null;
assert.equal(posts.window.AchaarWeb.action('save'), false, 'Generic removal controls are never used for Save');


const story = fixture({path: '/stories/fixture_account/123/'});
story.window.AchaarWeb.setEnhanced(true);
assert.equal(story.events.at(-1).value, 'immersive', 'Story viewer hides native chrome without hiding story actions');
story.location.pathname = '/'; story.mutate();
assert.equal(story.events.at(-1).value, 'native', 'Closing a story restores native navigation');
const conversation = fixture({path: '/direct/t/123/'});
conversation.window.AchaarWeb.setEnhanced(true);
assert.equal(conversation.events.at(-1).value, 'immersive', 'Conversation composer has no overlapping native tabs');
conversation.window.AchaarWeb.setEnhanced(false);
assert.equal(conversation.events.at(-1).value, 'original', 'Original interface remains available in conversations');
const staleProfile = fixture({path: '/reels/', avatarProfile: true});
staleProfile.window.AchaarWeb.setEnhanced(true);
assert(staleProfile.window.AchaarWeb.action('profile'));
const previousQuery = staleProfile.document.querySelectorAll;
staleProfile.document.querySelectorAll = selector => selector === 'header' ? [{
    textContent: 'fixture_username 48 posts 238 followers 342 following',
    querySelectorAll: () => [{ textContent: 'fixture_username' }]
}] : previousQuery(selector);
staleProfile.mutate();
assert.equal(staleProfile.events.filter(e => e.type === 'tab').at(-1).value, 'profile', 'Verified own profile header wins over a stale SPA route');
staleProfile.document.querySelectorAll = previousQuery;
staleProfile.location.pathname = '/'; staleProfile.mutate();
assert.equal(staleProfile.events.filter(e => e.type === 'tab').at(-1).value, 'home', 'Leaving the profile returns selection to the actual page');
const replacedClasses = fixture();
replacedClasses.window.AchaarWeb.setEnhanced(true);
replacedClasses.classes.delete('achaar-verified-bottom-navigation');
replacedClasses.mutate([{type:'attributes', attributeName:'class', oldValue:'achaar-verified-bottom-navigation', target:replacedClasses.nav}]);
assert(replacedClasses.classes.has('achaar-verified-bottom-navigation'), 'A website class replacement cannot reveal duplicate navigation');
let inspected = false;
const previousNavigationQuery = replacedClasses.nav.querySelectorAll;
replacedClasses.nav.querySelectorAll = (...args) => { inspected = true; return previousNavigationQuery(...args); };
replacedClasses.mutate([{type:'attributes', attributeName:'class', oldValue:'achaar-verified-bottom-navigation', target:replacedClasses.nav}]);
assert.equal(inspected, false, 'Adapter class additions do not cause an inspection feedback loop');
assert.equal(valid.window.AchaarWeb.reactionControlRect(), null, 'No reaction geometry outside a verified conversation');
assert.equal(valid.window.AchaarWeb.openVisibleReaction(), false, 'No reaction activation outside a verified conversation');
const firstVideo = { muted: true, volume: 0, paused: true, parentElement: null, getBoundingClientRect: () => ({top:0,bottom:700,left:0,right:390}), play() {this.paused=false;return Promise.resolve();} };
const secondVideo = { ...firstVideo, getBoundingClientRect: () => ({top:900,bottom:1600,left:0,right:390}) };
const sound = fixture({path:'/reels/', videos:[firstVideo,secondVideo]});
sound.window.AchaarWeb.setEnhanced(true);
assert.equal(firstVideo.muted, false, 'Visible reel is unmuted');
assert.equal(secondVideo.muted, true, 'Offscreen reel stays muted');
assert.equal(firstVideo.volume, 1, 'Zero-volume visible reel becomes audible');
sound.window.AchaarWeb.setReelsMuted(true);
assert.equal(firstVideo.muted, true, 'Explicit mute is respected');
firstVideo.getBoundingClientRect = () => ({top:-900,bottom:-200,left:0,right:390});
secondVideo.getBoundingClientRect = () => ({top:0,bottom:700,left:0,right:390});
sound.mutate();
assert.equal(secondVideo.muted, true, 'Next reel retains explicit mute');
sound.window.AchaarWeb.setReelsMuted(false);
assert.equal(secondVideo.muted, false, 'Unmute applies to next visible reel');
assert.equal(firstVideo.muted, true, 'Previous reel no longer emits audio');
console.log('Web adapter: 59 assertions passed.');
