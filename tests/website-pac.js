const fs=require('fs'),vm=require('vm'),assert=require('assert');let count=0;
for(const name of fs.readdirSync(process.argv[2]).filter(n=>n.endsWith('.pac'))){
 function context(script){let c={dnsDomainIs:(h,d)=>h.endsWith(d),shExpMatch:(s,p)=>new RegExp('^'+p.split('*').map(x=>x.replace(/[.+?^${}()|[\]\\]/g,'\\$&')).join('.*')+'$').test(s)};vm.createContext(c);vm.runInContext(script,c,{timeout:1000});return c;}
 let a=context(fs.readFileSync(__dirname+'/../layout/usr/share/mybloxx/pacs/'+name,'utf8')),b=context(fs.readFileSync(process.argv[2]+'/'+name,'utf8'));
 for(const h of ['100widgets.com','sub.100widgets.com','100widgets.com.evil.example','not100widgets.com','example.com','ads.example.com','apple.com','facebook.com','pornhub.com','youtube.com']){assert.equal(b.FindProxyForURL('https://'+h+'/',h),h==='100widgets.com'||h.endsWith('.100widgets.com')?'DIRECT':a.FindProxyForURL('https://'+h+'/',h));count++;}
}
console.log(count+' website-exception PAC checks passed; category differences retained.');

const overlayFile=require('path').join(process.argv[2],'..','mybloxx-user-overlay.pac');
const source=fs.readFileSync(__dirname+'/../layout/usr/share/mybloxx/pacs/Default.pac','utf8');
const overlay=fs.readFileSync(overlayFile,'utf8');
function wrapContext(script){
 const c={dnsDomainIs:(h,d)=>h.endsWith(d),shExpMatch:(str,pat)=>pat==='*'||str===pat};
 vm.createContext(c);
 vm.runInContext(script,c,{timeout:1000});
 return c;
}
const normal=wrapContext(source),globalRules=wrapContext(overlay);
for(const host of ['shouldblock.example','child.shouldblock.example']){
 assert.equal(globalRules.FindProxyForURL('https://'+host+'/',host),'PROXY 127.0.0.1:8788');
}
for(const host of ['shouldallow.example','child.shouldallow.example','100widgets.com']){
 assert.equal(globalRules.FindProxyForURL('https://'+host+'/',host),'DIRECT');
}
for(const host of ['unrelated.example','apple.com','youtube.com']){
 assert.equal(globalRules.FindProxyForURL('https://'+host+'/',host),normal.FindProxyForURL('https://'+host+'/',host));
}
console.log('Custom global allow/block overlays and separate website exceptions passed.');

