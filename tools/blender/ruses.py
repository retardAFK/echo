"""Builds the models of the hunted's ruses (S-008, T-069).

- "bottle": an empty green glass bottle, 26 cm, to pick up and throw (Q1),
- "glass_shards": the shards a broken bottle leaves on the ground (Q2),
- "alarm_clock": an old mechanical alarm clock with two bells (Q3),
- "closet": a dented metal locker a hunted fits in, door toward -Y (Q5),
- "dumpster": a big dark green bin with its lid, front toward -Y (Q5).
Every model is centred on its footprint, its bottom at z = 0. In Godot, -Y
becomes +Z: the front of the hiding spots (HidingSpot faces +Z).
Dull colors only: orange is the noise color (constitution 2.3).
Same helpers as gallery.py (boxes, world projection at about 64 px per meter).
    python tools/blender/ruses.py -- <out.blend> <out_dir>
"""

import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import Model, _image, _tags, material, triangle_count  # noqa: E402

CLOSET = (0.9, 0.55, 1.95)  # Width, depth, height.
DUMPSTER = (1.8, 1.1, 1.2)


def glass_texture():
    """Dark bottle green, a lighter streak where the light catches the glass."""
    rng = random.Random(51)

    def shade(x, y):
        g = 0.2 + rng.uniform(-0.02, 0.02)
        if x in (2, 3):
            g += 0.12
        return [g * 0.55, g, g * 0.6]

    return _image("ruses_glass_tex", 8, 16, shade)


def clock_texture():
    """Tarnished grey-green metal of the case and the bells."""
    rng = random.Random(53)

    def shade(x, y):
        g = 0.35 + rng.uniform(-0.04, 0.04)
        return [g * 0.95, g, g * 0.9]

    return _image("ruses_clock_tex", 8, 8, shade)


def clock_face_texture():
    """A pale face with dark hands and hour marks."""

    def shade(x, y):
        if x in (0, 9) or y in (0, 9):
            return [0.2, 0.2, 0.19]  # The bezel.
        if (x, y) in ((5, 7), (5, 2), (2, 5), (7, 5), (5, 5), (5, 6), (6, 5)):
            return [0.08, 0.08, 0.08]
        return [0.72, 0.7, 0.62]

    return _image("ruses_clock_face_tex", 10, 10, shade)


def locker_texture():
    """Grey-green painted steel, scratches, rust at the bottom, a few tags."""
    rng = random.Random(57)
    width, height = 64, 128
    tags = _tags(rng, width, height, 2)

    def shade(x, y):
        if (x, y) in tags:
            return tags[(x, y)]
        g = 0.33 + rng.uniform(-0.03, 0.03)
        if y < 8 and rng.random() < 0.5 - y / 16:
            return [0.28, 0.16, 0.09]  # Rust creeping up from the floor.
        if 40 <= y <= 46 and 10 <= x <= 52 and x % 4 < 2:
            g -= 0.12  # The vent slits of the door.
        if rng.random() < 0.02:
            g += 0.08  # Scratches showing bare metal.
        return [g * 0.9, g, g * 0.94]

    return _image("ruses_locker_tex", width, height, shade)


def bin_texture():
    """Dark green plastic, grime and tags, 2 x 1.25 m."""
    rng = random.Random(59)
    width, height = 128, 80
    tags = _tags(rng, width, height, 3)

    def shade(x, y):
        if (x, y) in tags:
            return tags[(x, y)]
        g = 0.2 + rng.uniform(-0.02, 0.02)
        if y < 12 and rng.random() < 0.4:
            g *= 0.6  # Grime at the bottom.
        return [g * 0.65, g, g * 0.75]

    return _image("ruses_bin_tex", width, height, shade)


def mats():
    return {
        "glass": material("ruses_glass_mat", glass_texture()),
        "clock": material("ruses_clock_mat", clock_texture()),
        "face": material("ruses_clock_face_mat", clock_face_texture()),
        "locker": material("ruses_locker_mat", locker_texture()),
        "bin": material("ruses_bin_mat", bin_texture()),
        "dark": material("ruses_dark_mat", _image("ruses_dark_tex", 4, 4, lambda x, y: [0.07, 0.07, 0.07])),
    }


def bottle(k):
    m = Model("bottle")
    m.box(-0.035, -0.035, 0.0, 0.035, 0.035, 0.17, k["glass"], stretch=True)
    m.box(-0.025, -0.025, 0.17, 0.025, 0.025, 0.2, k["glass"], stretch=True)  # Shoulder.
    m.box(-0.013, -0.013, 0.2, 0.013, 0.013, 0.26, k["glass"], stretch=True)  # Neck.
    return m


def glass_shards(k):
    m = Model("glass_shards")
    rng = random.Random(61)
    for _ in range(6):
        x, y = rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2)
        w, d = rng.uniform(0.02, 0.06), rng.uniform(0.015, 0.04)
        m.box(x - w, y - d, 0.0, x + w, y + d, 0.008, k["glass"], stretch=True)
    m.box(-0.03, 0.05, 0.0, 0.03, 0.12, 0.05, k["glass"], stretch=True)  # The bottom piece.
    return m


def alarm_clock(k):
    m = Model("alarm_clock")
    m.box(-0.06, -0.025, 0.02, 0.06, 0.025, 0.14, k["clock"], meters=0.1)  # Case.
    m.box(-0.045, -0.029, 0.035, 0.045, -0.025, 0.125, k["face"], stretch=True)  # Face, to -Y.
    for x in (-0.045, 0.045):
        m.box(x - 0.025, -0.02, 0.14, x + 0.025, 0.02, 0.17, k["clock"], meters=0.1)  # Bells.
        m.box(x - 0.008, -0.008, 0.0, x + 0.008, 0.008, 0.02, k["dark"])  # Feet.
    m.box(-0.006, -0.006, 0.17, 0.006, 0.006, 0.19, k["dark"])  # Hammer.
    m.box(-0.04, 0.02, 0.17, 0.04, 0.03, 0.18, k["dark"])  # Handle.
    return m


def closet(k):
    m = Model("closet")
    w, d, h = CLOSET
    m.box(-w / 2, -d / 2, 0.08, w / 2, d / 2, h, k["locker"], meters=(1.0, 2.0))  # Cabinet.
    m.box(-w / 2 + 0.03, -d / 2 - 0.02, 0.12, w / 2 - 0.03, -d / 2, h - 0.04, k["locker"], meters=(1.0, 2.0))  # Door.
    m.box(w / 2 - 0.12, -d / 2 - 0.05, 1.0, w / 2 - 0.08, -d / 2 - 0.02, 1.15, k["dark"])  # Handle.
    for x in (-w / 2 + 0.04, w / 2 - 0.08):  # Feet.
        for y in (-d / 2 + 0.04, d / 2 - 0.08):
            m.box(x, y, 0.0, x + 0.04, y + 0.04, 0.08, k["dark"])
    return m


def dumpster(k):
    m = Model("dumpster")
    w, d, h = DUMPSTER
    m.box(-w / 2, -d / 2, 0.15, w / 2, d / 2, h - 0.08, k["bin"], meters=(2.0, 1.25))  # Body.
    m.box(-w / 2 - 0.04, -d / 2 - 0.04, h - 0.08, w / 2 + 0.04, d / 2 + 0.04, h, k["bin"], meters=(2.0, 1.25))  # Lid.
    m.box(-w / 2 + 0.1, -d / 2 - 0.1, h - 0.2, w / 2 - 0.1, -d / 2 - 0.04, h - 0.14, k["dark"])  # Grip bar.
    for x in (-w / 2 + 0.1, w / 2 - 0.22):  # Wheels.
        for y in (-d / 2 + 0.08, d / 2 - 0.2):
            m.box(x, y, 0.0, x + 0.12, y + 0.12, 0.15, k["dark"])
    return m


BUILDERS = (bottle, glass_shards, alarm_clock, closet, dumpster)


if __name__ == "__main__":
    for leftover in list(bpy.data.objects):  # The default scene's cube, camera and light.
        bpy.data.objects.remove(leftover)
    k = mats()
    objects = []
    x = 0.0
    for builder in BUILDERS:
        objects.append(builder(k).build(offset_x=x))
        x += 3.0
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
