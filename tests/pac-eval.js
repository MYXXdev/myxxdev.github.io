// Evaluates PAC files against a probe list. stdin JSON {pacs:{name:path},probes:[[url,host],...]} -> {name:[results]}
const fs=require('fs'),vm=require('vm');
const input=JSON.parse(fs.readFileSync(0,'utf8'));const out={};
for(const [name,path] of Object.entries(input.pacs)){
 const c={shExpMatch:(s,g)=>new RegExp('^'+g.replace(/[.+^${}()|\\[\]]/g,'\\$&').replace(/\*/g,'.*').replace(/\?/g,'.')+'$').test(s),dnsDomainIs:(h,d)=>h.endsWith(d),isPlainHostName:h=>h.indexOf('.')<0,localHostOrDomainIs:(h,x)=>h===x||x.indexOf(h+'.')===0,dnsResolve:()=>null,isResolvable:()=>false,myIpAddress:()=>'10.0.0.2',isInNet:()=>false,dnsDomainLevels:h=>h.split('.').length-1};vm.createContext(c);vm.runInContext(fs.readFileSync(path,'utf8'),c,{timeout:5000});
 out[name]=input.probes.map(([u,h])=>c.FindProxyForURL(u,h));
}
process.stdout.write(JSON.stringify(out));
