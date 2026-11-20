"""Builds the models of the underground car park and the garages (S-006, T-047).

- "car_wreck": a burnt-out car shell, round flat tyres, no glass (4.2 x 2 x 1.4 m),
- "car_park_sign": the "P" sign at the top of the ramp, on its post,
- "car_park_pillar": a 0.5 m pillar with worn white bands and its bay number,
- "neon_fixture": a dead neon tube hanging from the slab,
- "garage_closed": the dented up-and-over door of a closed garage, tagged,
- "garage_open": the frame of an open garage, its door swung up inside.
Dull colors only: orange is the noise color (constitution 2.3).
Same conventions and helpers as gallery.py: origin at the bottom-left corner
of the outer face, the outside faces -Y; centred models are noted.
    python tools/blender/car_park.py -- <out.blend> <out_dir>
"""

import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import FONT, Model, _image, _tags, material, triangle_count  # noqa: E402

GARAGE_DOOR = (4.83, 2.4)  # Width and height of a garage opening.
PILLAR = (0.5, 2.8)
PILLAR_BANDS = ((0.0, 0.25), (1.0, 1.15))  # Painted bands, heights from the floor.


def burnt_texture():
    """Burnt paint: soot, bare rusty metal, a few flakes of grey-blue paint."""
    rng = random.Random(41)

    def shade(x, y):
        r = rng.random()
        if r < 0.3:
            return [0.3, 0.16, 0.09]
        if r < 0.45:
            return [0.3, 0.35, 0.4]
        g = 0.11 + rng.uniform(0, 0.06)
        return [g, g, g * 0.95]

    return _image("car_park_burnt_tex", 64, 64, shade)


def tyre_texture():
    return _image("car_park_tyre_tex", 8, 8, lambda x, y: [0.05, 0.05, 0.055])


def sign_p_texture():
    """Blue panel, white border, a big pixel "P"."""
    rows = FONT["P"] if "P" in FONT else ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
    size, scale = 32, 4
    x0, y0 = (size - 5 * scale) // 2, (size - 7 * scale) // 2

    def shade(x, y):
        if x < 2 or y < 2 or x >= size - 2 or y >= size - 2:
            return [0.75, 0.76, 0.74]
        col, row = (x - x0) // scale, 6 - (y - y0) // scale
        if 0 <= col < 5 and 0 <= row < 7 and rows[row][col] == "1" and x >= x0 and y >= y0:
            return [0.8, 0.82, 0.8]
        return [0.1, 0.2, 0.42]

    return _image("car_park_sign_p_tex", size, size, shade)


def pillar_texture(number):
    """Grey concrete, dark at the foot, a stencilled bay number at 1.6 m."""
    rng = random.Random(42 + number)
    width, height = 32, 192  # 0.5 x 3 m at 64 px per meter.
    digits = str(number)
    scale = 2
    x0 = (width - len(digits) * 6 * scale) // 2
    y0 = 100

    def lit(x, y):
        i = (x - x0) // (6 * scale)
        if x < x0 or i >= len(digits):
            return False
        col, row = ((x - x0) % (6 * scale)) // scale, 6 - (y - y0) // scale
        rows = DIGITS[digits[i]]
        return 0 <= col < 5 and 0 <= row < 7 and rows[row][col] == "1"

    def shade(x, y):
        z = y / 64.0
        if any(a <= z < b for a, b in PILLAR_BANDS):
            return [0.62 - rng.uniform(0, 0.25)] * 3  # Worn white paint.
        if y >= y0 and lit(x, y):
            return [0.65, 0.65, 0.62]
        g = 0.36 + rng.uniform(-0.04, 0.04)
        g *= 0.7 + 0.3 * min(1.0, y / 40.0)
        return [g, g * 0.99, g * 0.95]

    return _image("car_park_pillar_tex", width, height, shade)


DIGITS = {
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
}


def garage_texture():
    """Green-grey corrugated door, dents, rust and tags, 5 x 2.5 m."""
    rng = random.Random(43)
    width, height = 320, 160
    tags = _tags(rng, width, height, 5)

    def shade(x, y):
        if (x, y) in tags:
            return tags[(x, y)]
        g = 0.27 + rng.uniform(-0.02, 0.02)
        if x % 10 < 2:
            g -= 0.07  # Vertical ribs.
        if rng.random() < 0.06:
            return [0.27, 0.15, 0.08]
        return [g * 0.85, g, g * 0.92]

    return _image("car_park_garage_tex", width, height, shade)


def mats():
    concrete = _image(
        "car_park_concrete_tex", 64, 64,
        lambda x, y: [0.4 + random.Random(x * 97 + y).uniform(-0.04, 0.04)] * 3,
    )
    return {
        "burnt": material("car_park_burnt_mat", burnt_texture()),
        "tyre": material("car_park_tyre_mat", tyre_texture()),
        "metal": material("car_park_metal_mat", _image("car_park_metal_tex", 8, 8, lambda x, y: [0.32, 0.33, 0.33])),
        "sign": material("car_park_sign_p_mat", sign_p_texture(), emission=0.4),
        "pillar": material("car_park_pillar_mat", pillar_texture(14)),
        "neon": material("car_park_neon_mat", _image("car_park_neon_tex", 8, 8, lambda x, y: [0.55, 0.57, 0.58])),
        "garage": material("car_park_garage_mat", garage_texture()),
        "concrete": material("car_park_concrete_mat", concrete),
    }


def car_wreck(k):
    """Centred on its footprint, nose toward -Y."""
    m = Model("car_wreck")
    m.box(-0.9, -2.1, 0.3, 0.9, 2.1, 0.62, k["burnt"], meters=1.0)  # Body.
    hood = m.box(-0.88, -2.05, 0.62, 0.88, -0.75, 0.78, k["burnt"], meters=1.0)
    _slope(hood, -2.05, 0.78, -0.08)  # The bonnet dips toward the nose.
    m.box(-0.88, 1.25, 0.62, 0.88, 2.05, 0.82, k["burnt"], meters=1.0)  # Boot.
    cabin = []
    for x0, x1 in ((-0.85, -0.75), (0.75, 0.85)):  # Door frames, glass gone.
        cabin += m.box(x0, -0.75, 0.62, x1, 1.25, 1.3, k["burnt"], meters=1.0)
    roof = m.box(-0.85, -0.35, 1.3, 0.85, 0.95, 1.36, k["burnt"], meters=1.0)
    for x0, x1 in ((-0.85, -0.7), (0.7, 0.85)):  # Slanted pillars.
        cabin += m.box(x0, -0.75, 0.78, x1, -0.35, 1.3, k["burnt"], meters=1.0)
        cabin += m.box(x0, 0.95, 0.82, x1, 1.25, 1.3, k["burnt"], meters=1.0)
    m.box(-0.75, -0.7, 0.62, 0.75, 1.2, 0.95, k["tyre"])  # Burnt seats.
    m.box(-0.92, -2.2, 0.3, 0.92, -2.1, 0.45, k["metal"])  # Bumpers.
    m.box(-0.92, 2.1, 0.3, 0.92, 2.2, 0.45, k["metal"])
    for x in (-0.95, 0.75):
        for y in (-1.6, 1.05):
            # Flat tyres: round, 12 sides, squashed flat on the ground (T-324).
            tyre = m.cylinder((x + 0.1, y + 0.3, 0.22), 0.3, 0.2, "x", k["tyre"], meters=4.0)
            for v in {v for f in tyre for v in f.verts}:
                v.co.z = max(v.co.z, 0.0)
            rim = x - 0.005 if x < 0 else x + 0.205
            m.cylinder((rim, y + 0.3, 0.22), 0.13, 0.01, "x", k["metal"], segments=8)
    del roof, cabin
    return m


def _slope(faces, y_edge, z_top, drop):
    """Lowers the top vertices of a box along its y_edge, for slanted panels."""
    for f in faces:
        for v in f.verts:
            if abs(v.co.y - y_edge) < 1e-4 and abs(v.co.z - z_top) < 1e-4:
                v.co.z = z_top + drop


def car_park_sign(k):
    """Centred on its post."""
    m = Model("car_park_sign")
    m.box(-0.08, -0.08, 0.0, 0.08, 0.08, 2.6, k["metal"])
    m.box(-0.5, -0.12, 2.6, 0.5, -0.08, 3.4, k["sign"], stretch=True)
    m.box(-0.5, -0.08, 2.6, 0.5, -0.04, 3.4, k["metal"])
    return m


def car_park_pillar(k):
    """Centred, a hair wider than the 0.5 m greybox pillar it covers."""
    m = Model("car_park_pillar")
    half = PILLAR[0] / 2 + 0.01
    m.box(-half, -half, 0.0, half, half, PILLAR[1], k["pillar"], stretch=True)
    return m


def neon_fixture(k):
    """Centred, hangs below its origin (the underside of the slab)."""
    m = Model("neon_fixture")
    m.box(-0.6, -0.06, -0.12, 0.6, 0.06, -0.06, k["metal"])
    m.box(-0.58, -0.03, -0.16, 0.2, 0.03, -0.12, k["neon"])  # Half the tube fell.
    for x in (-0.5, 0.5):
        m.box(x - 0.01, -0.01, -0.06, x + 0.01, 0.01, 0.0, k["metal"])
    return m


def garage_closed(k):
    m = Model("garage_closed")
    w, h = GARAGE_DOOR
    m.box(0.0, -0.06, 0.0, w, -0.02, h, k["garage"], meters=(5.0, 2.5))
    for x in (-0.08, w):
        m.box(x, -0.1, 0.0, x + 0.08, 0.0, h + 0.08, k["metal"])
    m.box(-0.08, -0.1, h, w + 0.08, 0.0, h + 0.08, k["metal"])
    m.box(w / 2 - 0.15, -0.1, 1.0, w / 2 + 0.15, -0.06, 1.06, k["metal"])  # Handle.
    return m


def garage_open(k):
    m = Model("garage_open")
    w, h = GARAGE_DOOR
    for x in (-0.08, w):
        m.box(x, -0.1, 0.0, x + 0.08, 0.0, h + 0.08, k["metal"])
    m.box(-0.08, -0.1, h, w + 0.08, 0.0, h + 0.08, k["metal"])
    # The door swung up under the ceiling, its edge hanging just above the opening.
    m.box(0.05, 0.1, h + 0.0, w - 0.05, 2.2, h + 0.04, k["garage"], meters=(5.0, 2.5))
    return m


BUILDERS = (car_wreck, car_park_sign, car_park_pillar, neon_fixture, garage_closed, garage_open)


if __name__ == "__main__":
    k = mats()
    objects = []
    x = 0.0
    for builder in BUILDERS:
        objects.append(builder(k).build(offset_x=x))
        x += 8.0
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
