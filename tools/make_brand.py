"""Draws the Joynetic logo mark and writes every place it is used as a file.

    python3 tools/make_brand.py

Outputs
  app/assets/brand/logo_mark.png      the in-app mark (JoyneticMark loads this)
  app/android/.../mipmap-*/ic_launcher.png   the launcher icon, five densities

The mark: a rounded tile in the brand gradient (volt to aqua) with a dark "J"
whose dot has leapt up and to the right, and three speed lines behind it.
Joy + kinetic. The geometry here matches the fallback painter in
app/lib/widgets/brand.dart.

To use your own logo instead, replace app/assets/brand/logo_mark.png with a
square PNG (512 px or larger, transparent corners if you want them rounded)
and the launcher PNGs with your own. No code changes are needed.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
VOLT = (200, 245, 66)
AQUA = (94, 230, 208)
INK = (10, 12, 16)


def bezier(p0, p1, p2, p3, n=28):
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t**2, t**3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def mark(size: int, radius: float = 0.24) -> Image.Image:
    ss = 4  # supersample
    n = size * ss

    # Diagonal gradient, drawn small and scaled up (it is smooth anyway).
    g = Image.new("RGB", (64, 64))
    px = g.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            px[x, y] = tuple(round(VOLT[i] + (AQUA[i] - VOLT[i]) * t) for i in range(3))
    tile = g.resize((n, n), Image.BICUBIC)

    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), radius=radius * n, fill=255)

    d = ImageDraw.Draw(tile)

    def stroke(points, width):
        w = round(width * n)
        pts = [(x * n, y * n) for x, y in points]
        d.line(pts, fill=INK, width=w, joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)

    # The J: a stem and a hook.
    stroke([(0.60, 0.32), (0.60, 0.62)] + bezier((0.60, 0.62), (0.60, 0.84), (0.33, 0.86), (0.32, 0.68)), 0.13)
    # Its dot, mid-leap.
    cx, cy, r = 0.745 * n, 0.175 * n, 0.082 * n
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK)
    # Speed lines.
    for y, x0 in ((0.30, 0.23), (0.41, 0.14), (0.52, 0.27)):
        stroke([(x0, y), (0.44, y)], 0.05)

    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(tile, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def main():
    brand = ROOT / "app/assets/brand"
    brand.mkdir(parents=True, exist_ok=True)
    mark(512).save(brand / "logo_mark.png")
    res = ROOT / "app/android/app/src/main/res"
    for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        mark(px, radius=0.22).save(res / f"mipmap-{name}/ic_launcher.png")
    print("wrote the logo mark and five launcher icons")


if __name__ == "__main__":
    main()
