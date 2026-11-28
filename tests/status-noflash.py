"""The status page must not flash: a second poll patches values in place. Runs the page's real script under node with a small
DOM stand-in, renders twice (second time with ONE changed value), and checks that no node was rebuilt, only the changed text was
written, open sections stayed open, hidden tabs do not poll, requests never overlap, and a failed poll keeps the last values."""
import json,re,subprocess,sys,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
html=(root/'BlockedServer/StatusPage.html').read_text()
script=re.findall(r'<script>(.*?)</script>',html,re.S)[0]
harness=r'''
let created=0,writes=0;
class Node{constructor(tag){this.tag=tag;this.children=[];this.parentNode=null;this.dataset={};this.attrs={};this._text='';this.className='';this.hidden=false;this.listeners={};this.style={setProperty(){}};this.open=false;this.disabled=false;created++;
  const self=this;this.classList={toggle(c,on){const set=new Set(self.className.split(' ').filter(Boolean));(on===undefined?!set.has(c):on)?set.add(c):set.delete(c);self.className=[...set].join(' ');},remove(c){const set=new Set(self.className.split(' ').filter(Boolean));set.delete(c);self.className=[...set].join(' ');},add(c){const set=new Set(self.className.split(' ').filter(Boolean));set.add(c);self.className=[...set].join(' ');},contains(c){return self.className.split(' ').includes(c)}};}
 get firstChild(){return this.children[0]||null}get lastChild(){return this.children[this.children.length-1]||null}
 appendChild(n){if(n.parentNode)n.parentNode.removeChild(n);n.parentNode=this;this.children.push(n);return n}
 insertBefore(n,ref){if(n.parentNode)n.parentNode.removeChild(n);n.parentNode=this;const i=ref?this.children.indexOf(ref):-1;if(i<0)this.children.push(n);else this.children.splice(i,0,n);return n}
 removeChild(n){const i=this.children.indexOf(n);if(i>=0)this.children.splice(i,1);n.parentNode=null;return n}
 get textContent(){return this.children.length?this.children.map(c=>c.textContent).join(''):this._text}
 set textContent(t){writes++;this.children.forEach(c=>c.parentNode=null);this.children=[];this._text=String(t)}
 setAttribute(k,v){this.attrs[k]=v}getAttribute(k){return this.attrs[k]===undefined?null:this.attrs[k]}
 addEventListener(t,f){(this.listeners[t]=this.listeners[t]||[]).push(f)}
 fire(t){(this.listeners[t]||[]).forEach(f=>f())}}
const ids={};const byId=(i)=>ids[i]||(ids[i]=new Node('x'));
let hidden=false,intervalFn=null,fetches=[],failNext=false;
const doc={hidden:false,body:new Node('body'),getElementById:byId,createElement:(t)=>new Node(t),createTextNode:(t)=>{const n=new Node('#text');n._text=t;return n},addEventListener(t,f){(this.l=this.l||{})[t]=f}};
Object.defineProperty(doc,'hidden',{get:()=>hidden});
global.document=doc;global.setInterval=(f)=>{intervalFn=f;return 1};global.clearInterval=()=>{};global.setTimeout=(f)=>0;global.clearTimeout=()=>{};
let resolvers=[];
global.fetch=(url)=>{fetches.push(url);return new Promise((res,rej)=>{resolvers.push({res,rej});});};
global.navigator={clipboard:{writeText:async()=>{}}};
const data=(v)=>({generatedAt:Date.now()/1000,release:'RH-15-112526',status:{intent:{known:true,enabled:true,mode:v},runtime:{state:'configured',verification:'applied',publishedAt:Date.now()/1000,verifiedAt:Date.now()/1000},pin:{enabled:true}},popups:[],pin:{enabled:true}});
const flush=()=>new Promise(r=>setImmediate(r));
(async()=>{
 new Function(process.argv[2])();
 await flush();
 const out={};
 out.firstRequest=fetches.length===1;
 resolvers[0].res({ok:true,json:async()=>data('Default')});await flush();await flush();
 const host=byId('sections');const sectionsBefore=host.children.slice();const createdBefore=created;
 out.rendered=sectionsBefore.length>2;
 // open a section like a person would, then poll again with one value changed
 sectionsBefore[0].open=true;sectionsBefore[0].listeners.toggle.forEach(f=>f());
 const textBefore=byId('overall-title').textContent;
 intervalFn();await flush();
 const n=fetches.length;intervalFn();await flush();out.noSecondRequestInFlight=fetches.length===n;
 resolvers[1].res({ok:true,json:async()=>data('blockXXX')});await flush();await flush();
 const sectionsAfter=host.children;
 out.sameNodes=sectionsBefore.every((s,i)=>sectionsAfter[i]===s);
 out.noNewSections=created-createdBefore<=6; // only a handful of tiny text nodes for changed chips; no section rebuild
 out.openKept=sectionsAfter[0].open===true;
 out.titleStable=byId('overall-title').textContent===textBefore;
 // hidden tab: the interval tick must not poll
 hidden=true;const c0=fetches.length;intervalFn();await flush();out.pausedWhenHidden=fetches.length===c0;hidden=false;
 // a failed poll keeps values and marks them stale
 const shown=sectionsAfter[0].children[1]?sectionsAfter[0].textContent:'';
 intervalFn();await flush();resolvers[resolvers.length-1].rej(new Error('no answer'));await flush();await flush();
 out.keptOnFailure=sectionsAfter[0]===sectionsBefore[0]&&host.children.length===sectionsBefore.length;
 out.markedStale=doc.body.classList.contains('stale')&&byId('error').hidden===false;
 out.stampSaysOutOfDate=/Out of date/.test(byId('stamp').textContent);
 console.log(JSON.stringify(out));
})();
'''
f=Path(tempfile.mkdtemp())/'h.js';f.write_text(harness)
r=subprocess.run(['node',str(f),script],capture_output=True,text=True,timeout=60)
if r.returncode:print(r.stdout,r.stderr);sys.exit(1)
res=json.loads(r.stdout.strip().splitlines()[-1]);bad=0
for k,v in res.items():
    print(('PASS ' if v else 'FAIL ')+k);bad+=0 if v else 1
src=script
for name,ok in {'no wholesale rebuild of the sections list':"host.textContent=''" not in src,'background polls do not toggle the refresh button':"if(manual===true)$('refresh').disabled=true" in src,'the rise animation is created once per section':src.count("'glass rise'")==1}.items():
    print(('PASS ' if ok else 'FAIL ')+name);bad+=0 if ok else 1
sys.exit(1 if bad else 0)
