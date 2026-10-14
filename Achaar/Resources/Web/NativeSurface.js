// Native presentation of the rendered page only. No private APIs, cookies,
// account tokens, React internals, or persistent copies of page content.
(() => {
    if (window.top !== window || !['instagram.com', 'www.instagram.com'].includes(location.hostname)
        || location.protocol !== 'https:') return;
    const documentID = `${Date.now()}-${Math.random()}`;
    let nextID = 0;
    let requestedSearchPage = null;
    const ids = new WeakMap();
    let targets = new Map();
    const visible = node => node?.isConnected && node.getClientRects().length > 0
        && !node.closest('[aria-hidden="true"], [inert]')
        && getComputedStyle(node).visibility !== 'hidden' && getComputedStyle(node).display !== 'none';
    const nearby = node => {
        const rect = node.getBoundingClientRect();
        return rect.bottom >= 0 && rect.top <= innerHeight * 2;
    };
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const label = node => normalize(node.getAttribute('aria-label') || node.getAttribute('placeholder')
        || node.getAttribute('title') || (!node.querySelector?.('button,[role="button"]')
            ? node.querySelector?.('svg[aria-label]')?.getAttribute('aria-label') || node.querySelector?.('svg title')?.textContent : '')
        || node.innerText || node.textContent || node.getAttribute('alt') || node.querySelector?.('img')?.getAttribute('alt'));
    const signature = node => [node.tagName, node.getAttribute('role'), node.getAttribute('type'),
        node.getAttribute('href'), label(node)].join('|');
    const allowedMedia = value => {
        try {
            const url = new URL(value, location.href);
            return url.protocol === 'https:' && !url.username && !url.password
                && ['cdninstagram.com', 'fbcdn.net'].some(host => url.hostname === host || url.hostname.endsWith(`.${host}`))
                ? url.href : null;
        } catch { return null; }
    };
    const isEditor = node => node.matches('textarea, input:not([type]), input[type="text"], input[type="search"], [contenteditable="true"], [role="textbox"]');
    const actionSelector = 'a[href],button,[role="button"],[role="tab"],[role="checkbox"],[role="switch"]';
    const getRoot = () => {
        const dialog=[...document.querySelectorAll('[role="dialog"],[aria-modal="true"]')].filter(visible).at(-1);
        if (dialog) return dialog;
        if (location.pathname.startsWith('/stories/')) {
            const close=[...document.querySelectorAll('button,[role="button"]')].find(node=>visible(node) && label(node).toLowerCase()==='close');
            for (let node=close?.parentElement, depth=0; node && node !== document.body && depth<12; node=node.parentElement,depth++) {
                if (node.querySelector('video,img') && node.querySelector('textarea')) return node;
            }
            for (let node=close?.parentElement, depth=0; node && node !== document.body && depth<12; node=node.parentElement,depth++) {
                if (node.querySelector('video,img')) return node;
            }
        }
        return document.body;
    };
    const sensitivePage = () => /\/(accounts|challenge|checkpoint|oauth)(\/|$)/.test(location.pathname)
        || [...document.querySelectorAll('input[type="password"]')].some(visible);
    const register = (node, kind, title) => {
        if (!ids.has(node)) ids.set(node, String(++nextID));
        const id = ids.get(node);
        targets.set(id, { node, signature: signature(node), kind });
        return {id, kind, text: title, disabled: node.disabled === true || node.getAttribute('aria-disabled') === 'true'};
    };
    const feedPosts = root => {
        if (location.pathname !== '/' && !/\/(p|reel)\/[^/]+\/?$/.test(location.pathname)) return [];
        const controls = node => [...node.querySelectorAll('button,[role="button"]')].filter(visible);
        const isLike = node => !node.querySelector('button,[role="button"]') && ['like','unlike'].includes(label(node).toLowerCase());
        const media = node => [...node.querySelectorAll('img,video')].filter(n => {
            const rect = n.getBoundingClientRect();
            return visible(n) && rect.width >= innerWidth * 0.6 && rect.height >= 120
                && !n.getAttribute('alt')?.includes('profile picture');
        });
        const containers = new Set();
        for (const like of controls(root).filter(isLike)) {
            let container = like.parentElement;
            for (let depth = 0; container && container !== document.body && depth < 10; depth++,container=container.parentElement) {
                if (controls(container).filter(isLike).length !== 1) break;
                if (media(container).length) {
                    const parent = container.parentElement;
                    if (parent && parent !== document.body && controls(parent).filter(isLike).length === 1
                        && parent.querySelector('img[alt*="profile picture"]')) container = parent;
                    containers.add(container); break;
                }
            }
        }
        const posts = [];
        for (const container of containers) {
            if (!nearby(container) || posts.length >= 10) continue;
            const actions = controls(container).filter(n => !n.querySelector('button,[role="button"]'));
            const links = [...container.querySelectorAll('a[href]')].filter(visible);
            const profile = links.find(n => {
                try { const url = new URL(n.href,location.href); return url.origin === location.origin
                    && /^\/[^/]+\/$/.test(url.pathname) && !['p','reels','explore','direct','stories'].includes(url.pathname.split('/')[1]); }
                catch { return false; }
            });
            let author = null;
            if (profile) {
                const username = new URL(profile.href,location.href).pathname.split('/')[1];
                const target = links.find(n => n.href === profile.href && !n.querySelector('img')) || profile;
                author = register(target,'action',username);
                const avatar = container.querySelector('img[alt*="profile picture"]');
                if (avatar) author.source = allowedMedia(avatar.currentSrc || avatar.getAttribute('src'));
            }
            const postMedia = media(container).slice(0,10).map(node => {
                const src = allowedMedia(node.currentSrc || node.getAttribute('src'));
                const item = register(node,node.tagName === 'VIDEO' ? (src ? 'video' : 'web') : 'image',node.getAttribute('alt') || 'Post media');
                if (src) item.source=src;
                const rect = node.getBoundingClientRect(); item.aspectRatio=rect.width / rect.height;
                return item;
            });
            const postActions = actions.filter(n => ['like','unlike','comment','comments','repost','share','share post','save','unsave','remove from saved','more options'].includes(label(n).toLowerCase()))
                .map(n => register(n,'action',label(n)));
            const captions = [...container.querySelectorAll('span[dir="auto"],div[dir="auto"]')]
                .filter(n=>visible(n) && !n.closest('button,[role="button"]') && !n.querySelector('button,[role="button"]'))
                .map(n=>normalize(n.innerText)).filter(value=>value.length > 30);
            const caption = captions.sort((a,b)=>b.length-a.length)[0]?.slice(0,4000) || '';
            const commentsLink=links.find(node=>{ try { return new URL(node.href,location.href).pathname.endsWith('/comments/'); } catch { return false; } });
            posts.push({id:register(container,'post','Post').id,author,media:postMedia,actions:postActions,caption,commentsLink:commentsLink ? register(commentsLink,'action',label(commentsLink)) : null});
        }
        return posts;
    };
    const commentRows = root => {
        if (/^\/(direct|stories|accounts)(\/|$)/.test(location.pathname)) return [];
        const replies=[...root.querySelectorAll('button,[role="button"]')].filter(node=>visible(node) && label(node).toLowerCase()==='reply');
        const rows=[];
        for(const reply of replies) {
            const listRow=reply.closest('li,[role="listitem"]');
            const candidates=[];
            if(listRow)candidates.push(listRow);
            else for(let node=reply.parentElement,depth=0;node && node!==document.body && depth<10;node=node.parentElement,depth++)candidates.push(node);
            for(const row of candidates) {
                const controls=[...row.querySelectorAll('button,[role="button"]')].filter(node=>visible(node)
                    && (!listRow || node.closest('li,[role="listitem"]')===row));
                if(controls.filter(node=>label(node).toLowerCase()==='reply').length!==1)continue;
                const like=controls.find(node=>!node.querySelector('button,[role="button"]') && /^(unlike|like)( comment)?$/.test(label(node).toLowerCase()));
                const links=[...row.querySelectorAll('a[href]')].filter(node=>{
                    try{const url=new URL(node.href,location.href);return url.origin===location.origin && /^\/[^/]+\/$/.test(url.pathname)
                        && !['p','reels','direct','explore','stories'].includes(url.pathname.split('/')[1]);}catch{return false;}
                });
                const author=row.querySelector('h3 a') || links.find(node=>normalize(node.innerText) && !node.querySelector('img')) || links[0]
                    || row.querySelector('h3,h2,[role="heading"]');
                if(!listRow && (!like || !author))continue;
                let username=author ? label(author) : '';
                if(author?.matches('a[href]'))username=new URL(author.href,location.href).pathname.split('/')[1];
                const rowID=register(row,'comment','Comment').id;
                const authorItem=author ? register(author,author.matches('a[href],button,[role="button"]')?'action':'text',username)
                    : {id:`author-${rowID}`,kind:'text',text:'',disabled:false};
                const avatar=row.querySelector('img');
                if(avatar)authorItem.source=allowedMedia(avatar.currentSrc||avatar.getAttribute('src'));
                const parts=[];
                const collect=node=>{
                    if(node.nodeType===3){const value=normalize(node.textContent);if(value && value!==username && !/^\d+\s*[smhdw]$/.test(value))parts.push(value);}
                    else if(node.nodeType===1 && visible(node)){
                        if(node!==row && (node.matches('button,[role="button"],h3,h2,[role="heading"]')
                            || (listRow && node.matches('li,[role="listitem"]'))))return;
                        for(const child of node.childNodes)collect(child);
                    }
                };
                collect(row);
                const timeNode=[...row.querySelectorAll('time,a,span')].find(node=>/^\d+\s*[smhdw]$/.test(normalize(node.innerText||node.textContent)));
                rows.push({id:rowID,author:authorItem,text:parts.join(' ').slice(0,4000),timestamp:timeNode?normalize(timeNode.innerText||timeNode.textContent):null,actions:controls.filter(node=>node===reply || node===like
                    || (['see translation','comment options'].includes(label(node).toLowerCase()) || /^\d[\d.,KMB]*\s+likes?$/i.test(label(node)))).map(node=>register(node,'action',label(node)))});
                break;
            }
            if(rows.length>=50)break;
        }
        return rows;
    };
    const profileData = root => {
        const parts=location.pathname.split('/').filter(Boolean);
        if (root !== document.body || parts.length < 1 || parts.length > 2
            || (parts.length===2 && !['reels','tagged','reposts','saved'].includes(parts[1]))
            || ['accounts','explore','direct','stories','reels','p','notifications','activity','archive'].includes(parts[0])) return null;
        const links=[...root.querySelectorAll('a[href]')].filter(visible);
        const controls=[...root.querySelectorAll('button,[role="button"]')].filter(visible);
        const avatar=[...root.querySelectorAll('img')].find(node=>{
            const rect=node.getBoundingClientRect();
            return visible(node) && rect.width>=70 && rect.width<=170 && Math.abs(rect.width-rect.height)<5;
        });
        const stats=links.filter(node=>/^\d[\d.,KMB]*\s+(followers|following|posts)$/i.test(label(node)))
            .map(node=>register(node,'action',label(node)));
        const postsCount=[...root.querySelectorAll('span')].find(node=>visible(node) && /^\d[\d.,KMB]*\s+posts$/i.test(normalize(node.innerText || node.textContent)));
        if (postsCount && !stats.some(item=>item.text.toLowerCase().endsWith('posts'))) stats.unshift({id:'posts-count',kind:'text',text:normalize(postsCount.innerText),disabled:false});
        const actions=[...links,...controls].filter(node=>['edit profile','view archive','options','follow','following','message'].includes(label(node).toLowerCase()))
            .map(node=>register(node,'action',label(node)));
        const highlights=links.filter(node=>{try{return new URL(node.href,location.href).pathname.startsWith('/stories/highlights/');}catch{return false;}}).map(node=>{
            const item=register(node,'action',label(node)); const image=node.querySelector('img');
            if(image)item.source=allowedMedia(image.currentSrc||image.getAttribute('src')); return item;
        });
        const tabs=links.filter(node=>['posts','reels','saved','reposts','tagged'].includes(label(node).toLowerCase())).map(node=>register(node,'action',label(node)));
        const grid=links.filter(node=>{try{return /\/(p|reel)\/[^/]+\/?$/.test(new URL(node.href,location.href).pathname);}catch{return false;}}).slice(0,60).map(node=>{
            const item=register(node,'action',label(node)); const image=node.querySelector('img');
            if(image)item.source=allowedMedia(image.currentSrc||image.getAttribute('src')); return item;
        });
        const top=avatar?.getBoundingClientRect().top ?? 0;
        const highlightTop=links.find(node=>{try{return new URL(node.href,location.href).pathname.startsWith('/stories/highlights/');}catch{return false;}})?.getBoundingClientRect().top ?? top+250;
        const about=[...root.querySelectorAll('span[dir="auto"],div[dir="auto"]')].filter(node=>{
            const rect=node.getBoundingClientRect(); return visible(node) && rect.top>=top && rect.top<highlightTop
                && !node.closest('a,button,[role="button"],h1') && !node.querySelector('[dir="auto"]');
        }).map(node=>normalize(node.innerText)).filter(value=>value && value !== parts[0] && !/^\d[\d.,KMB]*\s+(posts|followers|following)$/i.test(value));
        if (!stats.length && !actions.length && !grid.length) return null;
        return {username:parts[0],avatar:avatar ? allowedMedia(avatar.currentSrc||avatar.getAttribute('src')) : null,
            stats,about:[...new Set(about)].slice(0,8),actions,highlights,tabs,grid};
    };
    const setEnabled = value => { if (document.documentElement) document.documentElement.dataset.achaarNative = String(value === true); };
    const snapshot = () => {
        setEnabled(true);
        targets = new Map();
        const page = `${documentID}|${location.href}`;
        if (!document.body || sensitivePage()) return {page, title:'Instagram', fallback:true, items:[]};
        const root = getRoot();
        if (location.pathname.startsWith('/stories/') && root === document.body && ![...root.querySelectorAll('button,[role="button"]')].some(node=>visible(node) && label(node).toLowerCase()==='close')) return {page,title:'Stories',fallback:true,items:[]};
        const items = [];
        const visit = node => {
            if (items.length >= 300) return;
            if (node.nodeType === 3) {
                const text = normalize(node.textContent);
                if (text && visible(node.parentElement) && nearby(node.parentElement)) items.push({id:`text-${items.length}`,kind:'text',text:text.slice(0,4000),disabled:false});
                return;
            }
            if (node.nodeType !== 1 || !visible(node) || !nearby(node) || node.matches('script,style,noscript,svg,nav,[role="navigation"]')) return;
            // Authentication, billing, file uploads, and custom widgets stay in WebKit.
            if (node.matches('input') && !isEditor(node)) {
                items.push(register(node, 'web', label(node) || 'Open this control in Instagram'));
                return;
            }
            if (isEditor(node)) {
                if (node.getAttribute('autocomplete')?.includes('password') || node.getAttribute('autocomplete') === 'one-time-code') return;
                const item = register(node, 'editor', label(node) || (location.pathname.startsWith('/stories/') ? 'Reply to story' : 'Write a message or comment'));
                item.value = (node.value ?? node.innerText ?? '').slice(0,10000);
                items.push(item); return;
            }
            if (node.matches('select,[role="combobox"],iframe,canvas')) {
                items.push(register(node,'web',label(node) || 'Open in Instagram')); return;
            }
            if (node.matches('video')) {
                const src = allowedMedia(node.currentSrc || node.getAttribute('src'));
                const item = register(node, src ? 'video' : 'web', 'Play video');
                if (src) item.source = src;
                items.push(item); return;
            }
            if (node.matches('img')) {
                const src = allowedMedia(node.currentSrc || node.getAttribute('src'));
                if (src) {
                    const item = register(node,'image',node.getAttribute('alt') || 'Instagram image');
                    item.source = src; items.push(item);
                }
                return;
            }
            if (node.matches(actionSelector)) {
                const title = label(node);
                // Composite comment rows are also buttons; preserve their Reply,
                // Like, translation, and pagination children instead of flattening.
                const nested = node.querySelector(`${actionSelector},textarea,input,[contenteditable="true"]`);
                if (nested && title && node.matches('a[href]')) {
                    const item=register(node,'action',title.slice(0,1000));
                    const preview=node.querySelector('img');
                    if(preview)item.source=allowedMedia(preview.currentSrc||preview.getAttribute('src'));
                    items.push(item);
                    for(const control of node.querySelectorAll('button,[role="button"]')) {
                        if(visible(control) && label(control))items.push(register(control,'action',label(control)));
                    }
                    return;
                }
                if (!nested && title) {
                    const item = register(node, /^story by /i.test(title) ? 'story' : 'action', title.slice(0,1000));
                    const preview = node.querySelector('img');
                    const previewSource = preview && allowedMedia(preview.currentSrc || preview.getAttribute('src'));
                    if (previewSource) item.source = previewSource;
                    item.selected = node.getAttribute('aria-pressed') === 'true' || node.getAttribute('aria-selected') === 'true'
                        || node.getAttribute('aria-checked') === 'true';
                    items.push(item); return;
                }
            }
            for (const child of node.childNodes) visit(child);
        };
        visit(root);
        const searchInput=[...root.querySelectorAll('input')].find(node=>visible(node) && /search/i.test(label(node)));
        if (searchInput && !items.some(item=>item.id===ids.get(searchInput))) {
            const editor=register(searchInput,'editor',label(searchInput));
            editor.value=searchInput.value || ''; items.unshift(editor);
        }
        const searching=searchInput && (document.activeElement===searchInput || requestedSearchPage===location.href);
        const profile = profileData(root);
        const comments = commentRows(root);
        const title = searching ? 'Search' : profile ? profile.username : comments.length || location.pathname.endsWith('/comments/') ? 'Comments' : location.pathname.startsWith('/stories/') ? 'Stories' : location.pathname.startsWith('/direct/') ? 'Messages'
            : location.pathname.startsWith('/reels/') ? 'Reels' : location.pathname.startsWith('/explore/') ? 'Search'
            : location.pathname === '/' ? 'Home' : /\/(p|reel)\/[^/]+\/?$/.test(location.pathname) ? 'Post' : 'Instagram';
        const posts = feedPosts(root);
        const storyAuthor = title === 'Stories' ? [...root.querySelectorAll('a[href]')].find(node=>visible(node) && normalize(node.innerText)) : null;
        const commentFields=comments.length ? [...root.querySelectorAll('textarea,input,[role="textbox"]')].filter(node=>visible(node) && isEditor(node) && !/search/i.test(label(node))) : [];
        const commentInput=commentFields.find(node=>/comment/i.test(label(node))) || commentFields.at(-1);
        const genericEditor=items.find(item=>item.kind==='editor' && !/search/i.test(item.text));
        const commentEditor=commentInput ? register(commentInput,'editor',label(commentInput)||'Add a comment…') : (comments.length && genericEditor ? {...genericEditor,text:'Add a comment…'} : null);
        if(commentEditor && commentInput)commentEditor.value=(commentInput.value ?? commentInput.innerText ?? '').slice(0,10000);
        const moreComments=comments.length ? [...root.querySelectorAll('button,[role="button"]')].find(node=>visible(node) && label(node).toLowerCase()==='load more comments') : null;
        const commentMore=moreComments ? register(moreComments,'action',label(moreComments)) : null;
        const navAvatar=document.querySelector('.achaar-verified-bottom-navigation img');
        return {page,title,fallback:items.length === 0 && !posts.length && !comments.length && !profile,items,posts,comments,profile,commentEditor,commentMore,searching:!!searching,navigationAvatar:navAvatar ? allowedMedia(navAvatar.currentSrc||navAvatar.getAttribute('src')) : null,storyAuthor:storyAuthor ? register(storyAuthor,'action',label(storyAuthor)) : null};
    };
    const act = ({page,id,operation,value}) => {
        if (page !== `${documentID}|${location.href}` || sensitivePage()) return 'stale';
        const target = targets.get(id);
        if (!target || !visible(target.node) || signature(target.node) !== target.signature
            || !getRoot().contains(target.node)) return 'stale';
        const node = target.node;
        if (node.disabled || node.getAttribute('aria-disabled') === 'true') return 'disabled';
        if (operation === 'edit' && target.kind === 'editor' && isEditor(node) && typeof value === 'string' && value.length <= 10000) {
            if (node.readOnly || (node.maxLength >= 0 && value.length > node.maxLength)) return 'unsupported';
            if (node.matches('input,textarea')) {
                const prototype = node.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
                const setter = Object.getOwnPropertyDescriptor(prototype,'value')?.set;
                if (!setter) return 'unsupported';
                setter.call(node,value);
            } else {
                // Rich editors depend on browser editing/selection and trusted
                // input; never claim a message was entered using textContent.
                return 'unsupported';
            }
            node.dispatchEvent(new Event('input',{bubbles:true}));
            node.dispatchEvent(new Event('change',{bubbles:true}));
            return 'dispatched'; // Editing never presses Enter or submits.
        }
        if (operation === 'activate' && ['action','story'].includes(target.kind)) {
            if (typeof node.click !== 'function') return 'unsupported';
            if(node.matches('a[href]') || label(node).toLowerCase()==='back')requestedSearchPage=null;
            node.click(); return 'dispatched';
        }
        return 'unsupported';
    };
    const compose = async ({page,id,value}) => {
        const result = act({page,id,operation:'edit',value});
        if (result !== 'dispatched') return result;
        const editor = targets.get(id)?.node;
        for (let attempt=0; attempt<15; attempt++) {
            if (page !== `${documentID}|${location.href}` || !visible(editor) || sensitivePage()) return 'stale';
            let scope = editor.parentElement;
            for (let depth=0; scope && scope !== document.body && depth<5; depth++,scope=scope.parentElement) {
                const editors = [...scope.querySelectorAll('textarea,input,[contenteditable="true"],[role="textbox"]')].filter(visible);
                if (editors.length !== 1 || editors[0] !== editor) break;
                const buttons = [...scope.querySelectorAll('button,[role="button"]')].filter(node=>visible(node)
                    && !node.disabled && node.getAttribute('aria-disabled') !== 'true'
                    && ['send','post','reply'].includes(label(node).toLowerCase()));
                if (buttons.length > 1) return 'unsupported';
                if (buttons.length === 1 && getRoot().contains(buttons[0])) {
                    buttons[0].click(); return 'dispatched';
                }
            }
            await new Promise(resolve=>setTimeout(resolve,100));
        }
        return 'draftOnly';
    };
    const openSearch = () => {
        if(sensitivePage())return false;
        const field=[...document.querySelectorAll('input')].find(node=>visible(node) && /search/i.test(label(node)));
        requestedSearchPage=location.href;
        if(field){field.focus({preventScroll:true});field.click();return true;}
        const button=[...document.querySelectorAll('button,[role="button"]')].find(node=>visible(node) && label(node).toLowerCase()==='search');
        if(button){button.click();return true;}
        requestedSearchPage=null;return false;
    };
    const closeSearch = () => {
        requestedSearchPage=null;
        const button=[...document.querySelectorAll('button,[role="button"]')].find(node=>visible(node) && label(node).toLowerCase()==='back');
        if(!button)return false;
        button.click();return true;
    };
    const scroll = direction => {
        if (sensitivePage() || ![-1,1].includes(direction)) return false;
        const root = getRoot();
        const candidates = [root,...root.querySelectorAll('*')].filter(node => visible(node)
            && node.scrollHeight > node.clientHeight + 20 && ['auto','scroll'].includes(getComputedStyle(node).overflowY));
        const target = candidates.sort((a,b) => b.clientHeight - a.clientHeight)[0] || document.scrollingElement;
        if (!target) return false;
        target.scrollBy({top:direction * Math.max(200,target.clientHeight * 0.75),behavior:'instant'});
        return true;
    };
    window.AchaarNative = Object.freeze({snapshot,act,compose,scroll,setEnabled,openSearch,closeSearch});
})();
