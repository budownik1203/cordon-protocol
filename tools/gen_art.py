#!/usr/bin/env python3
"""Generuje proceduralną grafikę pikselową do art/ (postacie 16x16 x 3 klatki, kontenery, kafelki 32x32).
Uruchom: python3 tools/gen_art.py   (wymaga Pillow). Wynik jest w repozytorium, więc gra nie wymaga uruchamiania skryptu."""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "art")
os.makedirs(OUT, exist_ok=True)

def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

OUTLINE = C("14141a")
SKIN = C("d9a88a")

def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3] if len(c) > 3 else 255)

def save(im, name):
    im.save(os.path.join(OUT, name))

# ------------------------------------------------------------------ postacie
def humanoid(pal, frame, bulk=0, backpack=None, helmet_style="cap", extra=None):
    """Widok z góry, postać patrzy w prawo (+x). frame 0 idle, 1/2 kroki."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # stopy
    off = {0: (0, 0), 1: (2, -2), 2: (-2, 2)}[frame]
    for (fy, o) in ((4, off[0]), (11, off[1])):
        d.rectangle([5 + o, fy, 8 + o, fy + 1], fill=OUTLINE)
        d.rectangle([6 + o, fy, 7 + o, fy], fill=shade(pal["pants"], 1.1))
    # plecak
    if backpack:
        d.rectangle([2, 5, 5, 10], fill=OUTLINE)
        d.rectangle([3, 6, 5, 9], fill=backpack)
    # tułów
    t0, t1 = 3 - bulk, 12 + bulk
    d.ellipse([4, t0, 11, t1], fill=OUTLINE)
    d.ellipse([5, t0 + 1, 10, t1 - 1], fill=pal["body"])
    d.line([(6, t0 + 2), (6, t1 - 2)], fill=shade(pal["body"], 0.8))
    if "trim" in pal:
        d.line([(9, t0 + 2), (9, t1 - 2)], fill=pal["trim"])
    # ramiona i broń
    d.line([(9, 5 - bulk), (13, 8)], fill=OUTLINE, width=2)
    d.line([(9, 11 + bulk), (13, 9)], fill=OUTLINE, width=2)
    d.point((10, 6 - bulk), fill=pal["body"]); d.point((10, 10 + bulk), fill=pal["body"])
    d.rectangle([11, 7, 15, 9], fill=OUTLINE)
    d.rectangle([11, 8, 15, 8], fill=C("8a8f98"))
    d.point((13, 8), fill=C("b9bec7"))
    d.point((12, 7), fill=pal["body"]); d.point((12, 9), fill=pal["body"])
    # głowa
    d.ellipse([5, 5, 10, 10], fill=OUTLINE)
    d.ellipse([6, 6, 9, 9], fill=pal["head"])
    if helmet_style == "helmet":
        d.ellipse([5, 5, 10, 10], outline=OUTLINE)
        d.ellipse([6, 6, 9, 9], fill=pal["helm"])
        d.line([(9, 6), (9, 9)], fill=C("2a3038"))
    elif helmet_style == "cap":
        d.ellipse([6, 6, 9, 9], fill=pal["helm"])
        d.point((9, 8), fill=SKIN)
    elif helmet_style == "scarf":
        d.ellipse([6, 6, 9, 9], fill=pal["helm"])
        d.point((9, 7), fill=SKIN); d.point((9, 8), fill=shade(pal["helm"], 0.7))
    if extra:
        extra(d, im)
    return im

def sheet(frames, name):
    w = frames[0].size[0]
    h = frames[0].size[1]
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    save(s, name)

PALS = {
    "player": {"body": C("4d6e8f"), "pants": C("2f3d4f"), "head": SKIN, "helm": C("33414f"), "trim": C("d8dde3")},
    "szab": {"body": C("8a6a3a"), "pants": C("4a4033"), "head": SKIN, "helm": C("b8985a"), "trim": C("5a4528")},
    "najem": {"body": C("3a3a44"), "pants": C("26262e"), "head": SKIN, "helm": C("2a2a32"), "trim": C("b83a58")},
    "wojsk": {"body": C("4f6b3a"), "pants": C("37492b"), "head": SKIN, "helm": C("5a7a42"), "trim": C("2f4326")},
    "elita": {"body": C("3f5230"), "pants": C("2b3820"), "head": SKIN, "helm": C("2d3a22"), "trim": C("e0c050")},
}
STYLE = {"player": "cap", "szab": "scarf", "najem": "helmet", "wojsk": "helmet", "elita": "helmet"}
PACK = {"player": C("5a4a33"), "szab": C("6b5a3a"), "najem": None, "wojsk": C("42522f"), "elita": C("2f3a24")}

def make_characters():
    for k, pal in PALS.items():
        frames = [humanoid(pal, f, bulk=1 if k == "elita" else 0, backpack=PACK[k], helmet_style=STYLE[k]) for f in range(3)]
        sheet(frames, k + ".png")
        # zwłoki: zlana sylwetka + kałuża krwi
        c = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(c)
        d.ellipse([2, 3, 14, 14], fill=C("5a1616", 200))
        d.ellipse([4, 5, 12, 12], fill=C("7a1c1c", 200))
        base = humanoid(pal, 0, bulk=1 if k == "elita" else 0, backpack=PACK[k], helmet_style=STYLE[k])
        dark = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        px = base.load(); dx = dark.load()
        for y in range(16):
            for x in range(16):
                r, g, b, a = px[x, y]
                if a:
                    dx[x, y] = (int(r * 0.55), int(g * 0.5), int(b * 0.5), 255)
        dark = dark.rotate(25, resample=Image.NEAREST)
        c.alpha_composite(dark)
        save(c, "corpse_" + k + ".png")

def fauna_frame(frame):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    flesh = C("8f4a8a"); dark = C("5a2a58"); belly = C("b36aa8")
    off = {0: 0, 1: 2, 2: -2}[frame]
    # kończyny (więcej niż trzeba)
    for i, x in enumerate((3, 6, 9, 12)):
        o = off if i % 2 == 0 else -off
        d.line([(x, 2), (x + o, 0)], fill=OUTLINE, width=2)
        d.line([(x, 13), (x - o, 15)], fill=OUTLINE, width=2)
    d.line([(7, 7), (10 + off // 2, 1)], fill=dark, width=1)  # dodatkowa łapa
    # ciało
    d.ellipse([1, 3, 12, 12], fill=OUTLINE)
    d.ellipse([2, 4, 11, 11], fill=flesh)
    d.ellipse([4, 6, 9, 9], fill=belly)
    for sx in (3, 5, 7):
        d.point((sx, 5), fill=dark); d.point((sx + 1, 10), fill=dark)
    # głowa
    d.ellipse([9, 4, 15, 11], fill=OUTLINE)
    d.ellipse([10, 5, 14, 10], fill=flesh)
    d.rectangle([13, 7, 15, 8], fill=C("2a0f2a"))
    d.point((12, 5), fill=C("ff4a4a")); d.point((12, 10), fill=C("ff4a4a"))
    d.point((14, 7), fill=C("e8d8c8")); d.point((14, 8), fill=C("e8d8c8"))
    return im

def make_fauna():
    sheet([fauna_frame(f) for f in range(3)], "fauna.png")
    c = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.ellipse([1, 3, 14, 13], fill=C("3a1a3a", 200))
    f = fauna_frame(0).rotate(-30, resample=Image.NEAREST)
    px = f.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.45), int(g * 0.4), int(b * 0.45), 255)
    c.alpha_composite(f)
    save(c, "corpse_fauna.png")

# ------------------------------------------------------------------ kontenery 20x20
def box_img(draw_fn):
    im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d)
    return im

def make_boxes():
    def locker(body, light, handle):
        def f(d):
            d.rectangle([1, 2, 18, 17], fill=OUTLINE)
            d.rectangle([2, 3, 17, 16], fill=body)
            d.rectangle([2, 3, 17, 5], fill=light)
            d.line([(9, 6), (9, 16)], fill=shade(body, 0.7))
            d.rectangle([7, 10, 8, 12], fill=handle); d.rectangle([11, 10, 12, 12], fill=handle)
            for x in (4, 14):
                d.line([(x, 8), (x + 2, 8)], fill=shade(body, 0.7))
        return f
    def crate(wood, dark):
        def f(d):
            d.rectangle([1, 1, 18, 18], fill=OUTLINE)
            d.rectangle([2, 2, 17, 17], fill=wood)
            d.line([(2, 2), (17, 17)], fill=dark); d.line([(17, 2), (2, 17)], fill=dark)
            d.rectangle([2, 2, 17, 17], outline=dark)
            d.rectangle([2, 2, 5, 5], fill=shade(wood, 0.8)); d.rectangle([14, 14, 17, 17], fill=shade(wood, 0.8))
        return f
    def desk(top, paper):
        def f(d):
            d.rectangle([0, 3, 19, 16], fill=OUTLINE)
            d.rectangle([1, 4, 18, 15], fill=top)
            d.rectangle([3, 6, 8, 11], fill=paper); d.line([(4, 8), (7, 8)], fill=C("8a8a78")); d.line([(4, 10), (7, 10)], fill=C("8a8a78"))
            d.ellipse([12, 6, 16, 10], fill=C("d6c47a")); d.point((14, 8), fill=C("fff3b0"))
            d.rectangle([11, 12, 17, 14], fill=shade(top, 0.75))
        return f
    def safe(body, dial):
        def f(d):
            d.rectangle([1, 1, 18, 18], fill=OUTLINE)
            d.rectangle([2, 2, 17, 17], fill=body)
            d.rectangle([4, 4, 15, 15], outline=shade(body, 0.7))
            d.ellipse([7, 7, 12, 12], fill=OUTLINE); d.ellipse([8, 8, 11, 11], fill=dial)
            d.point((9, 9), fill=C("ffffff"))
            d.rectangle([14, 8, 15, 11], fill=shade(body, 1.3))
        return f
    save(box_img(locker(C("5d6a78"), C("7c8a99"), C("c9ced6"))), "box_a_szafka.png")
    save(box_img(crate(C("8a6a36"), C("5a4422"))), "box_a_skrzynia.png")
    save(box_img(desk(C("6b4f3a"), C("e8e4cc"))), "box_a_biurko.png")
    save(box_img(safe(C("7c7a3a"), C("d0cf6a"))), "box_a_sejf.png")
    # kompleks
    save(box_img(locker(C("c7d2dc"), C("e4eef6"), C("4fa3d6"))), "box_b_szafka.png")
    save(box_img(crate(C("4f6b3a"), C("2f4326"))), "box_b_skrzynia.png")
    def terminal(d):
        d.rectangle([0, 3, 19, 16], fill=OUTLINE)
        d.rectangle([1, 4, 18, 15], fill=C("8a949e"))
        d.rectangle([3, 5, 12, 11], fill=OUTLINE); d.rectangle([4, 6, 11, 10], fill=C("3fd0a0"))
        for y in (7, 9):
            d.line([(5, y), (10, y)], fill=C("1c6e55"))
        d.rectangle([3, 12, 15, 14], fill=C("5a636d"))
        d.rectangle([14, 5, 17, 9], fill=C("aab4be"))
    save(box_img(terminal), "box_b_biurko.png")
    save(box_img(safe(C("a2acb6"), C("3fd0a0"))), "box_b_sejf.png")
    def anomalia(d):
        d.polygon([(10, 0), (19, 8), (14, 19), (5, 18), (0, 7)], fill=OUTLINE)
        d.polygon([(10, 2), (17, 8), (13, 17), (6, 16), (2, 7)], fill=C("3a1f55"))
        d.polygon([(10, 5), (14, 9), (11, 14), (7, 12), (6, 8)], fill=C("8a3fd0"))
        d.point((10, 9), fill=C("ffffff")); d.point((9, 8), fill=C("ff9af0"))
        for p in ((3, 4), (16, 15), (2, 15), (17, 3)):
            d.point(p, fill=C("c070ff"))
    save(box_img(anomalia), "box_anomalia.png")

# ------------------------------------------------------------------ kafelki 32x32
def noise_tile(base, spread, rng, speckle=None, n=0):
    im = Image.new("RGBA", (32, 32), base)
    px = im.load()
    for y in range(32):
        for x in range(32):
            v = rng.uniform(-spread, spread)
            px[x, y] = (int(base[0] + v), int(base[1] + v), int(base[2] + v * 0.9), 255)
    if speckle:
        for _ in range(n):
            px[rng.randrange(32), rng.randrange(32)] = speckle
    return im

def make_tiles():
    rng = random.Random(7)
    # --- biom A: osiedle ---
    for i in range(4):
        im = noise_tile(C("66675f"), 7, rng, C("4f504a"), 40)
        d = ImageDraw.Draw(im)
        # szwy płyt
        if i % 2 == 0:
            d.line([(0, 15), (31, 15)], fill=C("5a5b55")); d.line([(15, 0), (15, 31)], fill=C("5a5b55"))
        else:
            d.line([(0, 8), (31, 8)], fill=C("5a5b55")); d.line([(0, 24), (31, 24)], fill=C("5a5b55")); d.line([(10, 0), (10, 31)], fill=C("5a5b55"))
        if i == 1:  # pęknięcie
            pts = [(3, 3), (8, 9), (11, 12), (17, 14), (20, 20), (26, 24), (29, 30)]
            d.line(pts, fill=C("3f403b"))
        if i == 2:  # kępa trawy
            for _ in range(22):
                gx, gy = rng.randrange(18, 31), rng.randrange(18, 31)
                d.point((gx, gy), fill=rng.choice([C("5d7a3a"), C("6f8f45"), C("4a6430")]))
        if i == 3:  # plama / kałuża
            d.ellipse([6, 18, 20, 27], fill=C("4d5559")); d.ellipse([8, 19, 16, 23], fill=C("62707a"))
        save(im, "floor_a%d.png" % i)
    # ściana A: cegła
    im = Image.new("RGBA", (32, 32), C("8a4f3e"))
    d = ImageDraw.Draw(im)
    for row in range(0, 32, 6):
        d.line([(0, row), (31, row)], fill=C("5a3226"))
        off = 0 if (row // 6) % 2 == 0 else 8
        for bx in range(off, 32, 16):
            d.line([(bx, row), (bx, row + 5)], fill=C("5a3226"))
    px = im.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = px[x, y]
            v = rng.randint(-10, 10)
            px[x, y] = (max(0, min(255, r + v)), max(0, min(255, g + v)), max(0, min(255, b + v)), 255)
    d.rectangle([0, 0, 31, 2], fill=C("b27a62"))
    d.rectangle([0, 29, 31, 31], fill=C("3a2018"))
    save(im, "wall_a.png")
    # osłona A: worki z piaskiem
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for (x, y) in ((2, 6), (17, 6), (9, 15), (2, 22), (17, 22)):
        d.rounded_rectangle([x, y, x + 12, y + 7], 3, fill=OUTLINE)
        d.rounded_rectangle([x + 1, y + 1, x + 11, y + 6], 3, fill=C("b0a070"))
        d.line([(x + 3, y + 3), (x + 8, y + 3)], fill=C("8f8052"))
    save(im, "cover_a.png")
    # --- biom B: kompleks ---
    for i in range(4):
        im = noise_tile(C("5f6972"), 4, rng, C("525c65"), 25)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 31, 31], outline=C("5f6972"))
        d.line([(0, 15), (31, 15)], fill=C("6c767f")); d.line([(15, 0), (15, 31)], fill=C("6c767f"))
        if i == 1:
            d.rectangle([5, 6, 13, 12], fill=C("8b8f78"))  # zacieki
            d.point((20, 20), fill=C("5a6670"))
        if i == 2:
            d.line([(16, 2), (16, 29)], fill=C("e0c050")); d.line([(18, 2), (18, 29)], fill=C("e0c050"))  # pasy
        if i == 3:
            d.ellipse([8, 8, 24, 24], outline=C("7a848d"))
            d.point((16, 16), fill=C("5a6670"))
        save(im, "floor_b%d.png" % i)
    im = Image.new("RGBA", (32, 32), C("c4ccd3"))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 31], outline=C("8a949d"))
    d.rectangle([2, 2, 29, 29], outline=C("a9b3bb"))
    d.rectangle([0, 12, 31, 18], fill=C("3f86c0")); d.line([(0, 15), (31, 15)], fill=C("8cc4ee"))
    for (x, y) in ((4, 4), (27, 4), (4, 27), (27, 27)):
        d.point((x, y), fill=C("6a747d"))
    d.rectangle([0, 29, 31, 31], fill=C("6a747d"))
    save(im, "wall_b.png")
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 5, 29, 26], fill=OUTLINE)
    d.rectangle([3, 6, 28, 25], fill=C("d8dee4"))
    d.rectangle([3, 6, 28, 9], fill=C("f0f4f7"))
    d.rectangle([5, 12, 12, 22], fill=C("9bd0ea")); d.rectangle([14, 13, 17, 20], fill=C("6a8f6a")); d.rectangle([20, 12, 26, 22], fill=C("b7c1ca"))
    d.ellipse([7, 14, 10, 17], fill=C("ffffff"))
    save(im, "cover_b.png")
    # anomalia: powtarzający się wzór
    for i in range(2):
        im = Image.new("RGBA", (32, 32), C("1d1530"))
        d = ImageDraw.Draw(im)
        for r in range(2, 16, 3):
            col = C("5a2f8a") if (r // 3 + i) % 2 == 0 else C("2f7a7a")
            d.rectangle([16 - r, 16 - r, 15 + r, 15 + r], outline=col)
        d.point((16, 16), fill=C("ffffff"))
        save(im, "floor_x%d.png" % i)

# ------------------------------------------------------------------ strefa wyjścia, ikony
def make_misc():
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(0, 64, 8):
        col = C("ffffff", 120) if (i // 8) % 2 == 0 else C("000000", 0)
        d.rectangle([i, 0, i + 7, 3], fill=col); d.rectangle([i, 60, i + 7, 63], fill=col)
        d.rectangle([0, i, 3, i + 7], fill=col); d.rectangle([60, i, 63, i + 7], fill=col)
    save(im, "exit_frame.png")
    # trafienia / gilza
    im = Image.new("RGBA", (4, 4), C("ffffff")); save(im, "px.png")

if __name__ == "__main__":
    make_characters(); make_fauna(); make_boxes(); make_tiles(); make_misc()
    print("art ok:", sorted(os.listdir(OUT)))
