const fs=require('fs'),vm=require('vm'),assert=require('assert');
const root=__dirname+'/../layout/usr/share/mybloxx/pacs/';
function context(script){const c={dnsDomainIs:(h,d)=>h.endsWith(d),shExpMatch:(s,p)=>new RegExp('^'+p.split('*').map(x=>x.replace(/[.+?^${}()|[\]\\]/g,'\\$&')).join('.*')+'$').test(s),isPlainHostName:h=>!h.includes('.'),dnsResolve:()=>null,isInNet:()=>false};vm.createContext(c);vm.runInContext(script,c,{timeout:1000});return c;}
const modes=['Default','allowY','blockAdSense','blockApple','blockSocials','blockXXX'];
let checks=0;
for(const mode of modes){const script=fs.readFileSync(root+mode+'.pac','utf8');const c=context(script);for(const host of ['example.com','ads.example.com','apple.com','google.com','youtube.com','facebook.com','localhost']){assert.equal(typeof c.FindProxyForURL('https://'+host+'/',host),'string');checks++;}}
// Read the actual Objective-C formatting templates used by the generator.
const helper=fs.readFileSync(__dirname+'/../Helper/MYXXdev.m','utf8');
const format=helper.match(/stringWithFormat:@"(\(h===.*?\))",domain,domain/)[1].replace(/\\"/g,'"');
function term(d){return format.replace('%@',d).replace('%@',d);}
function custom(block,allow){
 const base=fs.readFileSync(root+'Default.pac','utf8');if(!block.length&&!allow.length)return base;
 let rule='';if(allow.length)rule+='if('+allow.map(term).join('||')+')return "DIRECT";';if(block.length)rule+='if('+block.map(term).join('||')+')return "PROXY 127.0.0.1:8021";';
 const template=JSON.parse('"'+helper.match(/NSString \*wrapper=\[NSString stringWithFormat:@"(.*?)",rules/)[1]+'"');
 return base.replace(/function\s+FindProxyForURL\s*\(/,'function MYBBaseFindProxyForURL(')+template.replace('%@',rule);
}

const base=context(fs.readFileSync(root+'Default.pac','utf8')),empty=context(custom([],[])),blocked=context(custom(['example.com'],[])),allowed=context(custom(['example.com'],['ads.example.com']));
for(const host of ['example.com','ads.example.com','badexample.com','notexample.com','example.com.evil.org']){
 const url='https://'+host+'/';assert.equal(empty.FindProxyForURL(url,host),base.FindProxyForURL(url,host));checks++;
}
assert.equal(blocked.FindProxyForURL('https://example.com/','example.com'),'PROXY 127.0.0.1:8021');checks++;
assert.equal(blocked.FindProxyForURL('https://a.example.com/','a.example.com'),'PROXY 127.0.0.1:8021');checks++;
assert.equal(blocked.FindProxyForURL('https://badexample.com/','badexample.com'),base.FindProxyForURL('https://badexample.com/','badexample.com'));checks++;
assert.equal(allowed.FindProxyForURL('https://ads.example.com/','ads.example.com'),'DIRECT');checks++;
// Remove the last rule: regenerated empty PAC must restore the original result.
assert.equal(empty.FindProxyForURL('https://example.com/','example.com'),base.FindProxyForURL('https://example.com/','example.com'));checks++;
console.log(`${checks} PAC behavioral checks passed`);
