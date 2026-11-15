"""Mood renders of the HLM interiors of the cité des Tilleuls (after D-019).

Not game assets: five quick scenes, rendered with Cycles, to agree with Maxime
on interiors that read as real social housing ("ce sont des habitations")
with the mood of the hospital board (tools/blender/hospital_mood.py): dead
tubes, one light per room, fog, dirt, the trace of the people who lived there.
- "hall": the tower entrance hall, mailboxes, lift out of order, intercom,
- "escalier": the stairwell, two-tone paint, caged wall lamp, storey number,
- "palier": a storey corridor, flat doors with numbers and doormats, one ajar,
- "salon": a flat left in a hurry, floral wallpaper, sofa, TV snow,
- "cuisine": the kitchen, formica, oilcloth, the open fridge as only light.
Pixel textures with nearest filtering, dull colors, no orange (rule 2.3).
    python tools/blender/hlm_interior_mood.py -- <out_dir> [scene ...]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  isort: skip
from hospital_mood import (  # noqa: E402
    box,
    camera,
    common,
    fog,
    image,
    light,
    material,
    noisy,
    reset,
    scatter_papers,
    text,
    tiles,
)

# --- Textures -----------------------------------------------------------------


def wallpaper(name, base, motif, seed, size=32, peel=3):
    """Vertical stripes with a small flower every 8 px, stained and torn."""
    rng = random.Random(seed)
    holes = [(rng.randrange(size), rng.randrange(size), rng.uniform(2, 6)) for _ in range(peel)]

    def shade(x, y):
        for hx, hy, hr in holes:
            if math.hypot(x - hx, (y - hy) * 0.6) < hr:
                g = 0.42 + rng.uniform(-0.03, 0.03)
                return [g, g * 0.98, g * 0.9]  # Bare plaster.
        c = list(base)
        if x % 8 in (0, 1):
            c = [base[i] * 0.86 for i in range(3)]
        fx, fy = x % 8, y % 8
        if (fx - 4) ** 2 + (fy - 4) ** 2 <= 2:
            c = list(motif)
        n = rng.uniform(-0.025, 0.025)
        yellow = 0.12 * (y / size)  # Nicotine towards the ceiling.
        return [c[0] + n, c[1] + n - yellow * 0.2, c[2] + n - yellow]

    return image(name, size, size, shade)


def checker(name, a, b, seed, n=4, size=32, wear=0.05):
    rng = random.Random(seed)
    cell = size // n

    def shade(x, y):
        c = a if ((x // cell) + (y // cell)) % 2 == 0 else b
        n_ = rng.uniform(-wear, wear)
        return [c[0] + n_, c[1] + n_, c[2] + n_]

    return image(name, size, size, shade)


def terrazzo(name, base, seed, size=32):
    rng = random.Random(seed)

    def shade(x, y):
        r = rng.random()
        if r < 0.08:
            return [base[0] * 0.55, base[1] * 0.55, base[2] * 0.55]
        if r < 0.14:
            return [base[0] * 1.3, base[1] * 1.3, base[2] * 1.25]
        n = rng.uniform(-0.03, 0.03)
        return [base[0] + n, base[1] + n, base[2] + n]

    return image(name, size, size, shade)


def hlm_materials(m):
    m["terrazzo"] = material("terrazzo", terrazzo("t_terr", (0.34, 0.30, 0.25), 101))
    m["faience"] = material(
        "faience", tiles("t_faience", (0.52, 0.48, 0.40), (0.28, 0.26, 0.22), 102, n=4, dirt=0.08), rough=0.4
    )
    m["paint_low"] = material(
        "paint_low", noisy("t_plow", (0.16, 0.24, 0.20), 0.02, 103, stains=5, stain=(0.08, 0.08, 0.06)), rough=0.4
    )
    m["paint_high"] = material(
        "paint_high", noisy("t_phigh", (0.50, 0.48, 0.40), 0.03, 104, stains=6, stain=(0.25, 0.22, 0.14))
    )
    m["wallpaper"] = material("wallpaper", wallpaper("t_wp", (0.46, 0.42, 0.32), (0.38, 0.30, 0.28), 105, peel=4))
    m["wallpaper2"] = material("wallpaper2", wallpaper("t_wp2", (0.36, 0.40, 0.36), (0.30, 0.33, 0.33), 106, peel=2))
    m["lino"] = material("lino", checker("t_lino", (0.30, 0.25, 0.20), (0.22, 0.18, 0.15), 107), rough=0.5)
    m["parquet"] = material(
        "parquet", noisy("t_parq", (0.26, 0.18, 0.12), 0.03, 108, stains=4, stain=(0.12, 0.09, 0.06)), rough=0.6
    )
    m["wood_door"] = material(
        "wood_door", noisy("t_wdoor", (0.24, 0.15, 0.10), 0.02, 109, stains=2, stain=(0.1, 0.07, 0.05)), rough=0.5
    )
    m["formica"] = material("formica", noisy("t_formica", (0.48, 0.44, 0.34), 0.02, 110, stains=3, stain=(0.2, 0.18, 0.1)), rough=0.3)
    m["oilcloth"] = material("oilcloth", checker("t_oil", (0.42, 0.14, 0.12), (0.50, 0.46, 0.40), 111, n=8, wear=0.03), rough=0.3)
    m["fabric"] = material("fabric", noisy("t_fab", (0.20, 0.22, 0.26), 0.03, 112, stains=3, stain=(0.1, 0.1, 0.1)))
    m["blanket"] = material("blanket", checker("t_blk", (0.28, 0.20, 0.24), (0.20, 0.16, 0.18), 113, n=4))
    m["brass"] = material("brass", color=(0.35, 0.30, 0.16), rough=0.3)
    m["mat"] = material("doormat", noisy("t_mat", (0.20, 0.16, 0.11), 0.05, 114))
    m["tag"] = material("tag", color=(0.05, 0.05, 0.06))
    m["tag_blue"] = material("tag_blue", color=(0.10, 0.14, 0.30))
    m["tag_red"] = material("tag_red", color=(0.32, 0.06, 0.07))
    m["hublot"] = material("hublot", color=(0.8, 0.82, 0.78), emission=(0.85, 1.0, 0.9), strength=14.0)
    m["hublot_dead"] = material("hublot_dead", color=(0.35, 0.36, 0.34), rough=0.2)
    m["tv"] = material("tv", color=(0.3, 0.35, 0.45), emission=(0.55, 0.65, 1.0), strength=2.0)
    m["fridge_in"] = material("fridge_in", color=(0.8, 0.85, 0.85), emission=(0.8, 0.95, 1.0), strength=3.0)
    m["white"] = material("white_goods", noisy("t_white", (0.58, 0.58, 0.54), 0.02, 115, stains=3, stain=(0.3, 0.27, 0.2)), rough=0.3)
    m["sodium_glass"] = material("sodium_glass", color=(0.2, 0.15, 0.08), emission=(1.0, 0.62, 0.3), strength=0.25, rough=0.1)
    m["net"] = material("net_curtain", color=(0.55, 0.55, 0.5))
    m["photo"] = material("photo", noisy("t_photo", (0.35, 0.32, 0.28), 0.12, 116, size=8))
    m["button"] = material("button", color=(0.1, 0.25, 0.15), emission=(0.4, 1.0, 0.55), strength=3.0)
    m["plastic"] = material("plastic", color=(0.18, 0.22, 0.28), rough=0.4)
    m["toy"] = material("toy", color=(0.45, 0.40, 0.12))
    return m


def tags(m, rng, wall_y, x0, x1, z0, z1, count, facing=-1):
    """Scribbled tags: chains of short thin strokes on a wall facing -Y or +Y."""
    for i in range(count):
        mat = rng.choice([m["tag"], m["tag"], m["tag_blue"], m["tag_red"]])
        x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
        heading = rng.uniform(-0.5, 0.5)
        for _ in range(rng.randint(8, 16)):
            heading += rng.uniform(-1.3, 1.3)
            dx, dz = math.cos(heading) * 0.06, math.sin(heading) * 0.05
            y = wall_y + facing * 0.004
            box("tag", x, min(y, wall_y), z, x + 0.03, max(y, wall_y), z + 0.03, mat)
            x, z = x + dx, z + dz


def tags_x(m, rng, wall_x, y0, y1, z0, z1, count, facing=1):
    """Same as tags() on a wall facing +X or -X."""
    for i in range(count):
        mat = rng.choice([m["tag"], m["tag"], m["tag_blue"], m["tag_red"]])
        y, z = rng.uniform(y0, y1), rng.uniform(z0, z1)
        heading = rng.uniform(-0.5, 0.5)
        for _ in range(rng.randint(8, 16)):
            heading += rng.uniform(-1.3, 1.3)
            x = wall_x + facing * 0.004
            box("tag", min(x, wall_x), y, z, max(x, wall_x), y + 0.03, z + 0.03, mat)
            y, z = y + math.cos(heading) * 0.06, z + math.sin(heading) * 0.05


def two_tone_x(m, x0, x1, y0, y1, h, split=1.3):
    box("wall_low", x0, y0, 0, x1, y1, split, m["paint_low"], meters=2.0)
    box("wall_line", x0 - 0.005, y0 - 0.005, split, x1 + 0.005, y1 + 0.005, split + 0.04, m["tag"])
    box("wall_high", x0, y0, split + 0.04, x1, y1, h, m["paint_high"], meters=2.0)


def hublot(m, x, y, z, alive, axis="z"):
    """A round caged ceiling or wall lamp, drawn as a flat square with a grid."""
    mat = m["hublot"] if alive else m["hublot_dead"]
    if axis == "z":
        box("hublot", x - 0.15, y - 0.15, z - 0.06, x + 0.15, y + 0.15, z, mat)
        for d in (-0.07, 0.0, 0.07):
            box("cage", x + d - 0.006, y - 0.16, z - 0.07, x + d + 0.006, y + 0.16, z - 0.06, m["tag"])
    else:  # On a wall facing -Y.
        box("hublot", x - 0.15, y - 0.06, z - 0.15, x + 0.15, y, z + 0.15, mat)
        for d in (-0.07, 0.0, 0.07):
            box("cage", x + d - 0.006, y - 0.07, z - 0.16, x + d + 0.006, y - 0.06, z + 0.16, m["tag"])


def flat_door(m, x, y, s, ajar=False):
    """A flat door centred on x in a wall at y; s = +1 if the corridor is at +Y."""
    t = 0.04 * s
    if ajar:
        box("void", x - 0.45, min(y, y - 0.12 * s), 0, x + 0.45, max(y, y - 0.12 * s), 2.05, m["dark"])
        box("leaf", x - 0.47, min(y, y - 0.85 * s), 0, x - 0.43, max(y, y - 0.85 * s), 2.05, m["wood_door"])
    else:
        box("leaf", x - 0.45, min(y, y + t), 0, x + 0.45, max(y, y + t), 2.05, m["wood_door"])
        f0, f1 = sorted((y + t, y + 2 * t))
        box("handle", x + 0.28, f0, 0.98, x + 0.4, f1, 1.02, m["brass"])
        box("plate", x - 0.07, f0, 1.62, x + 0.07, f1, 1.7, m["brass"])
        box("peephole", x - 0.015, f0, 1.5, x + 0.015, f1, 1.53, m["brass"])
    box("doormat", x - 0.4, min(y + 0.05 * s, y + 0.55 * s), 0, x + 0.4, max(y + 0.05 * s, y + 0.55 * s), 0.015, m["mat"])


def window(m, x0, y, z0, x1, z1, facing=1, net=True):
    """A window in a wall at y facing -Y (outside is +Y), sodium light outside."""
    box("pane", x0, y, z0, x1, y + 0.02, z1, m["sodium_glass"])
    box("mullion", (x0 + x1) / 2 - 0.03, y - 0.03, z0, (x0 + x1) / 2 + 0.03, y, z1, m["white"])
    box("sill", x0 - 0.05, y - 0.15, z0 - 0.04, x1 + 0.05, y, z0, m["white"])
    if net:
        box("net", x0 + 0.02, y - 0.06, z0 + 0.05, x1 - 0.02, y - 0.05, z1, m["net"])
    del facing


# --- Scenes ---------------------------------------------------------------------


def hall(m):
    rng = random.Random(51)
    w, d, h = 6.0, 8.0, 2.8
    box("floor", 0, 0, -0.1, w, d, 0, m["terrazzo"], meters=1.0)
    box("ceil", 0, 0, h, w, d, h + 0.1, m["ceiling"], meters=1.2)
    # Left wall (x = 0): faience up to 1.5 m, mailboxes.
    box("left_low", -0.1, 0, 0, 0, d, 1.5, m["faience"], meters=0.8)
    box("left_high", -0.1, 0, 1.5, 0, d, h, m["paint_high"], meters=2.0)
    for c in range(8):
        for r in range(4):
            y0, z0 = 1.6 + c * 0.42, 0.9 + r * 0.32
            if (c, r) in ((2, 1), (5, 3), (6, 0)):  # Forced open, door hanging.
                box("mb_hole", 0.0, y0, z0, 0.3, y0 + 0.38, z0 + 0.28, m["dark"])
                box("mb_flap", 0.3, y0, z0 - 0.25, 0.32, y0 + 0.38, z0 + 0.02, m["steel"])
            else:
                box("mailbox", 0.0, y0, z0, 0.32, y0 + 0.38, z0 + 0.28, m["steel"])
                box("slot", 0.32, y0 + 0.08, z0 + 0.2, 0.325, y0 + 0.3, z0 + 0.22, m["dark"])
                box("label", 0.32, y0 + 0.05, z0 + 0.05, 0.322, y0 + 0.17, z0 + 0.1, m["paper"])
    scatter_papers(m, rng, 0.4, 1.4, 1.6, 5.0, 14)
    tags_x(m, rng, 0.0, 0.3, 1.5, 1.6, 2.4, 3, facing=1)
    # Right wall (x = w): intercom, tags, a pram left there.
    box("right_low", w, 0, 0, w + 0.1, d, 1.5, m["faience"], meters=0.8)
    box("right_high", w, 0, 1.5, w + 0.1, d, h, m["paint_high"], meters=2.0)
    tags_x(m, rng, w, 1.0, 6.5, 0.4, 1.4, 6, facing=-1)
    box("pram_body", w - 0.75, 4.2, 0.35, w - 0.15, 5.1, 0.75, m["fabric"])
    box("pram_hood", w - 0.75, 4.9, 0.75, w - 0.15, 5.15, 1.05, m["fabric"])
    for yy in (4.25, 4.95):
        box("pram_wheel", w - 0.8, yy, 0, w - 0.76, yy + 0.2, 0.3, m["dark"])
        box("pram_wheel", w - 0.14, yy, 0, w - 0.1, yy + 0.2, 0.3, m["dark"])
    # Back wall: lift (out of order), stairwell door with wired glass.
    box("back", 0, d, 0, w, d + 0.1, h, m["paint_high"], meters=2.0)
    box("back_low", 0, d - 0.01, 0, w, d, 1.3, m["paint_low"], meters=2.0)
    box("lift", 1.0, d - 0.05, 0, 2.2, d, 2.1, m["steel"])
    box("lift_gap", 1.59, d - 0.06, 0, 1.61, d - 0.05, 2.1, m["dark"])
    box("out_of_order", 1.3, d - 0.07, 1.3, 1.9, d - 0.06, 1.7, m["paper"])
    box("lift_button", 2.35, d - 0.04, 1.1, 2.45, d, 1.2, m["red"])
    box("stair_door", 3.6, d - 0.05, 0, 4.6, d, 2.1, m["door"])
    box("stair_glass", 3.8, d - 0.06, 1.2, 4.4, d - 0.05, 1.9, m["window_dark"])
    box("exit_sign", 3.8, d - 0.06, 2.3, 4.4, d - 0.05, 2.5, m["sign"])
    light("POINT", (4.1, d - 0.3, 2.4), 1.2, (0.45, 1.0, 0.6), name="exit")
    # Behind the camera: glass doors, sodium light coming in through the fog.
    box("front", 0, -0.1, 0, w, 0, h, m["window_dark"])
    light("AREA", (3.0, -2.0, 2.6), 60, (1.0, 0.62, 0.3), size=2.5, name="sodium_out")
    # Tubes: one dying (dim green), one dead.
    box("tube_dead", 1.4, 2.0, h - 0.05, 1.55, 3.2, h - 0.01, m["neon_dead"])
    box("tube", 3.5, 5.6, h - 0.05, 3.65, 6.8, h - 0.01, m["neon"])
    light("AREA", (3.6, 6.2, h - 0.1), 14, (0.55, 1.0, 0.7), size=0.8, name="tube")
    # Bin bags against the lift.
    for i, (bx, by) in enumerate(((2.4, 7.3), (2.8, 7.5), (2.5, 7.7))):
        box("bag", bx - 0.25, by - 0.25, 0, bx + 0.25, by + 0.25, 0.45, m["dark"], rot_z=i * 0.5)
    fog(0, 0, 0, w, d, h, 0.03)
    camera((3.8, 0.4, 1.6), (1.6, 7.5, 1.2), lens=18)


def escalier(m):
    rng = random.Random(61)
    w, h_top = 2.6, 5.6
    # Ground landing, two flights around a central wall, half landing.
    box("landing0", 0, -2.0, -0.1, w, 1.0, 0, m["terrazzo"], meters=1.0)
    steps = 9
    for i in range(steps):
        y0 = 1.0 + i * 0.3
        z1 = (i + 1) * 0.165
        box("step", 0, y0, 0, 1.2, y0 + 0.3, z1, m["concrete"], meters=0.5)
        box("nosing", 0, y0, z1 - 0.01, 1.2, y0 + 0.03, z1 + 0.005, m["steel"])
    top = steps * 0.165
    box("half_landing", 0, 1.0 + steps * 0.3, top - 0.15, w, 1.0 + steps * 0.3 + 1.3, top, m["terrazzo"])
    for i in range(steps):
        y1 = 1.0 + steps * 0.3 - i * 0.3
        z1 = top + (i + 1) * 0.165
        box("step2", 1.4, y1 - 0.3, top, w, y1, z1, m["concrete"], meters=0.5)
    box("upper", 1.4, -2.0, top * 2 - 0.15, w, 1.0, top * 2, m["terrazzo"])
    box("upper_slab", 0, -2.0, top * 2 - 0.15, 1.4, -0.4, top * 2, m["concrete"])
    # Central wall between the flights, with a handrail on top.
    box("core", 1.2, 1.0, 0, 1.4, 1.0 + steps * 0.3, top + 1.0, m["paint_low"])
    box("rail", 1.15, 1.0, 0.9, 1.2, 1.0 + steps * 0.3, top + 0.95, m["steel"])
    # Walls: dark green gloss below, cream above, a painted storey number.
    end = 1.0 + steps * 0.3 + 1.3
    for x0, x1 in ((-0.1, 0.0), (w, w + 0.1)):
        box("wall_low", x0, -2.0, 0, x1, end, 1.3 + top * 0.5, m["paint_low"], meters=2.0)
        box("wall_high", x0, -2.0, 1.3 + top * 0.5, x1, end, h_top, m["paint_high"], meters=2.0)
    box("end_low", 0, end, top - 0.15, w, end + 0.1, top + 1.2, m["paint_low"], meters=2.0)
    box("end_line", 0, end - 0.005, top + 1.2, w, end, top + 1.24, m["tag"])
    box("end_high", 0, end, top + 1.24, w, end + 0.1, h_top, m["paint_high"], meters=2.0)
    text("3", (0.35, end - 0.01, top + 1.45), 0.9, m["paint_low"])
    box("ceil", 0, -2.0, h_top, w, end, h_top + 0.1, m["ceiling"])
    hublot(m, 1.9, end, top + 2.2, True, axis="y")
    light("POINT", (1.9, end - 0.3, top + 2.2), 45, (0.75, 1.0, 0.85), size=0.1, name="hublot")
    # Timer switch glowing on the left wall.
    box("timer", 0.0, 0.6, 1.2, 0.03, 0.72, 1.32, m["button"])
    light("POINT", (0.1, 0.66, 1.26), 0.15, (0.4, 1.0, 0.55), name="timer")
    tags_x(m, rng, 0.0, 0.5, 4.0, 0.6, 1.9, 5, facing=1)
    tags_x(m, rng, w, 0.5, 3.5, 1.4, 2.4, 3, facing=-1)
    # Rubbish on the steps.
    for i in range(6):
        sy = 1.0 + rng.randrange(steps) * 0.3
        sz = (sy - 1.0) / 0.3 * 0.165 + 0.165
        box("can", rng.uniform(0.1, 1.0), sy + 0.05, sz, 0, 0, 0, m["steel"]) if False else box(
            "can", 0.2 + i * 0.13, sy + 0.08, sz, 0.27 + i * 0.13, sy + 0.15, sz + 0.12, m["steel"] if i % 2 else m["paper"]
        )
    fog(0, -2.0, 0, w, end, h_top, 0.03)
    hublot(m, 0.6, -2.0 + 0.0, 2.3, False, axis="z")
    light("POINT", (0.6, -0.5, 2.4), 4, (0.75, 1.0, 0.85), size=0.1, name="low_hublot")
    camera((0.6, -1.7, 1.6), (0.6, 4.8, 2.0), lens=18)


def palier(m):
    rng = random.Random(71)
    length, width, h = 14.0, 1.8, 2.5
    box("floor", 0, 0, -0.1, length, width, 0, m["lino"], meters=1.0)
    box("ceil", 0, 0, h, length, width, h + 0.1, m["ceiling"], meters=1.2)
    # Long walls (y = 0 and y = width) with flat doors every 3.5 m.
    for side, y in ((1, 0.0), (-1, width)):
        y0, y1 = (y - 0.1, y) if side > 0 else (y, y + 0.1)
        box("wall_low", 0, y0, 0, length, y1, 1.1, m["paint_low"], meters=2.0)
        box("line", 0, y0 - 0.005, 1.1, length, y1 + 0.005, 1.13, m["tag"])
        box("wall_high", 0, y0, 1.13, length, y1, h, m["wallpaper2"], meters=1.0)
        for i, x in enumerate((2.5, 6.0, 9.5)):
            xx = x + (0.0 if side > 0 else 1.2)
            ajar = side > 0 and i == 2
            flat_door(m, xx, y, side, ajar=ajar)
            if ajar:
                box("tv_glow", xx - 0.44, y - 1.5, 0.0, xx + 0.44, y - 1.49, 2.0, m["tv"])
                light("POINT", (xx, y - 0.7, 1.0), 25, (0.55, 0.65, 1.0), name="tv_spill")
    # End wall: fire door with wired glass, the green exit sign.
    box("end", length, 0, 0, length + 0.1, width, h, m["paint_high"])
    box("fire_door", length - 0.05, 0.3, 0, length, 1.5, 2.1, m["door"])
    box("fire_glass", length - 0.06, 0.6, 1.1, length - 0.05, 1.2, 1.8, m["window_lit"])
    box("exit_sign", length - 0.06, 0.6, 2.2, length - 0.05, 1.2, 2.4, m["sign"])
    light("POINT", (length - 0.6, 0.9, 2.0), 2.5, (0.45, 1.0, 0.6), name="exit")
    box("start", -0.1, 0, 0, 0, width, h, m["paint_high"])
    for x in (1.5, 5.0, 8.5, 12.0):
        hublot(m, x, width / 2, h, x in (5.0, 12.0))
    light("POINT", (12.0, width / 2, h - 0.2), 25, (0.75, 1.0, 0.85), size=0.1, name="last_hublot")
    light("POINT", (5.0, width / 2, h - 0.2), 6, (0.75, 1.0, 0.85), size=0.1, name="dim_hublot")
    # Signs of life: a tricycle, a dead plant, a bin bag, a child's drawing.
    box("tri_seat", 4.2, 1.2, 0.3, 4.5, 1.4, 0.35, m["toy"])
    box("tri_bar", 4.5, 1.28, 0.1, 4.7, 1.32, 0.5, m["steel"])
    box("tri_wheel", 4.7, 1.27, 0, 4.72, 1.33, 0.3, m["dark"])
    box("pot", 7.4, 1.45, 0, 7.7, 1.75, 0.35, m["plastic"])
    box("plant", 7.5, 1.55, 0.35, 7.6, 1.65, 0.8, m["tag"])
    box("bag", 11.0, 0.15, 0, 11.4, 0.55, 0.4, m["dark"])
    box("drawing", 3.0, width - 0.01, 1.3, 3.3, width, 1.7, m["paper"])
    tags(m, rng, width, 7.0, 9.0, 0.3, 1.0, 2, facing=-1)
    scatter_papers(m, rng, 1.0, 13.0, 0.3, 1.5, 8)
    fog(0, 0, 0, length, width, h, 0.035)
    camera((0.4, width / 2 - 0.2, 1.6), (13.0, width / 2 + 0.2, 1.1), lens=18)


def salon(m):
    rng = random.Random(81)
    w, d, h = 5.0, 4.2, 2.5
    box("floor", 0, 0, -0.1, w, d, 0, m["parquet"], meters=1.0)
    box("ceil", 0, 0, h, w, d, h + 0.1, m["ceiling"], meters=1.2)
    box("wall_back", 0, d, 0, w, d + 0.1, h, m["wallpaper"], meters=1.0)
    box("wall_left", -0.1, 0, 0, 0, d, h, m["wallpaper"], meters=1.0)
    box("wall_right", w, 0, 0, w + 0.1, d, h, m["wallpaper"], meters=1.0)
    box("skirting", 0, d - 0.02, 0, w, d, 0.1, m["wood_door"])
    # Window on the back wall, sodium street light behind net curtains.
    box("win_hole", 2.9, d, 0.9, 4.4, d + 0.1, 2.2, m["dark"])
    window(m, 2.9, d - 0.02, 0.9, 4.4, 2.2)
    light("AREA", (3.65, d + 0.6, 1.6), 40, (1.0, 0.62, 0.3), size=1.4, name="sodium")
    box("curtain_l", 2.6, d - 0.12, 0.05, 2.9, d - 0.08, 2.35, m["blanket"])
    # Sofa with a blanket, facing the TV on the right wall.
    box("sofa_base", 0.2, 1.2, 0, 1.1, 3.4, 0.42, m["fabric"])
    box("sofa_back", 0.0, 1.2, 0, 0.3, 3.4, 0.9, m["fabric"])
    box("sofa_arm", 0.0, 1.0, 0, 1.1, 1.2, 0.62, m["fabric"])
    box("sofa_arm2", 0.0, 3.4, 0, 1.1, 3.6, 0.62, m["fabric"])
    box("blanket", 0.3, 2.3, 0.42, 1.0, 3.2, 0.48, m["blanket"], rot_z=0.2)
    box("cushion", 0.5, 1.4, 0.42, 0.8, 1.8, 0.6, m["blanket"], rot_z=-0.3)
    # Coffee table: ashtray, bottles, a plate.
    box("table", 1.6, 1.8, 0.4, 2.5, 2.8, 0.45, m["wood_door"])
    for tx, ty in ((1.65, 1.85), (2.4, 1.85), (1.65, 2.7), (2.4, 2.7)):
        box("leg", tx, ty, 0, tx + 0.05, ty + 0.05, 0.4, m["wood_door"])
    box("ashtray", 1.8, 2.0, 0.45, 1.95, 2.15, 0.48, m["glass"] if "glass" in m else m["steel"])
    for bx, by in ((2.2, 2.4), (2.3, 2.5)):
        box("bottle", bx, by, 0.45, bx + 0.07, by + 0.07, 0.75, m["window_dark"])
    box("bottle_down", 2.6, 1.2, 0, 2.9, 1.27, 0.07, m["window_dark"], rot_z=0.8)
    # TV on a cabinet against the right wall: snow, the only light in the room.
    box("cabinet", w - 0.5, 1.5, 0, w, 3.0, 0.55, m["wood_door"])
    box("tv_box", w - 0.55, 1.85, 0.55, w - 0.05, 2.6, 1.05, m["plastic"])
    box("tv_screen", w - 0.56, 1.92, 0.6, w - 0.55, 2.53, 1.0, m["tv"])
    light("AREA", (w - 0.6, 2.22, 0.8), 30, (0.55, 0.65, 1.0), size=0.5, name="tv").rotation_euler = (0, math.pi / 2, 0)
    # Life left behind: photos, a clock, a calendar, a sideboard with plates.
    for i, (px, pz) in enumerate(((0.6, 1.5), (1.1, 1.6), (0.85, 1.95), (1.5, 1.45))):
        box("frame", px, d - 0.03, pz, px + 0.3, d, pz + 0.38, m["wood_door"])
        box("photo", px + 0.04, d - 0.035, pz + 0.04, px + 0.26, d - 0.03, pz + 0.34, m["photo"])
    box("frame_fallen", 1.2, d - 0.4, 0, 1.5, d - 0.36, 0.38, m["photo"], rot_z=0.3)
    box("clock", 2.1, d - 0.03, 1.9, 2.4, d, 2.2, m["white"])
    box("calendar", -0.0, 0.5, 1.2, 0.01, 0.85, 1.7, m["paper"])
    box("sideboard", -0.0, 0.1, 0, 0.45, 0.9, 0.9, m["wood_door"])
    for i in range(4):
        box("plate", 0.1 + 0.02 * i, 0.2 + 0.15 * i, 0.9, 0.12 + 0.02 * i, 0.32 + 0.15 * i, 1.15, m["white"])
    # A toy truck on the floor and papers scattered: people left in a hurry.
    box("toy", 3.2, 1.0, 0, 3.45, 1.15, 0.12, m["toy"], rot_z=0.6)
    box("teddy", 3.9, 0.7, 0, 4.15, 0.9, 0.28, m["blanket"])
    scatter_papers(m, rng, 1.3, 4.0, 0.6, 3.5, 6)
    # Ceiling lamp, dead.
    box("lamp_wire", 2.5, 2.1, 2.1, 2.52, 2.12, h, m["dark"])
    box("lamp_shade", 2.3, 1.9, 1.95, 2.72, 2.32, 2.1, m["blanket"])
    # Left in a hurry: a chair on its back, a mattress dragged in, torn strips.
    box("chair_down", 3.4, 2.4, 0, 3.85, 2.85, 0.06, m["wood_door"], rot_z=0.4)
    box("chair_down_back", 3.4, 2.85, 0, 3.85, 3.3, 0.05, m["wood_door"], rot_z=0.4, pivot=(3.62, 2.62))
    box("mattress", 1.4, 3.1, 0, 3.2, 4.0, 0.18, m["sheet"], rot_z=-0.15)
    for i, sx in enumerate((0.9, 2.55, 4.6)):
        box("strip", sx, d - 0.04 - 0.05 * i, 1.0 + 0.2 * i, sx + 0.25, d - 0.02 - 0.05 * i, h - 0.05, m["wallpaper"], rot_z=0.15 * (i - 1))
    fog(0, 0, 0, w, d, h, 0.03)
    camera((2.6, 0.2, 1.6), (2.5, 4.0, 0.9), lens=14)


def cuisine(m):
    rng = random.Random(91)
    w, d, h = 3.2, 2.8, 2.5
    box("floor", 0, 0, -0.1, w, d, 0, m["lino"], meters=0.6)
    box("ceil", 0, 0, h, w, d, h + 0.1, m["ceiling"])
    box("wall_back", 0, d, 0, w, d + 0.1, h, m["wallpaper2"], meters=1.0)
    box("splash", 0, d - 0.01, 0.9, w, d, 1.5, m["faience"], meters=0.6)
    box("wall_left", -0.1, 0, 0, 0, d, h, m["wallpaper2"], meters=1.0)
    box("wall_right", w, 0, 0, w + 0.1, d, h, m["wallpaper2"], meters=1.0)
    box("splash_r", w - 0.01, 0.8, 0.9, w, d, 1.5, m["faience"], meters=0.6)
    # Worktop along the back wall: sink full of dishes, cooker, cupboards above.
    box("units", 0.0, d - 0.6, 0, 2.4, d, 0.86, m["formica"])
    box("worktop", 0.0, d - 0.62, 0.86, 2.4, d, 0.9, m["white"])
    box("sink", 0.5, d - 0.5, 0.8, 1.1, d - 0.1, 0.9, m["steel"])
    for i in range(5):
        box("dish", 0.55 + i * 0.1, d - 0.45 + rng.uniform(0, 0.2), 0.88, 0.75 + i * 0.1, d - 0.25, 0.9 + i * 0.025, m["white"])
    box("tap", 0.78, d - 0.12, 0.9, 0.82, d - 0.08, 1.2, m["steel"])
    box("cooker", 1.5, d - 0.58, 0.9, 2.1, d - 0.02, 0.92, m["dark"])
    box("pan", 1.6, d - 0.5, 0.92, 1.85, d - 0.25, 1.02, m["steel"])
    box("cupboards", 0.0, d - 0.35, 1.6, 2.4, d, 2.3, m["formica"])
    box("cupboard_open", 1.2, d - 0.75, 1.6, 1.22, d - 0.35, 2.3, m["formica"])
    box("cupboard_void", 0.8, d - 0.36, 1.62, 1.2, d - 0.35, 2.28, m["dark"])
    # The fridge, door open, its light the only one in the kitchen.
    box("fridge", w - 0.65, d - 0.65, 0, w, d, 1.7, m["white"])
    box("fridge_in", w - 0.6, d - 0.66, 0.1, w - 0.05, d - 0.65, 1.6, m["fridge_in"])
    box("fridge_door", w - 0.06, d - 1.3, 0.0, w - 0.01, d - 0.66, 1.7, m["white"])
    light("AREA", (w - 0.33, d - 0.75, 1.0), 25, (0.8, 0.95, 1.0), size=0.5, name="fridge").rotation_euler = (-math.pi / 2, 0, 0)
    # Table with an oilcloth, two chairs, one knocked over, bowls still there.
    box("table", 0.3, 0.6, 0.72, 1.4, 1.4, 0.76, m["oilcloth"])
    box("cloth_drop", 0.28, 0.58, 0.55, 1.42, 0.6, 0.76, m["oilcloth"])
    box("table_leg", 0.8, 0.95, 0, 0.9, 1.05, 0.72, m["steel"])
    for bx in (0.5, 1.0):
        box("bowl", bx, 0.9, 0.76, bx + 0.16, 1.06, 0.82, m["white"])
    box("chair", 0.4, 0.05, 0, 0.8, 0.45, 0.45, m["formica"])
    box("chair_back", 0.4, 0.05, 0.45, 0.8, 0.09, 0.9, m["formica"])
    box("chair_down", 1.5, 0.3, 0, 1.92, 0.72, 0.06, m["formica"], rot_z=0.9)
    box("chair_down_back", 1.5, 0.72, 0, 1.92, 1.15, 0.05, m["formica"], rot_z=0.9, pivot=(1.71, 0.51))
    # Window on the left wall, a calendar, a child's drawing on the fridge.
    box("calendar", w - 0.01, 0.4, 1.3, w, 0.7, 1.75, m["paper"])
    box("drawing", w - 0.67, d - 1.0, 1.1, w - 0.66, d - 0.75, 1.4, m["paper"])
    box("win_hole", -0.1, 0.7, 1.0, -0.02, 1.8, 2.1, m["sodium_glass"])
    box("win_net", -0.02, 0.72, 1.05, 0.0, 1.78, 2.05, m["net"])
    light("AREA", (-0.3, 1.25, 1.8), 6, (1.0, 0.62, 0.3), size=1.0, name="sodium").rotation_euler = (0, -math.pi / 2, 0)
    box("tube_dead", 1.0, 1.2, h - 0.05, 2.2, 1.32, h - 0.01, m["neon_dead"])
    light("POINT", (1.2, 0.8, 2.2), 1.5, (0.55, 1.0, 0.7), name="fill")
    fog(0, 0, 0, w, d, h, 0.03)
    camera((0.5, 0.15, 1.6), (2.0, 2.6, 0.9), lens=16)


SCENES = {"hall": hall, "escalier": escalier, "palier": palier, "salon": salon, "cuisine": cuisine}


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = argv[0] if argv else "."
    names = argv[1:] or list(SCENES)
    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        sc = reset()
        SCENES[name](hlm_materials(common()))
        sc.render.filepath = os.path.join(out_dir, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", sc.render.filepath)


if __name__ == "__main__":
    main()
