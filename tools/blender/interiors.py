"""Builds the furniture and the doors of the building interiors (S-016, T-240).

Flats of the tower:
- "bed": a 2 x 1.4 m double bed, bare stained mattress, a thrown blanket,
- "sofa": a worn three-seat sofa (2.1 m),
- "kitchen_table": a 1.2 x 0.8 m table and two chairs pushed back,
- "fridge": a tall fridge, its door left wide open,
- "boxes": a stack of moving boxes, one fallen,
Social centre:
- "chairs_stacked": two stacks of plastic chairs,
- "stage_curtain": a 2.6 m length of heavy stage curtain, hanging from its rail,
- "oven": a professional kitchen range with its hood,
- "cold_cabinet": the stainless walk-in cold cabinet of the kitchen (hiding spot),
Gallery:
- "counter": a 2 m shop counter, laminate top, a till,
- "shelves": 2 m of metal shelving with a few boxes and tins left,
- "shop_pharmacie", "shop_tabac", "shop_boulangerie": the 8.4 m fronts of the
  three shops that S-016 opened (a door, a shutter to roll up, a door with a bell),
Tower and car park:
- "lift_doors": the closed stainless doors of the dead lift, in their frame,
Doors (S-016, Q1): leaves 1 m wide and 2.4 m high, scaled to their doorway:
- "door_leaf": a painted flat door, a handle each side,
- "fire_door_leaf": a heavy grey-green fire door, wired glass, a push plate,
- "emergency_leaf": the same with its green sign and crash bar,
- "shutter_leaf": a metal roller shutter, 1 m of it.
Dull colors only: orange is the noise color (constitution 2.3).
Same conventions and helpers as gallery.py: furniture is centred on its
footprint, its front toward -Y, its bottom at z = 0. Door leaves are centred
(x and z) like the leaf of game/entities/door. Shop fronts have their origin
at the bottom-left corner of the outer face like the gallery modules, x
running east to west as seen from the arcade.
    python tools/blender/interiors.py -- <out.blend> <out_dir>
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import (  # noqa: E402
    FONT,
    SHOP_HEIGHT,
    SHOP_WIDTH,
    SHUTTER_TEXTURE,
    Model,
    _image,
    _tags,
    concrete_texture,
    frame_texture,
    glass_texture,
    material,
    shutter_texture,
    sign_texture,
    triangle_count,
)

LEAF = (1.0, 2.4, 0.06)  # Width, height, thickness (DoorSettings.leaf_thickness).
DOOR_TOP = 2.4
# Openings of the three shop fronts, measured from the east end of the shop
# (build_tilleuls.gd, GALLERY_FRONTS), and the top of the opening.
PHARMACIE_DOOR = (6.4, 7.6)
TABAC_SHUTTER = (2.4, 6.4)
BOULANGERIE_DOOR = (5.2, 6.4)
GLASS_BOTTOM = 0.5
HOUSING = 2.7

FONT.update({
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
})


# --- Textures ----------------------------------------------------------------


def _noisy(name, base, spread, seed, size=32, stains=0.0, stain=(0.0, 0.0, 0.0)):
    rng = random.Random(seed)

    def shade(x, y):
        if rng.random() < stains:
            return list(stain)
        n = rng.uniform(-spread, spread)
        return [max(0.0, c + n) for c in base]

    return _image(name, size, size, shade)


def fabric_texture(name, base, seed):
    """Woven cloth: a fine cross pattern, worn patches, a few stains."""
    rng = random.Random(seed)
    worn = {(rng.randrange(32), rng.randrange(32)) for _ in range(40)}

    def shade(x, y):
        k = 0.92 if (x + y) % 2 else 1.0
        if (x, y) in worn or (x - 1, y) in worn:
            k *= 1.15
        if rng.random() < 0.02:
            k *= 0.7
        return [c * k for c in base]

    return _image(name, 32, 32, shade)


def wood_texture():
    rng = random.Random(51)

    def shade(x, y):
        grain = 0.04 * math.sin(y * 0.9 + math.sin(x * 0.3) * 2.0)
        g = 0.36 + grain + rng.uniform(-0.02, 0.02)
        return [g, g * 0.78, g * 0.55]

    return _image("interior_wood_tex", 32, 32, shade)


def mattress_texture():
    """Ticking stripes, yellowed, a big brown stain."""
    def shade(x, y):
        c = [0.62, 0.6, 0.52] if x % 6 else [0.42, 0.46, 0.5]
        if math.hypot(x - 20, y - 12) < 7 + 2 * math.sin(x):
            c = [c[0] * 0.7, c[1] * 0.62, c[2] * 0.5]
        return c

    return _image("interior_mattress_tex", 32, 32, shade)


def cardboard_texture():
    rng = random.Random(52)

    def shade(x, y):
        if 14 <= y <= 17:
            return [0.55, 0.5, 0.4]  # Tape.
        g = rng.uniform(-0.03, 0.03)
        return [0.45 + g, 0.34 + g, 0.22 + g]

    return _image("interior_cardboard_tex", 32, 32, shade)


def steel_texture():
    """Brushed stainless: horizontal streaks, dents, fingerprints."""
    rng = random.Random(53)
    rows = [rng.uniform(-0.04, 0.04) for _ in range(64)]

    def shade(x, y):
        g = 0.55 + rows[y] + rng.uniform(-0.02, 0.02)
        return [g, g, g * 1.02]

    return _image("interior_steel_tex", 64, 64, shade)


def lift_texture():
    """Stainless doors, scratched and tagged, a dark gap in the middle."""
    rng = random.Random(54)
    tags = _tags(rng, 128, 128, 2)
    rows = [rng.uniform(-0.04, 0.04) for _ in range(128)]

    def shade(x, y):
        if 63 <= x <= 64:
            return [0.05, 0.05, 0.05]
        if (x, y) in tags:
            return tags[(x, y)]
        g = 0.5 + rows[y] + rng.uniform(-0.02, 0.02)
        if rng.random() < 0.004:
            g += 0.2  # Scratch.
        return [g, g, g * 1.02]

    return _image("interior_lift_tex", 128, 128, shade)


def door_texture():
    """A flat door painted dull beige, grimy round the handle and at the foot."""
    rng = random.Random(55)

    def shade(x, y):
        g = rng.uniform(-0.02, 0.02)
        c = [0.55 + g, 0.52 + g, 0.43 + g]
        k = 0.75 + 0.25 * min(1.0, y / 12.0)
        if 22 <= x <= 30 and 60 <= y <= 74:
            k *= 0.85
        if x < 1 or x > 30 or y > 125:
            k *= 0.8
        return [v * k for v in c]

    return _image("interior_door_tex", 32, 128, shade)


def fire_door_texture(emergency):
    """Grey-green metal door, a wired glass window, the sign of its kind."""
    rng = random.Random(56 + emergency)
    sign = set()
    if emergency:  # Little running man, white on green, over the bar.
        for x in range(8, 24):
            for y in range(82, 92):
                sign.add((x, y))

    def shade(x, y):
        if (x, y) in sign:
            if 13 <= x <= 18 and 84 <= y <= 90 and (x + y) % 3:
                return [0.85, 0.88, 0.85]
            return [0.08, 0.38, 0.2]
        if 10 <= x <= 21 and 96 <= y <= 118:  # Wired glass.
            if x % 4 == 0 or y % 4 == 0:
                return [0.32, 0.33, 0.32]
            return [0.1, 0.13, 0.15]
        g = rng.uniform(-0.02, 0.02)
        k = 0.8 + 0.2 * min(1.0, y / 14.0)
        return [(0.36 + g) * k, (0.41 + g) * k, (0.37 + g) * k]

    return _image("interior_fire_door_%d_tex" % emergency, 32, 128, shade)


def curtain_texture():
    """Heavy velvet, dull burgundy, vertical folds, dusty at the hem."""
    def shade(x, y):
        fold = 0.75 + 0.25 * math.sin(x * 0.8)
        dust = 1.0 + 0.3 * max(0.0, 1.0 - y / 10.0)
        return [0.3 * fold * dust, 0.07 * fold * dust, 0.09 * fold * dust]

    return _image("interior_curtain_tex", 32, 64, shade)


def plastic_texture():
    return _noisy("interior_plastic_tex", (0.24, 0.3, 0.36), 0.02, 57, 8)


def laminate_texture():
    return _noisy("interior_laminate_tex", (0.6, 0.58, 0.52), 0.02, 58, 16, 0.03, (0.4, 0.38, 0.33))


def enamel_texture():
    return _noisy("interior_enamel_tex", (0.7, 0.7, 0.66), 0.015, 59, 16, 0.02, (0.5, 0.48, 0.42))


def tin_texture():
    rng = random.Random(60)
    colors = ((0.5, 0.15, 0.13), (0.2, 0.3, 0.45), (0.6, 0.6, 0.55), (0.25, 0.35, 0.2))
    return _image("interior_tin_tex", 16, 16, lambda x, y: list(colors[(x // 4 + y // 8) % 4]) if y % 8 else [0.5] * 3)


def mats():
    green = (0.08, 0.38, 0.2)
    return {
        "wood": material("interior_wood_mat", wood_texture()),
        "mattress": material("interior_mattress_mat", mattress_texture()),
        "blanket": material("interior_blanket_mat", fabric_texture("interior_blanket_tex", (0.22, 0.26, 0.3), 61)),
        "sofa": material("interior_sofa_mat", fabric_texture("interior_sofa_tex", (0.3, 0.32, 0.22), 62)),
        "cardboard": material("interior_cardboard_mat", cardboard_texture()),
        "steel": material("interior_steel_mat", steel_texture()),
        "enamel": material("interior_enamel_mat", enamel_texture()),
        "dark": material("interior_dark_mat", _image("interior_dark_tex", 4, 4, lambda x, y: [0.06, 0.06, 0.065])),
        "lift": material("interior_lift_mat", lift_texture()),
        "door": material("interior_door_mat", door_texture()),
        "fire_door": material("interior_fire_door_mat", fire_door_texture(0)),
        "emergency": material("interior_emergency_mat", fire_door_texture(1)),
        "curtain": material("interior_curtain_mat", curtain_texture()),
        "plastic": material("interior_plastic_mat", plastic_texture()),
        "laminate": material("interior_laminate_mat", laminate_texture()),
        "tins": material("interior_tin_mat", tin_texture()),
        "shutter": material("gallery_shutter_mat", shutter_texture()),
        "concrete": material("gallery_concrete_mat", concrete_texture()),
        "frame": material("gallery_frame_mat", frame_texture()),
        "glass": material("gallery_glass_mat", glass_texture(False)),
        "pharmacie": material(
            "interior_sign_pharmacie_mat",
            sign_texture("interior_sign_pharmacie_tex", "PHARMACIE", [0.8, 0.9, 0.82], [0.06, 0.2, 0.12], 384),
            emission=0.3,
        ),
        "cross": material("interior_cross_mat", _image("interior_cross_tex", 4, 4, lambda x, y: list(green)), 0.6),
        "tabac": material(
            "interior_sign_tabac_mat",
            sign_texture("interior_sign_tabac_tex", "TABAC", [0.85, 0.82, 0.75], [0.12, 0.14, 0.2], 96),
        ),
        "carotte": material("interior_carotte_mat", _image("interior_carotte_tex", 4, 4, lambda x, y: [0.42, 0.08, 0.08])),
        "boulangerie": material(
            "interior_sign_boulangerie_mat",
            sign_texture("interior_sign_boulangerie_tex", "BOULANGERIE", [0.8, 0.72, 0.55], [0.18, 0.12, 0.1], 320),
        ),
    }


# --- Flats -------------------------------------------------------------------


def bed(k):
    m = Model("bed")
    m.box(-0.75, -1.05, 0.0, 0.75, 1.05, 0.3, k["wood"])  # Frame.
    m.box(-0.72, 0.95, 0.3, 0.72, 1.05, 0.9, k["wood"])  # Headboard.
    m.box(-0.7, -1.0, 0.3, 0.7, 0.95, 0.5, k["mattress"], stretch=True)
    m.box(-0.72, -0.95, 0.5, 0.35, 0.1, 0.56, k["blanket"])  # Thrown blanket.
    m.box(0.1, -0.2, 0.5, 0.72, 0.4, 0.58, k["blanket"])
    m.box(-0.6, 0.55, 0.5, 0.0, 0.9, 0.62, k["mattress"], meters=0.5)  # Pillow.
    return m


def sofa(k):
    m = Model("sofa")
    m.box(-1.05, -0.45, 0.08, 1.05, 0.45, 0.42, k["sofa"])  # Seat base.
    m.box(-1.05, 0.2, 0.42, 1.05, 0.45, 0.85, k["sofa"])  # Back.
    for x in (-1.05, 0.85):
        m.box(x, -0.45, 0.42, x + 0.2, 0.2, 0.62, k["sofa"])  # Arms.
    for i, x in enumerate((-0.85, -0.28, 0.29)):  # Cushions, the middle one sunk.
        m.box(x, -0.42, 0.42, x + 0.56, 0.2, 0.52 - 0.04 * (i == 1), k["sofa"])
    for x in (-1.0, 0.95):
        for y in (-0.4, 0.35):
            m.box(x, y, 0.0, x + 0.05, y + 0.05, 0.08, k["dark"])
    return m


def _chair(m, k, x, y, mat):
    m.box(x - 0.2, y - 0.2, 0.43, x + 0.2, y + 0.2, 0.47, mat)
    m.box(x - 0.2, y + 0.16, 0.47, x + 0.2, y + 0.2, 0.88, mat)
    for dx in (-0.19, 0.16):
        for dy in (-0.19, 0.16):
            m.box(x + dx, y + dy, 0.0, x + dx + 0.03, y + dy + 0.03, 0.43, k["frame"])


def kitchen_table(k):
    m = Model("kitchen_table")
    m.box(-0.6, -0.4, 0.72, 0.6, 0.4, 0.76, k["laminate"])
    for x in (-0.56, 0.52):
        for y in (-0.36, 0.32):
            m.box(x, y, 0.0, x + 0.04, y + 0.04, 0.72, k["frame"])
    _chair(m, k, -0.3, -0.7, k["wood"])
    _chair(m, k, 0.85, 0.1, k["wood"])
    return m


def fridge(k):
    m = Model("fridge")
    m.box(-0.3, -0.3, 0.0, 0.3, 0.32, 1.75, k["enamel"])
    m.box(-0.28, -0.32, 0.05, 0.28, -0.3, 1.7, k["dark"])  # Dark inside, the door open.
    m.box(-0.24, -0.28, 0.4, 0.24, 0.26, 0.42, k["frame"])  # Shelves, empty.
    m.box(-0.24, -0.28, 0.9, 0.24, 0.26, 0.92, k["frame"])
    m.box(0.25, -0.9, 0.02, 0.3, -0.3, 1.73, k["enamel"])  # The door, swung wide.
    m.box(0.3, -0.85, 1.2, 0.32, -0.82, 1.5, k["frame"])  # Handle.
    return m


def boxes(k):
    m = Model("boxes")
    m.box(-0.5, -0.3, 0.0, 0.1, 0.3, 0.45, k["cardboard"], meters=0.6)
    m.box(-0.45, -0.25, 0.45, 0.05, 0.25, 0.8, k["cardboard"], meters=0.6)
    m.box(0.15, -0.25, 0.0, 0.6, 0.25, 0.4, k["cardboard"], meters=0.6)
    # The fallen one, on its side, its flaps open.
    m.box(0.2, -0.75, 0.0, 0.7, -0.35, 0.35, k["cardboard"], meters=0.6)
    m.box(0.2, -0.95, 0.33, 0.7, -0.75, 0.35, k["cardboard"], meters=0.6)
    return m


# --- Social centre -----------------------------------------------------------


def chairs_stacked(k):
    m = Model("chairs_stacked")
    for sx in (-0.3, 0.32):
        _chair(m, k, sx, 0.0, k["plastic"])
        for i in range(1, 7 if sx < 0 else 4):
            z = i * 0.07
            m.box(sx - 0.2, -0.2, 0.43 + z, sx + 0.2, 0.2, 0.47 + z, k["plastic"])
            m.box(sx - 0.2, 0.16 + z * 0.15, 0.47 + z, sx + 0.2, 0.2 + z * 0.15, 0.88 + z, k["plastic"])
    return m


def stage_curtain(k):
    m = Model("stage_curtain")
    m.box(-1.35, -0.05, 3.2, 1.35, 0.05, 3.26, k["frame"])  # Rail.
    for i in range(10):  # Folds: alternate depths.
        x = -1.3 + i * 0.26
        y = 0.04 if i % 2 else -0.04
        m.box(x, y - 0.05, 0.0, x + 0.26, y + 0.05, 3.2, k["curtain"], meters=(1.0, 3.2))
    return m


def oven(k):
    m = Model("oven")
    m.box(-0.6, -0.4, 0.0, 0.6, 0.4, 0.9, k["steel"])
    for x in (-0.55, 0.05):
        m.box(x, -0.42, 0.15, x + 0.5, -0.4, 0.7, k["dark"])  # Oven doors.
        m.box(x + 0.05, -0.46, 0.62, x + 0.45, -0.42, 0.64, k["frame"])  # Handles.
    for x in (-0.4, 0.15):
        for y in (-0.25, 0.1):
            m.box(x, y, 0.9, x + 0.25, y + 0.2, 0.93, k["dark"])  # Burners.
    m.box(-0.6, 0.36, 0.9, 0.6, 0.4, 1.9, k["steel"])  # Splashback.
    m.box(-0.7, -0.3, 1.9, 0.7, 0.4, 2.3, k["steel"])  # Hood.
    m.box(-0.2, 0.0, 2.3, 0.2, 0.4, 2.8, k["steel"])
    return m


def cold_cabinet(k):
    m = Model("cold_cabinet")
    m.box(-0.75, -0.4, 0.0, 0.75, 0.4, 2.1, k["steel"])
    m.box(-0.72, -0.42, 0.08, -0.01, -0.4, 2.0, k["steel"])
    m.box(0.01, -0.42, 0.08, 0.72, -0.4, 2.0, k["steel"])
    for x in (-0.12, 0.08):
        m.box(x, -0.48, 0.9, x + 0.04, -0.42, 1.4, k["frame"])
    m.box(-0.3, -0.43, 1.75, 0.3, -0.42, 1.9, k["dark"])  # Thermometer panel.
    return m


# --- Gallery -----------------------------------------------------------------


def counter(k):
    m = Model("counter")
    m.box(-1.0, -0.35, 0.0, 1.0, 0.35, 0.95, k["laminate"])
    m.box(-1.05, -0.4, 0.95, 1.05, 0.4, 1.0, k["wood"])
    m.box(0.4, -0.1, 1.0, 0.8, 0.25, 1.15, k["dark"])  # Till.
    m.box(0.45, 0.15, 1.15, 0.75, 0.2, 1.35, k["dark"])
    return m


def shelves(k):
    m = Model("shelves")
    for x in (-1.0, 0.97):
        m.box(x, -0.25, 0.0, x + 0.03, 0.25, 1.9, k["frame"])
    rng = random.Random(70)
    for z in (0.1, 0.55, 1.0, 1.45, 1.87):
        m.box(-1.0, -0.25, z, 1.0, 0.25, z + 0.03, k["frame"])
        x = -0.95
        while x < 0.85:  # What is left: tins and a few boxes, gaps.
            w = rng.choice((0.08, 0.08, 0.25))
            if rng.random() < 0.55:
                mat = k["tins"] if w < 0.1 else k["cardboard"]
                m.box(x, -0.2, z + 0.03, x + w, 0.15, z + 0.03 + (0.12 if w < 0.1 else 0.25), mat, meters=0.5)
            x += w + 0.03
    return m


def _front(m, k, opening, top):
    """Concrete piers and fascia, glass on both sides of an opening (x from the east end)."""
    a, b = opening
    m.box(0.0, -0.05, SHOP_HEIGHT - 0.1, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(0.0, -0.08, 0.0, 0.6, 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(7.8, -0.08, 0.0, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])
    for x0, x1 in ((0.6, a), (b, 7.8)):
        if x1 - x0 < 0.1:
            continue
        m.box(x0, -0.08, 0.0, x1, 0.0, GLASS_BOTTOM, k["concrete"])
        m.box(x0, -0.06, GLASS_BOTTOM, x1, -0.04, HOUSING, k["glass"], stretch=True)
        for x in (x0, x1):
            m.box(x - 0.04, -0.09, GLASS_BOTTOM, x + 0.04, -0.03, HOUSING, k["frame"])
        m.box(x0, -0.09, GLASS_BOTTOM - 0.04, x1, -0.03, GLASS_BOTTOM + 0.04, k["frame"])
    m.box(0.6, -0.09, HOUSING - 0.04, 7.8, -0.03, HOUSING, k["frame"])
    for x in (a, b):  # Door frame.
        m.box(x - 0.06, -0.1, 0.0, x + 0.06, -0.02, top, k["frame"])
    m.box(a, -0.1, top, b, -0.02, top + 0.08, k["frame"])
    if top + 0.08 < HOUSING:
        m.box(a, -0.06, top + 0.08, b, -0.04, HOUSING, k["glass"], stretch=True)


def _sign(m, k, sign, x0=1.0, x1=7.4):
    m.box(x0, -0.25, HOUSING, x1, -0.05, SHOP_HEIGHT - 0.1, k["frame"])
    m.box(x0, -0.26, HOUSING, x1, -0.25, SHOP_HEIGHT - 0.1, k[sign], stretch=True)


def shop_pharmacie(k):
    m = Model("shop_pharmacie")
    _front(m, k, PHARMACIE_DOOR, DOOR_TOP)
    _sign(m, k, "pharmacie", 1.0, 6.0)
    # The green cross on its bracket, sticking out over the arcade.
    m.box(6.85, -0.6, 2.85, 6.95, 0.0, 2.9, k["frame"])
    m.box(6.85, -0.75, 2.5, 6.95, -0.45, 3.3, k["cross"])
    m.box(6.85, -1.0, 2.75, 6.95, -0.2, 3.05, k["cross"])
    return m


def shop_tabac(k):
    m = Model("shop_tabac")
    a, b = TABAC_SHUTTER
    _front(m, k, TABAC_SHUTTER, DOOR_TOP)
    m.box(a - 0.1, -0.3, DOOR_TOP + 0.08, b + 0.1, -0.02, HOUSING, k["shutter"])  # Shutter box.
    for x in (a, b):
        m.box(x - 0.1, -0.14, 0.0, x + 0.02, -0.02, DOOR_TOP, k["frame"])  # Rails.
    _sign(m, k, "tabac", 6.6, 7.7)
    # The red diamond ("carotte"), hanging under its bracket.
    m.box(1.25, -0.6, 2.95, 1.35, 0.0, 3.0, k["frame"])
    m.box(1.25, -0.7, 2.35, 1.35, -0.5, 2.95, k["carotte"])
    m.box(1.25, -0.8, 2.55, 1.35, -0.4, 2.75, k["carotte"])
    return m


def shop_boulangerie(k):
    m = Model("shop_boulangerie")
    _front(m, k, BOULANGERIE_DOOR, DOOR_TOP)
    _sign(m, k, "boulangerie", 0.8, 5.0)
    a, b = BOULANGERIE_DOOR
    m.box((a + b) / 2 - 0.05, -0.25, DOOR_TOP - 0.15, (a + b) / 2 + 0.05, -0.1, DOOR_TOP - 0.02, k["steel"])  # Bell.
    return m


# --- Lift and doors ----------------------------------------------------------


def lift_doors(k):
    m = Model("lift_doors")
    m.box(-0.6, -0.04, 0.0, 0.6, 0.0, 2.1, k["lift"], stretch=True)
    for x in (-0.75, 0.6):
        m.box(x, -0.08, 0.0, x + 0.15, 0.0, 2.25, k["steel"])
    m.box(-0.75, -0.08, 2.1, 0.75, 0.0, 2.25, k["steel"])
    m.box(0.8, -0.05, 1.0, 0.92, 0.0, 1.25, k["dark"])  # Dead call button.
    return m


def _leaf(name, mat, k, handle=True, bar=False):
    m = Model(name)
    w, h, t = LEAF
    m.box(-w / 2, -t / 2, -h / 2, w / 2, t / 2, h / 2, mat, stretch=True)
    for side in (-1, 1):
        y = side * (t / 2 + 0.04)
        if handle:
            m.box(0.32, min(y, side * t / 2), -0.15, 0.42, max(y, side * t / 2), -0.12, k["steel"])
        if bar and side < 0:  # Crash bar across the inside face.
            m.box(-0.4, y - 0.02, -0.18, 0.4, y + 0.02, -0.12, k["steel"])
            for x in (-0.42, 0.38):
                m.box(x, y, -0.2, x + 0.04, -t / 2, -0.1, k["steel"])
    return m


def door_leaf(k):
    return _leaf("door_leaf", k["door"], k)


def fire_door_leaf(k):
    return _leaf("fire_door_leaf", k["fire_door"], k)


def emergency_leaf(k):
    return _leaf("emergency_leaf", k["emergency"], k, handle=False, bar=True)


def shutter_leaf(k):
    m = Model("shutter_leaf")
    w, h, t = LEAF
    m.box(-w / 2, -t / 4, -h / 2, w / 2, t / 4, h / 2, k["shutter"], meters=SHUTTER_TEXTURE)
    m.box(-w / 2, -t / 2, -h / 2, w / 2, t / 2, -h / 2 + 0.05, k["frame"])  # Bottom bar.
    return m


BUILDERS = (
    bed, sofa, kitchen_table, fridge, boxes,
    chairs_stacked, stage_curtain, oven, cold_cabinet,
    counter, shelves, shop_pharmacie, shop_tabac, shop_boulangerie,
    lift_doors, door_leaf, fire_door_leaf, emergency_leaf, shutter_leaf,
)


if __name__ == "__main__":
    for obj in list(bpy.data.objects):  # The default scene.
        bpy.data.objects.remove(obj)
    k = mats()
    objects = []
    x = 0.0
    for builder in BUILDERS:
        model = builder(k)
        objects.append(model.build(offset_x=x))
        x += 10.0
    for obj in objects:
        print("TRIANGLES", obj.name, triangle_count(obj))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        for obj in objects:
            for other in objects:
                other.select_set(other == obj)
            x = obj.location.x
            obj.location.x = 0.0
            path = os.path.join(args[1], obj.name + ".glb")
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True)
            obj.location.x = x
