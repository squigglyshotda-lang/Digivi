import numpy as np
from PIL import Image

def hexrgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], dtype=float) / 255.0

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=float) / 16.0

def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgba = np.zeros((h, w, 4), dtype=float)
        Y, X = np.mgrid[0:h, 0:w]
        self.X = X.astype(float) + 0.5
        self.Y = Y.astype(float) + 0.5
        self.B = bayer(h, w)

    def save(self, path):
        im = Image.fromarray((np.clip(self.rgba, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
        im.save(path)

    def paint(self, mask, color, alpha=1.0):
        if isinstance(color, np.ndarray) and color.ndim == 3:
            col = color
        else:
            col = np.broadcast_to(np.asarray(color, dtype=float), (self.h, self.w, 3))
        m = mask[..., None]
        self.rgba[..., :3] = np.where(m, col, self.rgba[..., :3])
        self.rgba[..., 3] = np.where(mask, alpha, self.rgba[..., 3])

# ---- sdf primitives (negative inside)
def ell(c, cx, cy, rx, ry):
    return (np.sqrt(((c.X - cx) / rx) ** 2 + ((c.Y - cy) / ry) ** 2) - 1.0) * min(rx, ry)

def rot_ell(c, cx, cy, rx, ry, ang):
    dx, dy = c.X - cx, c.Y - cy
    ca, sa = np.cos(ang), np.sin(ang)
    u = dx * ca + dy * sa
    v = -dx * sa + dy * ca
    return (np.sqrt((u / rx) ** 2 + (v / ry) ** 2) - 1.0) * min(rx, ry)

def circ(c, cx, cy, r):
    return np.sqrt((c.X - cx) ** 2 + (c.Y - cy) ** 2) - r

def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)

def poly(c, pts):
    pts = np.array(pts, dtype=float)
    n = len(pts)
    d = np.full((c.h, c.w), 1e9)
    s = np.ones((c.h, c.w))
    px_, py_ = c.X, c.Y
    j = n - 1
    for i in range(n):
        ex, ey = pts[j] - pts[i]
        wx, wy = px_ - pts[i][0], py_ - pts[i][1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, np.sqrt(bx * bx + by * by))
        c1 = py_ >= pts[i][1]
        c2 = py_ < pts[j][1]
        c3 = ex * wy > ey * wx
        flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        s = np.where(flip, -s, s)
        j = i
    return d * s

def box(c, cx, cy, hw, hh, r=0):
    qx = np.abs(c.X - cx) - hw + r
    qy = np.abs(c.Y - cy) - hh + r
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r

# ---- palettes
def ramp(base):
    b = hexrgb(base) if isinstance(base, str) else base
    cool = np.array([0.5, 0.45, 0.78])
    warm = np.array([1.0, 0.97, 0.82])
    s2 = b * cool * 0.8
    s1 = b * (cool * 0.45 + 0.55)
    l1 = np.clip(b + (warm - b) * 0.38, 0, 1)
    l2 = np.clip(b + (np.array([1, 1, 1]) - b) * 0.72, 0, 1)
    return [s2, s1, b, l1, l2]

def outline_of(base):
    b = hexrgb(base) if isinstance(base, str) else base
    return np.clip(b * 0.22 + np.array([0.09, 0.05, 0.2]) * 0.8, 0, 1)

LIGHT = np.array([-0.5, -0.66, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

def shade_part(c, d, nell, base, outline=None, flat=None, bias=0.0, dither=True, rim=True):
    """Paint a part: outline ring + 5-tone dithered lit fill. nell=(cx,cy,rx,ry) for pseudo-sphere normals."""
    rp = ramp(base)
    ol = outline if outline is not None else outline_of(base)
    ncx, ncy, nrx, nry = nell
    u = np.clip((c.X - ncx) / nrx, -1, 1)
    v = np.clip((c.Y - ncy) / nry, -1, 1)
    r2 = np.clip(u * u + v * v, 0, 1)
    z = np.sqrt(1 - r2)
    lum = u * LIGHT[0] + v * LIGHT[1] + z * LIGHT[2]
    val = np.clip(lum * 0.62 + 0.42 + bias, 0, 0.999)
    q = val * 5.0
    if dither:
        q = q + (c.B - 0.5) * 0.9
    idx = np.clip(np.floor(q), 0, 4).astype(int)
    if flat is not None:
        idx = np.full_like(idx, flat)
    col = np.zeros((c.h, c.w, 3))
    for i in range(5):
        col[idx == i] = rp[i]
    inside = d < 0
    ring = (d >= 0) & (d < 1.0)
    c.paint(ring, ol)
    c.paint(inside, col)
    if rim:
        edge = inside & (d > -1.0)
        facing_bounce = edge & (c.Y > ncy + nry * 0.35)
        c.paint(facing_bounce, np.clip(rp[3] * 0.5 + np.array([0.5, 0.6, 0.9]) * 0.35, 0, 1))
    return inside

def spec(c, x, y, w=2, h=1, color=(1, 1, 1)):
    m = (c.X > x) & (c.X < x + w) & (c.Y > y) & (c.Y < y + h)
    c.paint(m, np.array(color))
