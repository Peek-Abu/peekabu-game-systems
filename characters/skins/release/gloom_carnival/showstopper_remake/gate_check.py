# Reads the gate renders: red pixels = the inside of a garment showing; magenta shut inside the figure = see-through hole.
# Writes <dir>/gate/gate.json and a marked contact sheet <dir>/gate/gate_sheet.jpg (problems in yellow).
#   python gate_check.py <out_dir> [pose]
import sys, json, glob, os
import numpy as np
from PIL import Image, ImageDraw
D = sys.argv[1]; pre = 'pose_' if 'pose' in sys.argv[2:] else ''
res, tiles, bad = {}, [], 0
for f in sorted(glob.glob(f'{D}/gate/{pre}e*_a*.png')):
    if not pre and os.path.basename(f).startswith('pose_'): continue
    im = np.asarray(Image.open(f).convert('RGB')).astype(int)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    green = (r > 200) & (g < 50) & (b < 50)   # red = inside of a garment showing
    mag = (r > 200) & (b > 200) & (g < 60)
    m = Image.fromarray(np.pad(mag, 1, constant_values=True).astype(np.uint8) * 255).copy()  # fromarray shares a read-only buffer: floodfill would do nothing
    ImageDraw.floodfill(m, (0, 0), 128)
    hole = (np.asarray(m)[1:-1, 1:-1] == 255)
    ng, nh = int(green.sum()), int(hole.sum())
    res[os.path.basename(f)] = {'inside_px': ng, 'hole_px': nh}
    bad += int(ng > 0 or nh > 0)
    vis = im.copy(); vis[green | hole] = (255, 230, 0)
    t = Image.fromarray(vis.astype(np.uint8)); t.thumbnail((350, 450))
    ImageDraw.Draw(t).text((6, 6), f'{os.path.basename(f)[:-4]}  inside {ng}  holes {nh}', fill=(255, 255, 255))
    tiles.append(t)
W = 8; sheet = Image.new('RGB', (W * 350, ((len(tiles) + W - 1) // W) * 450), (20, 20, 20))
for n, t in enumerate(tiles): sheet.paste(t, ((n % W) * 350, (n // W) * 450))
sheet.save(f'{D}/gate/{pre}gate_sheet.jpg', quality=85)
blend = json.load(open(f'{D}/gate/{pre}gate_blend.json'))
out = {'views': res, 'views_failing': bad, 'open_edges': blend['open_edges']}
json.dump(out, open(f'{D}/gate/{pre}gate.json', 'w'), indent=1)
print('VIEWS FAILING', bad, 'of', len(res))
for k, v in res.items():
    if v['inside_px'] or v['hole_px']: print(' ', k, v)
print('OPEN EDGES', {k: v for k, v in blend['open_edges'].items() if v})
