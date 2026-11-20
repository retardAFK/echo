"""Builds the models of the shopping gallery and the social centre (S-006, T-046).

- "shop_shutter": a shop front closed by a dented, tagged metal shutter,
- "shop_half": the same front, its middle shutter stuck 1.1 m up (the hunted
  crawls under it, the monster cannot),
- "laundrette": the glass front of the open laundrette, its door and its pale
  "LAVERIE" sign,
- "washers": two front-loading washing machines, side by side,
- "centre_window": the aluminium frame of a 2 m window of the social centre,
  without glass (the openings of the greybox stay open),
- "centre_entrance": the concrete canopy over the north door and its sign,
- "folding_table": a 2 x 1 m folding table of the great hall.
Dull colors only: orange is the noise color (constitution 2.3).

Origin at the bottom-left corner of the outer face, the outside faces -Y, as
the facade modules (facade.py). 64 px per meter where the texture repeats.
Run with the bpy module or inside Blender:
    python tools/blender/gallery.py -- <out.blend> <out_dir>
"""

import math
import os
import random
import sys

import bmesh
import bpy

SHOP_WIDTH = 8.4  # 42 m of gallery, 5 shops.
SHOP_HEIGHT = 3.2  # Under the arcade roof.
SHUTTER = (0.6, 7.8)  # x range of the shutters on a shop front.
HOUSING = 2.7  # Bottom of the shutter box.
# Seen from the arcade, x runs east to west: the openings of the greybox
# (build_tilleuls.gd, 2.0 to 5.0 m and 2.0 to 4.4 m from the west end of their
# shop) are measured here from the east end.
HALF_GAP = (3.4, 6.4, 1.1)  # x0, x1, bottom of the shutter left half up.
LAUNDRETTE_DOOR = (4.0, 6.4, 2.4)
GLASS_BOTTOM = 0.5
CENTRE_WINDOW = (2.0, 1.0, 2.4)  # width, sill, top.
CENTRE_DOOR = 2.2  # Width of the north entrance (160.4 to 162.6 on the plan).
PPM = 64
SHUTTER_TEXTURE = (8.0, 4.0)  # Meters covered by the shutter texture, across and up.

# Pixel font (5 x 7) for the signs, only the letters they need.
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    " ": ["00000"] * 7,
}
TAG_COLORS = ((0.06, 0.06, 0.07), (0.12, 0.17, 0.36), (0.38, 0.08, 0.09), (0.7, 0.7, 0.66))


# --- Textures ----------------------------------------------------------------


def _image(name, width, height, shade):
    img = bpy.data.images.get(name)
    if img:
        return img
    img = bpy.data.images.new(name, width, height)
    px = []
    for y in range(height):
        for x in range(width):
            c = shade(x, y)
            px += [c[0], c[1], c[2], 1.0]
    img.pixels = px
    img.pack()
    return img


def _tags(rng, width, height, count):
    """Pixels of scribbled tags: {(x, y): color}."""
    marks = {}
    for _ in range(count):
        color = TAG_COLORS[rng.randrange(len(TAG_COLORS))]
        x, y = rng.uniform(4, width - 40), rng.uniform(10, height * 0.6)
        heading = rng.uniform(-0.4, 0.4)
        for _ in range(rng.randint(60, 110)):
            heading += rng.uniform(-1.2, 1.2)
            x += math.cos(heading) * 1.4
            y += math.sin(heading) * 1.0
            for dx in (0, 1):
                marks[(int(x + dx) % width, int(y) % height)] = color
    return marks


def shutter_texture():
    """8 x 4 m of corrugated metal: slats every 8 cm, rust, dirt, tags."""
    rng = random.Random(21)
    size = 256
    tags = _tags(rng, 2 * size, size, 7)
    rust = {(rng.randrange(2 * size), rng.randrange(size)) for _ in range(1000)}

    def shade(x, y):
        if (x, y) in tags:
            return tags[(x, y)]
        g = 0.34 + rng.uniform(-0.03, 0.03)
        if y % 5 == 0:
            g -= 0.12  # Slat joint.
        elif y % 5 == 1:
            g += 0.05
        g *= 0.75 + 0.25 * min(1.0, y / 60.0)  # Dirt splashed at the bottom.
        if (x, y) in rust or (x, y - 1) in rust:
            return [0.28, 0.15, 0.08]
        return [g * 0.95, g, g * 0.97]

    return _image("gallery_shutter_tex", 2 * size, size, shade)


def concrete_texture():
    rng = random.Random(22)

    def shade(x, y):
        g = 0.42 + rng.uniform(-0.04, 0.04) - (0.08 if rng.random() < 0.05 else 0.0)
        g *= 0.8 + 0.2 * min(1.0, y / 50.0)
        return [g, g * 0.99, g * 0.95]

    return _image("gallery_concrete_tex", 128, 128, shade)


def frame_texture():
    rng = random.Random(23)
    return _image("gallery_frame_tex", 16, 16, lambda x, y: [0.5 + rng.uniform(-0.05, 0.03)] * 3)


def glass_texture(lit):
    rng = random.Random(24 if lit else 25)
    if lit:  # Pale cold light of the neon tubes inside the laundrette.
        return _image(
            "gallery_glass_lit_tex", 32, 32,
            lambda x, y: [0.3, 0.36, 0.42] if (x + 2 * y) % 29 > 3 else [0.38, 0.44, 0.5],
        )
    return _image(
        "gallery_glass_tex", 32, 32,
        lambda x, y: [0.04, 0.045, 0.06] if (x + y + rng.randrange(2)) % 23 > 2 else [0.09, 0.1, 0.12],
    )


def sign_texture(name, text, ink, back, width=256):
    """A sign: pixel letters, 2 px per font pixel, centred on a width x 32 board."""
    height, scale = 32, 2
    lit = set()
    text_width = len(text) * 6 * scale
    x0 = (width - text_width) // 2
    y0 = (height - 7 * scale) // 2
    for i, letter in enumerate(text):
        rows = FONT[letter]
        for row in range(7):
            for col in range(5):
                if rows[row][col] == "1":
                    for dx in range(scale):
                        for dy in range(scale):
                            lit.add((x0 + (i * 6 + col) * scale + dx, y0 + (6 - row) * scale + dy))

    def shade(x, y):
        return ink if (x, y) in lit else back

    return _image(name, width, height, shade)


def machine_texture():
    """Front of a washing machine: white enamel, dark round door, controls."""
    size = 32

    def shade(x, y):
        dx, dy = x - 16, y - 13
        d = math.hypot(dx, dy)
        if d < 8:
            return [0.12, 0.14, 0.17] if d < 6.5 else [0.55, 0.56, 0.56]
        if y > 27:
            return [0.3, 0.32, 0.34] if x % 6 < 3 else [0.6, 0.6, 0.58]
        return [0.68, 0.68, 0.64]

    return _image("gallery_machine_tex", size, size, shade)


def table_texture():
    rng = random.Random(26)
    return _image(
        "gallery_table_tex", 32, 32,
        lambda x, y: [0.42 + rng.uniform(-0.03, 0.03), 0.38, 0.3] if y % 9 else [0.3, 0.27, 0.21],
    )


# --- Geometry ----------------------------------------------------------------


def material(name, img, emission=None):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    if emission:
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


class Model:
    """A mesh made of boxes, each face mapped by world projection or stretched."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        self.materials = []

    def _slot(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def box(self, x0, y0, z0, x1, y1, z1, mat, meters=4.0, stretch=False):
        before = set(self.bm.faces)
        box = bmesh.ops.create_cube(self.bm, size=1.0)
        for v in box["verts"]:
            v.co.x = x0 if v.co.x < 0 else x1
            v.co.y = y0 if v.co.y < 0 else y1
            v.co.z = z0 if v.co.z < 0 else z1
        faces = set(self.bm.faces) - before
        self.bm.normal_update()
        slot = self._slot(mat)
        for f in faces:
            f.material_index = slot
            axis = max(range(3), key=lambda i: abs(f.normal[i]))
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
            lo = (x0, y0, z0)
            hi = (x1, y1, z1)
            for loop in f.loops:
                co = loop.vert.co
                if stretch:
                    u = (co[a] - lo[a]) / max(hi[a] - lo[a], 1e-6)
                    v = (co[b] - lo[b]) / max(hi[b] - lo[b], 1e-6)
                else:
                    mu, mv = meters if isinstance(meters, tuple) else (meters, meters)
                    u, v = co[a] / mu, co[b] / mv
                loop[self.uv].uv = (u, v)
        return faces

    def cylinder(self, center, radius, length, axis, mat, segments=12, meters=1.0):
        """A prism of `segments` sides along axis "x", "y" or "z", its faces
        mapped by world projection like box() (wheels, S-020, T-324)."""
        before = set(self.bm.faces)
        made = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length
        )
        for v in made["verts"]:
            x, y, z = v.co
            if axis == "x":
                x, y, z = z, y, x
            elif axis == "y":
                x, y, z = x, z, y
            v.co = (x + center[0], y + center[1], z + center[2])
        faces = set(self.bm.faces) - before
        bmesh.ops.recalc_face_normals(self.bm, faces=list(faces))  # The swap mirrors them.
        self.bm.normal_update()
        slot = self._slot(mat)
        for f in faces:
            f.material_index = slot
            axis_index = max(range(3), key=lambda i: abs(f.normal[i]))
            a, b = [(1, 2), (0, 2), (0, 1)][axis_index]
            for loop in f.loops:
                co = loop.vert.co
                loop[self.uv].uv = (co[a] / meters, co[b] / meters)
        return faces

    def build(self, offset_x=0.0):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location.x = offset_x
        bpy.context.collection.objects.link(obj)
        return obj


def mats():
    return {
        "shutter": material("gallery_shutter_mat", shutter_texture()),
        "concrete": material("gallery_concrete_mat", concrete_texture()),
        "frame": material("gallery_frame_mat", frame_texture()),
        "glass": material("gallery_glass_mat", glass_texture(False)),
        "glass_lit": material("gallery_glass_lit_mat", glass_texture(True), emission=0.35),
        "laverie": material(
            "gallery_sign_laverie_mat",
            sign_texture("gallery_sign_laverie_tex", "LAVERIE", [0.75, 0.85, 0.95], [0.08, 0.09, 0.1]),
            emission=1.0,
        ),
        "centre": material(
            "gallery_sign_centre_mat",
            sign_texture("gallery_sign_centre_tex", "CENTRE SOCIAL J-MOULIN", [0.9, 0.85, 0.7], [0.16, 0.2, 0.3], 512),
            emission=0.5,
        ),
        "machine": material("gallery_machine_mat", machine_texture()),
        "enamel": material(
            "gallery_enamel_mat", _image("gallery_enamel_tex", 8, 8, lambda x, y: [0.66, 0.66, 0.62 + 0.02 * (x % 2)])
        ),
        "table": material("gallery_table_mat", table_texture()),
    }


def _housing(m, k):
    """Shutter box and side rails over the whole shop front."""
    m.box(SHUTTER[0] - 0.1, -0.3, HOUSING, SHUTTER[1] + 0.1, 0.0, SHOP_HEIGHT - 0.1, k["shutter"])
    for x in SHUTTER:
        m.box(x - 0.1, -0.12, 0.0, x + 0.02, 0.0, HOUSING, k["frame"])
    # Concrete fascia above, and the piers at both ends.
    m.box(0.0, -0.05, SHOP_HEIGHT - 0.1, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(0.0, -0.08, 0.0, SHUTTER[0] - 0.1, 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(SHUTTER[1] + 0.1, -0.08, 0.0, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])


def shop_shutter(k):
    m = Model("gallery_shop_shutter")
    _housing(m, k)
    m.box(SHUTTER[0], -0.08, 0.0, SHUTTER[1], -0.04, HOUSING, k["shutter"], meters=SHUTTER_TEXTURE)
    return m


def shop_half(k):
    m = Model("gallery_shop_half")
    _housing(m, k)
    x0, x1, bottom = HALF_GAP
    m.box(SHUTTER[0], -0.08, 0.0, x0, -0.04, HOUSING, k["shutter"], meters=SHUTTER_TEXTURE)
    m.box(x1, -0.08, 0.0, SHUTTER[1], -0.04, HOUSING, k["shutter"], meters=SHUTTER_TEXTURE)
    m.box(x0, -0.08, bottom, x1, -0.04, HOUSING, k["shutter"], meters=SHUTTER_TEXTURE)
    m.box(x0, -0.1, bottom - 0.05, x1, -0.02, bottom, k["frame"])  # Bottom bar, bent.
    return m


def laundrette(k):
    m = Model("gallery_laundrette")
    x0, x1, top = LAUNDRETTE_DOOR
    # Concrete fascia and piers, a low wall under the windows.
    m.box(0.0, -0.05, SHOP_HEIGHT - 0.1, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(0.0, -0.08, 0.0, SHUTTER[0], 0.0, SHOP_HEIGHT, k["concrete"])
    m.box(SHUTTER[1], -0.08, 0.0, SHOP_WIDTH, 0.0, SHOP_HEIGHT, k["concrete"])
    for a, b in ((SHUTTER[0], x0), (x1, SHUTTER[1])):
        m.box(a, -0.1, 0.0, b, 0.0, GLASS_BOTTOM, k["concrete"])
        m.box(a, -0.06, GLASS_BOTTOM, b, -0.04, top, k["glass_lit"], stretch=True)
        for x in (a, (a + b) / 2, b):  # Mullions.
            m.box(x - 0.04, -0.09, GLASS_BOTTOM, x + 0.04, -0.03, top, k["frame"])
        m.box(a, -0.09, GLASS_BOTTOM - 0.04, b, -0.03, GLASS_BOTTOM + 0.04, k["frame"])
    # Door frame, the door itself stays open (a hole in the greybox wall).
    for x in (x0, x1):
        m.box(x - 0.06, -0.1, 0.0, x + 0.06, -0.02, top, k["frame"])
    m.box(SHUTTER[0], -0.1, top, SHUTTER[1], -0.02, top + 0.08, k["frame"])
    # Glass above the door line, then the sign.
    m.box(SHUTTER[0], -0.06, top + 0.08, SHUTTER[1], -0.04, HOUSING, k["glass_lit"], stretch=True)
    m.box(1.0, -0.25, HOUSING, 7.4, -0.05, SHOP_HEIGHT - 0.1, k["frame"])  # Sign box.
    m.box(1.0, -0.26, HOUSING, 7.4, -0.25, SHOP_HEIGHT - 0.1, k["laverie"], stretch=True)
    return m


def washers(k):
    m = Model("gallery_washers")
    for i in range(2):
        x = i * 0.62
        m.box(x, 0.02, 0.0, x + 0.6, 0.65, 0.85, k["enamel"])
        m.box(x, 0.0, 0.0, x + 0.6, 0.02, 0.85, k["machine"], stretch=True)  # Front.
        m.box(x + 0.02, 0.04, 0.85, x + 0.58, 0.63, 0.88, k["frame"])
    return m


def centre_window(k):
    m = Model("centre_window")
    width, sill, top = CENTRE_WINDOW
    bar = 0.06
    for x in (0.0, width / 2 - bar / 2, width - bar):  # Frame and mullion.
        m.box(x, -0.02, sill, x + bar, 0.06, top, k["frame"])
    for z in (sill, (sill + top) / 2, top - bar):
        m.box(0.0, -0.02, z, width, 0.06, z + bar, k["frame"])
    m.box(-0.1, -0.15, sill - 0.08, width + 0.1, 0.06, sill, k["concrete"])  # Sill.
    return m


def centre_entrance(k):
    m = Model("centre_entrance")
    width = CENTRE_DOOR
    m.box(-0.8, -1.4, 2.6, width + 0.8, 0.0, 2.8, k["concrete"])  # Canopy.
    for x in (-0.7, width + 0.55):
        m.box(x, -1.35, 0.0, x + 0.15, -1.2, 2.6, k["frame"])  # Posts.
    m.box(-1.4, -0.06, 2.85, width + 1.4, 0.0, 3.35, k["frame"])  # Sign board.
    m.box(-1.4, -0.07, 2.85, width + 1.4, -0.06, 3.35, k["centre"], stretch=True)
    for x in (0.0, width - 0.06):  # Door frame.
        m.box(x, -0.04, 0.0, x + 0.06, 0.02, 2.4, k["frame"])
    return m


def folding_table(k):
    m = Model("folding_table")
    m.box(-1.0, -0.5, 0.71, 1.0, 0.5, 0.75, k["table"])
    for x in (-0.9, 0.86):
        m.box(x, -0.45, 0.0, x + 0.04, 0.45, 0.04, k["frame"])
        m.box(x, -0.02, 0.0, x + 0.04, 0.02, 0.71, k["frame"])
    return m


BUILDERS = (shop_shutter, shop_half, laundrette, washers, centre_window, centre_entrance, folding_table)


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if __name__ == "__main__":
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
