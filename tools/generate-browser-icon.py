#!/usr/bin/env python3
"""Generates the MYB Private app icon: the same canonical ribbon mark as the main MYbloXX identity (tools/generate-
icons.py), optically centred the same way, but on a distinct deep teal "privacy" gradient instead of the main app's
purple -- so the two icons read as clearly related but are never confused for each other on the home screen.
Requires: rsvg-convert, Pillow, numpy (same as tools/generate-icons.py)."""
import io, re, subprocess
from pathlib import Path
from PIL import Image
import numpy as np

root = Path(__file__).resolve().parents[1]
svg = (root / "Brand/MYBRibbon.svg").read_text()
path_data = re.search(r'\bd="([^"]+)"', svg).group(1)
MIN_X, MAX_X, MIN_Y, MAX_Y = 20.0, 108.0, 18.0, 112.0
W, H = MAX_X - MIN_X, MAX_Y - MIN_Y

def _glyph_alpha(big, factor, tx, ty):
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="0 0 {big} {big}">
<path transform="translate({tx:.4f} {ty:.4f}) scale({factor:.6f})" fill="#fff" d="{path_data}"/></svg>'''
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=doc.encode(), check=True, stdout=subprocess.PIPE).stdout
    return np.asarray(Image.open(io.BytesIO(png)).convert("RGBA").getchannel("A")).astype(float) / 255.0

def optical_offset(big, factor, tx, ty):
    a = _glyph_alpha(big, factor, tx, ty)
    ys, xs = np.nonzero(a > 0.5)
    bx, by = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
    wy, wx = np.mgrid[0:big, 0:big]
    cx, cy = (a * wx).sum() / a.sum() + .5, (a * wy).sum() / a.sum() + .5
    return big / 2 - (bx + cx) / 2, big / 2 - (by + cy) / 2

def render(size: int) -> Image.Image:
    scale = 4
    big = size * scale
    factor = big * 0.62 / max(W, H)
    tx = (big - W * factor) / 2 - MIN_X * factor
    ty = (big - H * factor) / 2 - MIN_Y * factor
    dx, dy = optical_offset(big, factor, tx, ty); tx += dx; ty += dy
    # Deep teal background (privacy/shield association, distinct from the main app's purple) + a cooler, paler ribbon tint.
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="0 0 {big} {big}">
<defs>
<linearGradient id="bg" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{big}">
<stop offset="0" stop-color="#0a1416"/><stop offset="1" stop-color="#12272a"/></linearGradient>
<linearGradient id="rb" gradientUnits="userSpaceOnUse" x1="0" y1="{MIN_Y}" x2="0" y2="{MAX_Y}">
<stop offset="0" stop-color="#9df0dc"/><stop offset="1" stop-color="#2fb89a"/></linearGradient>
</defs>
<rect width="{big}" height="{big}" fill="url(#bg)"/>
<path transform="translate({tx:.4f} {ty:.4f}) scale({factor:.6f})" fill="url(#rb)" d="{path_data}"/>
</svg>'''
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=doc.encode(), check=True, stdout=subprocess.PIPE).stdout
    return Image.open(io.BytesIO(png)).convert("RGB").resize((size, size), Image.LANCZOS)

out = root / "PrivateBrowser/Resources"
out.mkdir(parents=True, exist_ok=True)
# iOS resolves "AppIconNNxNN" + device scale to the matching @2x/@3x file; both are provided so it always finds one.
for name, size in (
    ("AppIcon29x29@2x.png", 58), ("AppIcon29x29@3x.png", 87),
    ("AppIcon40x40@2x.png", 80), ("AppIcon40x40@3x.png", 120),
    ("AppIcon60x60@2x.png", 120), ("AppIcon60x60@3x.png", 180),
):
    render(size).save(out / name, "PNG", optimize=True)
print("Generated MYB Private app icon set (teal privacy variant of the ribbon mark).")
