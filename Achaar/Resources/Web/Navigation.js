(() => {
    "use strict";
    if (window.top !== window || window.AchaarWeb) return;
    const bridge = window.webkit?.messageHandlers?.achaar;
    let enhanced = false;
    let pending = false;
    let lastPath = "";
    let verified = null;
    const knownPath = path => {
        if (path === "/") return "home";
        if (path.startsWith("/explore/")) return "explore";
        if (path.startsWith("/reels/")) return "reels";
        if (path.startsWith("/direct/")) return "messages";
        return null;
    };
    const sameOriginLinks = root => [...root.querySelectorAll("a[href]")].filter(a => {
        try { return new URL(a.href).origin === location.origin; } catch { return false; }
    });
    const visible = node => !!node && node.getClientRects().length > 0;
    const restore = () => {
        document.querySelectorAll(".achaar-verified-bottom-navigation").forEach(node =>
            node.classList.remove("achaar-verified-bottom-navigation"));
        verified = null;
    };
    const inspect = () => {
        pending = false;
        if (lastPath !== location.pathname) {
            lastPath = location.pathname;
            const tab = knownPath(lastPath);
            if (tab) bridge?.postMessage({ type: "tab", value: tab });
        }
        if (verified && !verified.isConnected) verified = null;
        if (!enhanced || /accounts|challenge|checkpoint/.test(location.pathname)) { restore(); return; }
        if (verified) {
            const paths = sameOriginLinks(verified).map(a => new URL(a.href).pathname);
            if (paths.includes("/") && paths.some(p => p.startsWith("/explore/"))
                && paths.some(p => p.startsWith("/direct/"))) return;
            restore();
        }
        // Never hide generic headers, sidebars, or controls on guessed class names.
        for (const nav of document.querySelectorAll("nav, [role='navigation']")) {
            if (!visible(nav)) continue;
            const rect = nav.getBoundingClientRect();
            const paths = sameOriginLinks(nav).map(a => new URL(a.href).pathname);
            if (rect.height > 0 && rect.height <= 90 && rect.top > innerHeight * 0.65
                && paths.includes("/") && paths.some(p => p.startsWith("/explore/"))
                && paths.some(p => p.startsWith("/direct/"))) {
                verified = nav;
                nav.classList.add("achaar-verified-bottom-navigation");
                break;
            }
        }
    };
    const schedule = () => {
        if (!pending) { pending = true; requestAnimationFrame(inspect); }
    };
    const clickAction = action => {
        if (!["profile", "create", "activity"].includes(action)) return false;
        // Prefer functional hrefs. English accessible labels are a conservative fallback.
        const candidates = sameOriginLinks(document);
        let target;
        if (action === "activity") target = candidates.find(a => new URL(a.href).pathname === "/accounts/activity/");
        if (action === "create") target = candidates.find(a => new URL(a.href).pathname.startsWith("/create/"));
        const labels = { profile: ["Profile"], create: ["New post", "Create"], activity: ["Notifications", "Activity"] };
        if (!target) {
            for (const node of document.querySelectorAll("a, button, [role='button']")) {
                const label = node.getAttribute("aria-label") || "";
                const childLabel = node.querySelector("[aria-label]")?.getAttribute("aria-label") || "";
                const title = node.querySelector("svg title")?.textContent?.trim() || "";
                if (labels[action].some(text => [label, childLabel, title].includes(text))
                    && (visible(node) || verified?.contains(node))) { target = node; break; }
            }
        }
        if (!target) return false;
        target.click();
        return true;
    };
    window.AchaarWeb = Object.freeze({
        setEnhanced(value) {
            enhanced = value === true;
            document.documentElement.dataset.achaarEnhanced = String(enhanced);
            if (!enhanced) restore();
            schedule();
        },
        action: clickAction,
        navigate(tab) {
            const paths = { home: "/", explore: "/explore/", reels: "/reels/", messages: "/direct/inbox/" };
            if (!Object.prototype.hasOwnProperty.call(paths, tab)) return false;
            const target = sameOriginLinks(document).find(a => new URL(a.href).pathname === paths[tab]);
            if (!target) return false;
            target.click();
            return true;
        }
    });
    new MutationObserver(schedule).observe(document.documentElement, { subtree: true, childList: true });
    for (const method of ["pushState", "replaceState"]) {
        const original = history[method];
        history[method] = function(...args) { const result = original.apply(this, args); schedule(); return result; };
    }
    addEventListener("popstate", schedule);
    addEventListener("resize", schedule);
    schedule();
})();
