// Deterministic PAC generator, JavaScript twin of rules/generate.py.
// It runs inside JavaScriptCore on the device (the helper feeds it canonical rules and rules/runtime.txt) and under node in CI,
// where tests require byte-identical output to the Python generator. Pure function: no I/O, no clock, no randomness.
// MYBGenerate(canonJSON, runtimeText) -> JSON string {"<modeID>.pac name": "<pac text>"} for every combination and alias.
// MYBValidateCanonical(canonJSON) -> "" when acceptable, else a plain reason.
(function (g) {
  'use strict';
  function sortedUnique(a) { return Array.from(new Set(a)).sort(); }
  function frontEncode(entries) {
    var A = [], T = [];
    for (var i = 0; i < entries.length; i += 32) {
      var chunk = entries.slice(i, i + 32), deltas = '', prev = chunk[0];
      for (var j = 1; j < chunk.length; j++) {
        var e = chunk[j], cut = 0, m = Math.min(prev.length, e.length);
        while (cut < m && prev[cut] === e[cut]) cut++;
        cut = Math.min(cut, 25);
        deltas += String.fromCharCode(65 + cut) + e.substring(cut);
        prev = e;
      }
      A.push(chunk[0]); T.push(deltas);
    }
    return [A, T];
  }
  function esc(ch) { return '.\\/+*?[](){}|^$'.indexOf(ch) >= 0 ? '\\' + ch : ch; }
  function literalsRegex(words) {
    words = sortedUnique(words);
    function build(ws, depth) {
      var groups = {}, order = [], end = false, i;
      for (i = 0; i < ws.length; i++) {
        var w = ws[i];
        if (w.length === depth) end = true;
        else { var c = w.charAt(depth); if (!groups.hasOwnProperty(c)) { groups[c] = []; order.push(c); } groups[c].push(w); }
      }
      order.sort();
      var parts = [];
      for (i = 0; i < order.length; i++) {
        var sub = groups[order[i]], d = depth + 1;
        for (;;) {
          var first = null, same = true;
          for (var k = 0; k < sub.length; k++) {
            var n = sub[k].length > d ? sub[k].charAt(d) : null;
            if (n === null) { same = false; break; }
            if (first === null) first = n; else if (first !== n) { same = false; break; }
          }
          if (same) d++; else break;
        }
        var prefix = sub[0].substring(depth, d), pe = '';
        for (var q = 0; q < prefix.length; q++) pe += esc(prefix.charAt(q));
        parts.push(pe + build(sub, d));
      }
      if (!parts.length) return '';
      if (parts.length === 1 && !end) return parts[0];
      var body = parts.join('|');
      return end ? '(?:' + body + ')?' : '(?:' + body + ')';
    }
    var inner = build(words, 0);
    if (inner.indexOf('(?:') === 0 && inner.charAt(inner.length - 1) === ')' && inner.slice(-2) !== ')?') return '/' + inner + '/';
    return '/(?:' + inner + ')/';
  }
  function modeID(order, options) {
    var chosen = order.filter(function (o) { return options.indexOf(o) >= 0; });
    return chosen.length ? chosen.join('+') : 'Default';
  }
  function allIDs(order) {
    var ids = [], n = order.length;
    for (var mask = 0; mask < (1 << n); mask++) {
      var o = []; for (var i = 0; i < n; i++) if (mask & (1 << i)) o.push(order[i]);
      ids.push(modeID(order, o));
    }
    return ids.sort(function (a, b) {
      var ka = a === 'Default' ? -1 : a.split('+').length - 1, kb = b === 'Default' ? -1 : b.split('+').length - 1;
      return ka !== kb ? ka - kb : (a < b ? -1 : a > b ? 1 : 0);
    });
  }
  function antichain(set) {
    var out = new Set();
    set.forEach(function (d) {
      var p = d.split('.'), covered = false;
      for (var i = 1; i < p.length && !covered; i++) if (set.has(p.slice(i).join('.'))) covered = true;
      if (!covered) out.add(d);
    });
    return out;
  }
  function effective(C, options) {
    var b = C.base, sel = C.order.filter(function (o) { return options.indexOf(o) >= 0; }).map(function (o) { return C.options[o]; });
    var domains = new Set(b.domains), kill = new Set(b.kill), subs = new Set(b.block.substrings), chains = b.block.chains.map(function (c) { return JSON.parse(JSON.stringify(c)); });
    sel.forEach(function (o) { o.domains_remove.forEach(function (d) { domains.delete(d); }); });
    sel.forEach(function (o) {
      o.domains_add.forEach(function (d) { domains.add(d); });
      o.kill_add.forEach(function (d) { kill.add(d); });
      o.substrings_add.forEach(function (d) { subs.add(d); });
      o.chains_add.forEach(function (c) { var s = JSON.stringify(c), has = chains.some(function (x) { return JSON.stringify(x) === s; }); if (!has) chains.push(c); });
    });
    if (C.compact) {
      (C.compact.substrings_add || []).forEach(function (d) { subs.add(d); });
      (C.compact.chains_add || []).forEach(function (c) { var s = JSON.stringify(c), has = chains.some(function (x) { return JSON.stringify(x) === s; }); if (!has) chains.push(c); });
    }
    domains = antichain(domains); kill = antichain(kill);
    return { domains: sortedUnique(Array.from(domains)), kill: sortedUnique(Array.from(kill)), substrings: sortedUnique(Array.from(subs)), chains: chains };
  }
  function rev(s) { return s.split('').reverse().join(''); }
  function table(entries) { return frontEncode(sortedUnique(entries.map(function (e) { return rev(e) + '.'; }))); }
  function arr(name, entries) { return entries.length ? 'var ' + name + '="' + entries.join(',') + '".split(",")' : 'var ' + name + '=[]'; }
  function compact(v) { return JSON.stringify(v); }
  // ---- optional "compact" section (engine 2). An older generator ignores it and builds the same base rules without it. ----
  // table_dict: substring dictionary for the main domain table, applied in order (encode) and undone in reverse (decode).
  // host_labels / host_patterns: host-only rules tested on the lowercased host after every allow, exception and bypass.
  var HOST_HOOK = 'matchesPattern(u,BLOCK_PATTERNS)||';
  var DICT_FN = 'function MYBd(s,R){for(var i=R.length-1,k;i>=0;i--){k=R[i].charAt(0)=="~"?2:1;s=s.split(R[i].substring(0,k)).join(R[i].substring(k))}return s}';
  var CC2 = '(?!(?:com?|gov|ac|org|net|edu|go|gob|or|ne|blogspot)\\.[a-z]{2,3}$)';
  function dictCode(r) { return r.charAt(0) === '~' ? r.substring(0, 2) : r.charAt(0); }
  function dictEncode(s, R) { for (var i = 0; i < R.length; i++) { var k = dictCode(R[i]); s = s.split(R[i].substring(k.length)).join(k); } return s; }
  function dictDecode(s, R) { for (var i = R.length - 1; i >= 0; i--) { var k = dictCode(R[i]); s = s.split(k).join(R[i].substring(k.length)); } return s; }
  function hostRegex(X) {
    var parts = [];
    if (X.host_labels.length) parts.push('^' + literalsRegex(X.host_labels).slice(1, -1) + '\\.' + (X.labels_cc2 ? CC2 : '') + '[^.]+\\.');
    return parts.concat(X.host_patterns).join('|');
  }
  function chainRegex(chains) {
    var groups = {}, seconds = [];
    chains.forEach(function (c) { var s = c[1][1]; if (!groups.hasOwnProperty(s)) { groups[s] = []; seconds.push(s); } groups[s].push(c[1][0]); });
    return seconds.sort().map(function (s) { var e = ''; for (var i = 0; i < s.length; i++) e += esc(s.charAt(i)); return literalsRegex(groups[s]).slice(1, -1) + '.*' + e; }).join('|');
  }
  function applyCompact(C, out, eff, at) {
    var X = C.compact, extra = '', i;
    if (!X) return { extra: '', hook: '' };
    // three-label chains [true,[a,b]] become one URL regex test instead of a loop of indexOf
    var merge = eff.chains.filter(function (c) { return c[0] && c[1].length === 2; }), keep = eff.chains.filter(function (c) { return !(c[0] && c[1].length === 2); });
    for (i = 0; i < out.length; i++) if (out[i].indexOf('var BLOCK_PATTERNS=') === 0) out[i] = 'var BLOCK_PATTERNS=' + compact(keep) + ';';
    var hook = '';
    if (merge.length) { extra += 'var BLOCK_CHAIN_RE=/' + chainRegex(merge) + '/;'; hook += 'BLOCK_CHAIN_RE.test(u)||'; }
    var hr = hostRegex(X);
    if (hr) { extra += 'var HOST_BLOCK=/' + hr + '/;'; hook += 'HOST_BLOCK.test(h)||'; }
    if (X.table_dict.length && at[0].length) {
      var payload = at[0].join(',') + '|' + at[1].join(','), enc = dictEncode(payload, X.table_dict);
      if (dictDecode(enc, X.table_dict) === payload) for (i = 0; i < out.length; i++) if (out[i].indexOf('var BLOCKED_DOMAIN_ROOTS=') === 0)
        out[i] = 'var Q=MYBd("' + enc + '","' + X.table_dict.join(' ') + '".split(" ")).split("|");var BLOCKED_DOMAIN_ROOTS=Q[0].split(","),BLOCKED_DOMAIN_SUFFIXES=Q[1].split(",");' + DICT_FN + 'var BLOCKED_DOMAIN_CACHE=[];';
    }
    return { extra: extra, hook: hook };
  }
  function build(C, runtime, options) {
    var eff = effective(C, options), b = C.base, t = C.transport, mid = modeID(C.order, options), out = [];
    var display = {allowY: 'allowY!', blockApple: 'noApple', blockSocials: 'noSocials', blockXXX: 'noXXX'};
    var title = mid.split('+').map(function (name) { return display[name] || name; }).join(' + ');
    out.push('//', '// MYbloXX by MYXXdev (' + title + ')', '// Updated: ' + C.stamp,
      '// Support Development: myxxfm.com/donate', '//');
    out.push('var MYbloXX="' + t.block + '";\nvar ALLOW="' + t.allow + '";\nvar BYPASS="' + t.bypass + '";');
    out.push('var ALLOW_RULES=' + literalsRegex(b.allow.substrings.concat(C.compact ? C.compact.allow_substrings_add || [] : [])) + ';');
    out.push('var ALLOW_PATTERNS=' + compact(b.allow.chains) + ';');
    out.push('var BYPASS_RULES=' + literalsRegex(b.bypass.substrings) + ';');
    out.push('var BYPASS_PATTERNS=' + compact(b.bypass.chains) + ';');
    out.push('var BLOCK_RULES=' + literalsRegex(eff.substrings) + ';');
    out.push('var BLOCK_PATTERNS=' + compact(eff.chains) + ';');
    out.push('var BLOCKED_FILES=' + b.block.file + ';');
    var at = table(eff.domains);
    out.push(arr('BLOCKED_DOMAIN_ROOTS', at[0]) + ';' + arr('BLOCKED_DOMAIN_SUFFIXES', at[1]) + ';var BLOCKED_DOMAIN_CACHE=[];');
    if (eff.kill.length) {
      var kt = table(eff.kill);
      out.push('var PRIORITY_DOMAIN_ROOTS="' + kt[0].join(',') + '".split(",");var PRIORITY_DOMAIN_CACHE=[];'); out.push('var PRIORITY_DOMAIN_SUFFIXES="' + kt[1].join(',') + '".split(",");');
    } else out.push('var PRIORITY_DOMAIN_ROOTS=[];var PRIORITY_DOMAIN_SUFFIXES=[];var PRIORITY_DOMAIN_CACHE=[];');
    var ok = {}, hosts = C.exact_allow.slice(), unless = C.exact_allow_unless || {};
    Object.keys(unless).forEach(function (h) { if (!unless[h].some(function (o) { return options.indexOf(o) >= 0; })) hosts.push(h); });
    sortedUnique(hosts).forEach(function (h) { ok[h] = 1; });
    out.push('var ALLOWED_HOSTS=' + compact(ok) + ';');
    var cx = applyCompact(C, out, eff, at), rt = runtime.replace(/\n+$/, '');
    if (cx.extra) out.push(cx.extra);
    if (cx.hook) { if (rt.split(HOST_HOOK).length !== 2) throw new Error('runtime has no single block hook'); rt = rt.replace(HOST_HOOK, HOST_HOOK + cx.hook); }
    out.push(rt);
    return out.slice(0, 5).join('\n') + '\n' + out.slice(5).join('').replace(/\n/g, '') + '\n';
  }
  g.MYBGenerate = function (canonJSON, runtime) {
    var C = JSON.parse(canonJSON), res = {};
    allIDs(C.order).forEach(function (id) { res[id + '.pac'] = build(C, runtime, id === 'Default' ? [] : id.split('+')); });
    Object.keys(C.aliases).sort().forEach(function (a) { res[a + '.pac'] = res[C.aliases[a] + '.pac']; });
    return JSON.stringify(res);
  };
  var HOST = /^[a-z0-9_]([a-z0-9_.-]*[a-z0-9_])?$/;
  g.MYBValidateCanonical = function (canonJSON) {
    var C; try { C = JSON.parse(canonJSON); } catch (e) { return 'rules are not valid JSON'; }
    function list(a, what) { if (!Array.isArray(a)) return what + ' is not a list'; for (var i = 0; i < a.length; i++) if (typeof a[i] !== 'string' || !a[i].length || a[i].length > 253) return what + ' has a bad entry'; return ''; }
    function hosts(a, what) { var r = list(a, what); if (r) return r; for (var i = 0; i < a.length; i++) if (!HOST.test(a[i]) || a[i].indexOf('..') >= 0) return what + ' has a malformed host ' + a[i].substring(0, 40); return ''; }
    function chains(a, what) {
      if (!Array.isArray(a)) return what + ' is not a list';
      for (var i = 0; i < a.length; i++) {
        var entry = a[i];
        if (!Array.isArray(entry) || entry.length !== 2 || typeof entry[0] !== 'boolean' ||
            !Array.isArray(entry[1]) || !entry[1].length || list(entry[1], what)) return what + ' has a bad entry';
      }
      return '';
    }
    if (!C || C.format !== 1 || !C.base || !C.options || !C.transport || !C.aliases) return 'rules are missing required sections';
    if (JSON.stringify(C.order) !== JSON.stringify(['allowY', 'blockAdSense', 'blockApple', 'blockSocials', 'blockXXX'])) return 'option order changed';
    var t = C.transport; if (t.block !== 'PROXY 127.0.0.1:8021' || t.allow !== 'DIRECT' || t.bypass !== 'PROXY 8.8.8.8:53') return 'transport values changed';
    var date = typeof C.stamp === 'string' && /^(20\d{2})\/(\d{2})\/(\d{2}) - (\d{2}):(\d{2}) UTC$/.exec(C.stamp);
    if (!date || date[0] !== C.stamp) return 'bad UTC stamp';
    var time = new Date(Date.UTC(+date[1], +date[2] - 1, +date[3], +date[4], +date[5]));
    if (time.getUTCFullYear() !== +date[1] || time.getUTCMonth() + 1 !== +date[2] ||
        time.getUTCDate() !== +date[3] || time.getUTCHours() !== +date[4] ||
        time.getUTCMinutes() !== +date[5]) return 'bad UTC stamp';
    if (!C.base.allow || !C.base.block || !C.base.bypass) return 'missing rule groups';
    var patterns = chains(C.base.allow.chains, 'allow patterns') ||
      chains(C.base.block.chains, 'block patterns') || chains(C.base.bypass.chains, 'bypass patterns');
    if (patterns) return patterns;
    var primaryModes = allIDs(C.order);
    var aliasNames = Object.keys(C.aliases);
    for (var j = 0; j < aliasNames.length; j++) {
      var alias = aliasNames[j];
      if (!/^MYbloXX[A-Za-z]*$/.test(alias) || primaryModes.indexOf(C.aliases[alias]) < 0) return 'bad PAC alias';
    }
    var r = hosts(C.base.domains, 'domains') || hosts(C.base.kill, 'kill') || hosts(C.exact_allow, 'exceptions') || hosts(Object.keys(C.exact_allow_unless || {}), 'conditional exceptions') || list(C.base.block.substrings, 'block words') || list(C.base.allow.substrings, 'allow words') || list(C.base.bypass.substrings, 'bypass words');
    if (r) return r;
    var un = C.exact_allow_unless || {}, uk = Object.keys(un);
    for (var q = 0; q < uk.length; q++) if (!Array.isArray(un[uk[q]]) || !un[uk[q]].length || un[uk[q]].some(function (o) { return C.order.indexOf(o) < 0; })) return 'conditional exception names an unknown option';
    if (C.base.domains.length < 2000 || C.base.domains.length > 40000) return 'domain count is out of range';
    if (typeof C.base.block.file !== 'string' || C.base.block.file.charAt(0) !== '/') return 'bad file rule';
    for (var i = 0; i < C.order.length; i++) {
      var o = C.options[C.order[i]]; if (!o) return 'missing option ' + C.order[i];
      r = hosts(o.domains_add, 'option domains') || hosts(o.domains_remove, 'option exemptions') || hosts(o.kill_add, 'option kill') || list(o.substrings_add, 'option words') || chains(o.chains_add, 'option patterns');
      if (r) return r;
    }
    // Apple, certificates and the update service must never become blocked by a rules update in Default; they are guarded
    // by this explicit list (noApple is an option the user chooses, never Default).
    var dom = new Set(C.base.domains), kill = new Set(C.base.kill), guard = ['apple.com', 'icloud.com', 'mzstatic.com', 'ocsp.apple.com', 'googleapis.com', 'github.com', 'githubusercontent.com', 'microsoftonline.com', 'login.live.com', 'facebook.com', 'instagram.com', 'youtube.com', 'google.com'];
    for (i = 0; i < guard.length; i++) if (dom.has(guard[i]) || kill.has(guard[i])) return 'a protected service is blocked in Default: ' + guard[i];
    if (!dom.has('googlesyndication.com') && C.base.block.substrings.indexOf('doubleclick') < 0 && !dom.has('doubleclick.net')) return 'core ad rules missing';
    return validateCompact(C, guard, list, chains);
  };
  var COMPACT_GUARD = ['example.com', 'www.example.com', 'login.microsoftonline.com', 'raw.githubusercontent.com', 'www.apple.com', 'www.icloud.com', 'www.google.com', 'www.facebook.com', 'www.instagram.com', 'www.youtube.com', 'm.youtube.com', 'dns.google'];
  function validateCompact(C, guard, list, chains) {
    if (!C.hasOwnProperty('compact')) return '';
    var X = C.compact, i, codes = {};
    if (!X || typeof X !== 'object' || X.format !== 2 || !Array.isArray(X.host_labels) || !Array.isArray(X.host_patterns) || !Array.isArray(X.table_dict)) return 'compact rules are malformed';
    if (X.hasOwnProperty('labels_cc2') && typeof X.labels_cc2 !== 'boolean') return 'compact rules are malformed';
    var extra = list(X.substrings_add || [], 'compact words') || list(X.allow_substrings_add || [], 'compact allow words') || chains(X.chains_add || [], 'compact patterns');
    if (extra) return extra;
    if (X.host_labels.length > 2000 || X.host_patterns.length > 500 || X.table_dict.length > 1000) return 'compact rules are too large';
    for (i = 0; i < X.host_labels.length; i++) if (typeof X.host_labels[i] !== 'string' || !/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/.test(X.host_labels[i])) return 'compact rules have a bad host label';
    for (i = 0; i < X.host_patterns.length; i++) {
      var p = X.host_patterns[i];
      if (typeof p !== 'string' || !p.length || p.length > 400 || !/^[a-z0-9^$|?:*+()[\]{}\\.,=!-]+$/.test(p)) return 'compact rules have a bad host pattern';
      try { new RegExp(p); } catch (e) { return 'compact rules have a bad host pattern'; }
    }
    for (i = 0; i < X.table_dict.length; i++) {
      var r = X.table_dict[i];
      if (typeof r !== 'string' || !/^[!#-[\]-~]+$/.test(r) || r.length < (r.charAt(0) === '~' ? 3 : 2)) return 'compact rules have a bad dictionary entry';
      var k = dictCode(r); if (codes.hasOwnProperty(k)) return 'compact rules have a bad dictionary entry'; codes[k] = 1;
    }
    var hr = hostRegex(X);
    if (hr) { var re = new RegExp(hr), hosts = COMPACT_GUARD.concat(guard); for (i = 0; i < hosts.length; i++) if (re.test(hosts[i])) return 'a protected service is blocked in Default: ' + hosts[i]; }
    return '';
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
