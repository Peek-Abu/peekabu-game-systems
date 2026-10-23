# Draws the stairwellSign colour / normal / roughness maps with PIL (run under py -3.9 -I, called by build_set_stage2.py).
#   py -3.9 -I sign_images.py <outdir>
import os, sys
import numpy as np

def sign_images(OUT):
    """Colour / normal / roughness for the 2 x 1 sign, drawn with PIL. Top half = face (u 0..1, v 0.5..1); bottom half = edges + back."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    W = 1024; Hf = 512
    face = Image.new("RGB", (W, Hf), (30, 66, 60))
    hm = Image.new("L", (W, Hf), 0)          # height: raised features
    rm = Image.new("L", (W, Hf), 90)         # roughness (0..255)
    d = ImageDraw.Draw(face); dh = ImageDraw.Draw(hm); dr = ImageDraw.Draw(rm)
    # aluminium border
    B = 26
    d.rectangle([0, 0, W - 1, Hf - 1], fill=(176, 182, 184)); dh.rectangle([0, 0, W - 1, Hf - 1], fill=200); dr.rectangle([0, 0, W - 1, Hf - 1], fill=100)
    d.rectangle([B, B, W - 1 - B, Hf - 1 - B], fill=(26, 60, 54)); dh.rectangle([B, B, W - 1 - B, Hf - 1 - B], fill=0); dr.rectangle([B, B, W - 1 - B, Hf - 1 - B], fill=70)
    ink = (236, 232, 218)
    # stair pictogram (left): stepped silhouette + climbing figure + arrow
    sx0, sy0 = 70, 70
    steps = 5; sw = 62; sh = 56
    pts = [(sx0, sy0 + steps * sh + 40)]
    for i in range(steps):
        pts.append((sx0 + i * sw, sy0 + (steps - i) * sh + 40)); pts.append((sx0 + (i + 1) * sw, sy0 + (steps - i) * sh + 40))
    pts.append((sx0 + steps * sw, sy0 + 40 + 0)); pts.append((sx0 + steps * sw, sy0 + steps * sh + 40))
    # build as a staircase polygon from bottom-left rising to the right
    poly = [(sx0, 430 - 26)]
    for i in range(steps):
        poly += [(sx0 + i * sw, 430 - 26 - (i + 1) * sh + 0), (sx0 + (i + 1) * sw, 430 - 26 - (i + 1) * sh)]
    poly += [(sx0 + steps * sw, 430 - 26)]
    for dd, fill in ((d, ink), (dh, 120), (dr, 140)):
        dd.polygon(poly, fill=fill)
    # climbing figure on the stairs
    fx, fy = sx0 + 150, 430 - 26 - 3 * sh - 4
    for dd, fill in ((d, ink), (dh, 120), (dr, 140)):
        dd.ellipse([fx - 20, fy - 150, fx + 20, fy - 110], fill=fill)
        dd.line([(fx, fy - 105), (fx - 8, fy - 45)], fill=fill, width=26)
        dd.line([(fx - 4, fy - 90), (fx + 38, fy - 60)], fill=fill, width=14)
        dd.line([(fx - 8, fy - 45), (fx + 26, fy - 10)], fill=fill, width=18)
        dd.line([(fx - 8, fy - 45), (fx - 36, fy - 10)], fill=fill, width=18)
    # arrow pointing up-right above the stairs
    for dd, fill in ((d, (232, 168, 40)), (dh, 120), (dr, 140)):
        dd.polygon([(sx0 + 250, 70), (sx0 + 300, 70), (sx0 + 300, 120)], fill=fill)
        dd.line([(sx0 + 236, 150), (sx0 + 296, 74)], fill=fill, width=16)
    # text
    fb = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 112)
    fn = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 190)
    tx = 450
    for dd, fill in ((d, ink), (dh, 120), (dr, 150)):
        dd.text((tx, 70), "FLOORS", font=fb, fill=fill)
        dd.text((tx, 200), "2\u201314", font=fn, fill=fill)
    # underline bar in the accent colour
    d.rectangle([tx, 420, W - 80, 436], fill=(232, 168, 40)); dh.rectangle([tx, 420, W - 80, 436], fill=100); dr.rectangle([tx, 420, W - 80, 436], fill=140)
    # a few screw heads in the border
    for cx, cy in ((13, 13), (W - 14, 13), (13, Hf - 14), (W - 14, Hf - 14)):
        d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(120, 126, 128))
    # gentle paint grain on the green so it is not flat
    rng = np.random.default_rng(3)
    a = np.asarray(face).astype(np.float32)
    nz = rng.normal(0, 1, (Hf, W)).astype(np.float32)
    nz = np.asarray(Image.fromarray(((nz * 40) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) - 128
    green = (np.asarray(hm) < 5)[..., None]
    a = a + nz[..., None] * 0.12 * green
    face = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    # atlas: face on top, flat aluminium (edges + back) below
    col = Image.new("RGB", (W, 1024), (150, 156, 158)); col.paste(face, (0, 0))
    h = np.zeros((1024, W), np.float32); h[:Hf] = np.asarray(hm.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    r = np.full((1024, W), 100, np.uint8); r[:Hf] = np.asarray(rm)
    # normal from height (tangent space, OpenGL: +Y = up in the image), strength tuned for a ~0.04 stud relief
    k = 9.0
    dx = np.gradient(h, axis=1); dy = np.gradient(h, axis=0)
    nx = -dx * k; ny = dy * k; nzv = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nzv * nzv)
    nrm = np.stack([nx / ln, ny / ln, nzv / ln], -1)
    nrm8 = ((nrm * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)
    col.save(os.path.join(OUT, "stairwellSign_color.png"))
    Image.fromarray(nrm8).save(os.path.join(OUT, "stairwellSign_normal.png"))
    Image.fromarray(r).resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "stairwellSign_rough.png"))




if __name__ == "__main__":
    os.makedirs(sys.argv[1], exist_ok=True)
    sign_images(sys.argv[1])
