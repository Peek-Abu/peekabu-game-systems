# Leaf cards from the styled ScatteredLeaves008 scan: a drift (a leafy oval, its edge cut along leaf outlines from the
# scan's height map) and four small scatter clusters. RGBA colour + normal + roughness per card.
import numpy as np, os
from PIL import Image, ImageFilter
W = "F:/Dev/temp/claude/texwork"
col = np.asarray(Image.open(f"{W}/textures/leaves_scan2k_color.png").convert("RGB")).astype(np.float32) / 255
nrm = np.asarray(Image.open(f"{W}/textures/leaves_scan2k_normal.png").convert("RGB")).astype(np.float32) / 255
rgh = np.asarray(Image.open(f"{W}/textures/leaves_scan2k_rough.png").convert("L")).astype(np.float32) / 255
hgt = np.asarray(Image.open(f"{W}/cc0/ScatteredLeaves008/ScatteredLeaves008_2K-JPG_Displacement.jpg").convert("L")).astype(np.float32) / 255
OUT = f"{W}/leafcards"
rng = np.random.default_rng(7)

def smooth_noise(n, scale, seed):
    r = np.random.default_rng(seed).random((n // scale + 2, n // scale + 2)).astype(np.float32)
    return np.asarray(Image.fromarray((r * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)).astype(np.float32) / 255

def card(name, x0, y0, size, out_px, shape):
    c = col[y0:y0 + size, x0:x0 + size]; nn = nrm[y0:y0 + size, x0:x0 + size]; r = rgh[y0:y0 + size, x0:x0 + size]; h = hgt[y0:y0 + size, x0:x0 + size]
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size * 2 - 1
    field = shape(xx, yy, size)
    # leaf-edge cut: top leaves (high in the height map) survive further out, so the rim follows whole leaves
    hl = (h - h.mean()) / (h.std() + 1e-6)
    keep = field + 0.09 * hl
    a = np.clip((keep - 0.0) / 0.06, 0, 1)
    a = np.where(a > 0.5, 1.0, 0.0).astype(np.float32)
    m = Image.fromarray((a * 255).astype(np.uint8))
    k = 7 if size >= 512 else 3
    m = m.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MedianFilter(k + 2))
    a = np.asarray(m).astype(np.float32) / 255
    # darker underneath toward the rim (contact shade)
    shade = np.clip(0.78 + 0.22 * np.clip(field * 3, 0, 1), 0, 1)[..., None]
    rgba = np.concatenate([np.clip(c * shade, 0, 1), a[..., None]], -1)
    def save(arr, suffix, mode):
        im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), mode).resize((out_px, out_px), Image.LANCZOS)
        im.save(os.path.join(OUT, f"{name}_{suffix}.png"))
    save(rgba, "color", "RGBA"); save(nn, "normal", "RGB"); save(r, "rough", "L"); save(h, "height", "L")
    print(name, "coverage %.2f" % a.mean())

def oval(xx, yy, size):
    n = smooth_noise(size, 40, 3) - 0.5
    return 1 - np.sqrt((xx / 0.92) ** 2 + (yy / 0.7) ** 2) + 0.12 * n

card("leaf_drift", 300, 400, 560, 1024, oval)
for i, (x0, y0) in enumerate([(1100, 200), (1400, 900), (500, 1300), (1600, 1500)]):
    def blob(xx, yy, size, i=i):
        n = smooth_noise(size, 20, 11 + i) - 0.5
        return 0.6 - np.sqrt(xx ** 2 + (yy * (1.1 + 0.15 * i)) ** 2) + 0.3 * n
    card(f"leaf_scatter{i + 1}", x0, y0, 150, 256, blob)
