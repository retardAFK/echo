"""Builds the models of the prison and the network of the cité (S-018, T-269).

- "terminal": an old beige PC on a worn wooden desk, its CRT monitor, its
  keyboard, a mouse and the tower; the screen itself stays a quad of the
  Terminal scene (it lights up),
- "security_camera": a grey box camera with its sun hood, its lens and the
  arm that holds it to the wall (the lens toward +Y: Godot -Z, as its Lens),
- "loudspeaker": a cheap metal PA cabinet with a perforated grille,
- "cage_gate": the barred gate of a cellar cage, 1.4 x 2.8 m, its lock,
- "cage_lamp": the caged bulkhead lamp over a cage (its color is set by the
  Cage: lit or not),
- "relay_box": the grey electrical box of a relay switch, its conduit and
  its warning sticker,
- "relay_lever": the red handle of the relay switch,
- "floppy_disk": a dark blue 3.5 inch floppy disk, its metal shutter and its
  label,
- "post_it": a yellow lined note the code is written on.
Each model has one material, its own small texture atlas: one draw call.
In Godot, -Y becomes +Z: the fronts face -Y here, +Z there.
Dull colors only: orange is the noise color (constitution 2.3).
    python tools/blender/network.py -- <out.blend> <out_dir>
"""

import os
import random
import sys

import bpy  # noqa: I001 (bpy first: it makes bmesh importable)
import bmesh  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gallery import material, triangle_count  # noqa: E402

rng = random.Random(2018)


class Atlas:
    """Named texture regions packed side by side in one image."""

    def __init__(self, name, regions):
        """regions: [(name, width, height, shade(x, y) -> rgb)]."""
        width = sum(r[1] for r in regions)
        height = max(r[2] for r in regions)
        self.rects = {}
        px = [0.0] * (width * height * 4)
        x0 = 0
        for key, w, h, shade in regions:
            for y in range(h):
                for x in range(w):
                    c = shade(x, y)
                    i = (y * width + x0 + x) * 4
                    px[i : i + 4] = [c[0], c[1], c[2], 1.0]
            self.rects[key] = (x0 / width, 0.0, (x0 + w) / width, h / height)
            x0 += w
        img = bpy.data.images.new(name + "_tex", width, height)
        img.pixels = px
        img.pack()
        self.material = material(name + "_mat", img)


class Model:
    """Boxes, each face stretched over a region of the model's atlas."""

    def __init__(self, name, atlas):
        self.name = name
        self.atlas = atlas
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def box(self, x0, y0, z0, x1, y1, z1, region, faces=None):
        """faces: {"front"|"back"|"left"|"right"|"top"|"bottom": region} overrides."""
        before = set(self.bm.faces)
        cube = bmesh.ops.create_cube(self.bm, size=1.0)
        for v in cube["verts"]:
            v.co.x = x0 if v.co.x < 0 else x1
            v.co.y = y0 if v.co.y < 0 else y1
            v.co.z = z0 if v.co.z < 0 else z1
        self.bm.normal_update()
        lo, hi = (x0, y0, z0), (x1, y1, z1)
        for f in set(self.bm.faces) - before:
            n = f.normal
            axis = max(range(3), key=lambda i: abs(n[i]))
            side = {
                (0, True): "right",
                (0, False): "left",
                (1, True): "back",
                (1, False): "front",
                (2, True): "top",
                (2, False): "bottom",
            }[(axis, n[axis] > 0)]
            u0, v0, u1, v1 = self.atlas.rects[(faces or {}).get(side, region)]
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
            for loop in f.loops:
                co = loop.vert.co
                s = (co[a] - lo[a]) / max(hi[a] - lo[a], 1e-6)
                t = (co[b] - lo[b]) / max(hi[b] - lo[b], 1e-6)
                if side in ("back", "left"):
                    s = 1.0 - s  # Seen from outside, left to right.
                loop[self.uv].uv = (u0 + (u1 - u0) * s, v0 + (v1 - v0) * t)

    def build(self, offset_x=0.0):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(self.atlas.material)
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location.x = offset_x
        bpy.context.collection.objects.link(obj)
        return obj


# --- Shading helpers -----------------------------------------------------------


def _noisy(base, amount, seed):
    r = random.Random(seed)

    def shade(x, y):
        k = 1.0 + r.uniform(-amount, amount)
        return [c * k for c in base]

    return shade


def _flat(color):
    return lambda x, y: color


# --- Terminal ------------------------------------------------------------------

BEIGE = (0.6, 0.56, 0.45)


def _wood(x, y):
    """Worn desk top: grain along x, scratches, a coffee ring."""
    g = 0.3 + 0.03 * ((x * 7 + y * 31) % 5) / 4 + (0.02 if y % 3 == 0 else 0.0)
    if (x - 20) ** 2 + (y - 9) ** 2 in range(9, 14):
        g -= 0.08  # The ring of a mug.
    if rng.random() < 0.015:
        g += 0.1
    return [g * 1.1, g * 0.88, g * 0.62]


def _keys(x, y):
    """Rows of dirty beige keys over a darker frame, 32 x 12 px."""
    if 1 <= y <= 10 and 1 <= x <= 30 and x % 2 == 1 and y % 2 == 1:
        g = 0.62 if rng.random() > 0.15 else 0.5
        return [g, g * 0.95, g * 0.8]
    if y == 1 and 10 <= x <= 22:
        return [0.6, 0.57, 0.46]  # The space bar.
    return [0.38, 0.36, 0.3]


def _bezel(x, y):
    """The monitor's front: beige plastic, the dark hole of the tube, a logo."""
    if 3 <= x <= 28 and 5 <= y <= 25:
        return [0.05, 0.06, 0.05]
    if y == 2 and 4 <= x <= 7:
        return [0.25, 0.25, 0.22]  # The brand, worn off.
    if y == 2 and x == 26:
        return [0.15, 0.4, 0.18]  # The power LED.
    return [c * (1.0 + rng.uniform(-0.03, 0.03)) for c in BEIGE]


def _vents(x, y):
    if y % 3 == 0 and 2 <= x <= 13:
        return [0.28, 0.26, 0.21]
    return [c * 0.92 for c in BEIGE]


def _tower(x, y):
    """The tower's front: a floppy slot, a CD drive, the power button."""
    if 2 <= x <= 13 and 24 <= y <= 27:
        return [0.5, 0.47, 0.38]  # CD drive.
    if 3 <= x <= 12 and y == 21:
        return [0.08, 0.08, 0.08]  # Floppy slot.
    if 6 <= x <= 9 and 6 <= y <= 8:
        return [0.4, 0.38, 0.31]  # Power button.
    if y % 4 == 0 and y < 5:
        return [0.4, 0.37, 0.3]
    return [c * (1.0 + rng.uniform(-0.03, 0.03)) for c in BEIGE]


def terminal():
    atlas = Atlas(
        "network_terminal",
        [
            ("wood", 32, 16, _wood),
            ("wood_dark", 4, 4, _noisy([0.2, 0.16, 0.11], 0.08, 1)),
            ("beige", 8, 8, _noisy(list(BEIGE), 0.03, 2)),
            ("vents", 16, 16, _vents),
            ("keys", 32, 12, _keys),
            ("bezel", 32, 30, _bezel),
            ("tower", 16, 32, _tower),
            ("dark", 4, 4, _flat([0.1, 0.1, 0.09])),
        ],
    )
    m = Model("terminal", atlas)
    # The desk: Godot (x, y, z) = (x, z, -y) here; its front edge at y = 0.
    m.box(-0.6, 0.0, 0.72, 0.6, 0.6, 0.75, "wood_dark", {"top": "wood"})
    for x in (-0.57, 0.52):
        for y in (0.03, 0.52):
            m.box(x, y, 0.0, x + 0.05, y + 0.05, 0.72, "wood_dark")
    m.box(-0.55, 0.54, 0.3, 0.55, 0.57, 0.72, "wood_dark")  # Modesty panel.
    m.box(0.22, 0.02, 0.42, 0.55, 0.56, 0.72, "wood_dark", {"front": "wood"})  # Drawers.
    # The CRT monitor: its front at y = 0.17, the screen quad just in front.
    m.box(-0.23, 0.17, 0.77, 0.23, 0.3, 1.15, "beige", {"front": "bezel"})
    m.box(-0.18, 0.3, 0.81, 0.18, 0.56, 1.11, "vents", {"right": "beige", "left": "beige"})
    m.box(-0.1, 0.24, 0.75, 0.1, 0.44, 0.77, "beige")  # Its foot.
    # The keyboard and the mouse.
    m.box(-0.22, 0.02, 0.75, 0.22, 0.18, 0.79, "beige", {"top": "keys"})
    m.box(0.3, 0.06, 0.75, 0.36, 0.15, 0.775, "beige")
    # The tower, on the left of the desk.
    m.box(-0.58, 0.12, 0.75, -0.4, 0.56, 1.17, "beige", {"front": "tower", "left": "vents"})
    m.box(-0.3, 0.45, 0.75, 0.3, 0.6, 0.755, "dark")  # Cables behind.
    return m


# --- Camera, loudspeaker -------------------------------------------------------


def security_camera():
    atlas = Atlas(
        "network_camera",
        [
            ("grey", 8, 8, _noisy([0.55, 0.55, 0.52], 0.05, 3)),
            ("dirty", 8, 8, _noisy([0.42, 0.42, 0.39], 0.12, 4)),
            ("lens", 8, 8, lambda x, y: [0.03, 0.03, 0.04] if (x - 3.5) ** 2 + (y - 3.5) ** 2 < 9 else [0.2] * 3),
            ("metal", 4, 4, _noisy([0.3, 0.3, 0.29], 0.1, 5)),
        ],
    )
    m = Model("security_camera", atlas)
    # Body centred on the origin, the lens toward +Y here (Godot -Z, its Lens node).
    m.box(-0.08, -0.16, -0.07, 0.08, 0.16, 0.07, "grey", {"top": "dirty"})
    m.box(-0.095, -0.14, 0.07, 0.095, 0.2, 0.085, "dirty")  # The sun hood.
    m.box(-0.05, 0.16, -0.05, 0.05, 0.19, 0.05, "metal", {"back": "lens"})
    m.box(-0.02, -0.3, -0.02, 0.02, -0.16, 0.02, "metal")  # The arm.
    m.box(-0.06, -0.32, -0.08, 0.06, -0.3, 0.08, "metal")  # Its wall plate.
    return m


def _grille(x, y):
    """Perforated steel: dark holes in a grid, a rim."""
    if x in (0, 19) or y in (0, 25):
        return [0.22, 0.22, 0.21]
    if x % 2 == 1 and y % 2 == 1:
        return [0.04, 0.04, 0.04]
    return [0.28, 0.28, 0.27]


def loudspeaker():
    atlas = Atlas(
        "network_speaker",
        [
            ("cabinet", 8, 8, _noisy([0.18, 0.18, 0.17], 0.1, 6)),
            ("grille", 20, 26, _grille),
            ("metal", 4, 4, _noisy([0.35, 0.35, 0.33], 0.1, 7)),
        ],
    )
    m = Model("loudspeaker", atlas)
    # Hung on a wall behind it (+Y here), its front at y = 0.
    m.box(-0.16, 0.02, -0.21, 0.16, 0.2, 0.21, "cabinet")
    m.box(-0.15, 0.0, -0.2, 0.15, 0.02, 0.2, "cabinet", {"front": "grille"})
    m.box(-0.03, 0.2, -0.06, 0.03, 0.22, 0.06, "metal")  # The bracket.
    return m


# --- Prison --------------------------------------------------------------------


def _steel(x, y):
    g = 0.17 + rng.uniform(-0.02, 0.02)
    if rng.random() < 0.12:
        return [0.26, 0.15, 0.09]  # Rust.
    return [g, g * 1.02, g * 1.06]


def cage_gate():
    atlas = Atlas(
        "prison_gate",
        [
            ("steel", 16, 16, _steel),
            ("lock", 8, 8, lambda x, y: [0.08, 0.08, 0.08] if x in (3, 4) and 2 <= y <= 5 else [0.24, 0.24, 0.22]),
        ],
    )
    m = Model("cage_gate", atlas)
    w, h, t = 0.7, 1.4, 0.025  # Centred: 1.4 x 2.8 m.
    m.box(-w, -t, -h, w, t, -h + 0.06, "steel")  # Frame.
    m.box(-w, -t, h - 0.06, w, t, h, "steel")
    m.box(-w, -t, -h, -w + 0.06, t, h, "steel")
    m.box(w - 0.06, -t, -h, w, t, h, "steel")
    for z in (-0.45, 0.5):
        m.box(-w, -t * 0.8, z - 0.025, w, t * 0.8, z + 0.025, "steel")
    x = -w + 0.17
    while x < w - 0.1:
        m.box(x - 0.012, -0.012, -h, x + 0.012, 0.012, h, "steel")
        x += 0.12
    m.box(w - 0.2, -0.05, -0.15, w - 0.06, 0.05, 0.05, "steel", {"front": "lock", "back": "lock"})
    return m


def cage_lamp():
    atlas = Atlas("prison_lamp", [("white", 4, 4, _flat([0.8, 0.8, 0.78]))])
    m = Model("cage_lamp", atlas)
    m.box(-0.15, -0.06, 0.02, 0.15, 0.06, 0.04, "white")  # Base on the ceiling.
    m.box(-0.12, -0.05, -0.04, 0.12, 0.05, 0.02, "white")  # Glass.
    for x in (-0.08, 0.0, 0.08):
        m.box(x - 0.006, -0.065, -0.05, x + 0.006, 0.065, 0.03, "white")  # Wire cage.
    return m


# --- Objectives ----------------------------------------------------------------


def _box_front(x, y):
    """Grey cabinet front, a yellow-black warning triangle, a worn label."""
    if 8 <= y <= 14 and abs(x - 9.5) <= (14 - y) * 0.6 + 0.5:
        if abs(x - 9.5) >= (14 - y) * 0.6 - 0.8 or y == 8:
            return [0.08, 0.08, 0.07]
        return [0.65, 0.58, 0.16]
    if 20 <= y <= 22 and 3 <= x <= 16:
        return [0.7, 0.68, 0.6]  # The label: RELAIS.
    return [0.4 + rng.uniform(-0.02, 0.02), 0.42, 0.38]


def relay_box():
    atlas = Atlas(
        "relay_box",
        [
            ("grey", 8, 8, _noisy([0.4, 0.42, 0.38], 0.06, 8)),
            ("front", 20, 26, _box_front),
            ("conduit", 4, 4, _noisy([0.32, 0.33, 0.31], 0.1, 9)),
        ],
    )
    m = Model("relay_box", atlas)
    # On a wall behind it (+Y), its front at y = -0.14; floor at z = 0.
    m.box(-0.15, -0.14, 1.1, 0.15, 0.0, 1.5, "grey", {"front": "front"})
    m.box(-0.02, -0.09, 1.5, 0.02, -0.05, 2.4, "conduit")
    return m


def relay_lever():
    atlas = Atlas(
        "relay_lever",
        [("red", 4, 4, _noisy([0.55, 0.07, 0.05], 0.1, 10)), ("black", 4, 4, _flat([0.06, 0.06, 0.06]))],
    )
    m = Model("relay_lever", atlas)
    m.box(-0.015, -0.015, -0.01, 0.015, 0.015, 0.16, "red")
    m.box(-0.025, -0.025, 0.16, 0.025, 0.025, 0.22, "black")  # The grip.
    return m


def _floppy(x, y):
    """Top of the disk, 18 x 18 px: shutter, label, write-protect hole."""
    if 5 <= x <= 12 and y >= 12:
        return [0.6, 0.62, 0.64] if x != 9 else [0.3, 0.3, 0.32]  # The shutter.
    if 3 <= x <= 14 and 1 <= y <= 9:
        if y in (4, 6) and 4 <= x <= 12:
            return [0.25, 0.25, 0.4]  # Handwriting.
        return [0.82, 0.8, 0.72]  # The label.
    if x == 16 and y == 1:
        return [0.02, 0.02, 0.03]
    return [0.1, 0.12, 0.22]


def floppy_disk():
    atlas = Atlas("floppy_disk", [("top", 18, 18, _floppy), ("edge", 4, 4, _flat([0.08, 0.09, 0.17]))])
    m = Model("floppy_disk", atlas)
    m.box(-0.045, -0.045, 0.001, 0.045, 0.045, 0.007, "edge", {"top": "top"})
    return m


def _note(x, y):
    """Yellow lined paper, 22 x 22 px, a shadow where it curls."""
    g = [0.86, 0.79, 0.36]
    if y % 4 == 1 and y < 19:
        g = [0.72, 0.7, 0.42]
    if y >= 19:
        g = [0.8, 0.72, 0.3]  # The glue strip.
    if x + y > 38:
        g = [c * 0.8 for c in g]  # Curled corner.
    return g


def post_it():
    atlas = Atlas("post_it", [("note", 22, 22, _note)])
    m = Model("post_it", atlas)
    m.box(-0.11, -0.003, -0.11, 0.11, -0.001, 0.11, "note")
    return m


BUILDERS = [
    terminal,
    security_camera,
    loudspeaker,
    cage_gate,
    cage_lamp,
    relay_box,
    relay_lever,
    floppy_disk,
    post_it,
]


if __name__ == "__main__":
    for leftover in list(bpy.data.objects):
        bpy.data.objects.remove(leftover)
    objects = []
    x = 0.0
    for builder in BUILDERS:
        objects.append(builder().build(offset_x=x))
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
