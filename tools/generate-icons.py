#!/usr/bin/env python3
"""Generate MYbloXX identity artwork.

Consumers, and who owns the corner shape for each:
  * MYBIcon*.png (in-app mark, web brand image): opaque full-bleed square. The view / CSS clips it ONCE with the iOS
    continuous curve (MYBMarkView, border-radius 22.37%).
  * MYBSettingsIcon*.png (the row in iOS Settings, loaded by PreferenceLoader): PRE-MASKED with the iOS continuous
    squircle, transparent outside it, and carrying the same subtle frame as the in-app mark (apply_frame). Settings does not mask a third-party row icon reliably, which is why an opaque
    square showed as a square. The mask curve is the iOS one, so if a system mask is also applied it clips nothing.
  * Control Centre glyph: transparent white template, tinted by iOS.
The ribbon is placed by optical centre (average of its bounding-box centre and its centre of mass), because the mark is
top-heavy and bounding-box centring made it look high and off-centre. The canonical ribbon vector in
Brand/MYBRibbon.svg is used unchanged.

Rendering: SVG -> 4x supersampled bitmap (rsvg-convert) -> Lanczos downsample -> RGB.
Requires: rsvg-convert, Pillow.
"""
import io, re, subprocess, sys
from pathlib import Path
from PIL import Image, ImageChops
import numpy as np

root = Path(__file__).resolve().parents[1]
svg = (root / "Brand/MYBRibbon.svg").read_text()
path_data = re.search(r'\bd="([^"]+)"', svg).group(1)

# Bounds of the canonical ribbon in its 128-unit design space (same as the
# previous generator: x 20..108, y 18..112).
MIN_X, MAX_X, MIN_Y, MAX_Y = 20.0, 108.0, 18.0, 112.0
W, H = MAX_X - MIN_X, MAX_Y - MIN_Y

def _glyph_alpha(big: int, factor: float, tx: float, ty: float):
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="0 0 {big} {big}">
<path transform="translate({tx:.4f} {ty:.4f}) scale({factor:.6f})" fill="#fff" d="{path_data}"/></svg>'''
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=doc.encode(), check=True, stdout=subprocess.PIPE).stdout
    return np.asarray(Image.open(io.BytesIO(png)).convert("RGBA").getchannel("A")).astype(float) / 255.0

def optical_offset(big: int, factor: float, tx: float, ty: float):
    """(dx, dy) in big-canvas pixels that put the average of bbox centre and centre of mass on the canvas centre."""
    a = _glyph_alpha(big, factor, tx, ty)
    ys, xs = np.nonzero(a > 0.5)
    bx, by = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
    wy, wx = np.mgrid[0:big, 0:big]
    cx, cy = (a * wx).sum() / a.sum() + .5, (a * wy).sum() / a.sum() + .5
    return big / 2 - (bx + cx) / 2, big / 2 - (by + cy) / 2

def squircle_alpha(size: int, n: float = 5.0, inset: float = 0.0) -> Image.Image:
    """Alpha mask of the iOS-style continuous rounded square |x|^n + |y|^n <= r^n, 8x supersampled.
    `inset` is a distance in pixels from the outer edge; the shape shrinks uniformly towards the centre by that amount."""
    s8 = size * 8
    c = (np.arange(s8) + .5) / s8 * 2 - 1
    x, y = np.meshgrid(c, c)
    r = max(0.0, 1.0 - 2.0 * inset / size)
    m = (np.abs(x) ** n + np.abs(y) ** n <= r ** n).astype(np.uint8) * 255
    return Image.fromarray(m, "L").resize((size, size), Image.LANCZOS)

# The framed mark in the main header (MYBMarkView) has a 0.75 pt border, white at 24% opacity. The Settings row icon gets the
# same frame, drawn just inside the squircle edge so the mask never clips it. Width scales with the pixel size of the
# variant (29 px = 1x, 58 px = 2x, 87 px = 3x), so it is 0.75 pt at every scale.
FRAME_POINTS, FRAME_ALPHA, ICON_POINTS = 0.75, 0.24, 29.0

def apply_frame(img: Image.Image, size: int) -> Image.Image:
    width = FRAME_POINTS * size / ICON_POINTS
    ring = np.asarray(squircle_alpha(size)).astype(float) - np.asarray(squircle_alpha(size, inset=width)).astype(float)
    ring = np.clip(ring, 0, 255) / 255.0 * FRAME_ALPHA
    base = np.asarray(img.convert("RGB")).astype(float)
    out = base * (1 - ring[..., None]) + 255.0 * ring[..., None]
    return Image.fromarray(np.rint(out).astype(np.uint8), "RGB")

def render(size: int, masked: bool = False) -> Image.Image:
    scale = 4
    big = size * scale
    factor = big * 0.62 / max(W, H)
    tx = (big - W * factor) / 2 - MIN_X * factor
    ty = (big - H * factor) / 2 - MIN_Y * factor
    dx, dy = optical_offset(big, factor, tx, ty);tx += dx;ty += dy
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="0 0 {big} {big}">
<defs>
<linearGradient id="bg" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{big}">
<stop offset="0" stop-color="#0e1118"/><stop offset="1" stop-color="#1f212e"/></linearGradient>
<linearGradient id="rb" gradientUnits="userSpaceOnUse" x1="0" y1="{MIN_Y}" x2="0" y2="{MAX_Y}">
<stop offset="0" stop-color="#cfa3fa"/><stop offset="1" stop-color="#8c50d6"/></linearGradient>
</defs>
<rect width="{big}" height="{big}" fill="url(#bg)"/>
<path transform="translate({tx:.4f} {ty:.4f}) scale({factor:.6f})" fill="url(#rb)" d="{path_data}"/>
</svg>'''
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=doc.encode(),
                         check=True, stdout=subprocess.PIPE).stdout
    img = Image.open(io.BytesIO(png)).convert("RGB").resize((size, size), Image.LANCZOS)
    if not masked:
        return img                                       # opaque: the view / CSS owns the corner shape
    out = apply_frame(img, size).convert("RGBA");out.putalpha(squircle_alpha(size));return out

def save_all():
    res = root / "Preferences/Resources"
    for name, size in (("MYBIcon.png", 180),):
        render(size).save(res / name, "PNG", optimize=True)
    for folder in ("Preferences/Resources", "layout/Library/PreferenceLoader/Preferences"):
        out = root / folder
        out.mkdir(parents=True, exist_ok=True)
        for name, size in (("MYBSettingsIcon.png", 29), ("MYBSettingsIcon@2x.png", 58), ("MYBSettingsIcon@3x.png", 87)):
            render(size, masked=True).save(out / name, "PNG", optimize=True)
save_all()
print("Generated: opaque in-app mark; pre-masked Settings row icons (iOS squircle, optically centred).")

# Control Centre glyph: a transparent, white, centred template image (iOS tints it). The ribbon is fitted to 62% of the
# canvas on its longest side so the optical weight matches system glyphs, and is centred by its real bounds.
def glyph(size: int) -> Image.Image:
    scale = 4
    big = size * scale
    factor = big * 0.62 / max(W, H)
    tx = (big - W * factor) / 2 - MIN_X * factor
    ty = (big - H * factor) / 2 - MIN_Y * factor
    dx, dy = optical_offset(big, factor, tx, ty);tx += dx;ty += dy
    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="0 0 {big} {big}">
<path transform="translate({tx:.4f} {ty:.4f}) scale({factor:.6f})" fill="#ffffff" d="{path_data}"/></svg>'''
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=doc.encode(),
                         check=True, stdout=subprocess.PIPE).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA").resize((size, size), Image.LANCZOS)

cc = root / "CCPreview/Resources"
for name, size in (("icon.png", 36), ("icon@2x.png", 72), ("icon@3x.png", 108)):
    glyph(size).save(cc / name, "PNG", optimize=True)
print("Generated transparent Control Centre glyphs.")
