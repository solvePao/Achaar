(() => {
    "use strict";
    if (window.top !== window || window.AchaarWeb) return;
    const bridge = window.webkit?.messageHandlers?.achaar;
    let enhanced = false;
    let pending = false;
    let lastPath = "";
    let lastReportedTab = "";
    let verified = null;
    let verifiedDesktop = false;
    let lastMode = "";
    let profilePath = null;
    let originalViewport = null;
    let viewportElement = null;
    let conversationPane = null;
    let nativeViewportHeight = null;
    const restoredAttributes = new Map();
    const exposeActions = node => {
        if (node.getAttribute("aria-hidden") === "true") {
            if (!restoredAttributes.has(node)) restoredAttributes.set(node, "true");
            node.setAttribute("aria-hidden", "false");
        }
    };
    const reportMode = value => {
        if (value !== lastMode) { lastMode = value; bridge?.postMessage({ type: "navigation", value }); }
    };
    const knownPath = path => {
        if (profilePath && path === profilePath) return "profile";
        // Instagram sometimes paints the signed-in profile before updating its
        // SPA URL. Confirm its own header locally so stale Reels routes cannot
        // override native selection or apply the wrong page layout.
        if (profilePath && [...document.querySelectorAll("header")].some(header => {
            const text = (header.textContent || "").toLowerCase();
            return ["posts", "followers", "following"].every(label => text.includes(label))
                && [...(header.querySelectorAll?.("h1, h2, a, span") || [])]
                    .some(n => n.textContent?.trim() === profilePath.split("/")[1]);
        })) return "profile";
        if (path === "/") return "home";
        if (path.startsWith("/explore/")) return "explore";
        if (path.startsWith("/reels/")) return "reels";
        if (path.startsWith("/direct/")) return "messages";
        return null;
    };
    const reportRoute = () => {
        const tab = knownPath(location.pathname);
        if (tab && tab !== lastReportedTab) {
            lastReportedTab = tab;
            bridge?.postMessage({ type: "tab", value: tab });
        }
    };
    const sameOriginLinks = root => [...root.querySelectorAll("a[href]")].filter(a => {
        try { return new URL(a.href).origin === location.origin; } catch { return false; }
    });
    const controlLabels = node => [node.getAttribute("aria-label"),
        node.querySelector("[aria-label]")?.getAttribute("aria-label"),
        node.querySelector("svg title")?.textContent?.trim(),
        node.textContent?.trim().replace(/\s+/g, " ")]
        .filter(Boolean).map(label => label.toLowerCase());
    const profileLink = root => sameOriginLinks(root).find(a => {
        const path = new URL(a.href).pathname;
        if (controlLabels(a).includes("profile")) return true;
        // Only a one-segment avatar link within verified navigation can be
        // the signed-in account. Do not mistake feed authors for this control.
        return root === verified && /^\/[^/]+\/$/.test(path)
            && !["explore", "reels", "direct", "accounts", "stories"].includes(path.split("/")[1])
            && !!a.querySelector("img");
    });
    const visible = node => !!node && node.getClientRects().length > 0
        && getComputedStyle(node).visibility !== "hidden" && getComputedStyle(node).display !== "none";
    const modalOpen = () => [...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')].some(visible);
    const restore = () => {
        document.querySelectorAll(".achaar-verified-bottom-navigation").forEach(node =>
            { node.classList.remove("achaar-verified-bottom-navigation"); node.classList.remove("achaar-verified-desktop-navigation"); });
        verified = null; verifiedDesktop = false;
        for (const [node, value] of restoredAttributes) if (node.isConnected) node.setAttribute("aria-hidden", value);
        restoredAttributes.clear();
    };
    const navigationLinks = node => sameOriginLinks(node).filter(a => {
        const path = new URL(a.href).pathname;
        return !/accounts|challenge|checkpoint/.test(path);
    });
    const isNavigation = node => {
        const links = navigationLinks(node);
        const paths = links.map(a => new URL(a.href).pathname);
        const profile = links.some(a => {
            const labels = [a.getAttribute("aria-label"),
                a.querySelector("[aria-label]")?.getAttribute("aria-label"),
                a.querySelector("svg title")?.textContent?.trim()];
            return labels.includes("Profile");
        });
        return paths.includes("/")
            && paths.some(p => p.startsWith("/explore/") || p.startsWith("/reels/"))
            && (paths.some(p => p.startsWith("/direct/")) || profile);
    };
    const isBottomBar = node => {
        if (!visible(node) || !isNavigation(node)) return false;
        const rect = node.getBoundingClientRect();
        if (viewportElement && rect.width > 0 && rect.width <= 110 && rect.height >= innerHeight * 0.6
            && rect.left <= 1 && isNavigation(node)) {
            node.classList.add("achaar-verified-desktop-navigation");
            return true;
        }
        if (!(rect.height > 0 && rect.height <= 110 && rect.width >= (window.visualViewport?.width || innerWidth) * 0.7
            && rect.top >= innerHeight * 0.65 && rect.bottom >= innerHeight - 40
            && rect.bottom <= innerHeight + 110)) return false;
        const semantic = node.matches("nav, [role='navigation']");
        // Instagram also renders its mobile bar as nested divs. Require a
        // fixed/sticky, full-width strip with several distinct destinations.
        const position = getComputedStyle(node).position;
        const destinations = new Set(navigationLinks(node).map(a => new URL(a.href).pathname));
        return semantic || (["fixed", "sticky"].includes(position) && destinations.size >= 4);
    };
    const conversationEditor = () => location.pathname.startsWith("/direct/")
        ? [...document.querySelectorAll('[contenteditable="true"][role="textbox"], textarea[placeholder="Message..."], textarea[aria-label="Message"]')].find(node => {
            if (!visible(node) || node.closest?.('[role="dialog"]')) return false;
            const r = node.getBoundingClientRect();
            if (r.width < 40 || r.height < 16 || r.top < 0 || r.bottom > innerHeight) return false;
            const hit = document.elementFromPoint?.(r.left + Math.min(20, r.width / 2), r.top + r.height / 2);
            return hit === node || node.contains(hit);
        }) : null;
    const styleRecognizedPage = () => {
        const page = location.pathname.startsWith("/stories/") ? "story" : knownPath(location.pathname);
        const conversation = /^\/direct\/t\//.test(location.pathname) || !!conversationEditor();
        const inbox = !conversation && page === "messages" && ["/direct/", "/direct/inbox/"].includes(location.pathname);
        const dialogOpen = modalOpen();
        const expandedInbox = inbox && !dialogOpen;
        if (document.documentElement) {
            document.documentElement.dataset.achaarPage = page || "other";
            document.documentElement.dataset.achaarConversation = String(conversation && enhanced);
            document.documentElement.dataset.achaarInbox = String(expandedInbox && enhanced);
            document.documentElement.style?.setProperty("--achaar-visible-width", `${window.visualViewport?.width || innerWidth}px`);
            document.documentElement.style?.setProperty("--achaar-visible-height", `${nativeViewportHeight || window.visualViewport?.height || innerHeight}px`);
        }
        // Instagram omits row names at its compact desktop breakpoint. Let its
        // own responsive renderer produce the full list, then fit that list to
        // the phone. No thread data is extracted or reconstructed natively.
        const meta = document.querySelector?.('meta[name="viewport"]');
        if (enhanced && expandedInbox && meta) {
            if (!viewportElement) { viewportElement = meta; originalViewport = meta.content; }
            const expanded = "width=1000, initial-scale=1, viewport-fit=cover";
            if (meta.content !== expanded) meta.content = expanded;
        } else if (viewportElement) {
            viewportElement.content = originalViewport;
            viewportElement = null; originalViewport = null;
        }
        if (!enhanced) return;
        // Remove only measured desktop gutter spacing around recognized mobile
        // content. Keep Instagram's own responsive content and event handlers.
        const alignPhoneColumn = start => {
            for (let node = start, depth = 0; node && node !== document.body && depth < 20; node = node.parentElement, depth++) {
                const r = node.getBoundingClientRect(), style = getComputedStyle(node);
                if (page !== "explore" && r.height < innerHeight * 0.5) continue;
                const gutter = parseFloat(style.marginLeft) || parseFloat(style.paddingLeft);
                if (gutter >= 40 && gutter <= 110) node.classList.add("achaar-mobile-alignment");
            }
        };
        if (conversation) {
            if (conversationPane?.isConnected) {
                conversationPane.classList.add("achaar-conversation-pane");
                conversationPane.parentElement?.classList.add("achaar-conversation-columns");
                for (let node = conversationPane.parentElement, i = 0; node && node !== document.body && i < 10; node = node.parentElement, i++) {
                    const r = node.getBoundingClientRect();
                    if (r.width >= innerWidth * 0.9 && r.height >= innerHeight * 0.8) node.classList.add("achaar-conversation-viewport");
                }
            }
            const editor = conversationEditor();
            let composer = null;
            for (let node = editor?.parentElement, i = 0; node && i < 9; node = node.parentElement, i++) {
                const r = node.getBoundingClientRect();
                if (r.height > 64) break;
                if (r.width >= (window.visualViewport?.width || innerWidth) * 0.7 && r.height >= 40) composer = node;
            }
            if (composer) {
                composer.classList.add("achaar-conversation-composer");
                for (let node = editor.parentElement, i = 0; node && node !== composer && i < 9; node = node.parentElement, i++) {
                    node.classList.add("achaar-conversation-composer-content");
                }
                for (let container = composer.parentElement, i = 0; container && container !== document.body && i < 30; container = container.parentElement, i++) {
                    container.classList.add("achaar-conversation-composer-container");
                }
                // A transformed website ancestor can anchor position:fixed to
                // its old desktop height. Correct only the identified composer
                // against the actual root viewport, including keyboard resize.
                composer.style?.setProperty("--achaar-composer-shift", "0px");
                const viewportHeight = nativeViewportHeight || (window.visualViewport?.height || innerHeight);
                const shift = viewportHeight - 8 - composer.getBoundingClientRect().bottom;
                if (Number.isFinite(shift) && Math.abs(shift) <= 200) composer.style?.setProperty("--achaar-composer-shift", `${shift}px`);
            }
            let pane = editor?.parentElement;
            for (let depth = 0; pane && pane !== document.body && depth < 24; depth++, pane = pane.parentElement) {
                const r = pane.getBoundingClientRect(), parent = pane.parentElement;
                if (r.width < 150 || r.height < innerHeight * 0.6 || !parent) continue;
                const sidebar = [...parent.children].find(n => {
                    const s = n.getBoundingClientRect();
                    return n !== pane && s.width >= 40 && s.width <= 500 && s.height >= innerHeight * 0.6
                        && n.querySelectorAll("img").length >= 3 && !n.contains(editor);
                });
                if (!sidebar) continue;
                pane.classList.add("achaar-conversation-pane");
                conversationPane = pane;
                sidebar.classList.add("achaar-conversation-sidebar");
                parent.classList.add("achaar-conversation-columns");
                alignPhoneColumn(pane);
                const header = [...pane.querySelectorAll('header, [role="banner"]')].find(n => n.getBoundingClientRect().height <= 100);
                header?.classList.add("achaar-conversation-header");
                if (!header) {
                    const avatar = [...pane.querySelectorAll("img")].find(n => {
                        const r = n.getBoundingClientRect();
                        return r.top >= 0 && r.top < 80 && r.width >= 20 && r.width <= 64;
                    });
                    for (let row = avatar?.parentElement, i = 0; row && row !== pane && i < 8; row = row.parentElement, i++) {
                        const r = row.getBoundingClientRect();
                        if (r.width >= (window.visualViewport?.width || innerWidth) * 0.7 && r.height >= 40 && r.height <= 100) {
                            row.classList.add("achaar-conversation-header"); break;
                        }
                    }
                }
                break;
            }
        }
        if (conversation) {
            for (const control of document.querySelectorAll('.achaar-conversation-pane [role="button"][aria-label]')) {
                if (!controlLabels(control).some(label => label.includes("react") && label.includes("message"))) continue;
                let group = control.closest('[role="group"]');
                if (!group || group.getBoundingClientRect().height > 64 || group.getBoundingClientRect().width > 180) {
                    group = null;
                    for (let node = control.parentElement, depth = 0; node && depth < 6; node = node.parentElement, depth++) {
                        const r = node.getBoundingClientRect();
                        if (r.height > 64 || r.width > 180) break;
                        if (node.querySelectorAll('[role="button"]').length >= 2) group = node;
                    }
                }
                if (!group) continue;
                group.classList.add("achaar-message-actions");
                exposeActions(group);
                for (const node of group.querySelectorAll('[aria-hidden="true"]')) exposeActions(node);
                for (let parent = group.parentElement, i = 0; parent && i < 3; parent = parent.parentElement, i++) {
                    const r = parent.getBoundingClientRect();
                    if (r.height > 64 || r.width > 160) break;
                    parent.classList.add("achaar-message-actions-visible");
                    exposeActions(parent);
                }
            }
        }
        if (page === "explore") {
            const search = document.querySelector?.('input[placeholder="Search"], input[aria-label="Search"]');
            alignPhoneColumn(search);
        }
        if (page === "home") {
            const brand = document.querySelector?.('svg[aria-label="Instagram"]');
            const header = brand?.closest?.("header");
            if (header && header.getBoundingClientRect().height <= 80) {
                for (const icon of header.querySelectorAll('svg[aria-label="Notifications"], svg[aria-label="Activity"]')) {
                    icon.closest('a, button, [role="button"]')?.classList.add("achaar-native-header-action");
                }
                header.classList.add("achaar-home-header");
                for (const control of header.querySelectorAll('a, button, [role="button"]')) {
                    if (controlLabels(control).some(label => ["notifications", "activity"].includes(label))) {
                        control.classList.add("achaar-native-header-action");
                    }
                }
                let search = header.querySelector('input')?.parentElement;
                for (let depth = 0; search && search !== header && depth < 6; depth++, search = search.parentElement) {
                    const r = search.getBoundingClientRect();
                    if (r.width >= 160 && r.height <= 60 && !search.contains(brand)) search.classList.add("achaar-home-search");
                }
            }
        }
        if (page === "reels") {
            document.documentElement.style?.setProperty("--achaar-reel-height", `${Math.max(240, (window.visualViewport?.height || innerHeight) - 80)}px`);
            for (const video of document.querySelectorAll("video")) {
                let card = video.parentElement;
                for (let depth = 0; card && depth < 20; depth++, card = card.parentElement) {
                    if (card.querySelectorAll("video").length !== 1) break;
                    const children = [...card.children];
                    const media = children.find(n => n.contains(video));
                    const actions = children.find(n => n !== media &&
                        n.querySelector('[aria-label="Like"], [aria-label="Unlike"]') &&
                        n.querySelector('[aria-label="Comment"], [aria-label="Save"], [aria-label="Remove"]'));
                    if (!media || !actions || children.length !== 2) continue;
                    card.classList.add("achaar-reel-card");
                    actions.classList.add("achaar-reel-actions");
                    for (let node = video; node && node !== card; node = node.parentElement) {
                        node.classList.add("achaar-reel-media");
                    }
                    let outer = card.parentElement;
                    for (let i = 0; outer && i < 2 && outer.children.length === 1; i++, outer = outer.parentElement) {
                        outer.classList.add("achaar-reel-frame");
                    }
                    for (const link of sameOriginLinks(media)) {
                        if (!/^\/[^/]+\/$/.test(new URL(link.href).pathname)) continue;
                        link.classList.add("achaar-reel-author");
                        let row = link.parentElement;
                        for (let i = 0; row && row !== media && i < 6; i++, row = row.parentElement) {
                            const follow = [...row.querySelectorAll('button, [role="button"]')].some(n => controlLabels(n).some(l => ["follow", "following"].includes(l)));
                            if (follow && row.getBoundingClientRect().height <= 120) {
                                row.classList.add("achaar-reel-author-row"); break;
                            }
                        }
                    }
                    break;
                }
            }
        }
        if (page === "profile") {
            const nodes = [...document.querySelectorAll("div, span, a, button")];
            const labelNode = label => nodes.find(n =>
                new RegExp(`^(?:[0-9.,kKmM]+)?${label}$`, "i").test((n.textContent || "").replace(/\s+/g, "")));
            const counters = ["posts", "followers", "following"].map(labelNode);
            let stats = counters[0]?.parentElement;
            for (let depth = 0; stats && depth < 6; depth++, stats = stats.parentElement) {
                const rect = stats.getBoundingClientRect?.();
                if (counters.every(n => n && stats.contains(n)) && rect?.width >= 180 && rect.height < 100) {
                    stats.classList.add("achaar-profile-stats");
                    const header = stats.closest("header");
                    const hero = header?.firstElementChild;
                    if (hero?.querySelector("img") && hero.children.length === 2
                        && hero.getBoundingClientRect().height < 240) {
                        hero.classList.add("achaar-profile-hero");
                        header.classList.add("achaar-profile-header");
                        const title = stats.previousElementSibling;
                        if (title?.textContent.trim() === profilePath?.split("/")[1]) title.classList.add("achaar-profile-handle");
                        const bio = header.children[1];
                        const name = [...(bio?.querySelectorAll("span") || [])].find(n =>
                            parseInt(getComputedStyle(n).fontWeight) >= 600 && n.getBoundingClientRect().height <= 24);
                        name?.classList.add("achaar-profile-name");
                        for (let parent = name?.parentElement; parent && parent !== header; parent = parent.parentElement) {
                            parent.classList.add("achaar-profile-name-container");
                        }
                    }
                    break;
                }
            }
        }
        if (inbox) {
            const avatar = [...document.querySelectorAll("img")].find(n => (n.getBoundingClientRect?.()?.width || 0) >= 40);
            let column = avatar?.parentElement;
            for (let depth = 0; column && depth < 24; depth++, column = column.parentElement) {
                const r = column.getBoundingClientRect();
                const parent = column.parentElement, p = parent?.getBoundingClientRect();
                if (r.width <= 500 && r.height > innerHeight * 0.6 && p?.width > r.width + 40
                    && column.querySelectorAll("img").length >= 3) {
                    column.classList.add("achaar-inbox-list");
                    parent.classList.add("achaar-inbox-columns");
                    alignPhoneColumn(column);
                    for (const sibling of parent.children) {
                        if (sibling !== column && [...sibling.querySelectorAll("span, h1, h2, div")]
                            .some(n => n.children.length <= 1 && n.textContent.trim() === "Your messages")) {
                            sibling.classList.add("achaar-inbox-empty");
                        }
                    }
                    break;
                }
            }
        }
    };
    let reelsMuted = false, audibleReel = null, soundPending = false;
    const applyReelSound = () => {
        if (!enhanced || knownPath(location.pathname) !== "reels") { audibleReel = null; return; }
        const videos = [...document.querySelectorAll("video")];
        const ranked = videos.map(node => {const r = node.getBoundingClientRect(); return {node, area: Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(0, r.top)) * Math.max(0, Math.min(r.right, innerWidth) - Math.max(0, r.left))};}).sort((a,b) => b.area-a.area);
        const current = ranked[0]?.area > 10000 ? ranked[0].node : null;
        const changed = current !== audibleReel; audibleReel = current;
        for (const video of videos) {
            const muted = video !== current || reelsMuted;
            if (video.muted !== muted) video.muted = muted;
            if (video === current && !reelsMuted && video.volume === 0) video.volume = 1;
        }
        if (changed && current && current.paused) current.play()?.catch(() => {});
    };
    const scheduleReelSound = () => {
        if (soundPending) return;
        soundPending = true; requestAnimationFrame(() => {soundPending = false; applyReelSound();});
    };
    document.addEventListener?.("scroll", scheduleReelSound, {capture:true,passive:true});
    document.addEventListener?.("volumechange", scheduleReelSound, true);
    document.addEventListener?.("loadedmetadata", scheduleReelSound, true);
    const inspect = () => {
        applyReelSound();
        pending = false;
        styleRecognizedPage();
        if (document.documentElement) document.documentElement.dataset.achaarEnhanced = String(enhanced);
        lastPath = location.pathname;
        reportRoute();
        if (verified && !verified.isConnected) verified = null;
        if (!enhanced) { restore(); reportMode("original"); return; }
        if (/accounts|challenge|checkpoint/.test(location.pathname)) { restore(); reportMode("native"); return; }
        // Website sheets own the whole phone viewport. Keep the verified web
        // navigation hidden, but remove native chrome until the sheet closes.
        if (modalOpen()) { reportMode("modal"); return; }
        const immersive = location.pathname.startsWith("/stories/") || /^\/direct\/t\//.test(location.pathname) || !!conversationEditor();
        if (immersive) { reportMode("immersive"); if (conversationPane?.isConnected) reportMessageLayout(); }
        if (verified) {
            if (isNavigation(verified)) {
                verified.classList.add("achaar-verified-bottom-navigation");
                if (verifiedDesktop) verified.classList.add("achaar-verified-desktop-navigation");
                // Menus may be nested inside the navigation strip. Preserve
                // controls drawn above it instead of inheriting its hiding.
                const bar = verified.getBoundingClientRect();
                for (const link of sameOriginLinks(verified)) {
                    const rect = link.getBoundingClientRect?.();
                    if (rect) link.classList.toggle("achaar-navigation-popover",
                        ["post", "story", "reel", "live", "live video"].some(label => controlLabels(link).includes(label))
                            && rect.height > 0 && rect.bottom <= bar.top && rect.top >= 0);
                }
                const profile = profileLink(verified);
                if (profile) profilePath = new URL(profile.href).pathname;
                reportRoute();
                reportMode(immersive ? "immersive" : "native");
                return;
            }
            restore();
        }
        const candidates = new Set(document.querySelectorAll("nav, [role='navigation']"));
        for (const link of sameOriginLinks(document)) {
            if (new URL(link.href).pathname !== "/") continue;
            let ancestor = link.parentElement;
            for (let depth = 0; ancestor && depth < 8; depth++, ancestor = ancestor.parentElement) {
                if (ancestor === document.body || ancestor === document.documentElement) break;
                candidates.add(ancestor);
            }
        }
        for (const node of candidates) {
            if (!isBottomBar(node)) continue;
            verified = node;
            verifiedDesktop = node.classList.contains?.("achaar-verified-desktop-navigation") === true;
            node.classList.add("achaar-verified-bottom-navigation");
            if (node.classList.contains?.("achaar-verified-desktop-navigation")) {
                for (let parent = node.parentElement, depth = 0; parent && parent !== document.body && depth < 8; parent = parent.parentElement, depth++) {
                    const r = parent.getBoundingClientRect();
                    if (r.width > 110 || r.height < innerHeight * 0.6) break;
                    parent.classList.add("achaar-verified-bottom-navigation", "achaar-verified-desktop-navigation");
                }
            }
            const profile = profileLink(node);
            if (profile) profilePath = new URL(profile.href).pathname;
                reportRoute();
            reportMode(immersive ? "immersive" : "native");
            break;
        }
    };
    const schedule = () => {
        if (!pending) { pending = true; requestAnimationFrame(inspect); }
    };
    const actionLabels = {
        profile: ["Profile"], create: ["New post", "Create"], activity: ["Notifications", "Activity"],
        search: ["Search"], newMessage: ["New message"], requests: ["Requests", "Message requests"],
        saved: ["Saved"], archive: ["Archive", "View archive"], editProfile: ["Edit profile"],
        accountSettings: ["Settings", "Settings and activity"]
    };
    const findAction = action => {
        if (!Object.prototype.hasOwnProperty.call(actionLabels, action)) return null;
        if (["following", "favorites"].includes(action) && location.pathname !== "/") return null;
        const root = ["profile", "create"].includes(action) ? (verified || document) : document;
        const candidates = sameOriginLinks(root);
        if (action === "profile") { const profile = profileLink(root); if (profile) return profile; }
        const routes = { activity: ["/accounts/activity/", "/notifications/", "/activity/"],
            editProfile: ["/accounts/edit/"], requests: ["/direct/requests/"] };
        let target = candidates.find(a => routes[action]?.includes(new URL(a.href).pathname)
            || (action === "create" && new URL(a.href).pathname.startsWith("/create/")));
        if (target) return target;
        for (const node of document.querySelectorAll("a, button, [role='button']")) {
            if (actionLabels[action].some(text => controlLabels(node).includes(text.toLowerCase()))
                && (visible(node) || verified?.contains(node) || node.classList?.contains("achaar-native-header-action"))) return node;
        }
        return null;
    };
    const clickAction = action => {
        inspect();
        if (["like", "save", "comments", "sharePost"].includes(action)) return clickPostAction(action);
        const target = findAction(action);
        if (!target) return false;
        const trigger = action === "create" ? (target.querySelector("[aria-label]") || target) : target;
        if (typeof trigger.click === "function") trigger.click();
        else trigger.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
        if (action === "profile") {
            if (target.href) profilePath = new URL(target.href).pathname;
            bridge?.postMessage({ type: "tab", value: "profile" });
        }
        return true;
    };
    const clickPostAction = action => {
        if (location.pathname.startsWith("/direct/") || /accounts|challenge|checkpoint/.test(location.pathname)) return false;
        const labels = { like: ["like", "unlike"], save: ["save", "unsave", "remove from saved"], comments: ["comment", "comments"], sharePost: ["share post", "share"] };
        const controls = root => [...root.querySelectorAll("button, [role='button'], a")].filter(visible);
        const has = (node, names) => controlLabels(node).some(value => names.includes(value));
        const candidates = new Set(document.querySelectorAll("article, [role='article']"));
        // Only infer a post container from the combined Like/Comment/Save
        // signature, not from a matching label elsewhere on the page.
        for (const button of controls(document).filter(node => has(node, labels.like))) {
            let parent = button.parentElement;
            for (let depth = 0; parent && depth < 7; depth++, parent = parent.parentElement) {
                if (parent === document.body || parent === document.documentElement) break;
                const buttons = controls(parent);
                if (buttons.filter(node => has(node, labels.like)).length === 1
                    && buttons.some(node => has(node, labels.comments))
                    && buttons.some(node => has(node, labels.save))) { candidates.add(parent); break; }
            }
        }
        const posts = [...candidates].map(node => ({ node, rect: node.getBoundingClientRect() }))
            .filter(({rect}) => rect.width >= (window.visualViewport?.width || innerWidth) * 0.7 && rect.height >= 120
                && Math.min(rect.bottom, innerHeight) - Math.max(rect.top, 0) >= 120)
            .sort((a, b) => Math.abs((a.rect.top + a.rect.bottom) / 2 - innerHeight / 2)
                - Math.abs((b.rect.top + b.rect.bottom) / 2 - innerHeight / 2));
        const post = posts[0]?.node;
        if (!post) return false;
        const target = controls(post).find(node => has(node, labels[action]));
        if (!target) return false;
        target.click();
        return true;
    };
    // A touch hold opens the website's existing per-message reaction picker.
    // No message identifiers or contents cross the native bridge. Moving or
    // scrolling cancels the hold; opening a picker never selects a reaction.
    const messageReaction = target => {
        if (!enhanced || !location.pathname.startsWith("/direct/") || !(conversationPane?.isConnected && conversationPane.contains(target))) return null;
        for (let row = target?.closest?.('div'), depth = 0; row && row !== document.body && depth < 12; row = row.parentElement, depth++) {
            const buttons = [...row.querySelectorAll('[role="button"][aria-label]')]
                .filter(n => controlLabels(n).some(label => label.includes("react") && label.includes("message")));
            if (buttons.length > 1) return null;
            if (buttons.length === 1 && [...row.querySelectorAll('[role="button"][aria-label]')].some(n => controlLabels(n).some(label => label.startsWith("double tap to like")))) return {row, button:buttons[0]};
        }
        return null;
    };
    let holdTimer = null, holdPoint = null, suppressedRow = null, suppressedControl = null, suppressUntil = 0;
    const cancelHold = () => { clearTimeout(holdTimer); holdTimer = null; holdPoint = null; };
    document.addEventListener?.("pointerdown", event => {
        cancelHold();
        if (event.pointerType === "mouse" || event.isPrimary === false) return;
        const reaction = messageReaction(event.target);
        if (!reaction) return;
        holdPoint = {x:event.clientX,y:event.clientY};
        holdTimer = setTimeout(() => {
            holdTimer = null;
            if (!enhanced || !reaction.button.isConnected) return;
            suppressedRow = reaction.row; suppressedControl = reaction.button; suppressUntil = Date.now() + 900;
            reaction.button.click();
        }, 450);
    }, {passive:true});
    document.addEventListener?.("pointermove", event => {
        if (holdPoint && Math.hypot(event.clientX-holdPoint.x, event.clientY-holdPoint.y) > 10) cancelHold();
    }, {passive:true});
    for (const name of ["pointerup", "pointercancel", "scroll"]) document.addEventListener?.(name, cancelHold, {capture:true,passive:true});
    document.addEventListener?.("contextmenu", event => {
        if (messageReaction(event.target)) event.preventDefault();
    });
    document.addEventListener?.("click", event => {
        if (enhanced && Date.now() < suppressUntil && suppressedRow?.contains(event.target) && !suppressedControl?.contains(event.target)) {
            event.preventDefault(); event.stopPropagation();
        }
    }, true);
    let visibleReaction = null;
    const reactionControl = () => {
        if (!enhanced || !conversationPane?.isConnected || !location.pathname.startsWith("/direct/")) return null;
        const candidates = [...conversationPane.querySelectorAll('[role="button"][aria-label]')]
            .filter(n => controlLabels(n).some(label => label.includes("react") && label.includes("message")))
            .map(node => ({node,r:node.getBoundingClientRect()}))
            .filter(({node,r}) => visible(node) && r.width >= 20 && r.width <= 64 && r.height >= 20 && r.height <= 64
                && r.top >= 64 && r.bottom < innerHeight - 72 && r.left >= 0 && r.right <= (window.visualViewport?.width || innerWidth));
        candidates.sort((a,b) => Math.abs(a.r.top + a.r.height/2-innerHeight/2) - Math.abs(b.r.top+b.r.height/2-innerHeight/2));
        return candidates[0] || null;
    };
    let layoutTimer = null;
    const reportMessageLayout = () => {
        if (!enhanced || !location.pathname.startsWith("/direct/")) return;
        clearTimeout(layoutTimer);
        layoutTimer = setTimeout(() => bridge?.postMessage({type:"messageControls",value:"changed"}), 100);
    };
    document.addEventListener?.("scroll", reportMessageLayout, {capture:true,passive:true});
    addEventListener("resize", reportMessageLayout);
    window.visualViewport?.addEventListener("resize", () => { schedule(); reportMessageLayout(); });
    window.AchaarWeb = Object.freeze({
        setReelsMuted(value) {
            reelsMuted = value === true;
            applyReelSound();
            return true;
        },
        setViewportHeight(height) {
            if (!Number.isFinite(height) || height < 100 || height > 4096 || nativeViewportHeight === height) return;
            nativeViewportHeight = height;
            schedule();
        },
        reactionControlRect() {
            const candidate = reactionControl();
            visibleReaction = candidate?.node || null;
            if (!candidate) return null;
            const {r} = candidate;
            return {x:r.left/innerWidth,y:r.top/innerHeight,width:r.width/innerWidth,height:r.height/innerHeight};
        },
        openVisibleReaction() {
            const candidate = visibleReaction?.isConnected ? visibleReaction : reactionControl()?.node;
            if (!enhanced || !candidate || !conversationPane?.contains(candidate)) return false;
            candidate.click(); return true;
        },
        navigationAvatarRect() {
            if (!enhanced || !verified) return null;
            const page = knownPath(location.pathname);
            let image = null;
            if (page === "profile") image = document.querySelector(".achaar-profile-hero img");
            else if (page === "home") {
                const story = [...document.querySelectorAll("li")].find(n => n.textContent.trim().toLowerCase() === "your story");
                image = story?.querySelector("img");
            }
            if (!image?.complete || !image.naturalWidth) return null;
            const r = image.getBoundingClientRect();
            if (r.width < 20 || r.width > 180 || r.height < 20 || r.height > 180
                || r.left < 0 || r.top < 0 || r.right > innerWidth || r.bottom > innerHeight) return null;
            return {x:r.x, y:r.y, width:r.width, height:r.height};
        },
        setEnhanced(value) {
            enhanced = value === true;
            lastMode = "";
            if (document.documentElement) document.documentElement.dataset.achaarEnhanced = String(enhanced);
            if (!enhanced) restore();
            inspect();
        },
        action: clickAction,
        prepareAction(action) {
            if (!["saved", "archive", "editProfile", "accountSettings"].includes(action)) return false;
            if (!profilePath || location.pathname !== profilePath) return clickAction("profile");
            if (!["saved", "archive", "accountSettings"].includes(action)) return false;
            // Options on the verified signed-in profile are safe navigation;
            // never confuse post options or another person's profile with it.
            const options = [...document.querySelectorAll("button, [role='button']")]
                .find(node => visible(node) && controlLabels(node).includes("options"));
            if (!options) return false;
            options.click();
            return true;
        },
        navigate(tab) {
            inspect();
            const paths = { home: "/", explore: "/explore/", reels: "/reels/", messages: "/direct/inbox/" };
            if (!Object.prototype.hasOwnProperty.call(paths, tab)) return false;
            const target = sameOriginLinks(verified || document).find(a => {
                const path = new URL(a.href).pathname;
                return tab === "home" ? path === "/" : path.startsWith(paths[tab].split("inbox/")[0]);
            });
            if (!target) return false;
            target.click();
            return true;
        }
    });
    new MutationObserver((records = []) => {
        // React can replace a node's class attribute after an enhancement was
        // applied. Reapply removed adapter classes without observing our own
        // additions as a fresh mutation, avoiding an inspection feedback loop.
        if (!records.length || records.some(record => record.type === "childList" || record.attributeName !== "class"
            || (record.oldValue || "").split(/\s+/).some(name => name.startsWith("achaar-") && !record.target.classList.contains(name)))) schedule();
    }).observe(document, { subtree: true, childList: true, attributes: true, attributeOldValue: true, attributeFilter: ["href", "role", "aria-label", "aria-modal", "aria-hidden", "class"] });
    for (const method of ["pushState", "replaceState"]) {
        const original = history[method];
        history[method] = function(...args) { const result = original.apply(this, args); schedule(); return result; };
    }
    addEventListener("popstate", schedule);
    addEventListener("resize", schedule);
    // Native content stays behind a loading surface until the first inspection.
    // On an unsupported web layout, expose the original interface and let the
    // native shell remove its duplicate bar rather than leave two bars visible.
    addEventListener("DOMContentLoaded", () => {
        schedule();
        setTimeout(() => {
            if (enhanced && !verified && lastMode !== "immersive" && !/accounts|challenge|checkpoint/.test(location.pathname)) reportMode("original");
        }, 2000);
    });
    schedule();
})();
