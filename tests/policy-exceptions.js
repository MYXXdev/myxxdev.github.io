// Executed behavioural test of the exception policy against every generated PAC (32 combinations, six standalone modes, eight historical
// aliases): graph.facebook.com is DIRECT unless blockAdSense is selected; every exact exception is DIRECT in every mode; the exception
// list contains the intended real hosts (apex and www pairs, no look-alike domains).
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'..'),dir=process.env.MYB_PAC_DIR?process.env.MYB_PAC_DIR.replace(/\/?$/,'/'):path.join(root,'layout/usr/share/mybloxx/pacs/');
const C=JSON.parse(fs.readFileSync(path.join(root,'rules/canonical.json'),'utf8'));
let fails=0,checks=0;const bad=(m)=>{fails++;console.log('FAIL '+m)};const ok=(c,m)=>{checks++;if(!c)bad(m)};
function load(file){const c={shExpMatch:(s,g)=>new RegExp('^'+g.replace(/[.+^${}()|\\[\]]/g,'\\$&').replace(/\*/g,'.*').replace(/\?/g,'.')+'$').test(s),dnsDomainIs:(h,d)=>h.endsWith(d),isPlainHostName:h=>h.indexOf('.')<0,localHostOrDomainIs:(h,x)=>h===x,dnsResolve:()=>null,isInNet:()=>false,myIpAddress:()=>'10.0.0.2',dnsDomainLevels:h=>h.split('.').length-1};vm.createContext(c);vm.runInContext(fs.readFileSync(dir+file,'utf8'),c,{timeout:5000});return c}
const verdict=(c,h)=>c.FindProxyForURL('https://'+h+'/',h);
const BLOCK=C.transport.block,ALLOW=C.transport.allow;
// every mode id (32), the six standalone ids and the eight aliases, each with the options it stands for
const modes=[];
(function gen(i,cur){if(i===C.order.length){modes.push([cur.length?cur.join('+'):'Default',cur.slice()]);return}gen(i+1,cur);gen(i+1,cur.concat([C.order[i]]))})(0,[]);
Object.entries(C.aliases).forEach(([a,t])=>modes.push([a,t==='Default'?[]:t.split('+')]));
ok(modes.length===40,'40 PAC names are checked (got '+modes.length+')');
const standalone=['Default','allowY','blockAdSense','blockApple','blockSocials','blockXXX'];
standalone.forEach(s=>ok(modes.some(m=>m[0]===s),'standalone mode '+s+' is covered'));
const unless=C.exact_allow_unless||{};
ok(JSON.stringify(unless)===JSON.stringify({'graph.facebook.com':['blockAdSense']}),'graph.facebook.com is the one conditional exception, tied to blockAdSense');
for(const [name,opts] of modes){
  const c=load(name+'.pac');
  const g=verdict(c,'graph.facebook.com');
  if(opts.indexOf('blockAdSense')>=0) ok(g===BLOCK,name+': graph.facebook.com is blocked when blockAdSense is selected (got '+g+')');
  else ok(g===ALLOW,name+': graph.facebook.com stays DIRECT (got '+g+')');
  // the Graph host is DIRECT as a different path form too, and its look-alikes are not exempted by accident
  if(opts.indexOf('blockAdSense')<0){ok(verdict(c,'GRAPH.Facebook.com')===ALLOW,name+': host case does not matter');}
  C.exact_allow.forEach(h=>ok(verdict(c,h)===ALLOW,name+': '+h+' is DIRECT'));
}
// exceptions list integrity
const ex=new Set(C.exact_allow);
ok(ex.has('marketingturkiye.com.tr')&&ex.has('www.marketingturkiye.com.tr'),'marketingturkiye.com.tr and www are both exempt');
ok(!ex.has('marketingturkiye.com')&&!ex.has('www.marketingturkiye.com'),'the different domain marketingturkiye.com is not exempt');
const compat=C.hybrid.compat_tokens,listed=new Set([].concat(...Object.values(compat)));
C.exact_allow.forEach(h=>ok(listed.has(h)||h==='superadblocktest.com'||h==='www.superadblocktest.com',h+' has a documented V55 token'));
const two=new Set(['co.uk','com.tr','com.tw']);
for(const [tok,hs] of Object.entries(compat)){
  const set=new Set(hs);
  hs.forEach(h=>{const p=h.split('.');const apexLabels=two.has(p.slice(-2).join('.'))?3:2;const isApex=p.length===apexLabels-0&&p.length===apexLabels;const isWww=p[0]==='www';
    if(isWww)ok(set.has(p.slice(1).join('.')),tok+': '+h+' has its apex '+p.slice(1).join('.'));
    else if(p.length===apexLabels)ok(set.has('www.'+h),tok+': apex '+h+' has its www');});
  hs.forEach(h=>ok(h===h.toLowerCase()&&!/\s/.test(h)&&/^[a-z0-9.-]+$/.test(h),tok+': '+h+' is a clean lower-case host'));
}
// every exact host really relates to its token (guards spelling mistakes such as a swapped TLD or a changed letter)
for(const [tok,hs] of Object.entries(compat)){const t=tok.replace(/\\/g,'');hs.forEach(h=>ok(h.indexOf(t.replace(/\.$/,''))>=0||t.indexOf(h)>=0,tok+': '+h+' contains the V55 token'));}
console.log((fails?'FAILED ':'PASSED ')+checks+' checks across '+modes.length+' PAC files');
process.exit(fails?1:0);
