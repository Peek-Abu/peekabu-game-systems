"""The truck's lore find (owner Q5, 2026-11-13): an old company sign, painted over in cream, that still shows through.

  python -I make_lore_sign.py <out.png>

A transparent PNG laid over the box's paint (a Decal on LoreSign's Right face, 6 x 1.8 studs at 200 px/stud). The old
lettering is a slightly darker, greyer cream with low alpha, broken up by horizontal roller strokes of overpaint, so
from a few studs away it reads as a patchy panel and only up close as "MORROW & MORROW / CLEARANCE". No face, no logo
art: plain painted lettering and a ring where an old seal was.
"""

import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1]
W, H = 1200, 360
INK = (120, 108, 92)  # old paint under the cream: a muddy brown-grey, kept faint by alpha
FONT = "C:/Windows/Fonts/georgiab.ttf"
FONT_SMALL = "C:/Windows/Fonts/georgia.ttf"

random.seed(7)
mask = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(mask)
# the old seal: a ring, left
cx, cy, r = 165, 180, 120
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=16)
d.ellipse((cx - r + 30, cy - r + 30, cx + r - 30, cy + r - 30), outline=255, width=6)



def fit(text, path, width, start):
    """The biggest size (from `start` down) at which `text` is at most `width` px wide."""
    size = start
    while size > 10:
        f = ImageFont.truetype(path, size)
        if d.textbbox((0, 0), text, font=f)[2] <= width:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def centred(text, font, x, y):
    b = d.textbbox((0, 0), text, font=font)
    d.text((x - (b[0] + b[2]) / 2, y - (b[1] + b[3]) / 2), text, font=font, fill=255)


title = fit("MORROW & MORROW", FONT, W - 330 - 60, 96)
centred("MORROW & MORROW", title, (330 + W - 60) / 2, 140)
centred("C L E A R A N C E", fit("C L E A R A N C E", FONT_SMALL, 520, 50), (330 + W - 60) / 2, 245)
centred("M&M", fit("M&M", FONT, 2 * (r - 40), 60), cx, cy)

m = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255
# overpaint: horizontal roller strokes of cream that hide the old paint more in some bands than others
cover = np.zeros((H, W), np.float32)
y = 0
while y < H:
    h = random.randint(18, 46)
    strength = random.choice((0.15, 0.35, 0.5, 0.65, 0.78))
    x0 = random.randint(-200, 100)
    x1 = random.randint(W - 100, W + 200)
    cover[y : y + h, max(0, x0) : min(W, x1)] = np.maximum(cover[y : y + h, max(0, x0) : min(W, x1)], strength)
    y += h - random.randint(0, 10)
cover = np.asarray(Image.fromarray((cover * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), np.float32) / 255
# a fine brush-hair streak so the cover is never perfectly even
streak = np.asarray(
    Image.effect_noise((W, H), 40).resize((W // 8, H), Image.BILINEAR).resize((W, H), Image.BILINEAR), np.float32
) / 255
alpha = m * (1 - cover) * (0.55 + 0.25 * streak)
# fade the edges so the panel has no hard border
yy, xx = np.mgrid[0:H, 0:W]
edge = np.clip(np.minimum.reduce([xx / 60, (W - 1 - xx) / 60, yy / 30, (H - 1 - yy) / 30]), 0, 1)
alpha *= edge
rgba = np.zeros((H, W, 4), np.uint8)
rgba[..., 0], rgba[..., 1], rgba[..., 2] = INK
rgba[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
Image.fromarray(rgba).save(OUT)
print("alpha mean (lettering)", round(float(alpha[m > 0.5].mean()), 3), "max", round(float(alpha.max()), 3))
