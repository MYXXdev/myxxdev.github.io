// RAGGR vs the user's Allow list, through the shipping rule-application code.
// The wrappers below are the literal templates of Shared/MYBWebsiteRules.h (MYBUserRulesPAC, MYBRuleEntryTerm, MYBWebsitePAC),
// Shared/MYBTransport.h (8021 -> 8788), Helper/MYXXdev.m (legacy Custom: customPACScript/pacTest) and the PAC builtins of
// Shared/MYBPACDecision.h (MYBEvaluatePAC). Each literal is asserted to be present in the source first, so a change there
// fails this test instead of silently testing something else.
// For every RAGGR matcher (100 host labels, 18 host shapes incl. .shop/.store, 9 family chains, 8 words, 551 table domains):
//   the base blocks two hosts matched by that same rule; Allow of the first -> DIRECT; the second stays blocked.
// Then: the saved Allow across all 32 modes, across r16 -> RAGGR regeneration, an r16-engine update of the same rules,
// rollback to r16, website exceptions and legacy Custom; and the noXXX PIN decision with and without the native fix.
const fs = require('fs'), path = require('path'), vm = require('vm');
const root = path.resolve(__dirname, '..'), R = p => fs.readFileSync(path.join(root, p), 'utf8');
let bad = 0, checks = 0; const need = (ok, msg) => { checks++; if (!ok) { bad++; if (bad < 40) console.error('FAIL ' + msg); } };

// ---- 1. the shipping literals ----------------------------------------------------------------------------------------
const src = { rules: R('Shared/MYBWebsiteRules.h'), transport: R('Shared/MYBTransport.h'), custom: R('Helper/MYXXdev.m'), decision: R('Shared/MYBPACDecision.h'), live: R('Shared/MYBSetupBackup.h'), pin: R('Helper/MYBPin.inc'), upd: R('Helper/MYBUpdates.inc') };
const lit = {
  rules: ['@"(shExpMatch(h,\\"%@\\")||shExpMatch(h,\\"*.%@\\"))"', '@"(h===\\"%@\\"||dnsDomainIs(h,\\".%@\\"))"', '@"function\\\\s+FindProxyForURL\\\\s*\\\\("',
    'withTemplate:@"function MYBUserBaseFindProxyForURL("', '@"\\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();"', '@"if(%@)return \\"DIRECT\\";"',
    '@"if(%@)return \\"PROXY 127.0.0.1:8788\\";"', '@"return MYBUserBaseFindProxyForURL(url,host);}\\n"', 'withTemplate:@"function MYBWebsiteBaseFindProxyForURL("',
    '@"\\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();if(%@)return \\"DIRECT\\";return MYBWebsiteBaseFindProxyForURL(url,host);}\\n"',
    'if(allowTerms.count)[wrapper appendFormat', 'if(blockTerms.count)[wrapper appendFormat'],
  transport: ['@"\\\\bPROXY[ \\\\t]+127\\\\.0\\\\.0\\\\.1:8021(?=[\\\\\\"\';\\\\s]|$)"', 'withTemplate:@"PROXY 127.0.0.1:8788"'],
  custom: ['withTemplate:@"function MYBBaseFindProxyForURL("', '[pacTest(allowed,@"\\"DIRECT\\"") stringByAppendingString:pacTest(blocked,@"\\"PROXY 127.0.0.1:8021\\"")]',
    '@"\\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();%@return MYBBaseFindProxyForURL(url,host); }\\n"'],
  live: ['NSString *text=MYBUserRulesPAC(base,rules[@"blocked"],rules[@"allowed"]);return text?MYBWatchWrap(MYBTransportPACText(text)'],
  pin: ['[parsed removeObjectForKey:@"compact"]', 'MYBGenerateModePACs(base,GeneratorDirectory(),&why)', 'NSString *with=PinRulesText(base,mode),*without=PinRulesText(base,MYBModeIDForOptions(rest));'],
  upd: ['[applied writeToFile:[stage stringByAppendingPathComponent:@"AppliedRules.plist"] atomically:YES]', 'MYBPACEngineCurrent(activeDefault)&&GenerationMatchesEngine(active)'],
};
for (const k in lit) for (const s of lit[k]) need(src[k].includes(s), 'shipping literal missing in ' + k + ': ' + s);
const builtinsObjC = src.decision.match(/\[c evaluateScript:@"(function dnsDomainIs.*?)"\];/);
need(!!builtinsObjC, 'PAC builtins literal in MYBPACDecision.h');
const builtins = builtinsObjC[1].replace(/\\(.)/g, '$1'); // ObjC string literal -> JS source

// ---- 2. the templates, transcribed ------------------------------------------------------------------------------------
const FN = /function\s+FindProxyForURL\s*\(/g;
const once = base => (base.match(FN) || []).length === 1;
const term = d => d.includes('*') ? '(shExpMatch(h,"' + d + '")||shExpMatch(h,"*.' + d + '"))' : '(h==="' + d + '"||dnsDomainIs(h,".' + d + '"))';
function userRulesPAC(base, blocked, allowed) {               // MYBUserRulesPAC
  if (!blocked.length && !allowed.length) return base; if (!once(base)) return null;
  let w = '\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();';
  if (allowed.length) w += 'if(' + allowed.map(term).join('||') + ')return "DIRECT";';
  if (blocked.length) w += 'if(' + blocked.map(term).join('||') + ')return "PROXY 127.0.0.1:8788";';
  return base.replace(FN, 'function MYBUserBaseFindProxyForURL(') + w + 'return MYBUserBaseFindProxyForURL(url,host);}\n';
}
const transport = t => t.replace(/\bPROXY[ \t]+127\.0\.0\.1:8021(?=["';\s]|$)/g, 'PROXY 127.0.0.1:8788'); // MYBTransportPACText
const live = (base, rules) => { const t = userRulesPAC(base, rules.blocked, rules.allowed); return t ? transport(t) : null; }; // MYBSetupLivePAC (watch off)
function websitePAC(base, domains) {                           // MYBWebsitePAC
  if (!domains.length) return base; if (!once(base)) return null;
  const terms = domains.map(d => '(h==="' + d + '"||dnsDomainIs(h,".' + d + '"))').join('||');
  return base.replace(FN, 'function MYBWebsiteBaseFindProxyForURL(') + '\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();if(' + terms + ')return "DIRECT";return MYBWebsiteBaseFindProxyForURL(url,host);}\n';
}
function customPAC(base, blocked, allowed) {                   // customPACScript + pacTest
  const t = (ds, o) => ds.length ? 'if(' + ds.map(d => '(h==="' + d + '"||dnsDomainIs(h,".' + d + '"))').join('||') + ')return ' + o + ';' : '';
  if (!once(base)) return null;
  return base.replace(FN, 'function MYBBaseFindProxyForURL(') + '\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();' + t(allowed, '"DIRECT"') + t(blocked, '"PROXY 127.0.0.1:8021"') + 'return MYBBaseFindProxyForURL(url,host); }\n';
}
const BLOCKED = new Set(['PROXY 127.0.0.1:8021', 'PROXY 127.0.0.1:8788', 'PROXY 8.8.8.8:53']);  // MYBBlockedRoute
function ctx(script) { const c = vm.createContext({}); vm.runInContext(builtins, c); vm.runInContext(script, c); return c; }
const route = (c, h, p) => c.FindProxyForURL('https://' + h + (p || '/'), h);
const blocked = (c, h, p) => BLOCKED.has(route(c, h, p).trim());

// ---- 3. the generations -----------------------------------------------------------------------------------------------
require(path.join(root, 'rules/generate.js'));
const canonText = R('rules/canonical.json'), canon = JSON.parse(canonText), rt = R('rules/runtime.txt');
need(MYBValidateCanonical(canonText) === '', 'candidate canonical validates');
const raggr = JSON.parse(MYBGenerate(canonText, rt));
const stripped = JSON.parse(canonText); delete stripped.compact; const strippedText = JSON.stringify(stripped);
const baseOnly = JSON.parse(MYBGenerate(strippedText, rt));                       // what the r16 engine / fixed PIN sees
const dir = path.join(root, 'layout/usr/share/mybloxx/pacs');
for (const n in raggr) need(fs.readFileSync(path.join(dir, n), 'utf8') === raggr[n], 'bundled ' + n + ' == generator output');
// r16's shipped PACs, read from the r16 commit (R16_COMMIT, default 7e87ee4) so the test needs no extra checkout.
const R16 = process.env.R16_COMMIT || '7e87ee4d8bd2610da18de31cc9ff595c65c7ab8f', cp = require('child_process');
const r16 = Object.fromEntries(Object.keys(raggr).map(n => [n, cp.execFileSync('git', ['-C', root, 'show', R16 + ':layout/usr/share/mybloxx/pacs/' + n], { encoding: 'utf8', maxBuffer: 1 << 26 })]));
need(Object.keys(r16).length === 40, 'r16 PACs read from ' + R16);
const modes = Object.keys(raggr).filter(n => n === 'Default.pac' || /^(allowY|block)/.test(n));
need(modes.length === 32, '32 combinations (' + modes.length + ')');

// ---- 4. one pair per RAGGR rule ---------------------------------------------------------------------------------------
const C = canon.compact, pairs = [];
const hexs = (n, s) => (s.repeat(Math.ceil(n / s.length))).slice(0, n);
for (const l of C.host_labels) pairs.push(['label ' + l, l + '.alpha-raggr.com', l + '.beta-raggr.net', new RegExp('^' + l.replace(/[-.]/g, '\\$&') + '\\.[^.]+\\.')]);
const shapes = {
  0: ['telemetry.alpha-raggr.com', 'telemetry.beta-raggr.net'], 1: [hexs(24, '0a1b2c3d') + '.click', hexs(24, '9f8e7d6c') + '.click'],
  2: [hexs(32, 'a1b2c3d4') + '.com', hexs(40, 'e5f60718') + '.com'], 3: ['ab12cd.bid', 'zz98yy.bid'], 4: ['abcdefgh123456.cfd', 'qrstuvwxyz98765.cfd'],
  5: ['abcdefgh123456.cyou', 'mnopqrstuvwxyz123456z.cyou'], 6: ['abcdefghijkl.ai', 'mnopqrstuvwx.ai'], 7: ['abcdefghijk.app', 'lmnopqrstuv.app'],
  8: ['abcdefghijklmn.click', 'opqrstuvwxyzab.click'], 9: ['abcdefghij.icu', 'klmnopqrst.icu'], 10: ['abcdefghij.live', 'klmnopqrst.live'],
  11: ['abcdefghij.rest', 'klmnopqrstuvwx.rest'], 12: ['abcdefghi.web.app', 'jklmnopqrs.web.app'], 13: ['12345678.xyz', '87654321.xyz'],
  14: ['2a665e60f0.com', 'abc8311641.com'], 16: ['0a1b2c3.apotune-booking.de', 'f9e8d7c.apotune-booking.de'], 17: ['abc123def456.spankbang.com', 'zyx987wvu654.spankbang.com'],
};
C.host_patterns.forEach((p, i) => { if (shapes[i]) pairs.push(['shape#' + i, shapes[i][0], shapes[i][1], new RegExp(p)]); });
const spam = C.host_patterns.findIndex(p => p.includes('shop|store')); need(spam >= 0, 'spam-TLD shape present');
for (const t of ['cfd', 'cyou', 'qpon', 'shop', 'store']) pairs.push(['shape .' + t, 'qwertyuiop.' + t, 'asdfghjklzx.' + t, new RegExp(C.host_patterns[spam])]);
need(C.host_patterns.every((_, i) => shapes[i] || i === spam), 'every host shape has a test pair');
for (const [, [a]] of C.chains_add.map((c, i) => [i, c[1]])) { const w = a.slice(3); pairs.push(['chain ' + a + '*', w + 'alpha-raggr.com', w + 'beta-raggr.net', null, a]); }
for (const w of C.substrings_add) {
  const h = w.startsWith('://') ? [w.slice(3) + 'alpha-raggr.com', w.slice(3) + 'beta-raggr.net'] : w.startsWith('.') ? ['alpha' + w, 'beta' + w] : ['alpha' + w, 'beta' + w];
  pairs.push(['word ' + w, h[0], h[1], null, w]);
}
const refJ = JSON.parse(R(canon.hybrid.raggr.reference)), held = new Set(canon.hybrid.raggr.held_for_noXXX_pin);
const dead = new Set(canon.hybrid.raggr.dead_under_allow_words || []);
for (const d of dead) need(canon.base.allow.substrings.some(w => ('https://' + d + '/').includes(w) && ('https://x.' + d + '/').includes(w)) && !canon.base.domains.includes(d), 'dead entry ' + d + ' is covered by an r16 Allow word and left out');
const tableDoms = refJ.domains_add.filter(d => !held.has(d) && !dead.has(d));
need(tableDoms.length === canon.hybrid.raggr.domains_add, 'RAGGR table domains ' + tableDoms.length);
for (const d of tableDoms) pairs.push(['domain ' + d, 'alpha.' + d, 'beta.' + d, null, null, d]);

const D = ctx(raggr['Default.pac']);
let tested = 0;
for (const [name, a, b, rx, word, dom] of pairs) {
  // both hosts are matched by THIS rule (not just blocked by something)
  if (rx) need(rx.test(a) && rx.test(b), name + ': both hosts match the rule (' + a + ', ' + b + ')');
  if (word) need(('https://' + a + '/').includes(word) && ('https://' + b + '/').includes(word), name + ': both URLs contain ' + word);
  if (dom) need(a.endsWith('.' + dom) && b.endsWith('.' + dom), name + ': both under ' + dom);
  need(blocked(D, a) && blocked(D, b), name + ': base blocks both (' + route(D, a) + ', ' + route(D, b) + ')');
  const e = ctx(live(raggr['Default.pac'], { blocked: [], allowed: [a] }));
  need(route(e, a) === 'DIRECT', name + ': Allow ' + a + ' -> DIRECT (got ' + route(e, a) + ')');
  need(route(e, b) === 'PROXY 127.0.0.1:8788', name + ': sibling ' + b + ' still blocked (got ' + route(e, b) + ')');
  tested++;
}
// user Allow also beats a user Block of the same host, and a user Block still blocks a sibling
{ const e = ctx(live(raggr['Default.pac'], { blocked: ['qwertyuiop.shop', 'beta.example.org'], allowed: ['qwertyuiop.shop'] }));
  need(route(e, 'qwertyuiop.shop') === 'DIRECT' && route(e, 'beta.example.org') === 'PROXY 127.0.0.1:8788' && route(e, 'example.com') === 'DIRECT', 'Allow precedes user Block; user Block works'); }
// wildcard Allow entries cover shape families too: "*.spankbang.com"-style is refused by validation, so test a valid wildcard
{ const e = ctx(live(raggr['Default.pac'], { blocked: [], allowed: ['telemetry*.alpha-raggr.com'] }));
  need(route(e, 'telemetry.alpha-raggr.com') === 'DIRECT' && blocked(e, 'telemetry.beta-raggr.net'), 'wildcard Allow overrides a token rule, sibling stays blocked'); }

// ---- 5. persistence: one saved Allow list, many generations and modes ------------------------------------------------
const saved = { blocked: [], allowed: pairs.map(p => p[1]) };      // AppliedRules.plist: lives outside generation folders
const sib = pairs.map(p => p[2]);
function persist(label, pacs, expectSiblingsBlocked) {
  let direct = 0, sibBlocked = 0, sibTotal = 0;
  for (const m of modes) {
    if (!pacs[m]) { need(false, label + ': missing ' + m); continue; }
    const e = ctx(live(pacs[m], saved)), b = ctx(pacs[m]);
    for (const h of saved.allowed) { const r = route(e, h); need(r === 'DIRECT', label + ' ' + m + ': saved Allow ' + h + ' -> ' + r); if (r === 'DIRECT') direct++; }
    if (expectSiblingsBlocked) for (const h of sib) if (blocked(b, h)) { sibTotal++; if (blocked(e, h)) sibBlocked++; else need(false, label + ' ' + m + ': sibling unblocked ' + h); }
  }
  return label + ': ' + direct + ' allowed->DIRECT over ' + modes.length + ' modes' + (expectSiblingsBlocked ? ', siblings blocked ' + sibBlocked + '/' + sibTotal : '');
}
const report = [];
report.push(persist('r16 generation (before update)', r16 || {}, false));
report.push(persist('RAGGR generation (after update, every mode switch)', raggr, true));
report.push(persist('r16 engine on the RAGGR canonical (older client update)', baseOnly, true));
report.push(persist('rollback to r16', r16 || {}, false));
// The sibling-blocked count must be the full set in every RAGGR mode (shape/label/chain/word/table rules apply in every mode).
{ let full = true; for (const m of modes) { const b = ctx(raggr[m]); for (const h of sib) if (!blocked(b, h)) { full = false; need(false, 'RAGGR ' + m + ' does not block sibling ' + h); } } need(full, 'RAGGR rules apply in all 32 modes'); }

// website exceptions and legacy Custom put the user's Allow first as well
{ const w = ctx(transport(websitePAC(raggr['Default.pac'], ['qwertyuiop.shop', 'alpha.' + tableDoms[0]])));
  need(route(w, 'qwertyuiop.shop') === 'DIRECT' && route(w, 'alpha.' + tableDoms[0]) === 'DIRECT' && blocked(w, 'asdfghjklzx.shop') && blocked(w, 'beta.' + tableDoms[0]), 'website exception: allowed DIRECT, sibling blocked');
  const c = ctx(transport(customPAC(raggr['Default.pac'], [], ['qwertyuiop.store', 'telemetry.alpha-raggr.com'])));
  need(route(c, 'qwertyuiop.store') === 'DIRECT' && route(c, 'telemetry.alpha-raggr.com') === 'DIRECT' && blocked(c, 'asdfghjklzx.store') && blocked(c, 'telemetry.beta-raggr.net'), 'legacy Custom: allowed DIRECT, sibling blocked'); }

// ---- 6. noXXX PIN (PinHostProtected) ---------------------------------------------------------------------------------
// protected = selected mode blocks host or www.host AND the same mode without blockXXX does not.
const withoutXXX = m => { const o = m.replace(/\.pac$/, '').split('+').filter(x => x !== 'blockXXX'); return (o.length ? o.join('+') : 'Default') + '.pac'; };
function pinProtected(set, m, h) { const a = ctx(set[m]), b = ctx(set[withoutXXX(m)]); const bl = (c, x) => blocked(c, x) || blocked(c, 'www.' + x); return bl(a, h) && !bl(b, h); }
const xxxModes = modes.filter(m => m.includes('blockXXX'));
const adult = 'abc123def456.spankbang.com';
let fixedOK = 0, unfixedDrop = 0;
for (const m of xxxModes) {
  if (pinProtected(baseOnly, m, adult)) fixedOK++;      // native fix: base rules from canonical minus compact
  if (!pinProtected(raggr, m, adult)) unfixedDrop++;    // r16 helper on full RAGGR PACs
  if (r16) need(pinProtected(r16, m, adult) === pinProtected(baseOnly, m, adult), 'PIN decision equals r16 in ' + m);
}
need(fixedOK === xxxModes.length, 'fixed helper keeps ' + adult + ' PIN-protected in every noXXX mode (' + fixedOK + '/' + xxxModes.length + ')');
// held domains: the 6 noXXX-overlapping RAGGR domains stay out of the every-mode table, so the PIN still owns them
for (const d of held) for (const m of xxxModes) need(!blocked(ctx(raggr[withoutXXX(m)]), d) || (r16 && blocked(ctx(r16[withoutXXX(m)]), d)), 'held ' + d + ' not blocked outside noXXX (' + withoutXXX(m) + ')');
// a protected host Allowed with the PIN goes DIRECT; non-adult RAGGR hosts are never PIN-gated
need(route(ctx(live(raggr['blockXXX.pac'], { blocked: [], allowed: [adult] })), adult) === 'DIRECT', 'PIN-approved Allow of a noXXX host -> DIRECT');
need(!pinProtected(baseOnly, 'blockXXX.pac', 'qwertyuiop.shop'), 'non-adult RAGGR host needs no PIN');

console.log('RAGGR Allow precedence: ' + tested + ' rules x (allow one -> DIRECT, sibling blocked) [' + C.host_labels.length + ' labels, ' + C.host_patterns.length + ' shapes + 5 spam TLDs, ' + C.chains_add.length + ' chains, ' + C.substrings_add.length + ' words, ' + tableDoms.length + ' table domains]');
for (const r of report) console.log('  ' + r);
console.log('  noXXX PIN on ' + adult + ': fixed helper protected in ' + fixedOK + '/' + xxxModes.length + ' modes; unpatched r16 helper on RAGGR PACs would drop it in ' + unfixedDrop + '/' + xxxModes.length);
if (bad) { console.error('FAILED ' + bad + ' of ' + checks + ' checks'); process.exit(1); }
console.log('raggr-allow: ' + checks + ' checks passed');
