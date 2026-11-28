// Byte parity: rules/generate.js output == Python generator output (the bundled PACs) for every combination and alias.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
require(path.join(root,'rules/generate.js'));
const canon=fs.readFileSync(path.join(root,'rules/canonical.json'),'utf8'),rt=fs.readFileSync(path.join(root,'rules/runtime.txt'),'utf8');
const why=MYBValidateCanonical(canon);if(why){console.error('FAIL canonical rejected: '+why);process.exit(1)}
const out=JSON.parse(MYBGenerate(canon,rt)),dir=path.join(root,'layout/usr/share/mybloxx/pacs');
let bad=0,n=0;for(const name of Object.keys(out)){n++;const f=path.join(dir,name);if(!fs.existsSync(f)||fs.readFileSync(f,'utf8')!==out[name]){console.error('FAIL differs: '+name);bad++}}
const have=fs.readdirSync(dir).filter(x=>x.endsWith('.pac'));if(have.length!==n){console.error('FAIL file count '+have.length+' vs '+n);bad++}
// negative validation
const c=JSON.parse(canon);const mutate=(f)=>{const x=JSON.parse(canon);f(x);return MYBValidateCanonical(JSON.stringify(x))};
const neg={'apple blocked':x=>x.base.domains.push('apple.com'),'bypass changed':x=>x.transport.bypass='DIRECT','bad host':x=>x.base.domains.push('a..b'),'too small':x=>x.base.domains=x.base.domains.slice(0,10),'quote in stamp':x=>x.stamp='a"b','no core':x=>{x.base.domains=x.base.domains.filter(d=>d!=='googlesyndication.com');x.base.block.substrings=x.base.block.substrings.filter(d=>d!=='doubleclick')},'order':x=>x.order=x.order.slice().reverse()};
for(const k in neg){if(!mutate(neg[k])){console.error('FAIL validator accepted: '+k);bad++}}
if(bad)process.exit(1);console.log('generator parity: '+n+' files byte-identical to the Python generator; validator rejects '+Object.keys(neg).length+' bad rule sets');
// The same canary decisions the device's self check makes (Shared/MYBRulesGen.h MYBPACSelfCheck) hold for every generated mode.
{const vm=require('vm');const BLOCK='PROXY 127.0.0.1:8021',ALLOW='DIRECT';let b2=0;
 const ids=Object.keys(out).filter(n=>n.indexOf('MYbloXX')!==0).map(n=>n.slice(0,-4));
 for(const id of ids){const ctx={};vm.createContext(ctx);vm.runInContext(out[id+'.pac'],ctx);
  const opts=id==='Default'?[]:id.split('+'),r=(h)=>ctx.FindProxyForURL('https://'+h+'/',h);
  const must=[['ads.doubleclick.net',BLOCK],['github.com',ALLOW],['raw.githubusercontent.com',ALLOW],['login.microsoftonline.com',ALLOW],['example.com',ALLOW]];
  if(!opts.includes('blockApple'))must.push(['www.apple.com',ALLOW]);
  for(const [h,e] of must)if(r(h)!==e){console.error('FAIL canary '+id+' '+h+' -> '+r(h));b2++}}
 if(b2)process.exit(1);console.log('self-check canaries hold in all '+ids.length+' modes');}
