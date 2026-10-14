// Dependency-free DOM fixtures for the bundled native bridge.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../Achaar/Resources/Web/NativeSurface.js', import.meta.url),'utf8');
class Element {
    nodeType = 1; isConnected = true; hidden = false; disabled = false;
    childNodes = []; attrs = {}; events = []; clicks = 0;
    constructor(tag, attrs = {}, text = '') { this.tagName=tag.toUpperCase(); this.attrs=attrs; this.text=text; }
    get href() { return this.attrs.href ? new URL(this.attrs.href,'https://www.instagram.com').href : undefined; }
    get children() { return this.childNodes.filter(n=>n.nodeType===1); }
    hasAttribute(name) { return this.attrs[name] != null; }
    get innerText() { return this.text + this.childNodes.map(n=>n.innerText ?? n.textContent ?? '').join(' '); }
    get textContent() { return this.innerText; }
    getAttribute(name) { return this.attrs[name] ?? null; }
    matches(selectors) {
        return selectors.split(',').some(raw => {
            let selector=raw.trim();
            const not=selector.match(/:not\(([^)]+)\)/);
            if (not) { if (this.matches(not[1])) return false; selector=selector.replace(not[0],''); }
            const tag=selector.match(/^[a-z][a-z0-9-]*/i)?.[0];
            if (tag && tag.toUpperCase() !== this.tagName) return false;
            return [...selector.matchAll(/\[([^=\]]+)(?:=["']?([^\]"']+)["']?)?\]/g)]
                .every(([,name,value])=>value === undefined ? this.attrs[name] != null : this.attrs[name] === value);
        });
    }
    closest(selector) { return this.matches(selector) ? this : this.parentElement?.closest(selector) ?? null; }
    querySelectorAll(selector) {
        if (selector === 'svg title') return [];
        if (selector === 'h3 a') return this.querySelectorAll('a').filter(n=>n.closest('h3'));
        return this.childNodes.filter(n=>n.nodeType===1).flatMap(n=>[...(n.matches(selector) ? [n]:[]),...n.querySelectorAll(selector)]);
    }
    querySelector(selector) { return this.querySelectorAll(selector)[0] ?? null; }
    append(...nodes) { for (const node of nodes) { node.parentElement=this; this.childNodes.push(node); } return this; }
    contains(node) { return node===this || this.childNodes.some(n=>n.nodeType===1 && n.contains(node)); }
    getClientRects() { return this.hidden ? [] : [{}]; }
    getBoundingClientRect() { return this.rect ?? {top:10,bottom:60,width:100,height:50}; }
    focus() { this.focused=true; }
    click() { this.clicks++; }
    dispatchEvent(event) { this.events.push(event.type); }
}
class Input extends Element { get value() { return this._value ?? ''; } set value(value) { this._value=value; } }
class TextArea extends Element { get value() { return this._value ?? ''; } set value(value) { this._value=value; } }
const text = value => ({nodeType:3,textContent:value});
function fixture(path='/') {
    const body = new Element('body');
    const document = {body,querySelector:selector=>selector.startsWith('.') ? null : body.querySelector(selector),querySelectorAll:selector=>body.querySelectorAll(selector),scrollingElement:body};
    const location = {origin:'https://www.instagram.com',hostname:'www.instagram.com',protocol:'https:',pathname:path,href:`https://www.instagram.com${path}`};
    const window={}; window.top=window;
    vm.runInNewContext(source,{window,document,location,innerHeight:800,innerWidth:390,URL,Date,Math,setTimeout:fn=>queueMicrotask(fn),
        getComputedStyle:()=>({visibility:'visible',display:'block',overflowY:'visible'}),
        HTMLTextAreaElement:TextArea,HTMLInputElement:Input,Event:class { constructor(type) {this.type=type;} }});
    return {body,document,location,api:window.AchaarNative};
}
let checks=0;
function equal(actual,expected,message) {assert.deepEqual(actual,expected,message ?? ""); checks++;}
const f=fixture('/stories/fixture/');
const editor=new TextArea('textarea',{placeholder:'Reply to fixture...'});
const send=new Element('button',{},'Send');
const close=new Element('button',{},'Close');
f.body.append(editor,send,close);
let snapshot=f.api.snapshot();
equal(snapshot.title,'Stories','Story screen title');
equal(snapshot.items.map(n=>n.kind).join(','),'editor,action,action','Native story controls');
const reply=snapshot.items[0];
equal(f.api.act({page:snapshot.page,id:reply.id,operation:'edit',value:'Draft only'}),'dispatched');
equal(editor.value,'Draft only');
equal(editor.events.join(','),'input,change','Controlled inputs receive events');
equal(send.clicks,0,'Editing never sends');
equal(f.api.act({page:snapshot.page,id:snapshot.items[1].id,operation:'activate'}),'dispatched');
equal(send.clicks,1,'A tap dispatches exactly once');
send.text='Delete';
equal(f.api.act({page:snapshot.page,id:snapshot.items[1].id,operation:'activate'}),'stale','Changed action label is rejected');
equal(send.clicks,1);
close.isConnected=false;
equal(f.api.act({page:snapshot.page,id:snapshot.items[2].id,operation:'activate'}),'stale','Detached node is rejected');
f.location.href+='?changed=true';
equal(f.api.act({page:snapshot.page,id:reply.id,operation:'edit',value:'No'}),'stale','Navigation invalidates handles');
const modalFixture=fixture();
const background=new Element('button',{},'Background action');
modalFixture.body.append(background);
const old=modalFixture.api.snapshot();
const dialog=new Element('div',{role:'dialog'}).append(new Element('button',{},'Cancel'));
modalFixture.body.append(dialog);
equal(modalFixture.api.act({page:old.page,id:old.items[0].id,operation:'activate'}),'stale','Modal blocks background controls');
equal(modalFixture.api.snapshot().items.map(n=>n.text).join(','),'Cancel','Only frontmost dialog is rendered');
const sensitive=fixture('/accounts/edit/');
sensitive.body.append(new Input('input',{type:'text'}));
equal(sensitive.api.snapshot().fallback,true,'Account settings use website');
equal(sensitive.api.snapshot().items.length,0,'Sensitive forms are not extracted');
const password=fixture(); password.body.append(new Input('input',{type:'password'}));
equal(password.api.snapshot().fallback,true,'Password on unexpected route uses website');
const media=fixture();
media.body.append(new Element('img',{src:'https://cdninstagram.com/image.jpg',alt:'Photo'}),
    new Element('img',{src:'https://cdninstagram.com.evil.example/image.jpg'}),
    new Element('video',{src:'blob:https://www.instagram.com/private-video'}));
equal(media.api.snapshot().items.map(n=>n.kind).join(','),'image,web','Only permitted HTTPS media; blob video uses website');
const comments=fixture('/p/example/');
const row=new Element('div',{role:'button'}).append(new Element('span').append(text('A comment')),
    new Element('button',{},'Reply'),new Element('button',{},'Like'));
comments.body.append(row,new Element('button',{},'Load more comments'));
equal(comments.api.snapshot().items.map(n=>n.text).join(','),'A comment,Reply,Like,Load more comments','Nested comment actions stay separate');
const rich=fixture('/direct/t/example/'); rich.body.append(new Element('div',{contenteditable:'true'},'Draft'));
const richSnapshot=rich.api.snapshot();
equal(rich.api.act({page:richSnapshot.page,id:richSnapshot.items[0].id,operation:'edit',value:'New'}),'unsupported','Rich editing uses website instead of unreliable textContent changes');
equal(rich.body.childNodes[0].innerText,'Draft');
const hidden=fixture();
hidden.body.append(new Element('div',{'aria-hidden':'true'}).append(new Element('button',{},'Hidden')),
    new Element('button',{'aria-disabled':'true'},'Unavailable'));
const h=hidden.api.snapshot();
equal(h.items.map(n=>n.text).join(','),'Unavailable');
equal(hidden.api.act({page:h.page,id:h.items[0].id,operation:'activate'}),'disabled');
const limits=fixture('/direct/t/fixture/');
const limited=new TextArea('textarea',{placeholder:'Reply'}); limited.maxLength=3;
limits.body.append(limited);
const limitedSnapshot=limits.api.snapshot();
equal(limits.api.act({page:limitedSnapshot.page,id:limitedSnapshot.items[0].id,operation:'edit',value:'Long'}),'unsupported','Website field length is respected');
equal(limited.value,'');
limited.readOnly=true;
equal(limits.api.act({page:limitedSnapshot.page,id:limitedSnapshot.items[0].id,operation:'edit',value:'OK'}),'unsupported','Read-only fields cannot be changed');
const composing=fixture('/direct/t/fixture/');
const form=new Element('form');
const message=new TextArea('textarea',{placeholder:'Reply'});
const scopedSend=new Element('button',{},'Send');
const unrelatedSend=new Element('button',{},'Send');
form.append(message,scopedSend); composing.body.append(form,unrelatedSend);
const c=composing.api.snapshot();
equal(await composing.api.compose({page:c.page,id:c.items[0].id,value:'Explicit native Send'}),'dispatched');
equal(scopedSend.clicks,1,'Explicit Send activates the editor’s own send button exactly once');
equal(unrelatedSend.clicks,0,'Other Send buttons are never used');
const noSend=fixture('/direct/t/example/');
const unsent=new TextArea('textarea',{placeholder:'Message'}); noSend.body.append(new Element('form').append(unsent));
const u=noSend.api.snapshot();
equal(await noSend.api.compose({page:u.page,id:u.items[0].id,value:'Keep as draft'}),'draftOnly','Missing submit keeps a draft and asks for web fallback');
equal(unsent.value,'Keep as draft');
const profileFixture=fixture('/fixture_user/');
const avatar=new Element('img',{src:'https://cdninstagram.com/avatar.jpg'}); avatar.rect={top:80,bottom:164,width:84,height:84};
profileFixture.body.append(avatar,new Element('a',{href:'/fixture_user/followers/'},'100 followers'),
    new Element('a',{href:'/fixture_user/following/'},'80 following'),new Element('span',{},'12 posts'),
    new Element('a',{href:'/accounts/edit/'},'Edit profile'),
    new Element('a',{href:'/fixture_user/'},'Posts'),
    new Element('a',{href:'/p/example/','aria-label':'Post preview'}).append(new Element('img',{src:'https://cdninstagram.com/post.jpg'})));
const p=profileFixture.api.snapshot();
equal(p.title,'fixture_user');
equal(p.profile.stats.map(n=>n.text).join(','),'12 posts,100 followers,80 following','Profile statistics keep their actual website values');
equal(p.profile.actions[0].text,'Edit profile');
equal(p.profile.grid.length,1,'Only observed media links enter the profile grid');
equal(p.profile.grid[0].source,'https://cdninstagram.com/post.jpg');
const searchFixture=fixture();
const searchInput=new Input('input',{'aria-label':'Search input'});
searchFixture.document.activeElement=searchInput;
searchFixture.body.append(searchInput,new Element('a',{href:'/instagram/','aria-label':'Instagram account'}).append(new Element('button',{},'Close')));
const searchSnapshot=searchFixture.api.snapshot();
equal(searchSnapshot.title,'Search','Search state is recognized even when the URL stays Home');
equal(searchSnapshot.items.filter(n=>n.kind==='action').some(n=>n.text==='Instagram account'),true,'Nested result controls do not erase the result link');
const dedicatedComments=fixture('/p/example/');
const commentRoot=new Element('div'); commentRoot.rect={top:5000,bottom:5100,width:390,height:100};
commentRoot.append(new Element('h3').append(new Element('a',{href:'/fixture_author/'},'fixture_author')),
    new Element('span').append(text('Rendered comment body')),
    new Element('div').append(new Element('button',{},'Reply')),new Element('button').append(new Element('svg',{'aria-label':'Like'})));
dedicatedComments.body.append(commentRoot,new TextArea('textarea',{placeholder:'Add a comment…'}));
const dc=dedicatedComments.api.snapshot();
equal(dc.title,'Comments');
equal(dc.comments.length,1,'Rendered comments outside the viewport are available natively');
equal(dc.comments[0].text,'Rendered comment body');
equal(dc.comments[0].author.text,'fixture_author');
equal(dc.comments[0].actions.some(n=>n.text==='Like'),true,'Icon-only mobile comment Like controls are recognized');
equal(dc.commentEditor.text,'Add a comment…');
equal(dc.fallback,false);
const mobileComments=fixture('/p/mobile/');
mobileComments.body.append(new Element('li').append(new Element('span').append(text('Mobile comment body')),new Element('button',{},'Reply')));
const mc=mobileComments.api.snapshot();
equal(mc.title,'Comments','Semantic mobile comment rows do not require a visible Like icon');
equal(mc.comments[0].text,'Mobile comment body');
equal(mc.comments[0].author.text,'','Unavailable author metadata is not invented');
const skippedLayout=fixture('/p/offscreen/');
const offscreenReply=new Element('button');
Object.defineProperty(offscreenReply,'innerText',{get:()=>''});
Object.defineProperty(offscreenReply,'textContent',{get:()=>'Reply'});
skippedLayout.body.append(new Element('li').append(new Element('span').append(text('Offscreen rendered comment')),offscreenReply));
equal(skippedLayout.api.snapshot().comments.length,1,'Content-visibility does not erase offscreen Reply labels');
const searchFocus=fixture('/explore/');
const focusField=new Input('input',{placeholder:'Search'});searchFocus.body.append(focusField);
equal(searchFocus.api.openSearch(),true);
equal(focusField.focused,true,'Native search focuses the actual website field, not the navigation tab');
equal(searchFocus.api.snapshot().searching,true,'Search state survives native keyboard focus');
const timestampComments=fixture('/p/timestamps/');
timestampComments.body.append(new Element('li').append(new Element('span').append(text('Comment with time')),
    new Element('span').append(text('14h')),new Element('button',{},'Reply')));
const timed=timestampComments.api.snapshot().comments[0];
equal(timed.text,'Comment with time','Timestamps stay out of comment body text');
equal(timed.timestamp,'14h','Timestamps remain available for the comment footer');
const nestedComments=fixture('/p/nested/');
nestedComments.body.append(new Element('li').append(new Element('span').append(text('Parent comment')),new Element('button',{},'Reply'),
    new Element('ul').append(new Element('li').append(new Element('span').append(text('Child reply')),new Element('button',{},'Reply')))));
const nested=nestedComments.api.snapshot().comments;
equal(nested.length,2,'Nested replies produce separate comment rows');
equal(nested[0].text,'Parent comment','Nested reply text does not leak into its parent');
equal(nested[1].text,'Child reply');
console.log(`Native bridge: ${checks} checks passed.`);
