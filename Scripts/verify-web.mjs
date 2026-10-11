// Dependency-free fixtures for the real bundled navigation adapter.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../Achaar/Resources/Web/Navigation.js', import.meta.url), 'utf8');
function fixture({ paths = ['/', '/explore/', '/direct/inbox/'], path = '/', top = 720, label = 'Profile' } = {}) {
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
    const nav = {
        isConnected: true,
        classList: { add: c => classes.add(c), remove: c => classes.delete(c) },
        getClientRects: () => classes.has('achaar-verified-bottom-navigation') ? [] : [{}],
        getBoundingClientRect: () => ({ top, height: 60 }),
        querySelectorAll: () => links,
        contains: n => n === profile || links.includes(n)
    };
    const location = { origin: 'https://www.instagram.com', pathname: path };
    const document = {
        documentElement: { dataset: {} },
        querySelectorAll: selector => {
            if (selector === '.achaar-verified-bottom-navigation') return classes.size ? [nav] : [];
            if (selector === "nav, [role='navigation']") return [nav];
            return [...links, profile];
        }
    };
    const window = { webkit: { messageHandlers: { achaar: { postMessage: data => events.push(data) } } } };
    window.top = window;
    vm.runInNewContext(source, {
        window, document, location, innerHeight: 800, URL,
        history: { pushState() {}, replaceState() {} },
        MutationObserver: class { constructor(fn) { observer = fn; } observe() {} },
        addEventListener() {}, requestAnimationFrame: fn => fn()
    });
    return { window, document, nav, classes, events, location, mutate: () => observer(), clicks: () => clicked };
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
console.log('Web adapter: 15 assertions passed.');
