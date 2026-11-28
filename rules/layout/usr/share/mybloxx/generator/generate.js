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
    domains = antichain(domains); kill = antichain(kill);
    return { domains: sortedUnique(Array.from(domains)), kill: sortedUnique(Array.from(kill)), substrings: sortedUnique(Array.from(subs)), chains: chains };
  }
  function rev(s) { return s.split('').reverse().join(''); }
  function table(entries) { return frontEncode(sortedUnique(entries.map(function (e) { return rev(e) + '.'; }))); }
  function arr(name, entries) { return entries.length ? 'var ' + name + '="' + entries.join(',') + '".split(",")' : 'var ' + name + '=[]'; }
  function compact(v) { return JSON.stringify(v); }
  function stampDigits(s) { var m = /^(\d{2})\/(\d{2})\/(\d{2}) - (\d{2}):(\d{2})/.exec(s); if (!m) throw new Error('bad stamp'); return '20' + m[3] + m[1] + m[2] + m[4] + m[5]; }
  function build(C, runtime, options) {
    var eff = effective(C, options), b = C.base, t = C.transport, mid = modeID(C.order, options), out = [];
    out.push('var MYB_STAMP=' + stampDigits(C.stamp) + ';');
    out.push('var MYbloXX="' + t.block + '",ALLOW="' + t.allow + '",BYPASS="' + t.bypass + '";');
    out.push('var MYB_ALLOW=' + literalsRegex(b.allow.substrings) + ';');
    out.push('var MYB_ALLOW_MORE=' + compact(b.allow.chains) + ';');
    out.push('var MYB_BYPASS=' + literalsRegex(b.bypass.substrings) + ';');
    out.push('var MYB_BYPASS_MORE=' + compact(b.bypass.chains) + ';');
    out.push('var MYB_BLOCK=' + literalsRegex(eff.substrings) + ';');
    out.push('var MYB_BLOCK_MORE=' + compact(eff.chains) + ';');
    out.push('var MYB_FILE=' + b.block.file + ';');
    out.push('var MYB_A=[],MYB_T=[],MYB_C=[];');
    var at = table(eff.domains);
    out.push(arr('MYB_SA', at[0]) + ',' + arr('MYB_ST', at[1]).replace('var ', '') + ',MYB_SC=[];');
    if (eff.kill.length) {
      var kt = table(eff.kill);
      out.push('var MYB_KA="' + kt[0].join(',') + '".split(","),MYB_KC=[];'); out.push('var MYB_KT="' + kt[1].join(',') + '".split(",");');
    } else out.push('var MYB_KA=[],MYB_KT=[],MYB_KC=[];');
    var ok = {}, hosts = C.exact_allow.slice(), unless = C.exact_allow_unless || {};
    Object.keys(unless).forEach(function (h) { if (!unless[h].some(function (o) { return options.indexOf(o) >= 0; })) hosts.push(h); });
    sortedUnique(hosts).forEach(function (h) { ok[h] = 1; });
    out.push('var MYB_OK=' + compact(ok) + ';');
    out.push(runtime.replace(/\n+$/, ''));
    return out.join('\n') + '\n\n';
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
    if (!C || C.format !== 1 || !C.base || !C.options || !C.transport || !C.aliases) return 'rules are missing required sections';
    if (JSON.stringify(C.order) !== JSON.stringify(['allowY', 'blockAdSense', 'blockApple', 'blockSocials', 'blockXXX'])) return 'option order changed';
    var t = C.transport; if (t.block !== 'PROXY 127.0.0.1:8021' || t.allow !== 'DIRECT' || t.bypass !== 'PROXY 8.8.8.8:53') return 'transport values changed';
    if (typeof C.stamp !== 'string' || C.stamp.length > 60 || /[\r\n"\\]/.test(C.stamp) || !/^\d{2}\/\d{2}\/\d{2} - \d{2}:\d{2}/.test(C.stamp)) return 'bad stamp';
    var r = hosts(C.base.domains, 'domains') || hosts(C.base.kill, 'kill') || hosts(C.exact_allow, 'exceptions') || hosts(Object.keys(C.exact_allow_unless || {}), 'conditional exceptions') || list(C.base.block.substrings, 'block words') || list(C.base.allow.substrings, 'allow words') || list(C.base.bypass.substrings, 'bypass words');
    if (r) return r;
    var un = C.exact_allow_unless || {}, uk = Object.keys(un);
    for (var q = 0; q < uk.length; q++) if (!Array.isArray(un[uk[q]]) || !un[uk[q]].length || un[uk[q]].some(function (o) { return C.order.indexOf(o) < 0; })) return 'conditional exception names an unknown option';
    if (C.base.domains.length < 2000 || C.base.domains.length > 40000) return 'domain count is out of range';
    if (typeof C.base.block.file !== 'string' || C.base.block.file.charAt(0) !== '/') return 'bad file rule';
    for (var i = 0; i < C.order.length; i++) {
      var o = C.options[C.order[i]]; if (!o) return 'missing option ' + C.order[i];
      r = hosts(o.domains_add, 'option domains') || hosts(o.domains_remove, 'option exemptions') || hosts(o.kill_add, 'option kill') || list(o.substrings_add, 'option words');
      if (r) return r;
    }
    // Apple, certificates and the update service must never become blocked by a rules update in Default; they are guarded
    // by this explicit list (noApple is an option the user chooses, never Default).
    var dom = new Set(C.base.domains), kill = new Set(C.base.kill), guard = ['apple.com', 'icloud.com', 'mzstatic.com', 'ocsp.apple.com', 'googleapis.com', 'github.com', 'githubusercontent.com', 'microsoftonline.com', 'login.live.com', 'facebook.com', 'instagram.com', 'youtube.com', 'google.com'];
    for (i = 0; i < guard.length; i++) if (dom.has(guard[i]) || kill.has(guard[i])) return 'a protected service is blocked in Default: ' + guard[i];
    if (!dom.has('googlesyndication.com') && C.base.block.substrings.indexOf('doubleclick') < 0 && !dom.has('doubleclick.net')) return 'core ad rules missing';
    return '';
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
