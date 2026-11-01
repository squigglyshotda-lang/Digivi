import json, sys, numpy as np
sys.path.insert(0, 'tools')
from artlib import *

META = {}
GY = 100  # ground row in every sprite

def finish(c, name, cx, eye_y, eye_dx, mouth_y, cheek_dy=None, cheek_dx=None, extra=None):
    c.save(f'art/{name}.png')
    ys = np.where(c.rgba[..., 3].max(axis=1) > 0)[0]
    xs = np.where(c.rgba[..., 3].max(axis=0) > 0)[0]
    META[name] = {"w": c.w, "h": c.h, "ax": cx, "ay": GY, "top": int(ys.min()), "left": int(xs.min()), "right": int(xs.max()),
                  "eye_y": eye_y, "eye_dx": eye_dx, "mouth_y": mouth_y}
    if extra: META[name].update(extra)

def add_blush(c, body_mask, x, y, rx=4.0, ry=2.4):
    pink = np.array([1.0, 0.55, 0.66])
    for sx in (-1, 1):
        d = ell(c, x * sx + c.w / 2.0, y, rx, ry)
        m = (d < 0) & body_mask & (c.B < 0.75)
        core = (d < -1.0) & body_mask
        c.paint(m & ~core, np.clip(c.rgba[..., :3] * 0.45 + pink * 0.55, 0, 1))
        c.paint(core, np.clip(c.rgba[..., :3] * 0.3 + pink * 0.7, 0, 1))

def feet(c, cx, y, dx, base, rx=6, ry=3.4):
    for sx in (-1, 1):
        d = ell(c, cx + sx * dx, y, rx, ry)
        shade_part(c, d, (cx + sx * dx, y, rx, ry), base, rim=False)

def baby():
    c = Canvas(80, 110); cx = 40
    base = '#8be8c9'
    feet(c, cx, GY - 2, 8, base)
    shade_part(c, ell(c, cx + 2, 56, 3.2, 6.0), (cx + 2, 56, 3.2, 6.0), '#58c48a')
    shade_part(c, rot_ell(c, cx - 3, 58, 3.2, 5.5, -0.6), (cx - 3, 58, 3.2, 5.5), '#6ad89a')
    for sx in (-1, 1):
        shade_part(c, ell(c, cx + sx * 19, 82, 4.5, 3.4), (cx + sx * 19, 82, 4.5, 3.4), base, rim=False)
    body = ell(c, cx, 80, 19, 17)
    m = shade_part(c, body, (cx, 80, 19, 17), base)
    belly = ell(c, cx, 88, 11, 8)
    shade_part(c, belly, (cx, 88, 11, 8), '#d6fbee', outline=hexrgb('#8be8c9') * 0.85, bias=0.05, rim=False)
    add_blush(c, m, 12.5, 83)
    spec(c, cx - 11, 69, 3, 1); spec(c, cx - 12, 70, 1, 2)
    finish(c, 'baby', cx, 76, 7, 85)

def child():
    c = Canvas(96, 110); cx = 48
    base = '#8be8c9'
    feet(c, cx, GY - 2, 9, base, 7, 3.8)
    for sx in (-1, 1):
        shade_part(c, rot_ell(c, cx + sx * 14, 55, 6.0, 8.0, sx * 0.4), (cx + sx * 14, 55, 6, 8), base)
        shade_part(c, rot_ell(c, cx + sx * 14, 56, 2.6, 4.6, sx * 0.4), (cx + sx * 14, 56, 3, 5), '#ffb0c4', outline=hexrgb('#e07a96'), rim=False)
    for sx in (-1, 1):
        shade_part(c, rot_ell(c, cx + sx * 23, 82, 5.5, 4.2, sx * 0.5), (cx + sx * 23, 82, 5.5, 4.2), base, rim=False)
    body = ell(c, cx, 77, 23, 21)
    m = shade_part(c, body, (cx, 77, 23, 21), base)
    belly = ell(c, cx, 86, 13, 10)
    shade_part(c, belly, (cx, 86, 13, 10), '#d6fbee', outline=hexrgb('#8be8c9') * 0.85, bias=0.05, rim=False)
    add_blush(c, m, 15, 82)
    spec(c, cx - 14, 62, 3, 1); spec(c, cx - 15, 63, 1, 3)
    finish(c, 'child', cx, 72, 8, 82)

def explorer():
    c = Canvas(96, 110); cx = 48
    base = '#7fc8ff'
    shade_part(c, rot_ell(c, cx + 20, 88, 10, 4, -0.5), (cx + 20, 88, 10, 4), '#5fa6ee', rim=False)
    feet(c, cx, GY - 4, 8, base, 6, 3.4)
    body = ell(c, cx, 76, 21, 21)
    m = shade_part(c, body, (cx, 76, 21, 21), base)
    belly = ell(c, cx, 86, 13, 10)
    shade_part(c, belly, (cx, 86, 13, 10), '#e8f6ff', outline=hexrgb('#7fc8ff') * 0.8, bias=0.05, rim=False)
    add_blush(c, m, 14, 81, 3.6, 2.2)
    band = (np.abs(c.Y - 62) < 2.4) & (body < -1)
    c.paint(band, hexrgb('#8a5a3a'))
    c.paint(band & (c.Y < 61.2), hexrgb('#b07a4a'))
    for sx in (-1, 1):
        lens = circ(c, cx + sx * 8, 62, 5.2)
        c.paint((lens < 1.2) & (lens >= 0.0), hexrgb('#3b2a1a'))
        c.paint(lens < 0, hexrgb('#9fe8ff'))
        c.paint((lens < 0) & (c.Y > 63.5), hexrgb('#5fc4e6'))
        spec(c, cx + sx * 8 - 3, 59.5, 2, 1)
        spec(c, cx + sx * 8 - 3, 60.5, 1, 1)
    spec(c, cx - 13, 66, 3, 1); spec(c, cx - 14, 67, 1, 3)
    finish(c, 'explorer', cx, 76, 7.5, 86)

def explorer_wing():
    c = Canvas(64, 56)
    rx0, ry0 = 4, 40
    base = '#a8dcff'
    feathers = [(-1.15, 40, 6.0), (-0.88, 42, 6.0), (-0.6, 40, 5.8), (-0.32, 36, 5.6), (-0.06, 30, 5.2)]
    for ang, L, w in feathers:
        cxx = rx0 + np.cos(ang) * L / 2
        cyy = ry0 + np.sin(ang) * L / 2
        d = rot_ell(c, cxx, cyy, L / 2, w, ang)
        shade_part(c, d, (cxx, cyy, L / 2, w), base, rim=False)
        tip = (d < 0) & (np.hypot(c.X - rx0, c.Y - ry0) > L * 0.72)
        c.paint(tip, hexrgb('#ffffff'))
    d = ell(c, rx0 + 2, ry0 + 1, 7, 7)
    shade_part(c, d, (rx0 + 2, ry0 + 1, 7, 7), '#7fc8ff', rim=False)
    c.save('art/explorer_wing.png')
    META['explorer_wing'] = {"w": 64, "h": 56, "px": rx0 + 2, "py": ry0 + 1}

def cuddly():
    c = Canvas(120, 112); cx = 60
    base = '#ffb3a1'
    for sx in (-1, 1):
        shade_part(c, ell(c, cx + sx * 21, 41, 11, 11), (cx + sx * 21, 41, 11, 11), base)
        shade_part(c, ell(c, cx + sx * 21, 42, 6, 6), (cx + sx * 21, 42, 6, 6), '#ff8fa6', outline=hexrgb('#d9607e'), rim=False)
    feet(c, cx, GY - 3, 16, base, 11, 5)
    for sx in (-1, 1):
        shade_part(c, rot_ell(c, cx + sx * 33, 82, 8, 12, sx * 0.35), (cx + sx * 33, 82, 8, 12), base, rim=False)
    th = np.arctan2(c.Y - 72, c.X - cx)
    body = ell(c, cx, 72, 35, 31) + np.sin(th * 20) * 0.6 + np.sin(th * 9 + 1) * 0.4
    m = shade_part(c, body, (cx, 72, 35, 31), base)
    belly = ell(c, cx, 84, 19, 16)
    shade_part(c, belly, (cx, 84, 19, 16), '#fff0e6', outline=hexrgb('#ffb3a1') * 0.85, bias=0.08, rim=False)
    add_blush(c, m, 25, 80, 6, 3.2)
    spec(c, cx - 23, 52, 4, 1); spec(c, cx - 24, 53, 1, 4)
    finish(c, 'cuddly', cx, 70, 12, 82)

def cheeky():
    c = Canvas(112, 112); cx = 56
    base = '#e9f06a'
    tail = poly(c, [(cx + 22, 84), (cx + 42, 70), (cx + 36, 90)])
    shade_part(c, tail, (cx + 34, 82, 10, 10), '#ffb43a', rim=False, flat=2)
    spikes = [(-18, 56, -22, 38), (-8, 52, -10, 32), (3, 50, 4, 28), (14, 52, 18, 32), (22, 57, 28, 40)]
    for x0, y0, x1, y1 in spikes:
        d = poly(c, [(cx + x0 - 3.5, y0 + 4), (cx + x1, y1), (cx + x0 + 3.5, y0 + 4)])
        shade_part(c, d, (cx + x0, y0, 5, 12), '#ff9b3d', rim=False)
    feet(c, cx, GY - 3, 10, base, 7.5, 4)
    for sx in (-1, 1):
        shade_part(c, rot_ell(c, cx + sx * 25, 84, 6, 4.5, sx * 0.4), (cx + sx * 25, 84, 6, 4.5), base, rim=False)
        d = poly(c, [(cx + sx * 20, 60), (cx + sx * 30, 44), (cx + sx * 12, 55)])
        shade_part(c, d, (cx + sx * 22, 54, 8, 8), base, rim=False)
    body = ell(c, cx, 78, 25, 22)
    m = shade_part(c, body, (cx, 78, 25, 22), base)
    belly = ell(c, cx, 88, 15, 11)
    shade_part(c, belly, (cx, 88, 15, 11), '#fbffc6', outline=hexrgb('#b8c040'), bias=0.05, rim=False)
    add_blush(c, m, 16, 84, 4, 2.4)
    spec(c, cx - 15, 65, 3, 1); spec(c, cx - 16, 66, 1, 3)
    finish(c, 'cheeky', cx, 76, 9, 87)

def sleepy():
    c = Canvas(120, 112); cx = 60
    base = '#dcd7ff'
    discs = [(-18, 78, 12), (-6, 68, 16), (10, 70, 16), (22, 78, 10), (2, 80, 14)]
    body = np.full((c.h, c.w), 1e9)
    for dx, y, r in discs:
        body = smin(body, circ(c, cx + dx, y, r), 6.0)
    m = shade_part(c, body, (cx, 74, 28, 18), base)
    belly = ell(c, cx + 2, 88, 15, 6)
    shade_part(c, belly, (cx + 2, 88, 15, 6), '#f2efff', outline=hexrgb('#a99fd8'), bias=0.1, rim=False)
    capcol = '#5b4bb0'
    cap = poly(c, [(cx - 18, 58), (cx - 2, 49), (cx + 12, 54), (cx + 20, 62), (cx + 27, 76), (cx + 10, 62), (cx - 6, 60)])
    brim = ell(c, cx - 6, 59, 15, 3.4)
    shade_part(c, cap, (cx + 4, 56, 16, 12), capcol, rim=False)
    shade_part(c, brim, (cx - 6, 59, 15, 3.4), '#f4ecff', outline=hexrgb('#8a7fd0'), rim=False, bias=0.1)
    pom = circ(c, cx + 27, 78, 4.0)
    shade_part(c, pom, (cx + 27, 78, 4, 4), '#fff7d0', outline=hexrgb('#b0a060'), rim=False)
    for sx, sy in [(cx - 8, 53), (cx + 4, 55), (cx + 14, 62)]:
        spec(c, sx, sy, 2, 2, (1.0, 0.92, 0.5))
    add_blush(c, m, 14, 78, 4, 2.4)
    spec(c, cx - 21, 68, 3, 1)
    finish(c, 'sleepy', cx, 71, 8, 80)

def egg():
    c = Canvas(72, 112); cx = 36
    cy = 72
    k = np.clip((c.Y - (cy - 29)) / 58.0, 0, 1)
    wscale = 0.74 + 0.3 * k
    d = (np.sqrt(((c.X - cx) / (22 * wscale)) ** 2 + ((c.Y - cy) / 29.0) ** 2) - 1.0) * 22
    shade_part(c, d, (cx, cy, 22, 29), '#f4ecff')
    for (dx, dy, col) in [(-8, -12, '#8be8c9'), (6, -4, '#ffb0c4'), (-6, 8, '#9fd4ff'), (10, 14, '#ffe08a')]:
        dd = circ(c, cx + dx, cy + dy, 3.4)
        c.paint((dd < 0) & (d < -2), hexrgb(col))
    spec(c, cx - 13, cy - 20, 3, 1); spec(c, cx - 14, cy - 19, 1, 4)
    finish(c, 'egg', cx, cy, 0, cy)

if __name__ == '__main__':
    for f in (baby, child, explorer, explorer_wing, cuddly, cheeky, sleepy, egg):
        f()
    json.dump(META, open('art/pets.json', 'w'), indent=1)
    from PIL import Image
    names = ['egg', 'baby', 'child', 'explorer', 'cuddly', 'cheeky', 'sleepy', 'explorer_wing']
    ims = [Image.open(f'art/{n}.png') for n in names]
    W = sum(i.width for i in ims) + 10 * len(ims)
    H = max(i.height for i in ims)
    sheet = Image.new('RGBA', (W, H), (150, 190, 255, 255))
    x = 0
    for i in ims:
        sheet.alpha_composite(i, (x, 0)); x += i.width + 10
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save('/tmp/is/pets_sheet.png')
