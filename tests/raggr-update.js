// Updater compatibility for RAGGR rules, with the real generators:
//   r16 engine  = generate.js + runtime.txt exactly as the r16 DEB installed them (git 7e87ee4, layout/usr/share/mybloxx/generator)
//   new engine  = this candidate's generator (layout/usr/share/mybloxx/generator)
// The device side transcribes Helper/MYBUpdates.inc: the rules check (stamp plausibility, older-than-local refusal,
// "up to date", install + previous generation), refreshBundledPACs on a DEB upgrade, and rollbackPACs; and
// Shared/MYBRulesGen.h MYBGenerateModePACs (validator, 40 names, self-check canaries, exact stamp, engine-current header).
// The r16 device keeps r16's header-only engine test; the new device uses GenerationMatchesEngine. Literals asserted first.
const fs = require('fs'), path = require('path'), vm = require('vm'), cp = require('child_process');
const root = path.resolve(__dirname, '..'), R = p => fs.readFileSync(path.join(root, p), 'utf8');
let bad = 0, checks = 0; const need = (ok, msg) => { checks++; if (!ok) { bad++; console.error('FAIL ' + msg); } };
const upd = R('Helper/MYBUpdates.inc'), gen = R('Shared/MYBRulesGen.h'), stampH = R('Shared/MYBPACStamp.h');
for (const [src, s] of [[upd, 'if(got<have){'], [upd, 'if(got==have&&engineCurrent&&got<=activeStamp){'], [upd, 'if(!MYBStampPlausible(got,[NSDate date]))'],
  [upd, 'if(activeStamp>bundledStamp&&activeRAGGR){'], [upd, 'if(regenerated&&MYBGenerationStamp(regenerated)>=activeStamp){install=regenerated;installCanonical=stored;'],
  [upd, '}else if(activeStamp==bundledStamp&&activeCurrent&&!activeBuiltIn){'], [upd, 'BOOL activeCurrent=MYBPACEngineCurrent(activeDefault)&&GenerationMatchesEngine(active)&&activeRAGGR;'],
  [upd, 'return MYBPACEngineCurrent(GenerationDefault(active))&&GenerationMatchesEngine(active)&&GenerationIsRAGGR(active);'], [upd, 'return again&&[again[@"Default"] isEqualToData:GenerationDefault(generation)];'],
  [upd, 'state[@"previousDirectory"]=current;state[@"revision"]=@"Rolled back"'],
  [gen, '@[@[@"ads.doubleclick.net",block],@[@"github.com",allow],@[@"raw.githubusercontent.com",allow],@[@"login.microsoftonline.com",allow],@[@"example.com",allow]]'],
  [gen, 'if(MYBPACStamp(data)!=releaseStamp||!MYBPACEngineCurrent(data))'], [stampH, 'time_t t=(time_t)[now timeIntervalSince1970]+7*86400;'],
  [stampH, 'return [head hasPrefix:@"//\\n// MYbloXX by MYXXdev ("]&&![head containsString:@"MYB_STAMP"];']])
  need(src.includes(s), 'shipping literal present: ' + s);

// ---- engines -----------------------------------------------------------------------------------------------------------
const R16 = process.env.R16_COMMIT || '7e87ee4d8bd2610da18de31cc9ff595c65c7ab8f';
const git = p => cp.execFileSync('git', ['-C', root, 'show', R16 + ':' + p], { encoding: 'utf8', maxBuffer: 1 << 26 });
function engine(js, rt) { const c = vm.createContext({}); vm.runInContext(js, c); return { c, rt }; }
const E16 = engine(git('layout/usr/share/mybloxx/generator/generate.js'), git('layout/usr/share/mybloxx/generator/runtime.txt'));
const ENEW = engine(R('layout/usr/share/mybloxx/generator/generate.js'), R('layout/usr/share/mybloxx/generator/runtime.txt'));
const stampOf = t => { const m = /(?:^|\n)\/\/ Updated: (\d{4})\/(\d{2})\/(\d{2}) - (\d{2}):(\d{2}) UTC(?=\r?\n|$)/.exec(t.slice(0, 4096)); return m ? +(m[1] + m[2] + m[3] + m[4] + m[5]) : 0; };
const engineCurrentHeader = t => !!stampOf(t) && t.startsWith('//\n// MYbloXX by MYXXdev (') && !t.slice(0, 4096).includes('MYB_STAMP');
const canonStamp = s => { const m = /^(\d{4})\/(\d{2})\/(\d{2}) - (\d{2}):(\d{2}) UTC$/.exec(s); return m ? +(m.slice(1).join('')) : 0; };
const MUST = [['ads.doubleclick.net', 'PROXY 127.0.0.1:8021'], ['github.com', 'DIRECT'], ['raw.githubusercontent.com', 'DIRECT'], ['login.microsoftonline.com', 'DIRECT'], ['example.com', 'DIRECT']];
function generate(E, canonText) {                      // MYBGenerateModePACs
  const why = E.c.MYBValidateCanonical(canonText); if (why) return { why: 'rejected: ' + why };
  const files = JSON.parse(E.c.MYBGenerate(canonText, E.rt)), release = canonStamp(JSON.parse(canonText).stamp);
  if (Object.keys(files).length !== 40) return { why: 'file count ' + Object.keys(files).length };
  for (const n in files) {
    const t = files[n], b = Buffer.byteLength(t); if (b < 100 || b > 2097152) return { why: n + ' size' };
    try { new vm.Script(t); } catch (e) { return { why: n + ' syntax' }; }   // SyntaxValid
    const c = vm.createContext({}); vm.runInContext(t, c);
    for (const [h, want] of MUST) if (c.FindProxyForURL('https://' + h + '/', h) !== want) return { why: n + ' canary ' + h };
    const apple = c.FindProxyForURL('https://www.apple.com/', 'www.apple.com'); if ((apple === 'DIRECT') === n.includes('blockApple') && !/noApple/.test(n)) return { why: n + ' apple canary ' + apple };
    if (stampOf(t) !== release || !engineCurrentHeader(t)) return { why: n + ' stamp/header' };
  }
  return { files, canon: canonText, stamp: release };
}
const NOW = Date.UTC(2026, 10, 26, 18, 30);
const plausible = s => { if (s < 202001010000) return false; const d = new Date(NOW + 7 * 86400e3); const lim = +(d.toISOString().slice(0, 16).replace(/[-T:]/g, '')); return s <= lim; };

// ---- devices ---------------------------------------------------------------------------------------------------------
const gens = new Map(); let gid = 0;   // generation folders: {files, canon}
function newGen(g) { const id = 'PAC-' + (++gid); gens.set(id, { files: g.files, canon: g.canon }); return id; }
function matchesEngine(E, id) { const g = gens.get(id); if (!g.canon) return true; const again = generate(E, g.canon); return !!again.files && again.files['Default.pac'] === g.files['Default.pac']; }
function device(E, nativeFix, bundledCanon) {
  const b = generate(E, bundledCanon); if (!b.files) throw new Error('bundled rules do not generate: ' + b.why);
  const d = { E, nativeFix, bundled: b, active: newGen(b), previous: null, revision: 'built-in-x', log: [] };
  return d;
}
const def = (d, id) => gens.get(id || d.active).files['Default.pac'];
function engineCurrent(d) { return engineCurrentHeader(def(d)) && (!d.nativeFix || matchesEngine(d.E, d.active)); }   // ActiveEngineCurrent
function check(d, upstreamCanon, revision) {           // the rules check
  const g = generate(d.E, upstreamCanon); if (!g.files) return d.log.push('rejected ' + g.why), 'rejected';
  const got = g.stamp; if (!plausible(got)) return d.log.push('implausible'), 'implausible';
  const activeStamp = stampOf(def(d)), have = Math.max(d.bundled.stamp, activeStamp);
  if (got < have) return 'older-refused';
  if (got === have && engineCurrent(d) && got <= activeStamp) return 'up-to-date';
  const id = newGen(g); d.previous = d.active; d.active = id; d.revision = revision || 'downloaded'; return 'installed';
}
function rollback(d) { if (!d.previous) return 'no-previous'; const cur = d.active; d.active = d.previous; d.previous = cur; d.revision = 'Rolled back'; return 'rolled-back'; }
function upgradeDEB(d, E, nativeFix, bundledCanon) {    // refreshBundledPACs after the new package is installed
  d.E = E; d.nativeFix = nativeFix; const b = generate(E, bundledCanon); d.bundled = b;
  const active = d.active, activeStamp = stampOf(def(d)), bundledStamp = b.stamp;
  const identical = Object.keys(b.files).every(n => gens.get(active).files[n] === b.files[n]);
  if (identical) return 'identical';
  const activeCurrent = engineCurrentHeader(def(d)) && (!nativeFix || matchesEngine(E, active));
  const builtIn = !d.revision || d.revision.startsWith('built-in-');
  let install = b, converted = false;
  if (activeStamp > bundledStamp) {
    if (activeCurrent) return 'kept-newer-download';
    const stored = gens.get(active).canon, again = stored ? generate(E, stored) : {};
    if (again.files && again.stamp >= activeStamp) { install = again; converted = true; } else return 'kept-until-next-check';
  } else if (activeStamp === bundledStamp && activeCurrent && !builtIn) return 'kept-same-date-download';
  const id = newGen(install); d.previous = active; d.active = id; if (!converted) d.revision = 'built-in-y';
  return converted ? 'converted' : 'built-in-installed';
}

// ---- rule sets -------------------------------------------------------------------------------------------------------
const r16Canon = git('rules/canonical.json'), cand = R('rules/canonical.json'), C = JSON.parse(cand);
const restamp = (t, s, f) => { const x = JSON.parse(t); x.stamp = s; if (f) f(x); return JSON.stringify(x, null, 1); };
const future = restamp(cand, '2026/11/27 - 06:00 UTC', x => x.compact.host_labels = [...x.compact.host_labels, 'statcollector'].sort());  // a later RAGGR release
const revertR16 = restamp(r16Canon, '2026/11/27 - 09:00 UTC');                // rollback published with a newer stamp
const raggrAgain = restamp(cand, '2026/11/27 - 12:00 UTC');                    // RAGGR re-published after the rollback
const oldAgain = restamp(cand, '2026/11/26 - 17:40 UTC');                      // an older RAGGR stamp republished by mistake
const tooNew = restamp(cand, '2026/12/04 - 00:00 UTC');

const route = (files, n, h) => { const c = vm.createContext({}); vm.runInContext(files[n], c); return c.FindProxyForURL('https://' + h + '/', h); };
const SHAPE = 'qwertyuiop.shop', TABLE = 'alpha.' + JSON.parse(R(C.hybrid.raggr.reference)).domains_add.find(d => !C.hybrid.raggr.held_for_noXXX_pin.includes(d) && !(C.hybrid.raggr.dead_under_allow_words || []).includes(d));
const out = [];
const say = (k, v, want) => { need(v === want, k + ': got ' + v + ', want ' + want); out.push(k.padEnd(78) + v); };

// r16 engine output for the candidate: the base rules (+549 domains), no compact rules, all checks pass
const r16OnCand = generate(E16, cand), newOnCand = generate(ENEW, cand), newOnR16 = generate(ENEW, r16Canon), r16OnR16 = generate(E16, r16Canon);
need(!!r16OnCand.files, 'r16 engine accepts the RAGGR canonical: ' + r16OnCand.why);
need(E16.c.MYBValidateCanonical(cand) === '', 'r16 validator returns "" for the RAGGR canonical');
need(Object.keys(newOnR16.files).every(n => newOnR16.files[n] === r16OnR16.files[n]), 'new engine == r16 engine, byte for byte, on rules without compact');
need(Object.keys(newOnCand.files).every(n => newOnCand.files[n] === R('layout/usr/share/mybloxx/pacs/' + n)), 'new engine output == candidate bundled PACs');
need(route(r16OnCand.files, 'Default.pac', TABLE) === 'PROXY 127.0.0.1:8021' && route(r16OnCand.files, 'Default.pac', SHAPE) === 'DIRECT', 'r16 engine: table domains block, shape rules absent');
need(route(newOnCand.files, 'Default.pac', TABLE) === 'PROXY 127.0.0.1:8021' && route(newOnCand.files, 'Default.pac', SHAPE) === 'PROXY 127.0.0.1:8021', 'new engine: table and shape rules block');
out.push('r16 engine on RAGGR canonical: Default ' + Buffer.byteLength(r16OnCand.files['Default.pac']) + ' B; new engine: Default ' + Buffer.byteLength(newOnCand.files['Default.pac']) + ' B');

// A. r16 device (r16 DEB) -----------------------------------------------------------------------------------------------
{ const d = device(E16, false, r16Canon);
  say('A1 r16 device: RAGGR 2026/11/26 18:10 published', check(d, cand), 'installed');
  need(def(d) === r16OnCand.files['Default.pac'], 'A1 installed = r16-engine base rules');
  say('A2 r16 device: same RAGGR checked again', check(d, cand), 'up-to-date');
  say('A3 r16 device: later RAGGR 11/27 06:00', check(d, future), 'installed');
  say('A4 r16 device: rollback (r16 rules, stamp 11/27 09:00)', check(d, revertR16), 'installed');
  need(Object.keys(r16OnR16.files).every(n => route(gens.get(d.active).files, n, TABLE) === route(r16OnR16.files, n, TABLE)), 'A4 rollback rules decide like r16');
  say('A5 r16 device: older RAGGR stamp republished (11/26 17:40)', check(d, oldAgain), 'older-refused');
  say('A6 r16 device: original r16 rules republished as-is (11/20)', check(d, r16Canon), 'older-refused');
  say('A7 r16 device: stamp 7+ days ahead (12/04)', check(d, tooNew), 'implausible');
  say('A8 r16 device: RAGGR republished 11/27 12:00', check(d, raggrAgain), 'installed');
  say('A9 r16 device: user "restore previous rules"', rollback(d), 'rolled-back');
  need(stampOf(def(d)) === 202611270900, 'A9 previous generation (rollback rules) active again');
}
// B. new DEB (engine 2, bundled RAGGR) ----------------------------------------------------------------------------------
{ const d = device(ENEW, true, cand);
  say('B1 new device: bundled RAGGR, same RAGGR upstream', check(d, cand), 'up-to-date');
  say('B2 new device: later RAGGR 11/27 06:00', check(d, future), 'installed');
  need(route(gens.get(d.active).files, 'Default.pac', 'statcollector.alpha-raggr.com') === 'PROXY 127.0.0.1:8021', 'B2 the new compact label is live');
  say('B3 new device: rollback (r16 rules, 11/27 09:00)', check(d, revertR16), 'installed');
  need(def(d) === generate(E16, revertR16).files['Default.pac'], 'B3 new engine rollback output == r16 engine output');
  say('B4 new device: older RAGGR stamp republished', check(d, oldAgain), 'older-refused');
  say('B5 new device: RAGGR republished 11/27 12:00', check(d, raggrAgain), 'installed');
  say('B6 new device: restore previous', rollback(d), 'rolled-back');
}
// C. DEB upgrade r16 -> new DEB, with and without the native engine check -------------------------------------------------
for (const fix of [false, true]) {
  const tag = fix ? 'new helper' : 'helper without fix';
  { const d = device(E16, false, r16Canon); check(d, cand);          // r16 device downloaded RAGGR 11/26 18:10 (r16-engine output)
    const r = upgradeDEB(d, ENEW, fix, cand);
    say('C1 ' + tag + ': r16-engine RAGGR (same date as package) after upgrade', r, fix ? 'built-in-installed' : 'kept-same-date-download');
    say('C1 ' + tag + ': shape rule active afterwards', route(gens.get(d.active).files, 'Default.pac', SHAPE), fix ? 'PROXY 127.0.0.1:8021' : 'DIRECT');
    if (!fix) say('C1 ' + tag + ': next rules check (same upstream)', check(d, cand), 'up-to-date'); }
  { const d = device(E16, false, r16Canon); check(d, future);        // r16 device downloaded a NEWER RAGGR than the package
    const r = upgradeDEB(d, ENEW, fix, cand);
    say('C2 ' + tag + ': r16-engine RAGGR newer than package after upgrade', r, fix ? 'converted' : 'kept-newer-download');
    say('C2 ' + tag + ': shape rule active afterwards', route(gens.get(d.active).files, 'Default.pac', SHAPE), fix ? 'PROXY 127.0.0.1:8021' : 'DIRECT');
    need(stampOf(def(d)) === 202611270600, 'C2 ' + tag + ': newer rules never downgraded'); }
  { const d = device(E16, false, r16Canon); check(d, cand); check(d, revertR16);  // on rollback rules (no compact) at upgrade time
    say('C3 ' + tag + ': r16 rollback rules newer than package after upgrade', upgradeDEB(d, ENEW, fix, cand), 'kept-newer-download'); }
}
// D. an engine-2 rules file that an r16 helper's validator would refuse must not exist: compact stays optional --------------
need(JSON.parse(cand).format === 1 && 'compact' in JSON.parse(cand), 'canonical keeps format 1 with an optional compact section');
need(generate(E16, future).files && generate(E16, raggrAgain).files, 'r16 engine accepts every later RAGGR release used here');

for (const l of out) console.log(l);
if (bad) { console.error('FAILED ' + bad + ' of ' + checks + ' checks'); process.exit(1); }
console.log('raggr-update: ' + checks + ' checks passed');
