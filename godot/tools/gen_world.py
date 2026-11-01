import sys, json, numpy as np
sys.path.insert(0, 'tools')
from artlib import *

def noise1(n, seed, scale, octaves=3):
    r = np.random.RandomState(seed)
    out = np.zeros(n)
    amp = 1.0
    for o in range(octaves):
        k = max(2, int(n / scale * (2 ** o)))
        pts = r.rand(k + 2)
        xs = np.linspace(0, k, n)
        i = np.floor(xs).astype(int)
        f = xs - i
        f = f * f * (3 - 2 * f)
        out += (pts[i] * (1 - f) + pts[i + 1] * f) * amp
        amp *= 0.5
    return out / (2 - 0.5 ** (octaves - 1))

def mix(a, b, k):
    return a * (1 - k) + b * k

# ------------------------------------------------------------ mountains
def mountains(name, W, Hh, seed, base, lit, shade, snow, snow_line, peak_h, pines=False):
    c = Canvas(W, Hh)
    xs = np.arange(W)
    n = noise1(W, seed, 50, 3)
    if pines:
        val = 0.5 + 0.5 * np.sin(xs * 0.028 + seed) * 0.7 + 0.3 * np.sin(xs * 0.07 + 2 * seed)
        ridge = np.round(Hh - 14 - peak_h * val)
    else:
        val = 1 - np.abs(np.sin(xs * 0.03 + seed) * 0.65 + np.sin(xs * 0.083 + 2 * seed) * 0.35)
        ridge = np.round(Hh - 12 - peak_h * (val * 0.85 + n * 0.3) - 22)
    slope = np.zeros(W)
    for x in range(W):
        slope[x] = ridge[min(W - 1, x + 2)] - ridge[max(0, x - 2)]
    Y = c.Y
    below = Y > ridge[None, :]
    depth = Y - ridge[None, :]
    xi = np.clip((c.X - depth * 0.45).astype(int), 0, W - 1)
    sl = slope[xi]
    toned = np.where(sl < -1.2, 2, np.where(sl > 1.2, 0, 1))
    # strata dithering
    strata = (c.B > 0.5) & (depth % 14 < 3)
    col = np.zeros((Hh, W, 3))
    litc, basec, shc = hexrgb(lit), hexrgb(base), hexrgb(shade)
    col[toned == 2] = litc
    col[toned == 1] = basec
    col[toned == 0] = shc
    col = np.where(strata[..., None], col * 0.92, col)
    # fade shade toward bottom with dither
    fade = depth / (Hh - 18)
    col = np.where(((c.B + 0.2) < fade * 0.9)[..., None], mix(col, hexrgb(shade) * 0.9, 0.5), col)
    c.paint(below, col)
    # snow caps
    if snow:
        jag = noise1(W, seed + 7, 8, 2) * 6
        cap = below & (Y < snow_line + jag[None, :] - (ridge[None, :] - 20) * 0.0) & (depth < (snow_line + jag[None, :] - ridge[None, :]))
        cap = below & (depth < (snow_line - ridge[None, :]) * 0.9 + jag[None, :]) & (ridge[None, :] < snow_line)
        sc = np.where((toned == 0)[..., None], hexrgb('#cfd3f5'), np.where((toned == 1)[..., None], hexrgb('#f0f2ff'), hexrgb('#ffffff')))
        c.paint(cap, sc)
    # outline top
    top = below & (depth < 1.2)
    c.paint(top, hexrgb(shade) * 0.8)
    if pines:
        r = np.random.RandomState(seed + 3)
        for i in range(34):
            x = r.randint(2, W - 2)
            y = ridge[x] + r.randint(2, 18)
            h = r.randint(10, 16)
            w = h * 0.38
            d = poly(c, [(x - w, y), (x, y - h), (x + w, y)])
            shade_part(c, d, (x, y - h / 2, w, h / 2), '#2f8f6a', rim=False, outline=hexrgb('#1f5f55'))
    c.save(f'art/{name}.png')

# ------------------------------------------------------------ cloud sea
def cloudsea(name, seed, ytop, tones, count, rmin, rmax):
    W, Hh = 216, 120
    c = Canvas(W, Hh)
    r = np.random.RandomState(seed)
    d = np.full((Hh, W), 1e9)
    xs = np.linspace(0, W, count, endpoint=False) + r.rand(count) * 6
    for x in xs:
        rad = r.uniform(rmin, rmax)
        y = ytop + r.uniform(-4, 8) + rad * 0.3
        for off in (-W, 0, W):
            d = smin(d, circ(c, x + off, y, rad), 5.0)
    # solid floor below
    d = np.minimum(d, (ytop + 22) - c.Y)
    d = np.where(c.Y > ytop + 22, -1.0, d)
    inside = d < 0
    lit, mid, shd, deep = [hexrgb(t) for t in tones]
    # tone by height under cloud surface: depth into cloud
    surf = np.zeros(W)
    for x in range(W):
        col_in = np.where(inside[:, x])[0]
        surf[x] = col_in.min() if len(col_in) else Hh
    depthv = c.Y - surf[None, :]
    q = depthv / 18.0 + (c.B - 0.5) * 0.35
    cols = np.where((q < 0.18)[..., None], lit, np.where((q < 0.55)[..., None], mid, np.where((q < 1.1)[..., None], shd, deep)))
    c.paint(inside, cols)
    c.save(f'art/{name}.png')

# ------------------------------------------------------------ sky clouds
def skycloud(name, w, h, seed, puffs):
    c = Canvas(w, h)
    d = np.full((h, w), 1e9)
    for (x, y, r) in puffs:
        d = smin(d, circ(c, x, y, r), 4.0)
    d = np.maximum(d, (h - 6) - c.Y * 1.0 + 0) if False else d
    flat = c.Y > h - 5
    d = np.where(flat, np.maximum(d, 0.1), d)
    inside = d < 0
    surf = np.array([np.where(inside[:, x])[0].min() if inside[:, x].any() else h for x in range(w)])
    dv = c.Y - surf[None, :]
    q = dv / 14.0 + (c.B - 0.5) * 0.4
    cols = np.where((q < 0.45)[..., None], hexrgb('#ffffff'), np.where((q < 0.8)[..., None], hexrgb('#e6ecff'), hexrgb('#c5c9f0')))
    c.paint(inside, cols)
    c.save(f'art/{name}.png')

# ------------------------------------------------------------ sun / moon
def sun():
    c = Canvas(44, 44)
    cx = cy = 22
    d = circ(c, cx, cy, 20)
    halo = np.clip(1 - np.maximum(circ(c, cx, cy, 10), 0) / 10.0, 0, 1)
    ring = (circ(c, cx, cy, 10) > 0) & (c.B < halo * 0.55)
    c.paint(ring, hexrgb('#fff0a0'), 0.55)
    c.paint(circ(c, cx, cy, 10) < 0, hexrgb('#ffd96a'))
    c.paint(circ(c, cx, cy, 8) < 0, hexrgb('#fff2a8'))
    c.paint(circ(c, cx, cy, 5.5) < 0, hexrgb('#fffbe0'))
    c.save('art/sun.png')

def moon(i, p):
    c = Canvas(30, 30)
    cx = cy = 15
    r = 10.5
    disc = circ(c, cx, cy, r)
    u = (c.X - cx) / r
    v = (c.Y - cy) / r
    lit_x = np.sqrt(np.clip(1 - v * v, 0, 1))
    if p <= 0.5:
        xt = np.cos(2 * np.pi * p) * lit_x
        lit = u > xt
    else:
        xt = np.cos(2 * np.pi * (1 - p)) * lit_x
        lit = u < -xt
    glow = (circ(c, cx, cy, r) > 0) & (circ(c, cx, cy, r + 4) < 0) & (c.B < 0.18)
    c.paint(glow, hexrgb('#cfd0ff'), 0.4)
    c.paint(disc < 0, hexrgb('#262b64'), 0.55)
    c.paint((disc < 0) & lit, hexrgb('#f4f1ff'), 1.0)
    for (dx, dy, rr) in [(-3, -3, 2.2), (3, 2, 2.6), (-2, 5, 1.6), (4, -5, 1.4)]:
        crat = (circ(c, cx + dx, cy + dy, rr) < 0) & lit & (disc < -1)
        c.paint(crat, hexrgb('#d4d0f0'))
    c.paint((disc >= 0) & (disc < 1.0), hexrgb('#9c9ad8'), 0.0)
    c.save(f'art/moon_{i}.png')

# ------------------------------------------------------------ islands
SEASONS = {
    'spring': dict(grass='#86e08c', grass2='#a8f0a0', lip='#4fb070', flowers=['#ff9ad9', '#ffffff', '#ffd1ec'], tree='#ffb7d5', tree2='#ff8fbf', leaf='#6ad89a'),
    'summer': dict(grass='#5fcf8a', grass2='#82e8a0', lip='#349e68', flowers=['#ffe46a', '#ffffff', '#ff9ad9'], tree='#3fae6e', tree2='#2c8a58', leaf='#4fc47e'),
    'autumn': dict(grass='#d9a441', grass2='#ecc46a', lip='#a8742a', flowers=['#ff6a3c', '#ffb43a', '#c0391e'], tree='#ff8a3c', tree2='#d9561e', leaf='#e8903a'),
    'winter': dict(grass='#e6eefc', grass2='#ffffff', lip='#a9bce0', flowers=['#cfe4ff', '#ffffff', '#9fd0ff'], tree='#dfe9ff', tree2='#a9bce0', leaf='#cfe0ff'),
}

def rock_shade(c, d, nell, base_lit='#a99bd8', seed=0):
    base = '#8e80c6'
    shade_part(c, d, nell, base, outline=hexrgb('#2f2558'), bias=0.04)

def island_main(season):
    P = SEASONS[season]
    W, Hh = 204, 140
    c = Canvas(W, Hh)
    cx, gy = 102, 30
    r = np.random.RandomState(11)
    # body cone
    prof = np.zeros(W)
    yy = c.Y
    t = np.clip((yy - gy) / 72.0, 0, 1)
    halfw = 96 * (1 - t ** 1.25)
    wob = noise1(Hh, 5, 18, 3)[:, None] * 6 - 3
    body = np.abs(c.X - cx) - (halfw + wob)
    body = np.where(yy < gy, 1e3, body)
    body = np.maximum(body, yy - (gy + 76))
    # rock tones with strata
    shade_part(c, body, (cx, gy + 34, 96, 56), '#8e80c6', outline=hexrgb('#2f2558'), bias=0.0)
    inside = body < 0
    strata = inside & (((yy + wob[:, 0][:, None] * 0) % 11) < 1.2) & (c.B > 0.35)
    c.paint(strata & (c.X > cx - 70), np.clip(c.rgba[..., :3] * 0.82, 0, 1))
    cracks = inside & (np.abs(np.sin(c.X * 0.35 + c.Y * 0.22)) < 0.05) & (yy > gy + 10) & (c.B > 0.4)
    c.paint(cracks, np.clip(c.rgba[..., :3] * 0.7, 0, 1))
    # dripping moss on the lip
    moss = inside & (yy < gy + 8 + noise1(W, 3, 9, 2)[None, :].repeat(Hh, 0) * 10)
    c.paint(moss, hexrgb(P['lip']))
    # grass top
    top = ell(c, cx, gy, 98, 10.5)
    lipd = ell(c, cx, gy + 4, 98, 10.5)
    shade_part(c, lipd, (cx, gy + 4, 98, 10.5), P['lip'], outline=hexrgb('#2f2558'), flat=2, dither=False, rim=False)
    gm = top < 0
    k = np.clip((c.Y - (gy - 10.5)) / 21.0, 0, 1)
    gcol = np.where((c.B + k * 0.6 < 0.55)[..., None], hexrgb(P['grass2']), hexrgb(P['grass']))
    c.paint(gm, gcol)
    # grass highlights
    for _ in range(46):
        x = r.randint(8, W - 8); y = gy + r.randint(-6, 7)
        if top[y, x] < -2:
            spec(c, x, y, 3, 1, tuple(hexrgb(P['grass2']) * 0.95 + 0.05))
    # blades above back edge
    for x in range(10, W - 10, 5):
        edge = gy - 10.5 * np.sqrt(max(0, 1 - ((x - cx) / 98.0) ** 2))
        h = r.randint(3, 7)
        for k2 in range(h):
            col = hexrgb(P['grass2']) if k2 > 1 else hexrgb(P['grass'])
            c.rgba[int(edge) - k2, x, :3] = col; c.rgba[int(edge) - k2, x, 3] = 1
            if k2 < h - 2:
                c.rgba[int(edge) - k2, x + 1, :3] = col; c.rgba[int(edge) - k2, x + 1, 3] = 1
    # flowers
    for _ in range(18):
        x = r.randint(14, W - 14); y = gy + r.randint(-5, 6)
        fc = hexrgb(P['flowers'][r.randint(0, 3)])
        c.paint(circ(c, x, y, 2.0) < 0, fc)
        spec(c, x, y, 1, 1, (1, 0.9, 0.4))
        spec(c, x, y + 2, 1, 2, tuple(hexrgb('#3a9a5a')))
    # rocks and mushrooms
    for (x, y, rr) in [(40, gy + 4, 4.5), (150, gy + 2, 5.5), (170, gy + 5, 3.0)]:
        d = ell(c, x, y, rr * 1.2, rr * 0.8)
        shade_part(c, d, (x, y, rr * 1.2, rr * 0.8), '#b3a7e0', rim=False)
    if season == 'autumn':
        for (x, y) in [(60, gy + 3), (128, gy + 5)]:
            c.paint(ell(c, x, y - 1, 4, 2.6) < 0, hexrgb('#ff6a5a'))
            spec(c, x - 1, y - 2, 2, 1); spec(c, x - 1, y + 1, 2, 3, (0.95, 0.9, 0.85))
    if season == 'winter':
        snowtop = (top < 0)
        c.paint(snowtop & (c.B < 0.3 + k * 0.2) & (k > 0.55), hexrgb('#cfdcf5'))
        for x in range(30, W - 30, 14):
            hh = 4 + (x * 7) % 9
            d = poly(c, [(x - 2, gy + 12), (x + 2, gy + 12), (x, gy + 12 + hh)])
            c.paint((d < 0) & inside, hexrgb('#eaf3ff'))
    # underside crystals
    for (x, y, hh) in [(70, gy + 62, 12), (102, gy + 76, 16), (136, gy + 60, 11)]:
        d = poly(c, [(x - 3.5, y), (x + 3.5, y), (x, y + hh)])
        shade_part(c, d, (x, y + hh / 2, 5, hh / 2), '#7affd9', rim=False, outline=hexrgb('#1f6a7a'))
    # hanging vines
    for x0, L in [(46, 40), (80, 58), (118, 66), (150, 42), (178, 24)]:
        for yv in range(gy + 8, gy + 8 + L):
            xv = x0 + int(np.sin(yv * 0.18 + x0) * 2.2)
            c.rgba[yv, xv, :3] = hexrgb('#3a9a5a'); c.rgba[yv, xv, 3] = 1
            if yv % 7 == 0:
                c.rgba[yv, xv + 1, :3] = hexrgb('#6ad89a'); c.rgba[yv, xv + 1, 3] = 1
    c.save(f'art/island_{season}.png')
    return c

def island_small(season, which):
    P = SEASONS[season]
    W, Hh = 52, 66
    c = Canvas(W, Hh)
    cx, gy = 26, 18
    t = np.clip((c.Y - gy) / 30.0, 0, 1)
    halfw = 23 * (1 - t ** 1.2)
    wob = noise1(Hh, 2 + which, 9, 2)[:, None] * 3 - 1.5
    body = np.abs(c.X - cx) - (halfw + wob)
    body = np.where(c.Y < gy, 1e3, body)
    body = np.maximum(body, c.Y - (gy + 32))
    shade_part(c, body, (cx, gy + 14, 23, 26), '#8e80c6', outline=hexrgb('#2f2558'))
    top = ell(c, cx, gy, 24, 5)
    lipd = ell(c, cx, gy + 2, 24, 5)
    shade_part(c, lipd, (cx, gy + 2, 24, 5), P['lip'], outline=hexrgb('#2f2558'), flat=2, dither=False, rim=False)
    c.paint(top < 0, np.where((c.B + (c.Y - gy) * 0.05 < 0.6)[..., None], hexrgb(P['grass2']), hexrgb(P['grass'])))
    # tree
    if which == 0:
        c.paint(box(c, cx - 4, gy - 5, 1.6, 7) < 0, hexrgb('#7a4a2a'))
        d = smin(circ(c, cx - 4, gy - 14, 6.5), circ(c, cx - 9, gy - 10, 5), 3)
        d = smin(d, circ(c, cx + 1, gy - 10, 5.5), 3)
        shade_part(c, d, (cx - 4, gy - 12, 9, 8), P['tree'], rim=False)
    else:
        for i, (w, y0) in enumerate([(9, gy - 2), (7, gy - 9), (5, gy - 15)]):
            d = poly(c, [(cx + 6 - w, y0), (cx + 6 + w, y0), (cx + 6, y0 - 11)])
            shade_part(c, d, (cx + 6, y0 - 4, w, 8), P['tree2'] if season != 'winter' else '#cfdcf5', rim=False)
        c.paint(box(c, cx + 6, gy, 1.2, 2) < 0, hexrgb('#7a4a2a'))
        d = ell(c, cx - 10, gy + 1, 5, 3.2)
        shade_part(c, d, (cx - 10, gy + 1, 5, 3.2), '#b3a7e0', rim=False)
    c.save(f'art/island_small{which}_{season}.png')

if __name__ == '__main__':
    mountains('mount_far', 240, 110, 3, '#a79ae0', '#c9bff7', '#8479c4', True, 58, 70)
    mountains('mount_near', 240, 84, 8, '#7fb9c4', '#9fd6d4', '#5f97aa', False, 0, 24, pines=True)
    cloudsea('sea_back', 1, 34, ['#fbfcff', '#dfe6ff', '#b9b8ec', '#a29fdc'], 11, 12, 20)
    cloudsea('sea_front', 5, 48, ['#ffffff', '#eef1ff', '#c9c6f2', '#aeaae2'], 9, 14, 24)
    skycloud('cloud0', 72, 30, 1, [(14, 20, 9), (28, 14, 12), (44, 15, 11), (58, 21, 8), (36, 22, 12)])
    skycloud('cloud1', 56, 24, 2, [(12, 15, 7), (24, 10, 9), (38, 14, 8), (46, 18, 6), (28, 17, 9)])
    skycloud('cloud2', 88, 34, 3, [(14, 24, 10), (30, 16, 13), (48, 12, 14), (66, 18, 12), (76, 25, 8), (46, 25, 13)])
    sun()
    for i in range(8):
        moon(i, i / 8.0)
    for s in SEASONS:
        island_main(s)
        island_small(s, 0)
        island_small(s, 1)
    # contact
    from PIL import Image
    bg = Image.new('RGBA', (900, 640), (120, 160, 255, 255))
    def put(n, x, y):
        im = Image.open(f'art/{n}.png'); bg.alpha_composite(im, (x, y)); return im
    put('mount_far', 0, 60); put('mount_near', 0, 120); put('sea_back', 0, 150); put('sea_front', 230, 150)
    put('cloud0', 460, 10); put('cloud1', 540, 10); put('cloud2', 610, 10); put('sun', 720, 10)
    for i in range(8): put(f'moon_{i}', 20 + i * 34, 20)
    x = 0
    for s in SEASONS:
        put(f'island_{s}', (x % 2) * 210, 270 + (x // 2) * 150)
        put(f'island_small0_{s}', 430 + x * 55, 270); put(f'island_small1_{s}', 430 + x * 55, 340)
        x += 1
    bg = bg.resize((bg.width * 2, bg.height * 2), Image.NEAREST)
    bg.save('/tmp/is/world_sheet.png')
