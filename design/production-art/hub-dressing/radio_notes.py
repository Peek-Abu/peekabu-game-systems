from PIL import Image, ImageDraw, ImageFilter
S = 512  # 2x2 flipbook, each cell 256
GOLD = (255, 205, 80, 255); MINT = (110, 230, 190, 255); INK = (40, 26, 60, 255); WHITE = (255, 255, 255, 220)
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
def note(d, ox, oy, kind, col):
    def head(cx, cy):
        # tilted oval head with ink outline and a shine
        for r, c in ((0, INK),):
            pass
        box = [cx - 38, cy - 26, cx + 38, cy + 26]
        hd = Image.new("RGBA", (120, 90), (0, 0, 0, 0)); hdd = ImageDraw.Draw(hd)
        hdd.ellipse([8, 8, 112, 82], fill=INK); hdd.ellipse([16, 15, 104, 75], fill=col)
        hdd.ellipse([34, 22, 58, 38], fill=WHITE)
        hd = hd.rotate(22, resample=Image.BICUBIC, expand=True)
        img.alpha_composite(hd, (int(cx - hd.width / 2), int(cy - hd.height / 2)))
    def stem(x, y0, y1):
        d.rounded_rectangle([x - 9, y0, x + 9, y1], radius=6, fill=INK); d.rounded_rectangle([x - 4, y0 + 4, x + 4, y1 - 4], radius=3, fill=col)
    if kind == 0:  # single eighth note with flag
        stem(ox + 160, oy + 40, oy + 185); head(ox + 122, oy + 190)
        d.polygon([(ox + 151, oy + 40), (ox + 215, oy + 85), (ox + 205, oy + 120), (ox + 168, oy + 88)], fill=INK)
        d.polygon([(ox + 160, oy + 52), (ox + 203, oy + 88), (ox + 198, oy + 106), (ox + 168, oy + 80)], fill=col)
    elif kind == 1:  # beamed pair
        stem(ox + 100, oy + 55, oy + 185); stem(ox + 205, oy + 35, oy + 165); head(ox + 62, oy + 190); head(ox + 167, oy + 170)
        d.polygon([(ox + 91, oy + 45), (ox + 214, oy + 22), (ox + 214, oy + 58), (ox + 91, oy + 82)], fill=INK)
        d.polygon([(ox + 100, oy + 53), (ox + 206, oy + 33), (ox + 206, oy + 50), (ox + 100, oy + 70)], fill=col)
    elif kind == 2:  # quarter note
        stem(ox + 160, oy + 35, oy + 185); head(ox + 122, oy + 190)
    else:  # sparkle star
        pts = []
        import math
        for i in range(8):
            r = 95 if i % 2 == 0 else 32
            a = i / 8 * math.tau - math.pi / 2
            pts.append((ox + 128 + math.cos(a) * r, oy + 128 + math.sin(a) * r))
        d.polygon(pts, fill=INK)
        pts2 = [(ox + 128 + (x - ox - 128) * 0.78, oy + 128 + (y - oy - 128) * 0.78) for (x, y) in pts]
        d.polygon(pts2, fill=col)
d = ImageDraw.Draw(img)
for i, (k, col) in enumerate(((0, GOLD), (1, MINT), (2, GOLD), (3, MINT))):
    note(d, (i % 2) * 256, (i // 2) * 256, k, col)
    d = ImageDraw.Draw(img)
P = "F:/Dev/temp/claude/79e819a93e99fc1d/4421d16e-0a00-4834-8a84-75c02216aa33/scratchpad/hub/"
img.save(P + "radio_notes_flipbook.png")
prev = Image.new("RGB", (S + 40, S + 40), (60, 48, 78)); prev.paste(img, (20, 20), img)
prev.save("C:/Users/Bruk Abu/AppData/Roaming/Claude/side-session-notes/local_563d59fb-00af-49e0-842b-041a39c00a94/hub-radio-notes-look-2026-11-11.png")
print("ok")
