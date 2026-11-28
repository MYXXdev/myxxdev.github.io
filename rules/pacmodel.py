"""Decode and encode the compact PAC format that MYbloXX ships.

The format (reverse-hostname tables, front-coded) is the one in the supplied Default.pac. This module is the only place
that knows it. decode() turns a PAC into an explicit model; encode() writes the model back deterministically.
"""
import re

def _var(lines, name):
    for l in lines:
        m = re.match(r'var ' + name + r'=(.*);\s*$', l)
        if m: return m.group(1)
    raise KeyError(name)

def _str(lit):
    assert lit[0] == '"' and lit[-1] == '"', lit[:40]
    return lit[1:-1].encode().decode('unicode_escape') if '\\' in lit else lit[1:-1]

def front_decode(A, T):
    """A: first entry of each block, T: per block deltas. Same algorithm as mybBlock()."""
    entries = []
    for p, t in zip(A, T):
        block = [p]
        if t:
            for k in re.split(r'(?=[A-Z])', t):
                if not k: continue
                p = p[:ord(k[0]) - 65] + k[1:]
                block.append(p)
        entries.extend(block)
    return entries

def front_encode(entries, block=32):
    """Entries must be sorted and unique. Blocks of `block` entries: the first is stored whole, each later one as
    chr(65+cut)+tail where cut is the length it shares with the previous entry, capped at 25 (A..Z)."""
    A, T = [], []
    for i in range(0, len(entries), block):
        chunk = entries[i:i + block]
        deltas = ''; prev = chunk[0]
        for e in chunk[1:]:
            cut = 0
            while cut < min(len(prev), len(e)) and prev[cut] == e[cut]: cut += 1
            cut = min(cut, 25)
            assert not any(c.isupper() for c in e), e
            deltas += chr(65 + cut) + e[cut:]
            prev = e
        A.append(chunk[0]); T.append(deltas)
    return A, T

def _split_list(lit):
    s = _str(lit)
    return s.split(',') if s else []


# ---- literal alternation regexes: (?:a|b(?:c|d)) -> {"a","bc","bd"} and back to a trie regex --------------------
def regex_literals(src):
    """Expand the shipped trie regex /(?:...)/ into the set of literal substrings it matches. Only the constructs the
    shipped regexes use are accepted (groups, alternation, escaped literals); anything else raises."""
    m = re.match(r'^/(.*)/$', src, re.S); assert m, src[:40]
    body = m.group(1)
    pos = 0

    def parse_alt():
        nonlocal pos
        options = [parse_seq()]
        while pos < len(body) and body[pos] == '|':
            pos += 1; options.append(parse_seq())
        out = set()
        for o in options: out |= o
        return out

    def parse_seq():
        nonlocal pos
        acc = {''}
        while pos < len(body) and body[pos] not in '|)':
            c = body[pos]
            if c == '(':
                assert body.startswith('(?:', pos), body[pos:pos + 10]
                pos += 3; inner = parse_alt(); assert body[pos] == ')'; pos += 1
                if pos < len(body) and body[pos] == '?':
                    pos += 1; inner = inner | {''}
                acc = {a + b for a in acc for b in inner}
            elif c == '[':
                pos += 1; chars = set()
                while body[pos] != ']':
                    ch = body[pos]
                    if ch == '\\': pos += 1; ch = body[pos]
                    chars.add(ch); pos += 1
                pos += 1
                if pos < len(body) and body[pos] == '?': pos += 1; chars.add('')
                acc = {a + b for a in acc for b in chars}
            else:
                if c == '\\':
                    pos += 1; c = body[pos]
                    assert c in '.\\/-+*?[](){}|^$_&=:;,!@#%~\'"', 'unsupported escape \\' + c
                else:
                    assert c not in '.[]{}+*?^$', 'unsupported regex char ' + c
                pos += 1
                acc = {a + c for a in acc}
        return acc

    out = parse_alt(); assert pos == len(body), (pos, len(body)); return out


def _esc(ch):
    return '\\' + ch if ch in '.\\/+*?[](){}|^$' else ch

def literals_regex(words):
    """Deterministic trie regex of a set of literal substrings (no empty string)."""
    words = sorted(set(words)); assert '' not in words
    def build(ws, depth):
        groups = {}
        end = False
        for w in ws:
            if len(w) == depth: end = True
            else: groups.setdefault(w[depth], []).append(w)
        parts = []
        for ch in sorted(groups):
            sub = groups[ch]
            # common prefix chain
            d = depth + 1
            while True:
                nxt = {w[d] if len(w) > d else None for w in sub}
                if len(nxt) == 1 and None not in nxt: d += 1
                else: break
            prefix = sub[0][depth:d]
            rest = build(sub, d)
            parts.append(''.join(_esc(c) for c in prefix) + rest)
        if not parts: return ''
        if len(parts) == 1 and not end: return parts[0]
        body = '|'.join(parts)
        if end: return '(?:' + body + ')?'
        return '(?:' + body + ')'
    inner = build(words, 0)
    if inner.startswith('(?:') and inner.endswith(')') and not inner.endswith(')?'):
        return '/' + inner + '/'
    return '/(?:' + inner + ')/'


# ---- whole-PAC decode --------------------------------------------------------------------------------------------
import json

def _tables(lines, a, t):
    def g(name):
        for l in lines:
            m = re.match(r'var ' + name + r'="(.*)"\.split\(","\)', l)
            if m: return m.group(1).split(',')
        return None
    A, T = g(a), g(t)
    if A is None: return []
    return front_decode(A, T)

def decode(text):
    lines = text.split('\n')
    m = re.search(r'var MYbloXX="([^"]+)",ALLOW="([^"]+)",BYPASS="([^"]+)";', text); assert m
    def rx(name):
        for l in lines:
            mm = re.match(r'var ' + name + r'=(/.*/);\s*$', l)
            if mm: return sorted(regex_literals(mm.group(1)))
        raise KeyError(name)
    def more(name):
        for l in lines:
            mm = re.match(r'var ' + name + r'=(\[.*\]);\s*$', l)
            if mm: return json.loads(mm.group(1))
        raise KeyError(name)
    f = re.search(r'var MYB_FILE=(/.*/);', text).group(1)
    ka = _tables(lines, 'MYB_KA', 'MYB_KT')
    return {
        'transport': {'block': m.group(1), 'allow': m.group(2), 'bypass': m.group(3)},
        'allow': {'substrings': rx('MYB_ALLOW'), 'chains': more('MYB_ALLOW_MORE')},
        'bypass': {'substrings': rx('MYB_BYPASS'), 'chains': more('MYB_BYPASS_MORE')},
        'block': {'substrings': rx('MYB_BLOCK'), 'chains': more('MYB_BLOCK_MORE'), 'file': f},
        'suffixes': _tables(lines, 'MYB_A', 'MYB_T'),     # reversed host prefixes, NO label boundary (legacy table)
        'domains': _tables(lines, 'MYB_SA', 'MYB_ST'),    # reversed host + '.', so a label boundary is required
        'kill': ka,                                       # reversed host + '.', blocked even where an allow matches
    }
