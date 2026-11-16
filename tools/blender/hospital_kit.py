"""Builds the models of the hospital of the cité des Tilleuls (S-014, T-189).

From the mood renders of hospital_mood.py, the props the hospital needs:
- "gurney": a steel stretcher on four casters, a thin stained mattress, a
  crumpled sheet, its push handle at the head (+Y here, Godot -Z): the
  Gurney scene's 0.7 x 0.85 x 2 m,
- "wheelchair": an old folding chair, black canvas, two big wheels, two
  casters in front (+Y here, Godot -Z): the Wheelchair scene's 0.6 x 0.9 x 0.7 m,
- "monitor": a patient monitor on a rolling stand, its leads hanging; the
  screen stays a quad of the Monitor scene (it lights up when it beeps),
- "hospital_bed": a rusty iron ward bed, barred head and foot, a stained
  mattress, a sheet thrown back, one side rail down,
- "morgue_drawers": the cold room's wall of 3 x 3 steel doors, one drawer
  pulled out, a shape under a sheet on its tray (against a wall at +Y),
- "curtain": a ward curtain on its ceiling rail, pale green, filthy at the
  hem, torn,
- "iv_pole": a drip stand on its star foot, an empty bag,
- "ambulance": an abandoned ambulance in front of the emergency entrance,
  flat tyres, a rear door ajar, its dead beacons.
Each model has one material, its own small texture atlas: one draw call.
In Godot, -Y becomes +Z: the fronts face -Y here, +Z there, unless stated.
Dull colors only: orange is the noise color (constitution 2.3).
    python tools/blender/hospital_kit.py -- <out.blend> <out_dir>
"""

import math
import os
import random
import sys

import bpy  # noqa: I001 (bpy first: it makes bmesh importable)
import bmesh  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import triangle_count  # noqa: E402
from network import Atlas, Model, _flat, _noisy  # noqa: E402

rng = random.Random(1914)


def cylinder(m, center, radius, length, axis, region, segments=8):
    """A prism of `segments` sides along axis "x", "y" or "z", one region for all faces."""
    before = set(m.bm.faces)
    made = bmesh.ops.create_cone(
        m.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length
    )
    for v in made["verts"]:
        x, y, z = v.co
        if axis == "x":
            x, y, z = z, y, x
        elif axis == "y":
            x, y, z = x, z, y
        v.co = (x + center[0], y + center[1], z + center[2])
    u0, v0, u1, v1 = m.atlas.rects[region]
    for f in set(m.bm.faces) - before:
        for i, loop in enumerate(f.loops):
            s = 0.5 + 0.45 * math.cos(i * 2.4)
            t = 0.5 + 0.45 * math.sin(i * 2.4)
            loop[m.uv].uv = (u0 + (u1 - u0) * s, v0 + (v1 - v0) * t)


# --- Shading helpers -----------------------------------------------------------


def _steel(x, y):
    """Brushed steel, scratched, with spots of rust."""
    g = 0.42 + rng.uniform(-0.03, 0.03) + (0.03 if x % 5 == 0 else 0.0)
    if rng.random() < 0.06:
        return [0.3, 0.18, 0.11]
    return [g, g * 1.01, g * 1.04]


def _rust(x, y):
    """Iron painted a sickly cream, peeling to rust."""
    if rng.random() < 0.3:
        return [0.28 + rng.uniform(-0.04, 0.04), 0.15, 0.08]
    g = 0.55 + rng.uniform(-0.04, 0.04)
    return [g, g * 0.97, g * 0.85]


def _stained(base, count, seed, stain=(0.32, 0.22, 0.12), size=24):
    """A pale cloth with round stains: old blood and damp, brown, not red."""
    r = random.Random(seed)
    spots = [(r.uniform(0, size), r.uniform(0, size), r.uniform(1.5, 4.5)) for _ in range(count)]

    def shade(x, y):
        c = [v * (1.0 + r.uniform(-0.04, 0.04)) for v in base]
        for sx, sy, rad in spots:
            d = math.hypot(x - sx, y - sy)
            if d < rad:
                k = 0.65 if d > rad - 1.0 else 0.85
                c = [c[i] * (1 - k) + stain[i] * k for i in range(3)]
        return c

    return shade


def _sheet(x, y):
    """A crumpled sheet: diagonal folds, a stain."""
    g = 0.6 + (0.06 if (x + 2 * y) % 7 < 2 else 0.0) - (0.05 if (x - y) % 9 == 0 else 0.0)
    c = [g * 0.95, g, g * 0.92]
    if (x - 14) ** 2 + (y - 8) ** 2 < 12:
        c = [0.36, 0.25, 0.15]
    return c


def _tyre(x, y):
    return [0.06 + rng.uniform(0, 0.03)] * 3


# --- Gurney --------------------------------------------------------------------


def gurney():
    atlas = Atlas(
        "hospital_gurney",
        [
            ("steel", 16, 16, _steel),
            ("mattress", 24, 24, _stained([0.36, 0.42, 0.4], 5, 11)),
            ("sheet", 24, 24, _sheet),
            ("rubber", 4, 4, _tyre),
        ],
    )
    m = Model("gurney", atlas)
    # Origin on the floor, centre of the gurney; head toward +Y.
    for x in (-0.27, 0.23):
        for y in (-0.88, 0.84):
            m.box(x, y, 0.1, x + 0.04, y + 0.04, 0.72, "steel")  # Legs.
            cylinder(m, (x + 0.02, y + 0.02, 0.05), 0.05, 0.03, "x", "rubber", 6)  # Casters.
    m.box(-0.3, -0.92, 0.3, 0.3, 0.92, 0.33, "steel")  # The lower shelf.
    m.box(-0.33, -1.0, 0.72, 0.33, 1.0, 0.77, "steel")  # The frame.
    m.box(-0.31, -0.98, 0.77, 0.31, 0.98, 0.86, "mattress")
    m.box(-0.33, -0.55, 0.86, 0.33, 0.4, 0.9, "sheet")  # Thrown over the middle.
    m.box(-0.24, 0.62, 0.86, 0.24, 0.92, 0.93, "sheet")  # The pillow, flat.
    # The push handle at the head.
    m.box(-0.3, 0.98, 0.77, -0.27, 1.02, 1.05, "steel")
    m.box(0.27, 0.98, 0.77, 0.3, 1.02, 1.05, "steel")
    m.box(-0.3, 0.98, 1.02, 0.3, 1.02, 1.05, "steel")
    return m


# --- Wheelchair ----------------------------------------------------------------


def wheelchair():
    atlas = Atlas(
        "hospital_wheelchair",
        [
            ("chrome", 16, 16, _steel),
            ("canvas", 16, 16, _stained([0.1, 0.1, 0.11], 3, 12, stain=(0.2, 0.18, 0.14), size=16)),
            ("rubber", 4, 4, _tyre),
        ],
    )
    m = Model("wheelchair", atlas)
    # Origin on the floor, centre of the chair; it faces +Y (Godot -Z).
    m.box(-0.25, -0.24, 0.47, 0.25, 0.24, 0.52, "canvas")  # The seat.
    m.box(-0.25, -0.28, 0.55, 0.25, -0.24, 0.92, "canvas")  # The back, sagging.
    for x in (-0.27, 0.25):
        m.box(x, -0.28, 0.3, x + 0.02, -0.26, 1.0, "chrome")  # Back posts, handles.
        m.box(x, -0.36, 0.97, x + 0.02, -0.26, 0.99, "chrome")  # The grips.
        m.box(x, -0.26, 0.5, x + 0.02, 0.28, 0.52, "chrome")  # Seat rails.
        m.box(x, 0.26, 0.12, x + 0.02, 0.28, 0.52, "chrome")  # Front posts.
        m.box(x, -0.26, 0.66, x + 0.02, 0.1, 0.68, "chrome")  # Armrests.
        cylinder(m, (x + 0.01, 0.27, 0.07), 0.07, 0.03, "x", "rubber", 6)  # Casters.
    m.box(-0.22, 0.28, 0.12, -0.02, 0.4, 0.14, "chrome")  # Footrests, one fallen.
    m.box(0.04, 0.3, 0.02, 0.24, 0.42, 0.04, "chrome")
    for x in (-0.31, 0.31):
        cylinder(m, (x, -0.08, 0.3), 0.3, 0.035, "x", "rubber", 12)  # Big wheels.
        cylinder(m, (x + (0.025 if x > 0 else -0.025), -0.08, 0.3), 0.26, 0.01, "x", "chrome", 12)
    return m


# --- Monitor -------------------------------------------------------------------


def _bezel(x, y):
    """The monitor's front, 24 x 18 px: grey plastic, the hole of the screen, knobs."""
    if 2 <= x <= 17 and 3 <= y <= 15:
        return [0.03, 0.04, 0.035]
    if x >= 19 and y in (5, 9, 13):
        return [0.12, 0.12, 0.11]
    if x == 20 and y == 15:
        return [0.4, 0.06, 0.05]  # The alarm light, dead.
    g = 0.38 + rng.uniform(-0.03, 0.03)
    return [g, g * 0.98, g * 0.92]


def monitor():
    atlas = Atlas(
        "hospital_monitor",
        [
            ("plastic", 8, 8, _noisy([0.36, 0.35, 0.32], 0.06, 13)),
            ("bezel", 24, 18, _bezel),
            ("steel", 16, 16, _steel),
            ("cable", 4, 4, _flat([0.12, 0.13, 0.12])),
            ("rubber", 4, 4, _tyre),
        ],
    )
    m = Model("monitor", atlas)
    # The Monitor scene's screen quad: 0.42 x 0.3 at 1.3 m, at y = 0.1 (Godot z -0.1).
    m.box(-0.26, -0.22, 1.12, 0.26, 0.09, 1.48, "plastic", {"front": "plastic", "back": "bezel"})
    m.box(-0.2, -0.3, 1.16, 0.2, -0.22, 1.44, "plastic")  # Its back.
    m.box(-0.08, -0.12, 1.06, 0.08, 0.02, 1.12, "steel")  # The tilt mount.
    m.box(-0.025, -0.08, 0.1, 0.025, -0.03, 1.06, "steel")  # The pole.
    m.box(-0.18, -0.2, 0.75, 0.18, 0.05, 0.78, "steel")  # A tray for the leads.
    for a in range(5):  # The star foot.
        ang = a * 2 * math.pi / 5
        x, y = 0.28 * math.cos(ang), -0.055 + 0.28 * math.sin(ang)
        m.box(min(0.0, x) - 0.02, min(-0.055, y) - 0.02, 0.06, max(0.0, x) + 0.02, max(-0.055, y) + 0.02, 0.1, "steel")
        cylinder(m, (x, y, 0.03), 0.03, 0.025, "x", "rubber", 6)
    # The leads, hanging from the tray, their ends trailing on the floor.
    for x, low in ((-0.14, 0.02), (-0.1, 0.25), (0.12, 0.02)):
        m.box(x, 0.04, low, x + 0.012, 0.052, 0.78, "cable")
    m.box(-0.14, 0.04, 0.0, -0.128, 0.22, 0.012, "cable")
    m.box(0.12, 0.04, 0.0, 0.132, 0.3, 0.012, "cable")
    return m


# --- Hospital bed --------------------------------------------------------------


def hospital_bed():
    atlas = Atlas(
        "hospital_bed",
        [
            ("iron", 16, 16, _rust),
            ("mattress", 24, 24, _stained([0.5, 0.52, 0.44], 7, 14)),
            ("sheet", 24, 24, _sheet),
            ("rubber", 4, 4, _tyre),
        ],
    )
    m = Model("hospital_bed", atlas)
    # Origin on the floor, centre of the bed; the head toward +Y, against a wall.
    for y0, top in ((0.98, 1.15), (-1.02, 0.95)):  # Head and foot.
        for x in (-0.47, 0.43):
            m.box(x, y0, 0.08, x + 0.04, y0 + 0.04, top, "iron")
        m.box(-0.47, y0, top - 0.04, 0.47, y0 + 0.04, top, "iron")
        m.box(-0.47, y0, 0.42, 0.47, y0 + 0.04, 0.45, "iron")
        for i in range(7):
            x = -0.36 + i * 0.12
            m.box(x, y0 + 0.01, 0.45, x + 0.02, y0 + 0.03, top - 0.04, "iron")
        for x in (-0.45, 0.45):
            cylinder(m, (x, y0 + 0.02, 0.05), 0.05, 0.03, "x", "rubber", 6)
    m.box(-0.47, -1.0, 0.4, 0.47, 1.0, 0.48, "iron")  # The frame.
    m.box(-0.44, -0.97, 0.48, 0.44, 0.97, 0.62, "mattress")
    m.box(-0.45, -0.97, 0.62, 0.45, 0.1, 0.65, "sheet")  # Thrown back.
    m.box(-0.3, 0.6, 0.62, 0.3, 0.92, 0.7, "sheet")  # The pillow.
    # The side rails: one up on the left, the other down on the right.
    m.box(-0.5, -0.6, 0.66, -0.48, 0.6, 0.69, "iron")
    for y in (-0.55, 0.0, 0.55):
        m.box(-0.5, y, 0.48, -0.48, y + 0.03, 0.66, "iron")
    m.box(0.48, -0.6, 0.3, 0.5, 0.6, 0.33, "iron")
    return m


# --- Morgue drawers ------------------------------------------------------------


def _door(x, y):
    """A cold-room door, 20 x 16 px: a label slot, the latch, dents."""
    if x in (0, 19) or y in (0, 15):
        return [0.2, 0.21, 0.21]
    if 7 <= x <= 12 and 11 <= y <= 13:
        return [0.6, 0.58, 0.48] if y != 12 or x in (7, 12) else [0.2, 0.2, 0.25]  # The label.
    if 14 <= x <= 17 and 7 <= y <= 8:
        return [0.55, 0.56, 0.56]  # The latch.
    g = 0.46 + rng.uniform(-0.04, 0.04)
    if rng.random() < 0.04:
        g -= 0.12  # A dent.
    return [g, g * 1.01, g * 1.04]


def morgue_drawers():
    atlas = Atlas(
        "hospital_morgue",
        [
            ("steel", 16, 16, _steel),
            ("door", 20, 16, _door),
            ("dark", 4, 4, _flat([0.02, 0.02, 0.025])),
            ("sheet", 24, 24, _stained([0.55, 0.57, 0.52], 4, 15)),
        ],
    )
    m = Model("morgue_drawers", atlas)
    # Against a wall behind it (+Y), its doors at y = -0.8; 2.4 m wide, 2.1 m high.
    m.box(-1.2, -0.78, 0.0, 1.2, 0.0, 2.1, "steel")
    for col in range(3):
        for row in range(3):
            x0, z0 = -1.15 + col * 0.78, 0.1 + row * 0.68
            if (col, row) == (2, 1):
                # The open one: the dark hole, the tray pulled out, a body under a sheet.
                m.box(x0, -0.8, z0, x0 + 0.7, -0.78, z0 + 0.6, "dark")
                m.box(x0 + 0.05, -2.6, z0 + 0.08, x0 + 0.65, -0.8, z0 + 0.12, "steel")
                m.box(x0 + 0.1, -2.5, z0 + 0.12, x0 + 0.6, -0.9, z0 + 0.3, "sheet")
                m.box(x0 + 0.2, -2.45, z0 + 0.12, x0 + 0.5, -2.2, z0 + 0.36, "sheet")  # The head.
                m.box(x0 + 0.68, -0.84, z0, x0 + 0.7, -0.8, z0 + 0.6, "steel")  # Its door, swung.
                m.box(x0 + 0.7, -1.5, z0, x0 + 0.72, -0.84, z0 + 0.6, "steel", {"left": "door"})
            else:
                m.box(x0, -0.8, z0, x0 + 0.7, -0.78, z0 + 0.6, "steel", {"front": "door"})
    return m


# --- Curtain, drip stand -------------------------------------------------------


def _cloth(x, y):
    """Pale green curtain, 16 x 32 px: vertical folds, a filthy hem, a tear."""
    g = 0.48 + (0.05 if x % 4 < 2 else -0.03) + rng.uniform(-0.02, 0.02)
    c = [g * 0.85, g, g * 0.88]
    if y < 6:
        k = (6 - y) / 6 * 0.6
        c = [c[0] * (1 - k) + 0.2 * k, c[1] * (1 - k) + 0.17 * k, c[2] * (1 - k) + 0.1 * k]
    return c


def _torn(x, y):
    if 7 <= x <= 9 and 8 <= y <= 17 and abs(x - 8 - (y % 3 - 1) * 0.5) < 1:
        return [0.03, 0.03, 0.03]  # The tear.
    return _cloth(x, y)


def curtain():
    atlas = Atlas(
        "hospital_curtain", [("cloth", 16, 32, _cloth), ("torn", 16, 32, _torn), ("rail", 8, 8, _steel)]
    )
    m = Model("curtain", atlas)
    # Its rail at 2.3 m along x, the curtain 1.8 m wide in folds, the hem at 0.3 m.
    m.box(-1.0, -0.02, 2.28, 1.0, 0.02, 2.32, "rail")
    for i in range(9):
        x = -0.9 + i * 0.2
        y = 0.04 if i % 2 else -0.04
        hem = 0.3 + (0.08 if i in (3, 4) else 0.0)
        m.box(x - 0.02, y - 0.01, hem, x + 0.22, y + 0.01, 2.27, "torn" if i == 5 else "cloth")
        m.box(x + 0.09, -0.01, 2.27, x + 0.11, 0.01, 2.28, "rail")  # The hooks.
    return m


def iv_pole():
    atlas = Atlas(
        "hospital_iv",
        [
            ("steel", 16, 16, _steel),
            ("bag", 8, 8, _noisy([0.55, 0.58, 0.55], 0.05, 16)),
            ("tube", 4, 4, _flat([0.5, 0.52, 0.5])),
            ("rubber", 4, 4, _tyre),
        ],
    )
    m = Model("iv_pole", atlas)
    m.box(-0.012, -0.012, 0.08, 0.012, 0.012, 1.95, "steel")
    m.box(-0.2, -0.012, 1.9, 0.2, 0.012, 1.92, "steel")  # The hooks.
    for a in range(5):
        ang = a * 2 * math.pi / 5
        x, y = 0.25 * math.cos(ang), 0.25 * math.sin(ang)
        m.box(min(0.0, x) - 0.015, min(0.0, y) - 0.015, 0.05, max(0.0, x) + 0.015, max(0.0, y) + 0.015, 0.08, "steel")
        cylinder(m, (x, y, 0.025), 0.025, 0.02, "x", "rubber", 6)
    m.box(0.13, -0.02, 1.62, 0.21, 0.02, 1.88, "bag")  # Empty, flat.
    m.box(0.165, -0.004, 0.9, 0.175, 0.004, 1.62, "tube")
    return m


# --- Ambulance -----------------------------------------------------------------


def _body(x, y):
    """Dirty white panel, 32 x 16 px: a faded green band, grime from below."""
    g = 0.62 + rng.uniform(-0.03, 0.03)
    c = [g, g, g * 0.95]
    if 7 <= y <= 9:
        c = [0.22, 0.36, 0.28]  # The band.
    if y < 5:
        k = (5 - y) / 5 * 0.5
        c = [v * (1 - k) + 0.12 * k for v in c]
    if rng.random() < 0.03:
        c = [0.3, 0.2, 0.12]  # Rust.
    return c


def _rear(x, y):
    """The rear doors, 24 x 24 px: a window each, the star of life, faded."""
    c = _body(x, y)
    if 3 <= y <= 4 and x not in (11, 12):
        c = [0.22, 0.36, 0.28]
    if 16 <= y <= 21 and (2 <= x <= 9 or 14 <= x <= 21):
        return [0.03, 0.035, 0.04]
    if x in (11, 12):
        return [0.15, 0.15, 0.15]  # The seam.
    if 7 <= y <= 13 and (x - 6) ** 2 + (y - 10) ** 2 < 8:
        return [0.25, 0.3, 0.42]  # The star of life, a dull blue.
    return c


def _cab(x, y):
    """The cab's front, 24 x 16 px: the grille, two dead headlights."""
    if 4 <= y <= 7 and 7 <= x <= 16:
        return [0.08, 0.08, 0.08] if y % 2 else [0.3, 0.3, 0.3]
    if 4 <= y <= 7 and (1 <= x <= 4 or 19 <= x <= 22):
        return [0.5, 0.5, 0.42]  # Headlights.
    if y <= 2:
        return [0.12, 0.12, 0.12]  # The bumper.
    return _body(x, y + 4)


def ambulance():
    atlas = Atlas(
        "hospital_ambulance",
        [
            ("body", 32, 16, _body),
            ("rear", 24, 24, _rear),
            ("cab", 24, 16, _cab),
            ("glass", 4, 4, _flat([0.03, 0.035, 0.04])),
            ("dark", 4, 4, _flat([0.07, 0.07, 0.07])),
            ("beacon", 4, 4, _flat([0.15, 0.2, 0.32])),
            ("rubber", 4, 4, _tyre),
            ("roof", 8, 8, _noisy([0.4, 0.4, 0.36], 0.12, 17)),
        ],
    )
    m = Model("ambulance", atlas)
    # Origin on the ground, the cab toward -Y (Godot +Z); 2.1 m wide, 6 m long.
    m.box(-1.05, -1.2, 0.4, 1.05, 3.0, 2.7, "body", {"back": "rear", "top": "roof"})  # The box.
    m.box(-1.0, -3.0, 0.4, 1.0, -1.2, 1.25, "body", {"front": "cab"})  # The bonnet.
    m.box(-1.0, -2.2, 1.25, 1.0, -1.2, 2.2, "body", {"top": "roof"})  # The cab.
    m.box(-0.95, -2.22, 1.35, 0.95, -2.2, 2.1, "glass")  # Windscreen.
    for x in (-1.02, 1.0):
        m.box(x, -2.0, 1.4, x + 0.02, -1.35, 2.05, "glass")  # Side windows.
    m.box(-0.9, -1.0, 2.7, -0.3, -0.75, 2.82, "beacon")  # The beacons, dead.
    m.box(0.3, -1.0, 2.7, 0.9, -0.75, 2.82, "beacon")
    m.box(-1.05, 2.98, 0.35, 1.05, 3.15, 0.45, "dark")  # The rear step.
    # The right rear door, ajar.
    m.box(1.02, 3.0, 0.45, 1.06, 4.0, 2.6, "body", {"right": "body"})
    for y in (-2.1, 1.9):  # Wheels; the front left flat.
        for x in (-1.0, 1.0):
            r = 0.3 if (x, y) == (-1.0, -2.1) else 0.38
            cylinder(m, (x, y, r), 0.38, 0.25, "x", "rubber", 10)
    m.box(-1.0, -2.6, 0.25, 1.0, 2.5, 0.4, "dark")  # The underbody.
    return m


BUILDERS = [
    gurney,
    wheelchair,
    monitor,
    hospital_bed,
    morgue_drawers,
    curtain,
    iv_pole,
    ambulance,
]


if __name__ == "__main__":
    for leftover in list(bpy.data.objects):
        bpy.data.objects.remove(leftover)
    objects = []
    x = 0.0
    for builder in BUILDERS:
        objects.append(builder().build(offset_x=x))
        x += 5.0
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
