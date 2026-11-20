"""Builds the outdoor models of the cité (S-006, T-048).

- "car_parked": an old grey hatchback, the car of the alarms (CarAlarm),
  1.8 x 1.45 x 4.2 m, nose toward +Y (glTF -Z, where its left hazard light is),
- "transformer": the green transformer cabinet, 9 x 7 x 2.6 m, vents, doors,
  a dull yellow warning sign (never orange: the noise color, constitution 2.3),
- "swing": the swing frame of the playground and its two seats on chains,
- "climbing_frame": the climbing frame and its slide,
- "stadium_board": a 2 m board of the city stadium fence, tagged,
- "stadium_goal": a small goal with its net of bars.
All centred on their footprint except stadium_board (origin at the bottom-left
corner of the outer face, outside toward -Y, as the facade modules).
Same helpers as gallery.py.
    python tools/blender/outdoor.py -- <out.blend> <out_dir>
"""

import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import Model, _image, _tags, material, triangle_count  # noqa: E402

TRANSFORMER = (9.0, 7.0, 2.6)
SWING_SPAN = 8.0  # Between the posts (57 and 65 m on the plan).
SWING_DEPTH = 2.8
SWING_TOP = 2.4
BOARD = (2.0, 1.1, 0.15)


def _noise(name, base, spread, seed, size=32):
    rng = random.Random(seed)
    return _image(name, size, size, lambda x, y: [c * (1 + rng.uniform(-spread, spread)) for c in base])


def paint_texture():
    """Grey-blue car paint, dull, with rust along the bottom."""
    rng = random.Random(51)

    def shade(x, y):
        if y < 6 and rng.random() < 0.5:
            return [0.27, 0.15, 0.08]
        g = 0.3 + rng.uniform(-0.02, 0.02)
        return [g * 0.95, g, g * 1.08]

    return _image("outdoor_paint_tex", 32, 32, shade)


def cabinet_texture():
    """Dark green sheet metal, 64 px per meter over 4 m, rust and tags at hand height."""
    rng = random.Random(52)
    size = 256
    tags = _tags(rng, size, size, 5)

    def shade(x, y):
        if (x, y) in tags and y < 120:
            return tags[(x, y)]
        if x % 64 < 2:
            return [0.08, 0.14, 0.1]  # Panel seams.
        if rng.random() < 0.05:
            return [0.28, 0.16, 0.08]
        g = 0.2 + rng.uniform(-0.02, 0.02)
        return [g * 0.7, g * 1.25, g * 0.85]

    return _image("outdoor_cabinet_tex", size, size, shade)


def warning_texture():
    """Dull yellow triangle with a black lightning bolt on grey."""
    size = 32

    def shade(x, y):
        inside = y > 4 and abs(x - 16) < (28 - y) * 0.55
        if not inside:
            return [0.3, 0.3, 0.3]
        bolt = abs((x - 16) - (y - 16) * 0.4) < 2 and 8 < y < 24
        return [0.05, 0.05, 0.05] if bolt else [0.62, 0.55, 0.18]

    return _image("outdoor_warning_tex", size, size, shade)


def board_texture():
    """Green painted plywood of the city stadium, kicked and tagged, 2 m wide."""
    rng = random.Random(53)
    width, height = 128, 72
    tags = _tags(rng, width, height, 3)

    def shade(x, y):
        if (x, y) in tags:
            return tags[(x, y)]
        if rng.random() < 0.04:
            return [0.3, 0.3, 0.27]  # Bare wood under the paint.
        g = 0.22 + rng.uniform(-0.02, 0.02) - (0.05 if y < 12 else 0.0)
        return [g * 0.75, g * 1.2, g * 0.8]

    return _image("outdoor_board_tex", width, height, shade)


def mats():
    return {
        "paint": material("outdoor_paint_mat", paint_texture()),
        "glass": material("outdoor_glass_mat", _noise("outdoor_glass_tex", (0.06, 0.07, 0.09), 0.2, 54, 8)),
        "tyre": material("outdoor_tyre_mat", _noise("outdoor_tyre_tex", (0.05, 0.05, 0.055), 0.1, 55, 8)),
        "chrome": material("outdoor_chrome_mat", _noise("outdoor_chrome_tex", (0.42, 0.43, 0.43), 0.08, 56, 8)),
        "light": material("outdoor_light_mat", _noise("outdoor_light_tex", (0.55, 0.5, 0.4), 0.05, 57, 8)),
        "cabinet": material("outdoor_cabinet_mat", cabinet_texture()),
        "warning": material("outdoor_warning_mat", warning_texture()),
        "concrete": material("outdoor_concrete_mat", _noise("outdoor_concrete_tex", (0.38, 0.38, 0.36), 0.1, 58, 64)),
        "metal": material("outdoor_metal_mat", _noise("outdoor_metal_tex", (0.25, 0.3, 0.33), 0.15, 59, 16)),
        "rust": material("outdoor_rust_mat", _noise("outdoor_rust_tex", (0.3, 0.17, 0.09), 0.2, 60, 16)),
        "seat": material("outdoor_seat_mat", _noise("outdoor_seat_tex", (0.1, 0.12, 0.2), 0.15, 61, 8)),
        "board": material("outdoor_board_mat", board_texture()),
    }


def _verts(faces):
    """The vertices of a box, each once."""
    return {v for f in faces for v in f.verts}


def car_parked(k):
    m = Model("car_parked")
    m.box(-0.9, -2.1, 0.3, 0.9, 2.1, 0.85, k["paint"], meters=1.0)  # Body.
    m.box(-0.8, -1.3, 0.85, 0.8, 0.9, 1.45, k["paint"], meters=1.0)  # Cabin.
    m.box(-0.81, -1.2, 0.95, 0.81, 0.8, 1.35, k["glass"])  # Side windows.
    m.box(-0.75, 0.9, 0.9, 0.75, 0.92, 1.4, k["glass"])  # Windscreen.
    m.box(-0.75, -1.32, 0.9, 0.75, -1.3, 1.4, k["glass"])  # Rear window.
    m.box(-0.92, -2.15, 0.3, 0.92, -2.1, 0.48, k["chrome"])  # Bumpers.
    m.box(-0.92, 2.1, 0.3, 0.92, 2.15, 0.48, k["chrome"])
    for x in (-0.75, 0.55):  # Head and tail lights, off.
        m.box(x, 2.1, 0.6, x + 0.2, 2.12, 0.72, k["light"])
        m.box(x, -2.12, 0.6, x + 0.2, -2.1, 0.72, k["rust"])
    for x in (-0.95, 0.75):
        for y in (-1.55, 1.05):  # Round wheels, 12 sides (S-020, T-324).
            m.cylinder((x + 0.1, y + 0.3, 0.3), 0.3, 0.2, "x", k["tyre"], meters=4.0)
    return m


def transformer(k):
    m = Model("transformer")
    w, d, h = TRANSFORMER
    m.box(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, k["cabinet"])
    m.box(-w / 2 - 0.3, -d / 2 - 0.3, h, w / 2 + 0.3, d / 2 + 0.3, h + 0.2, k["concrete"])  # Roof.
    m.box(-w / 2 - 0.1, -d / 2 - 0.1, 0.0, w / 2 + 0.1, d / 2 + 0.1, 0.15, k["concrete"])  # Plinth.
    # Double doors on the long sides, vents above them, the sign beside.
    for side in (-1, 1):
        y = side * (d / 2 + 0.02)
        for x0 in (-3.2, 0.6):
            m.box(x0, min(y, y - side * 0.04), 0.2, x0 + 2.4, max(y, y - side * 0.04), 2.2, k["metal"])
            for i in range(4):
                z = 2.25 + i * 0.07
                m.box(x0 + 0.2, min(y, y + side * 0.05), z, x0 + 2.2, max(y, y + side * 0.05), z + 0.03, k["metal"])
        m.box(-0.35, min(y, y + side * 0.03), 1.3, 0.35, max(y, y + side * 0.03), 1.9, k["warning"], stretch=True)
    return m


def swing(k):
    m = Model("swing")
    half, depth, top = SWING_SPAN / 2, SWING_DEPTH / 2, SWING_TOP
    for x in (-half, half):  # A-frames.
        for y in (-depth, depth):
            leg = m.box(x - 0.06, y - 0.06, 0.0, x + 0.06, y + 0.06, top, k["metal"])
            for v in _verts(leg):
                if v.co.z > top - 0.01:
                    v.co.y -= y  # The legs meet under the top bar.
    m.box(-half - 0.1, -0.06, top - 0.12, half + 0.1, 0.06, top, k["rust"])  # Top bar.
    for x in (-1.5, 1.5):  # Seats on their chains (59.5 and 62.5 m on the plan).
        m.box(x - 0.3, -0.12, 0.45, x + 0.3, 0.12, 0.5, k["seat"])
        for dx in (-0.27, 0.25):
            m.box(x + dx, -0.01, 0.5, x + dx + 0.02, 0.01, top - 0.12, k["chrome"])
    return m


def climbing_frame(k):
    """Centred on the 3 x 3 m frame; the slide runs toward +X."""
    m = Model("climbing_frame")
    for x in (-1.5, 1.4):
        for y in (-1.5, 1.4):
            m.box(x, y, 0.0, x + 0.1, y + 0.1, 2.4, k["metal"])  # Posts.
    m.box(-1.5, -1.5, 1.5, 1.5, 1.5, 1.6, k["rust"])  # Platform.
    for z in (0.5, 1.0, 2.3):  # Rails on three sides.
        m.box(-1.5, -1.5, z, -1.4, 1.5, z + 0.05, k["metal"])
        m.box(-1.5, -1.5, z, 1.5, -1.4, z + 0.05, k["metal"])
        m.box(-1.5, 1.4, z, 1.5, 1.5, z + 0.05, k["metal"])
    slide = m.box(1.5, -0.5, 1.5, 5.0, 0.5, 1.6, k["chrome"])
    for v in _verts(slide):
        if v.co.x > 4.9:
            v.co.z -= 1.4
    return m


def stadium_board(k):
    w, h, t = BOARD
    m = Model("stadium_board")
    m.box(0.0, -t / 2, 0.0, w, t / 2, h, k["board"], stretch=True)
    m.box(-0.04, -t / 2 - 0.02, 0.0, 0.04, t / 2 + 0.02, h + 0.05, k["metal"])  # Post.
    m.box(0.0, -t / 2 - 0.01, h, w, t / 2 + 0.01, h + 0.04, k["metal"])  # Top rail.
    return m


def stadium_goal(k):
    """Centred, 3 m wide, the net behind toward +Y."""
    m = Model("stadium_goal")
    for x in (-1.5, 1.44):
        m.box(x, -0.06, 0.0, x + 0.06, 0.0, 2.0, k["chrome"])
    m.box(-1.5, -0.06, 1.94, 1.5, 0.0, 2.0, k["chrome"])
    for i in range(7):  # Net: a grid of thin bars.
        x = -1.5 + i * 0.5
        m.box(x, 0.8, 0.0, x + 0.02, 0.82, 1.9, k["metal"])
    for z in (0.6, 1.2, 1.9):
        m.box(-1.5, 0.8, z, 1.5, 0.82, z + 0.02, k["metal"])
    for x in (-1.5, 1.48):  # Sides of the net.
        m.box(x, 0.0, 1.88, x + 0.02, 0.82, 1.9, k["metal"])
    return m


BUILDERS = (car_parked, transformer, swing, climbing_frame, stadium_board, stadium_goal)


if __name__ == "__main__":
    k = mats()
    objects = []
    x = 0.0
    for builder in BUILDERS:
        objects.append(builder(k).build(offset_x=x))
        x += 14.0
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
