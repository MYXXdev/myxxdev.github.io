#!/usr/bin/env python3
"""Compiles Mikey's own aggregated junk-caller phone list (tools/data/junk-callers-source.txt, one "+digits" E.164-style number per line) into the
compact, sorted, fixed-width binary dataset the Call Firewall's "Known Junk Callers" hook binary-searches at runtime (Shared/MYBJunkCallers.h).
Format: an 8-byte little-endian record count, then that many 15-byte zero-padded digit records, sorted ascending -- fixed width keeps numeric and
byte order identical, so the hook's binary search needs no parsing. A line that is not a bare "+" followed by 1-15 digits is skipped and counted,
never silently folded into the dataset or miscounted."""
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'tools' / 'data' / 'junk-callers-source.txt'
OUT = ROOT / 'layout' / 'usr' / 'share' / 'mybloxx' / 'junk-callers' / 'JunkCallers.dat'
RECORD_LEN = 15

OUT.parent.mkdir(parents=True, exist_ok=True)

seen = set()
invalid = 0
kept = 0
for line in SRC.read_text().splitlines():
    line = line.strip()
    if not line:
        continue
    digits = line[1:] if line.startswith('+') else None
    if not digits or not digits.isdigit() or not (1 <= len(digits) <= RECORD_LEN):
        invalid += 1
        continue
    kept += 1
    seen.add(digits.zfill(RECORD_LEN))

records = sorted(seen)
duplicates = kept - len(records)
with OUT.open('wb') as f:
    f.write(struct.pack('<Q', len(records)))
    for r in records:
        f.write(r.encode('ascii'))

print(f'Compiled {len(records)} junk-caller records ({invalid} invalid lines, {duplicates} duplicates skipped) -> {OUT}')
