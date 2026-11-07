"""Tiny pixel canvas + PNG writer (standard library only) for the placeholder art generators.

Deterministic: the same drawing calls always produce byte-identical PNG files.
"""
import struct, zlib

CLEAR = (0, 0, 0, 0)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f=0.72):
    """Shadow step: darker, nudged toward plum (doc/05 §3)."""
    r, g, b, a = c
    return (min(255, int(r * f + 6)), int(g * f), min(255, int(b * f + 10)), a)


def light(c, amt=0.18):
    r, g, b, a = c
    return (int(r + (255 - r) * amt), int(g + (255 - g) * amt), int(b + (255 - b) * amt), a)


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [fill] * (w * h)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return CLEAR

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y * self.w + x] = c

    def rect(self, x0, y0, x1, y1, c):
        """Filled, inclusive corners."""
        for y in range(int(min(y0, y1)), int(max(y0, y1)) + 1):
            for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1):
                self.set(x, y, c)

    def rounded(self, x0, y0, x1, y1, r, c):
        """Filled rectangle with rounded corners (inclusive)."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                dx = max(x0 + r - x, 0, x - (x1 - r))
                dy = max(y0 + r - y, 0, y - (y1 - r))
                if dx * dx + dy * dy <= r * r:
                    self.set(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / max(rx, 0.5)
                dy = (y + 0.5 - cy) / max(ry, 0.5)
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for k in range(width):
                self.set(round(x) + (k if abs(y1 - y0) > abs(x1 - x0) else 0),
                         round(y) + (0 if abs(y1 - y0) > abs(x1 - x0) else k), c)

    def poly(self, pts, c):
        """Filled polygon (even-odd scanline)."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            yc = y + 0.5
            xs = []
            for i in range(len(pts)):
                (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % len(pts)]
                if (ya <= yc < yb) or (yb <= yc < ya):
                    xs.append(xa + (yc - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1]))):
                    self.set(x, y, c)

    def outline(self, c):
        """Draws `c` on every clear pixel that touches an opaque one (4-neighbour)."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y)[3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if self.get(x + dx, y + dy)[3] > 0 and self.get(x + dx, y + dy) != c:
                            add.append((x, y))
                            break
        for x, y in add:
            self.set(x, y, c)

    def mirrored(self):
        m = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                m.set(self.w - 1 - x, y, self.get(x, y))
        return m

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                p = other.get(x, y)
                if p[3] > 0:
                    self.set(ox + x, oy + y, p)

    def scaled(self, k):
        s = Canvas(self.w * k, self.h * k)
        for y in range(s.h):
            for x in range(s.w):
                s.px[y * s.w + x] = self.px[(y // k) * self.w + x // k]
        return s

    def save_png(self, path):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for p in self.px[y * self.w:(y + 1) * self.w]:
                raw.extend(p)

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)
