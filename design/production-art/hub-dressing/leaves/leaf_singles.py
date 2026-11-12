"""Single autumn leaves for the hub (owner 11-11: "make a few good singles, and once approved combine them").

Cut-outs from the ScatteredLeaves008 scan are ~30 px per leaf at 2K (a carpet of small beech leaves), too small and
too busy for a single leaf. So the two passes of the Office procedure:
- texture pass (this script, numpy + PIL): each leaf's 512 px colour / normal / roughness, painted from its own outline
  with veins, a lighter midrib, a base-to-tip colour gradient, browned crisp edges and a few spots; the scan supplies
  the natural part: its low-frequency mottling (heavily blurred) and its fine grain (high-passed luminance, low gain),
  hue-shifted into each leaf's colour, so no two leaves read as flat fills.
- model pass (leaf_singles_blend.py, Blender): the outline as a thin curled mesh folded along the midrib, with a
  stalk, UV-mapped 1:1 onto these maps.

  py -3.9 -I leaf_singles.py <out_dir>        (TEXPIPE_WORK must hold cc0/ScatteredLeaves008)

Outlines are in leaf space: x across (-0.5..0.5), y from the stalk (0) to the tip (1).
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

WORK = os.environ.get("TEXPIPE_WORK", "F:/Dev/temp/claude/texwork")
SCAN = os.path.join(WORK, "cc0", "ScatteredLeaves008", "ScatteredLeaves008_2K-JPG_Color.jpg")
PX = 512


# A sugar maple's right half, from the stalk notch round to the tip: basal lobe, side lobe, top lobe, each with a tooth
# or two, rounded gaps (sinuses) between them. Mirrored for the left half.
MAPLE_RIGHT = [
    (0.0, 0.10), (0.10, 0.07), (0.22, 0.08), (0.34, 0.10), (0.45, 0.16), (0.37, 0.21), (0.39, 0.26), (0.28, 0.28),
    (0.21, 0.31), (0.20, 0.35), (0.27, 0.39), (0.37, 0.42), (0.42, 0.40), (0.47, 0.50), (0.57, 0.60), (0.47, 0.62),
    (0.45, 0.68), (0.35, 0.66), (0.23, 0.62), (0.17, 0.61), (0.17, 0.69), (0.24, 0.78), (0.16, 0.80), (0.12, 0.90),
    (0.0, 1.0),
]


def maple(squeeze=1.0, lift=0.0):
    """The maple outline; `squeeze` narrows the lobes, `lift` raises the side lobes (a second, redder leaf)."""
    right = [(0.82 * x * squeeze * (1 + 0.08 * math.sin(i * 1.7)), y + lift * max(0.0, 0.7 - abs(y - 0.6)) * (x > 0.3))
             for i, (x, y) in enumerate(MAPLE_RIGHT)]
    return right + [(-x, y) for x, y in reversed(right[1:-1])]


def oak(lobes=4):
    """An oak: rounded lobes down each side, a rounded tip."""
    pts = []
    side = []
    for i in range(60):
        t = i / 59
        w = 0.20 + 0.11 * (0.5 + 0.5 * math.cos(t * lobes * 2 * math.pi + 0.6)) * (1 - 0.6 * t)
        w *= math.sin(math.pi * min(1, t * 1.15 + 0.03)) ** 0.5
        side.append((w, 0.04 + min(1.0, t * 1.15 + 0.03) * 0.93))
    pts += [(x, y) for x, y in side]
    pts += [(-x, y) for x, y in reversed(side)]
    return pts


def beech():
    """A beech: a pointed oval with fine teeth (the scan's own species)."""
    pts = []
    side = []
    for i in range(70):
        t = i / 69
        w = 0.34 * math.sin(math.pi * min(1.0, t * 0.92 + 0.06)) ** 0.75 * (1 - 0.3 * t)
        w += 0.006 * ((i % 4) == 0) * (0.2 < t < 0.95)
        side.append((w, 0.03 + t * 0.97))
    pts += side
    pts += [(-x, y) for x, y in reversed(side)]
    return pts


LEAVES = {
    # name: (outline, base colour, tip colour, edge colour, spot colour, veins)
    "maple_orange": (maple(), (0.93, 0.50, 0.10), (0.97, 0.70, 0.18), (0.55, 0.22, 0.06), (0.45, 0.16, 0.05), "palm"),
    "maple_red": (maple(squeeze=0.92, lift=0.05), (0.80, 0.16, 0.08), (0.93, 0.36, 0.10), (0.42, 0.08, 0.05),
                  (0.35, 0.06, 0.04), "palm"),
    "oak_brown": (oak(), (0.62, 0.38, 0.14), (0.78, 0.54, 0.22), (0.38, 0.20, 0.07), (0.30, 0.15, 0.06), "pinnate"),
    "beech_gold": (beech(), (0.86, 0.66, 0.12), (0.72, 0.70, 0.20), (0.55, 0.36, 0.08), (0.45, 0.28, 0.07), "pinnate"),
}


def to_px(x, y):
    return ((x + 0.5) * PX, (1 - y) * PX)


def scan_layers(seed):
    im = np.asarray(Image.open(SCAN).convert("RGB"), np.float32) / 255
    rng = np.random.default_rng(seed)
    x0, y0 = rng.integers(0, im.shape[1] - 1024), rng.integers(0, im.shape[0] - 1024)
    crop = Image.fromarray((im[y0:y0 + 1024, x0:x0 + 1024] * 255).astype(np.uint8)).resize((PX, PX), Image.LANCZOS)
    lum = np.asarray(crop.convert("L"), np.float32) / 255
    low = np.asarray(crop.convert("L").filter(ImageFilter.GaussianBlur(28)), np.float32) / 255
    high = lum - np.asarray(crop.convert("L").filter(ImageFilter.GaussianBlur(3)), np.float32) / 255
    return low - low.mean(), high


def draw_mask(points, scale=4):
    big = Image.new("L", (PX * scale, PX * scale), 0)
    ImageDraw.Draw(big).polygon([(u * scale, v * scale) for u, v in (to_px(x, y) for x, y in points)], fill=255)
    return np.asarray(big.resize((PX, PX), Image.LANCZOS), np.float32) / 255


def veins(kind, scale=4):
    big = Image.new("L", (PX * scale, PX * scale), 0)
    d = ImageDraw.Draw(big)

    def line(a, b, w):
        d.line([tuple(c * scale for c in to_px(*a)), tuple(c * scale for c in to_px(*b))], fill=255, width=int(w * scale))

    base = (0.0, 0.05)
    if kind == "palm":
        for tip in ((0.0, 0.93), (0.50, 0.58), (-0.50, 0.58), (0.40, 0.17), (-0.40, 0.17)):
            r = math.atan2(tip[0] - base[0], tip[1] - base[1])
            line(base, tip, 5 if tip[0] == 0 else 4)
            for k in (0.35, 0.6):
                p = (base[0] + (tip[0] - base[0]) * k, base[1] + (tip[1] - base[1]) * k)
                for s in (-1, 1):
                    rr = r + s * math.radians(38)
                    line(p, (p[0] + math.sin(rr) * 0.12, p[1] + math.cos(rr) * 0.12), 2)
    else:
        line(base, (0.0, 0.97), 5)
        for k in np.linspace(0.14, 0.86, 8):
            for s in (-1, 1):
                line((0.0, k), (s * 0.30, k + 0.13), 2.5)
    return np.asarray(big.resize((PX, PX), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255


def make(name, out, seed):
    points, base, tip, edge, spot, kind = LEAVES[name]
    mask = draw_mask(points)
    yy, xx = np.mgrid[0:PX, 0:PX] / PX
    along = 1 - yy  # 0 at the stalk, 1 at the tip
    col = np.array(base)[None, None] * (1 - along[..., None]) + np.array(tip)[None, None] * along[..., None]
    low, high = scan_layers(seed)
    col = col * (1 + 0.55 * low[..., None]) + 0.22 * high[..., None]
    # browned, crisp rim: distance to the outline from the mask's blur
    rim = np.clip((1 - np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(9)), np.float32) / 255) * 2.2 - 0.25, 0, 1) * mask
    col = col * (1 - rim[..., None] * 0.75) + np.array(edge)[None, None] * rim[..., None] * 0.75
    # a few spots
    rng = np.random.default_rng(seed + 7)
    for _ in range(rng.integers(3, 7)):
        cx, cy, r = rng.uniform(0.25, 0.75), rng.uniform(0.3, 0.8), rng.uniform(0.012, 0.03)
        d2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / r ** 2
        s = np.clip(1.2 - d2, 0, 1) * 0.7
        col = col * (1 - s[..., None]) + np.array(spot)[None, None] * s[..., None]
    v = veins(kind) * mask
    # veins: a darker groove beside a lighter rib, so they read at a glance
    groove = np.clip(np.asarray(Image.fromarray((v * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5)),
                                np.float32) / 255 - v, 0, 1)
    rib = np.clip(np.array(tip) * 1.25, 0, 1)[None, None]
    col = col * (1 - 0.45 * groove[..., None])
    col = col * (1 - 0.6 * v[..., None]) + rib * 0.6 * v[..., None]
    col = np.clip(col, 0, 1)
    rgba = np.dstack([col, mask])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(out, f"{name}_color.png"))
    # normal: veins raised a touch, the scan grain as bumps
    h = 0.6 * v + 0.25 * (high - high.min()) / (np.ptp(high) + 1e-6)
    gy, gx = np.gradient(h)
    k = 6.0
    n = np.dstack([-gx * k, gy * k, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(out, f"{name}_normal.png"))
    rough = np.clip(0.72 + 0.12 * rim - 0.08 * v + 0.05 * low, 0, 1)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(os.path.join(out, f"{name}_rough.png"))
    return {"name": name, "outline": points}


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    meta = [make(name, out, i * 31 + 5) for i, name in enumerate(LEAVES)]
    json.dump(meta, open(os.path.join(out, "leaves.json"), "w"))
    print("wrote", [m["name"] for m in meta])
