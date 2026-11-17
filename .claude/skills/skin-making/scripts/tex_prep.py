# Texture round prep (2026-11-16), plain Python (py -3.9 -I tex_prep.py <tex_dir> <hat_png> [VIOLET=6A3A8E]):
#  1. <tex>/textures/<cls>_ratio.png: each styled detail colour map as lum/mean x 0.5 (grey 128 = no change). The bake
#     multiplies a garment's flat colour by 2 x this, so the flat concept colours stay exact on average.
#  2. <tex>/textures/ShowHat_violet.png: the hat's own texture with every plum pixel (crown, brim, diamond ground) moved
#     to the coat's violet, keeping its shading (owner 11-16: "make the hat violet"). Cream diamonds, gold band and the
#     lilac flower-side scraps stay. ShowHat_gold.png: the gold mask (no felt, low roughness there).
import sys, os, colorsys
import numpy as np
from PIL import Image

T = os.path.join(sys.argv[1], 'textures'); HAT = sys.argv[2]
V = next((a.split('=')[1] for a in sys.argv[3:] if a.startswith('VIOLET=')), '6A3A8E')
for c in ['ss_velvet', 'ss_weave', 'ss_cotton', 'ss_leather', 'ss_felt']:
    a = np.asarray(Image.open(f'{T}/{c}_color.png').convert('RGB')).astype(np.float32) / 255
    L = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    r = np.clip(L / L.mean() * 0.5, 0, 1)
    Image.fromarray((r * 255 + 0.5).astype(np.uint8)).save(f'{T}/{c}_ratio.png')
    print('ratio', c, 'std', round(float((L / L.mean()).std()), 4))

def lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def srgb(x): return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.clip(x, 0, None) ** (1 / 2.4) - 0.055)

im = np.asarray(Image.open(HAT).convert('RGB')).astype(np.float32) / 255
hsv = np.array([colorsys.rgb_to_hsv(*p) for p in im.reshape(-1, 3)]).reshape(im.shape)
h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
plum = ((h >= 290) | (h <= 15)) & (s > 0.18) & (v < 0.55) & (v > 0.03)
gold = (h >= 25) & (h <= 60) & (s > 0.35) & (v > 0.35)
Lin = lin(im); Lum = (Lin * [0.2126, 0.7152, 0.0722]).sum(-1)
ref = np.median(Lum[plum])
tgt = lin(np.array([int(V[i:i + 2], 16) / 255 for i in (0, 2, 4)]))
tl = (tgt * [0.2126, 0.7152, 0.0722]).sum()
out = Lin.copy()
out[plum] = tgt[None, :] * (Lum[plum] / ref)[:, None]         # same shading, violet hue, plum median -> the coat colour
o8 = (np.clip(srgb(out), 0, 1) * 255 + 0.5).astype(np.uint8)
Image.fromarray(o8).save(f'{T}/ShowHat_violet.png')
Image.fromarray((gold * 255).astype(np.uint8)).save(f'{T}/ShowHat_gold.png')
print('hat plum px', int(plum.sum()), 'gold px', int(gold.sum()), 'plum median lum', round(float(ref), 4), '-> violet lum', round(float(tl), 4))
