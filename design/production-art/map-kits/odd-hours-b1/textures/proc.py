# Procedural, seamlessly tiling source maps (colour + height + roughness) for the style filter.
#   py -3.9 -I proc.py <kind> <out_prefix> [seed]     kinds: wood, plaster, tile
# Every noise here is periodic (built in frequency space), so the result tiles with no seams.
import sys, os
import numpy as np
from PIL import Image

N = 1024


def fnoise(rng, freq, slope=2.0, aniso=(1.0, 1.0)):
    """Periodic fractal noise: random phases with a 1/f^slope spectrum around `freq` cycles per tile."""
    ky = np.fft.fftfreq(N)[:, None] * N / aniso[1]
    kx = np.fft.fftfreq(N)[None, :] * N / aniso[0]
    k = np.sqrt(kx ** 2 + ky ** 2)
    amp = 1 / (1 + (k / freq) ** slope)
    amp[0, 0] = 0
    ph = np.exp(2j * np.pi * rng.random((N, N)))
    f = np.real(np.fft.ifft2(amp * ph))
    return (f - f.mean()) / (f.std() + 1e-8)


def norm01(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-8)


def wood(rng):
    y, x = np.mgrid[0:N, 0:N] / N
    # plain-sawn oak: long, gently wandering growth lines with a few cathedral arches
    warp = fnoise(rng, 2, 2.5, (6, 1)) * 0.012 + fnoise(rng, 8, 2.0, (10, 1)) * 0.003
    arch = np.clip(fnoise(rng, 1.5, 3, (2, 1)), 0, None) * 0.02
    rings = np.sin(2 * np.pi * (y * 16 + (warp + arch) * 16 + 0.2 * np.sin(2 * np.pi * x)))
    figure = norm01(rings) ** 2.2
    fibres = fnoise(rng, 500, 1.0, (60, 1))
    streak = fnoise(rng, 40, 1.5, (30, 1))
    pores = (fnoise(rng, 400, 0.5, (8, 1)) > 2.3).astype(np.float32)
    h = figure * 0.5 + fibres * 0.06 + streak * 0.05 - pores * 0.2
    dark, light = np.array([0.45, 0.28, 0.14]), np.array([0.69, 0.50, 0.31])
    t = np.clip(figure * 0.55 + streak * 0.08 + fibres * 0.04 + fnoise(rng, 1.5, 2) * 0.06 + 0.15, 0, 1)[..., None]
    col = light * (1 - t) + dark * t - pores[..., None] * 0.06
    rough = 0.5 + fibres * 0.02 + pores * 0.2
    return col, h, rough


def plaster(rng):
    h = fnoise(rng, 40, 1.4) * 0.6 + fnoise(rng, 160, 1.2) * 0.35 + fnoise(rng, 5, 2) * 0.4
    trowel = np.clip(fnoise(rng, 8, 2.5, (1, 3)), 0, None) * 0.3   # broad trowel strokes
    h = h + trowel
    col = np.array([0.84, 0.80, 0.72])[None, None, :] + (fnoise(rng, 4, 2) * 0.012 + h * 0.006)[..., None]
    rough = 0.62 - trowel * 0.15 + fnoise(rng, 60, 1.5) * 0.03
    return col, norm01(h), rough


def tile(rng):
    y, x = np.mgrid[0:N, 0:N]
    n = 4                                     # 4 x 4 tiles per texture
    cell = N // n
    gx, gy = x % cell, y % cell
    grout = ((gx < 6) | (gy < 6)).astype(np.float32)
    idx = (y // cell) * n + (x // cell)
    tint = rng.normal(0, 0.025, n * n)[idx]   # each tile slightly different
    speck = (fnoise(rng, 500, 0.3) > 1.6) * 0.08 + (fnoise(rng, 500, 0.3) < -2.0) * -0.06
    grime = np.clip(fnoise(rng, 6, 2.0), 0, None) * 0.07
    stains = np.clip(fnoise(rng, 10, 2.5) - 1.6, 0, None) * 0.25
    base = np.array([0.80, 0.76, 0.66])
    col = base[None, None, :] + (tint + speck - grime - stains)[..., None] * np.array([1, 0.97, 0.9])
    col = col * (1 - grout[..., None] * 0.45)
    h = 1 - grout * 0.8 + fnoise(rng, 200, 1) * 0.03 - stains * 0.1
    rough = 0.45 + grime * 0.6 + stains * 0.5 + grout * 0.3
    return col, h, rough


def carpet(rng):
    """Commercial carpet tiles: calm loop pile, tiles laid in alternating (quarter-turned) pile direction, sparse flecks."""
    y, x = np.mgrid[0:N, 0:N]
    n = 4; cell = N // n
    ti, tj = y // cell, x // cell
    turned = ((ti + tj) % 2).astype(np.float32)
    pile_a = fnoise(rng, 260, 1.2, (3, 1)); pile_b = fnoise(rng, 260, 1.2, (1, 3))
    pile = pile_a * (1 - turned) + pile_b * turned
    loops = fnoise(rng, 380, 0.6) * 0.5
    fleck = (fnoise(rng, 300, 0.4) > 2.4).astype(np.float32)
    seam = ((x % cell < 2) | (y % cell < 2)).astype(np.float32)
    shade = (turned - 0.5) * 0.008 + fnoise(rng, 3, 2) * 0.006
    v = shade + pile * 0.012 + loops * 0.008 + fleck * 0.035 - seam * 0.012
    base = np.array([0.30, 0.35, 0.28])
    col = base[None, None, :] + v[..., None] * np.array([1.0, 1.05, 0.95])
    h = pile * 0.4 + loops * 0.4 - seam * 0.6
    rough = 0.92 + v * 0.1
    return col, h, rough


def ceiling(rng):
    """2 x 2 acoustic ceiling tiles with fissures and pinholes, a recessed grid."""
    y, x = np.mgrid[0:N, 0:N]
    n = 2; cell = N // n
    gx, gy = x % cell, y % cell
    grid = ((gx < 10) | (gy < 10)).astype(np.float32)
    fiss = np.clip(np.abs(fnoise(rng, 30, 1.6)) - 1.4, 0, None) * 0.6
    pin = (fnoise(rng, 450, 0.2) < -2.2).astype(np.float32)
    v = fnoise(rng, 6, 2) * 0.01 - fiss * 0.05 - pin * 0.06
    col = np.array([0.82, 0.80, 0.75])[None, None, :] + v[..., None]
    col = col * (1 - grid[..., None]) + np.array([0.62, 0.61, 0.6]) * grid[..., None]
    h = 1 - grid * 0.7 - fiss * 0.3 - pin * 0.4 + fnoise(rng, 120, 1) * 0.02
    rough = 0.88 - grid * 0.4
    return col, h, rough


def rug(rng):
    """Woven area rug: herringbone-ish weave, a darker border band and a thin accent line."""
    y, x = np.mgrid[0:N, 0:N] / N
    weave = np.sin(2 * np.pi * (x * 120 + y * 120)) * np.sin(2 * np.pi * (x * 120 - y * 120))
    tuft = fnoise(rng, 300, 1.0) * 0.4
    d = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    border = (d < 0.09).astype(np.float32); line = ((d > 0.11) & (d < 0.12)).astype(np.float32)
    field = np.array([0.55, 0.43, 0.30]); bcol = np.array([0.30, 0.20, 0.14]); lcol = np.array([0.70, 0.60, 0.44])
    col = field * (1 - border[..., None]) + bcol * border[..., None]
    col = col * (1 - line[..., None]) + lcol * line[..., None]
    col = col + (weave * 0.02 + tuft * 0.02 + fnoise(rng, 4, 2) * 0.015)[..., None]
    h = weave * 0.3 + tuft * 0.5
    rough = 0.9 + tuft * 0.02
    return col, h, rough


def vinyl(rng):
    """Server-room vinyl floor tiles: cool light grey-blue ~2-stud squares (4 x 4 per 8-stud tile), faint seams, light scuffs and wipe marks."""
    y, x = np.mgrid[0:N, 0:N]
    n = 4; cell = N // n
    gx, gy = x % cell, y % cell
    seam = ((gx < 3) | (gy < 3)).astype(np.float32)
    idx = (y // cell) * n + (x // cell)
    tint = rng.normal(0, 0.012, n * n)[idx]
    scuff = np.clip(fnoise(rng, 14, 2.0, (6, 1.5)) - 1.5, 0, None) * 0.05          # short dark drag marks
    wipe = fnoise(rng, 5, 2.4, (1, 4)) * 0.006                                     # faint mop streaks
    fine = fnoise(rng, 300, 0.6) * 0.004
    base = np.array([0.60, 0.66, 0.72])
    v = tint + wipe + fine - scuff - seam * 0.05
    col = base[None, None, :] + v[..., None] * np.array([0.95, 1.0, 1.05])
    h = 1 - seam * 0.6 + fnoise(rng, 200, 1) * 0.02 - scuff * 0.4
    rough = 0.38 + scuff * 3.0 + seam * 0.2 + wipe * 2
    return col, h, rough


def lino(rng):
    """Breakout-room sheet lino: one continuous warm sheet, fine speckle flecks, mottling, no tile seams."""
    fleck_l = (fnoise(rng, 380, 0.3) > 1.9).astype(np.float32)
    fleck_d = (fnoise(rng, 380, 0.3) < -1.9).astype(np.float32)
    mottle = fnoise(rng, 6, 2.0) * 0.003 + fnoise(rng, 40, 1.6) * 0.0015
    base = np.array([0.66, 0.54, 0.40])
    v = mottle + fleck_l * 0.035 - fleck_d * 0.03
    col = base[None, None, :] + v[..., None] * np.array([1.0, 0.95, 0.85])
    h = fnoise(rng, 150, 1.2) * 0.05 + (fleck_l + fleck_d) * 0.1
    rough = 0.5 + fleck_l * 0.1 + fnoise(rng, 8, 2) * 0.03
    return col, h, rough


if __name__ == "__main__":
    kind, out = sys.argv[1], sys.argv[2]
    rng = np.random.default_rng(int(sys.argv[3]) if len(sys.argv) > 3 else 7)
    col, h, r = {"wood": wood, "plaster": plaster, "tile": tile, "carpet": carpet, "ceiling": ceiling, "rug": rug, "vinyl": vinyl, "lino": lino}[kind](rng)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(out + "_srccolor.png")
    Image.fromarray((norm01(h) * 255).astype(np.uint8)).save(out + "_srcheight.png")
    Image.fromarray((np.clip(r, 0, 1) * 255).astype(np.uint8)).save(out + "_srcrough.png")
    print("proc", kind, out)
