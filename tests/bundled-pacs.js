// Bundled PAC set: every shipped mode is the supplied PAC (hash-pinned), every legacy alias is a byte copy of
// its mapped mode, all parse, behave as their mode, and survive the overlay wrapper unchanged.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),crypto=require('crypto'),path=require('path');
const dir=process.argv[2]||path.join(__dirname,'..','layout/usr/share/mybloxx/pacs');
const man=JSON.parse(fs.readFileSync(path.join(__dirname,'pac-sources.json'),'utf8'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');let n=0;
const read=m=>fs.readFileSync(path.join(dir,m+'.pac'));
const refDir=path.join(__dirname,'..','rules','reference');
for(const [mode,info] of Object.entries(man.modes)){assert.strictEqual(sha(fs.readFileSync(path.join(refDir,mode+'.pac'))),info.sha256,mode+': the reference copy differs from the supplied PAC');n++;}
// Bundled files are GENERATED from rules/canonical.json (rules/generate.py): every option combination, plus the legacy aliases.
const canon=JSON.parse(fs.readFileSync(path.join(__dirname,'..','rules','canonical.json'),'utf8'));
const combos=['Default'];for(let m=1;m<(1<<canon.order.length);m++)combos.push(canon.order.filter((o,i)=>m&(1<<i)).join('+'));
assert.strictEqual(new Set(combos).size,32);
for(const id of combos){assert.ok(fs.existsSync(path.join(dir,id+'.pac')),id+' is not bundled');n++;}
for(const [alias,mode] of Object.entries(man.aliases)){assert.ok(read(alias).equals(read(mode)),alias+' is not a copy of '+mode);n++;}
const shipped=new Set(fs.readdirSync(dir).filter(f=>f.endsWith('.pac')).map(f=>f.slice(0,-4)));
for(const k of [...combos,...Object.keys(man.aliases)]){assert.ok(shipped.delete(k),k+' missing');}
assert.strictEqual(shipped.size,0,'unexpected PAC files: '+[...shipped]);
function load(text){const c={};vm.createContext(c);vm.runInContext(text,c,{timeout:2000});assert.strictEqual(typeof c.FindProxyForURL,'function');return c;}
const v=(c,h)=>c.FindProxyForURL('https://'+h+'/',h);
const ctx={};for(const m of Object.keys(man.modes)){const t=read(m).toString('utf8');const lines=t.split('\n');assert.ok(/^\d{4}\/\d{2}\/\d{2} - \d{2}:\d{2} UTC$/.test(canon.stamp),'canonical stamp is YYYY/MM/DD - HH:MM UTC');assert.ok(lines[0]==='//'&&/^\/\/ MYbloXX by MYXXdev \(.+\)$/.test(lines[1])&&lines[2]==='// Updated: '+canon.stamp&&lines[3]==='// Support Development: myxxfm.com/donate'&&lines[4]==='//',m+' header');assert.strictEqual(lines.length,7,m+' is a five line header plus exactly one code line');assert.strictEqual(lines[6],'',m+' ends with one newline');assert.ok(!/MYB_STAMP/.test(t),m+' has no numeric stamp');ctx[m]=load(t);n++;}
const BLOCK='PROXY 127.0.0.1:8021';
assert.strictEqual(v(ctx.Default,'doubleclick.net'),BLOCK);
assert.strictEqual(v(ctx.Default,'example.com'),'DIRECT');
for(const h of ['apple.com','icloud.com'])assert.strictEqual(v(ctx.blockApple,h),BLOCK),assert.strictEqual(v(ctx.Default,h),'DIRECT');
for(const h of ['facebook.com','instagram.com'])assert.strictEqual(v(ctx.blockSocials,h),BLOCK),assert.strictEqual(v(ctx.Default,h),'DIRECT');
for(const h of ['pornhub.com','xvideos.com'])assert.strictEqual(v(ctx.blockXXX,h),BLOCK),assert.strictEqual(v(ctx.Default,h),'DIRECT');
for(const m of Object.keys(ctx))assert.strictEqual(v(ctx[m],'doubleclick.net'),BLOCK,m+' must still block ad servers');
for(const m of Object.keys(ctx)){assert.strictEqual(v(ctx[m],'example.com'),'DIRECT',m+' example.com');n+=2;}
// Overlay wrapper (allow -> DIRECT, block -> blocked page) keeps working on the new format.
const wrap=(base,allow,block)=>base.replace('function FindProxyForURL(','function MYBUserBaseFindProxyForURL(')+'\nfunction FindProxyForURL(u,h){if(h==="'+allow+'")return "DIRECT";if(h==="'+block+'")return "PROXY 127.0.0.1:8788";return MYBUserBaseFindProxyForURL(u,h);}';
for(const m of Object.keys(ctx)){const c=load(wrap(read(m).toString('utf8'),'doubleclick.net','allowed.test'));assert.strictEqual(v(c,'doubleclick.net'),'DIRECT');assert.strictEqual(v(c,'allowed.test'),'PROXY 127.0.0.1:8788');assert.strictEqual(v(c,'example.com'),'DIRECT');n+=3;}
console.log(n+' bundled PAC source/alias/behaviour checks passed');
