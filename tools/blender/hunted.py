"""Builds the three hunted of S-011 (T-124, T-125), rigged and animated.

The three are designated by their role only: "ambulancier" (former paramedic,
blue), "parka" (young woman in a parka, green), "masque" (old lineman in a
full gas mask, white). Validated by Maxime on 14/11/2026 (S-011 Q1).

Each hunted starts from a sculpted base body of the Universal Base Characters
by Quaternius (CC0, UE-style 65-bone skeleton), kept in art_src/quaternius_ubc:
- the body is decimated to a PS1 budget, then each body region (torso, arms,
  legs, boots, hands, head) found from the skin weights gets a cloth material
  and is pushed out along its normals (the clothes),
- garments (coat skirts, hood, plate, mask, packs, belts) are lofted tubes,
  weighted to a single bone and joined to the body: one skinned mesh,
- textures: grimy 64 px cloth tiles projected on cube UVs (about 3 tiles per
  meter), the base skin reduced to 256 px; Nearest filtering everywhere,
- animations keyed on the skeleton (S-011 Q4): idle, walk, run, crouch,
  crouch_idle, kneel. Loops; Godot plays them by name (HuntedBody).
Player colour on an armband and a small LED; never orange (noise) nor red
(the monster) on a hunted. Model faces +Y in Blender: forward (-Z) in Godot.

    python tools/blender/hunted.py -- <out_blend_dir> <out_dir> [role ...]
"""

import math
import os
import sys
import tempfile

import bpy  # isort: skip  (bpy first: the bpy module provides bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
UBC = os.path.join(HERE, "..", "..", "art_src", "quaternius_ubc")
BASE = os.path.join(UBC, "base")
HAIR = os.path.join(UBC, "hair")
TMP = tempfile.mkdtemp(prefix="hunted_")

N = 64  # Cloth texture size.
SKIN_SIZE = 256
TILES_PER_METER = 3.0
FPS = 30
BUDGET = 2500

BLUE = (0.16, 0.34, 0.62)
GREEN = (0.22, 0.6, 0.38)
WHITE = (0.8, 0.82, 0.8)

RNG = np.random.default_rng(7)
PARTS = []
FABRIC = {}  # Material name -> (rgb, kind).

# ------------------------------------------------------------ textures


def vnoise(cells):
    g = RNG.random((cells + 1, cells + 1))
    x = np.linspace(0, cells, N, endpoint=False)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    a = g[i][:, i]
    b = g[i][:, i + 1]
    c = g[i + 1][:, i]
    d = g[i + 1][:, i + 1]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(base=4, octaves=4):
    out, amp, tot = np.zeros((N, N)), 1.0, 0.0
    for o in range(octaves):
        out += vnoise(min(base * 2**o, N // 2)) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def lines(count):
    """Random wandering lines (scratches)."""
    m = np.zeros((N, N))
    for _ in range(count):
        x, y = RNG.integers(0, N, 2).astype(float)
        ang = RNG.random() * 6.28
        for _ in range(RNG.integers(15, 40)):
            m[int(y) % N, int(x) % N] = 1
            ang += RNG.normal(0, 0.5)
            x += np.cos(ang)
            y += np.sin(ang)
    return m


def tex_for(rgb, kind):
    """Grimy cloth tile: weave or knit or streaks, wear, scuffs, stains."""
    c = np.array(rgb)
    n = fbm(4, 3)
    img = c[None, None, :] * (0.82 + 0.36 * n[..., None])
    if kind == "hair":
        streak = np.tile(RNG.random((1, N)), (N, 1))
        img *= (0.75 + 0.5 * streak)[..., None]
    elif kind == "knit":
        rib = (np.arange(N) % 4 < 2)[None, :]
        img *= np.where(rib, 1.1, 0.85)[..., None]
    elif kind == "canvas":
        weave = np.arange(N)[:, None] % 2 == 0
        img *= np.where(weave, 1.05, 0.95)[..., None]
        img[:, 20] *= 0.6
        img[44, :] *= 0.6
    elif kind == "plastic":
        img = c[None, None, :] * (0.95 + 0.1 * n[..., None])
    img[fbm(8, 2) > 0.7] *= 0.78
    img *= (0.86 + 0.2 * fbm(5, 3))[..., None]
    scuff = lines(10) > 0
    img[scuff] = img[scuff] * 0.6 + 0.12
    stain = fbm(3, 2) > 0.62
    img[stain] = img[stain] * 0.85 + np.array([0.012, 0.01, 0.005])
    if kind == "plate":
        edge = np.zeros((N, N), bool)
        edge[:2, :] = edge[-2:, :] = edge[:, :2] = edge[:, -2:] = True
        img[edge] = img[edge] * 0.4 + 0.25
        for x, y in ((6, 6), (6, 57), (57, 6), (57, 57)):
            img[y - 1 : y + 2, x - 1 : x + 2] = (0.5, 0.5, 0.48)  # Rivets.
    return np.clip(img, 0, 1)


def image(name, rgb):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], axis=2)
    img.pixels = rgba[::-1].ravel()  # Blender rows start at the bottom.
    img.pack()
    return img


def textured(m, img, rough):
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Closest"
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])


def mat(name, rgb, rough=0.9, emit=None):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit[0], 1)
        b.inputs["Emission Strength"].default_value = emit[1]
    return m


def cloth(name, rgb, kind="fabric", rough=0.85):
    """Material with a grimy 64 px tile (cube UVs set by Char.uv_cloth)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = mat(name, rgb, rough)
    FABRIC[name] = kind
    textured(m, image("tx_" + name, tex_for(rgb, kind)), rough)
    return m


def skin_mat(name, path, tint):
    """The base skin, reduced to 256 px, tint baked into the pixels."""
    from PIL import Image

    im = Image.open(path).convert("RGB").resize((SKIN_SIZE, SKIN_SIZE), Image.LANCZOS)
    rgb = np.asarray(im, dtype=float) / 255.0 * np.array(tint)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    textured(m, image("tx_" + name, rgb), 0.6)
    return m


def accent(rgb):
    """Player colour: matte armband + small LED, never orange or red."""
    key = "%d%d%d" % tuple(int(c * 9) for c in rgb)
    return cloth("acc_" + key, rgb), mat("led_" + key, rgb, emit=(rgb, 18))


# ------------------------------------------------------------ geometry


def add(obj, m):
    obj.data.materials.append(m)
    PARTS.append(obj)
    return obj


def box(loc, size, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    return add(o, m)


def ball(loc, r, m, seg=6, rings_=3):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings_, radius=r, location=loc)
    return add(bpy.context.object, m)


def loft(points, radii, m, verts=8, front=(0, 1, 0), cap=(True, True)):
    """Tube through points; radii[i] = (rx side, ry front)."""
    pts = [Vector(p) for p in points]
    fr = Vector(front)
    vs, fs = [], []
    n = len(pts)
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        f = fr - t * fr.dot(t)
        if f.length < 1e-3:
            f = Vector((0, 0, 1)) - t * t.z
        f.normalize()
        s = f.cross(t).normalized()
        rx, ry = radii[i]
        for k in range(verts):
            ang = 2 * math.pi * k / verts + math.pi / verts
            vs.append(c + s * rx * math.cos(ang) + f * ry * math.sin(ang))
    for i in range(n - 1):
        for k in range(verts):
            a0 = i * verts + k
            a1 = i * verts + (k + 1) % verts
            fs.append((a0, a1, a1 + verts, a0 + verts))
    if cap[0]:
        fs.append(tuple(reversed(range(verts))))
    if cap[1]:
        fs.append(tuple(range((n - 1) * verts, n * verts)))
    me = bpy.data.meshes.new("loft")
    me.from_pydata([tuple(v) for v in vs], [], fs)
    me.update()
    o = bpy.data.objects.new("loft", me)
    bpy.context.collection.objects.link(o)
    return add(o, m)


def rings(z_r, m, verts=10, cap=(True, True)):
    """Vertical loft from (z, rx, ry, y) tuples."""
    return loft([(0, r[3], r[0]) for r in z_r], [(r[1], r[2]) for r in z_r], m, verts, cap=cap)


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def select(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def decimate(o, ratio):
    select([o], o)
    md = o.modifiers.new("dec", "DECIMATE")
    md.ratio = ratio
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
    bpy.ops.object.modifier_apply(modifier="dec")


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


REGION_OF = {"pelvis": "hips", "neck_01": "head", "Head": "head"}
for _b in ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"):
    REGION_OF[_b] = "torso"
for _s in ("l", "r"):
    REGION_OF["upperarm_" + _s] = "uarm"
    REGION_OF["lowerarm_" + _s] = "farm"
    REGION_OF["thigh_" + _s] = "thigh"
    REGION_OF["calf_" + _s] = "calf"
    REGION_OF["foot_" + _s] = "foot"
    REGION_OF["ball_" + _s] = "foot"


def region_name(bone):
    if bone in REGION_OF:
        return REGION_OF[bone]
    if bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")):
        return "hand"
    return "torso"


# ------------------------------------------------------------ character


class Char:
    """A base body to dress: armature + body mesh, facing -Y, T-pose."""

    def __init__(self, female, height):
        name = "Superhero_Female_FullBody" if female else "Superhero_Male_FullBody"
        objs = import_gltf(os.path.join(BASE, name + ".gltf"))
        self.arm = [o for o in objs if o.type == "ARMATURE"][0]
        meshes = [o for o in objs if o.type == "MESH"]
        self.body = max(meshes, key=lambda o: len(o.data.polygons))
        self.eyes = [o for o in meshes if o.name.startswith("Eyes")]
        for o in meshes:
            if o is not self.body and o not in self.eyes:
                bpy.data.objects.remove(o)
        top = max((self.body.matrix_world @ v.co).z for v in self.body.data.vertices)
        root = self.arm
        while root.parent:
            root = root.parent
        root.rotation_mode = "XYZ"
        root.rotation_euler.z += math.pi  # The base faces -Y: turn it to face +Y.
        self.k = height / top
        root.scale = [s * self.k for s in root.scale]
        bpy.context.view_layer.update()
        select([root] + list(root.children_recursive), root)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if root is not self.arm:
            for o in list(root.children):
                mw = o.matrix_world.copy()
                o.parent = None
                o.matrix_world = mw
            bpy.data.objects.remove(root)
        self.extras = []
        gi = {g.name: g.index for g in self.body.vertex_groups}["Head"]
        hp = [
            self.body.matrix_world @ v.co
            for v in self.body.data.vertices
            if v.groups and max(v.groups, key=lambda g: g.weight).group == gi
        ]
        xs, ys, zs = [p.x for p in hp], [p.y for p in hp], [p.z for p in hp]
        self.head = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2))

    def bone_head(self, name):
        return self.arm.matrix_world @ self.arm.data.bones[name].head_local

    def bone_tail(self, name):
        return self.arm.matrix_world @ self.arm.data.bones[name].tail_local

    def slice(self, z, xmax=0.32, dz=0.025):
        """Half width, half depth and centre y of the body around height z."""
        pts = [self.body.matrix_world @ v.co for v in self.body.data.vertices]
        pts = [p for p in pts if abs(p.z - z) < dz and abs(p.x) < xmax]
        xs = [p.x for p in pts]
        ys = [p.y for p in pts]
        return (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2, (max(ys) + min(ys)) / 2

    def dress(self, ratio, mats, inflate, boot_top=0.0):
        """mats/inflate: region -> material / metres. 'boot' is the calf below boot_top."""
        decimate(self.body, ratio)
        me = self.body.data
        groups = {g.index: g.name for g in self.body.vertex_groups}
        vreg = []
        for v in me.vertices:
            best = max(v.groups, key=lambda g: g.weight, default=None)
            r = region_name(groups[best.group]) if best else "torso"
            if r == "foot" or (r == "calf" and (self.body.matrix_world @ v.co).z < boot_top):
                r = "boot"
            vreg.append(r)
        me.materials.clear()
        order = list(mats)
        for r in order:
            me.materials.append(mats[r])
        for p in me.polygons:
            rs = [vreg[i] for i in p.vertices]
            r = max(set(rs), key=rs.count)
            p.material_index = order.index(r) if r in mats else order.index("torso")
        bm = bmesh.new()
        bm.from_mesh(me)
        for v in bm.verts:
            d = inflate.get(vreg[v.index], 0.0)
            if d:
                v.co += v.normal * d
        bm.to_mesh(me)
        bm.free()
        for e in self.eyes:
            decimate(e, 0.12)

    def piece(self, bone):
        """Join the parts built so far into one garment, weighted to one bone."""
        if not PARTS:
            return None
        select(PARTS, PARTS[0])
        bpy.ops.object.join()
        o = bpy.context.object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        PARTS.clear()
        g = o.vertex_groups.new(name=bone)
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        self.extras.append(o)
        return o

    def hair(self, name, m, ratio):
        objs = import_gltf(os.path.join(HAIR, name + ".gltf"))
        h = [o for o in objs if o.type == "MESH"][0]
        for o in objs:
            if o is not h:
                bpy.data.objects.remove(o)
        h.parent = None
        h.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(self.k, 4) @ h.matrix_world
        select([h], h)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        decimate(h, ratio)
        h.data.materials.clear()
        h.data.materials.append(m)
        h.vertex_groups.clear()
        g = h.vertex_groups.new(name="Head")
        g.add(list(range(len(h.data.vertices))), 1.0, "REPLACE")
        h["keep_uv"] = True
        self.extras.append(h)

    def merge(self):
        """One skinned mesh: body, eyes and garments, cloth on cube UVs."""
        for o in self.extras:
            if not o.get("keep_uv"):
                for layer in list(o.data.uv_layers):
                    o.data.uv_layers.remove(layer)
                o.data.uv_layers.new(name="UVMap")
        parts = [self.body] + self.eyes + self.extras
        for o in parts:
            for md in list(o.modifiers):
                o.modifiers.remove(md)
            o.parent = None
        select(parts, self.body)
        bpy.ops.object.join()
        body = self.body
        uv_cloth(body)
        body.parent = self.arm
        md = body.modifiers.new("skin", "ARMATURE")
        md.object = self.arm
        self.eyes, self.extras = [], []
        return body


def uv_cloth(o):
    """Cube projection of every cloth face, about 3 tiles per meter; skin keeps its UVs."""
    select([o], o)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(o.data)
    cloth_slots = {i for i, s in enumerate(o.material_slots) if s.material and s.material.name in FABRIC}
    for f in bm.faces:
        f.select = f.material_index in cloth_slots
    bmesh.update_edit_mesh(o.data)
    bpy.ops.uv.cube_project(cube_size=1.0 / TILES_PER_METER, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def armband_on(c, m, s="l", r=0.068):
    """Band round the upper arm."""
    h = c.bone_head(f"upperarm_{s}")
    t = c.bone_tail(f"upperarm_{s}")
    loft([h.lerp(t, 0.42), h.lerp(t, 0.58)], [(r, r)] * 2, m, 8, front=(0, 0, 1), cap=(False, False))
    c.piece(f"upperarm_{s}")


def skirt(c, z_top, z_hem, m, flare=1.25, extra=0.03, verts=14, roundness=0.72):
    """Coat skirt from waist to hem, wrapped round both legs, on the pelvis."""
    rad, pts = [], []
    for i in range(5):
        z = z_top - (z_top - z_hem) * i / 4
        rx, ry, cy = c.slice(max(z, 0.3), 0.3)
        ry = max(ry, rx * roundness)
        f = 1 + (flare - 1) * i / 4
        rad.append(((rx + extra) * f, (ry + extra) * (1 + (f - 1) * 0.6)))
        pts.append((0, cy, z))
    loft(pts, rad, m, verts, cap=(False, False))
    c.piece("pelvis")


# ------------------------------------------------------------ the three hunted
# Front is +Y in Blender, which is -Z (forward) in Godot.


def mk_ambulancier():
    c = Char(False, 1.8)
    jack = cloth("r1_jacket", (0.24, 0.29, 0.34), "canvas")
    pants = cloth("r1_cargo", (0.17, 0.17, 0.14), "canvas")
    boot = cloth("r1_boot", (0.08, 0.07, 0.06), "plastic", rough=0.5)
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    plate = cloth("r1_plate", (0.33, 0.34, 0.33), "plate", rough=0.4)
    strap = cloth("r1_strap", (0.06, 0.06, 0.06), "canvas")
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    glass = mat("glass", (0.05, 0.08, 0.08), rough=0.1)
    skin = skin_mat("skin_m", os.path.join(BASE, "T_Superhero_Male_Dark.png"), (0.95, 0.9, 0.85))
    acc, led = accent(BLUE)
    c.dress(
        0.12,
        {"torso": jack, "uarm": jack, "farm": jack, "hips": pants, "thigh": pants, "calf": pants, "boot": boot,
         "hand": glove, "head": skin},
        {"torso": 0.02, "uarm": 0.016, "farm": 0.014, "hips": 0.012, "thigh": 0.01, "calf": 0.008, "boot": 0.012,
         "hand": 0.004},
        boot_top=0.2,
    )
    hd = c.bone_head("Head")
    hh = c.head
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z, 0.2)
    rings([(hd.z - 0.07, 0.085, 0.08, cy - 0.01), (hd.z, 0.075, 0.072, cy - 0.015)], jack, 10, cap=(False, False))
    c.piece("neck_01")
    # Scrap plate on the chest, straps, gas mask hanging below the chin.
    zc = ch.z - 0.02
    fy = cy + ry + 0.03
    loft([(-0.13, fy - 0.012, zc), (0, fy + 0.004, zc), (0.13, fy - 0.012, zc)], [(0.006, 0.14)] * 3, plate, 4,
         front=(0, 0, 1))
    for z in (zc + 0.09, zc - 0.1):
        r2 = c.slice(z, 0.2)
        rings([(z - 0.018, r2[0] + 0.035, r2[1] + 0.045, r2[2]), (z + 0.018, r2[0] + 0.035, r2[1] + 0.045, r2[2])],
              strap, 12, cap=(False, False))
    ball((-0.1, fy + 0.008, zc + 0.08), 0.013, led)
    zm = hd.z - 0.12
    loft([(0, fy - 0.03, zm + 0.04), (0, fy + 0.03, zm), (0, fy + 0.05, zm - 0.03)],
         [(0.06, 0.05), (0.065, 0.055), (0.04, 0.035)], rubber, 8)
    for s in (-1, 1):
        loft([(0.03 * s, fy + 0.035, zm + 0.02), (0.031 * s, fy + 0.045, zm + 0.022)], [(0.022, 0.022)] * 2, glass, 8)
    loft([(0, fy + 0.04, zm - 0.04), (0, fy + 0.08, zm - 0.07)], [(0.03, 0.03), (0.034, 0.034)], metal, 8)
    c.piece("spine_03")
    zw = c.bone_head("spine_01").z
    w = c.slice(zw)
    rings([(zw - 0.02, w[0] + 0.03, w[1] + 0.03, w[2]), (zw + 0.02, w[0] + 0.03, w[1] + 0.03, w[2])], strap, 12,
          cap=(False, False))
    for x in (-0.12, 0.12):
        box((x, w[2] + w[1] + 0.04, zw - 0.02), (0.07, 0.05, 0.09), strap)
    c.piece("pelvis")
    rb = cy - ry - 0.02
    rings([(ch.z - 0.25, 0.15, 0.07, rb - 0.07), (ch.z - 0.05, 0.165, 0.085, rb - 0.085),
           (ch.z + 0.15, 0.15, 0.075, rb - 0.075), (ch.z + 0.2, 0.12, 0.05, rb - 0.06)],
          cloth("r1_pack", (0.17, 0.19, 0.14), "canvas"), 10)
    c.piece("spine_03")
    for s in ("l", "r"):  # Knee pads.
        k = c.bone_head(f"calf_{s}")
        box((k.x, k.y + 0.075, k.z), (0.11, 0.035, 0.12), strap)
        c.piece(f"calf_{s}")
    c.hair("Hair_Beard", cloth("r1_beard", (0.05, 0.04, 0.035), "hair"), 0.35)
    rings([(hh.z + 0.03, 0.097, 0.118, hh.y - 0.012), (hh.z + 0.065, 0.095, 0.114, hh.y - 0.014),
           (hh.z + 0.098, 0.079, 0.095, hh.y - 0.018), (hh.z + 0.122, 0.046, 0.056, hh.y - 0.02),
           (hh.z + 0.13, 0.005, 0.005, hh.y - 0.02)], cloth("r1_beanie", (0.09, 0.09, 0.09), "knit"), 12)
    c.piece("Head")
    armband_on(c, acc, "l")
    return c


def mk_parka():
    c = Char(True, 1.7)
    parka = cloth("r2_parka", (0.21, 0.23, 0.15), "canvas")
    fur = cloth("r2_fur", (0.32, 0.29, 0.24), "hair")
    pants = cloth("r2_pants", (0.08, 0.08, 0.09), "canvas")
    boot = cloth("r2_boot", (0.1, 0.075, 0.05), "plastic", rough=0.45)
    scarf = cloth("r2_scarf", (0.29, 0.26, 0.21), "canvas")
    strap = cloth("r2_strap", (0.08, 0.07, 0.06), "canvas")
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    glass = mat("glass_g", (0.08, 0.13, 0.11), rough=0.05)
    hairm = cloth("r2_hair", (0.06, 0.04, 0.03), "hair")
    skin = skin_mat("skin_f", os.path.join(BASE, "T_Superhero_Female_Dark_BaseColor.png"), (1.05, 0.98, 0.92))
    acc, led = accent(GREEN)
    c.dress(
        0.1,
        {"torso": parka, "uarm": parka, "farm": parka, "hips": pants, "thigh": pants, "calf": pants, "boot": boot,
         "hand": glove, "head": skin},
        {"torso": 0.03, "uarm": 0.024, "farm": 0.02, "hips": 0.01, "thigh": 0.006, "calf": 0.006, "boot": 0.012,
         "hand": 0.004},
        boot_top=0.42,
    )
    zw = c.bone_head("spine_01").z
    skirt(c, zw + 0.04, zw - 0.27, parka, flare=1.12, extra=0.045, verts=12, roundness=0.85)
    w = c.slice(zw + 0.05)
    rings([(zw + 0.03, w[0] + 0.045, w[1] + 0.045, w[2]), (zw + 0.07, w[0] + 0.045, w[1] + 0.045, w[2])], strap, 12,
          cap=(False, False))
    box((0, w[2] + w[1] + 0.05, zw + 0.05), (0.05, 0.02, 0.05), mat("buckle", (0.4, 0.4, 0.38), rough=0.3))
    c.piece("spine_01")
    hd = c.bone_head("Head")
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z + 0.05)
    back = cy - ry - 0.03  # Hood down with fur trim, behind the neck.
    loft([(-0.13, back + 0.06, hd.z - 0.05), (0, back - 0.02, hd.z - 0.02), (0.13, back + 0.06, hd.z - 0.05)],
         [(0.05, 0.06), (0.06, 0.08), (0.05, 0.06)], parka, 8)
    loft([(-0.14, back + 0.08, hd.z - 0.02), (0, back, hd.z + 0.02), (0.14, back + 0.08, hd.z - 0.02)],
         [(0.03, 0.035)] * 3, fur, 6)
    c.piece("spine_03")
    hh = c.head  # Scarf round the neck, pulled up over the nose.
    rings([(hh.z - 0.15, 0.075, 0.08, hh.y - 0.005), (hh.z - 0.1, 0.086, 0.1, hh.y + 0.008),
           (hh.z - 0.05, 0.09, 0.113, hh.y + 0.012), (hh.z - 0.02, 0.091, 0.114, hh.y + 0.01)], scarf, 12,
          cap=(False, False))
    loft([(0.06, cy + ry + 0.03, hd.z - 0.06), (0.08, cy + ry + 0.06, ch.z + 0.05),
          (0.09, cy + ry + 0.05, ch.z - 0.05)], [(0.04, 0.012)] * 3, scarf, 6)
    c.piece("Head")
    gz = hh.z + 0.075  # Goggles on the forehead.
    rings([(gz - 0.01, 0.092, 0.112, hh.y - 0.006), (gz + 0.008, 0.09, 0.11, hh.y - 0.008)], strap, 12,
          cap=(False, False))
    for s in (-1, 1):
        loft([(0.034 * s, hh.y + 0.085, gz + 0.004), (0.035 * s, hh.y + 0.112, gz + 0.012)],
             [(0.024, 0.021), (0.022, 0.02)], strap, 8)
        loft([(0.035 * s, hh.y + 0.111, gz + 0.012), (0.035 * s, hh.y + 0.116, gz + 0.013)], [(0.018, 0.016)] * 2,
             glass, 8)
    c.piece("Head")
    c.hair("Hair_Long", hairm, 0.16)
    loft([(-0.16, cy, ch.z + 0.15), (0.0, cy + ry + 0.04, ch.z - 0.05), (0.19, cy + 0.06, zw - 0.08)],
         [(0.025, 0.008)] * 3, strap, 4)
    loft([(-0.16, cy, ch.z + 0.15), (0.0, cy - ry - 0.04, ch.z - 0.05), (0.19, cy - 0.04, zw - 0.08)],
         [(0.025, 0.008)] * 3, strap, 4)
    box((0.21, cy + 0.02, zw - 0.14), (0.08, 0.2, 0.17), strap)
    ball((-0.1, cy + ry + 0.035, ch.z + 0.08), 0.013, led)
    c.piece("spine_03")
    armband_on(c, acc, "l", 0.07)
    return c


def mk_masque():
    c = Char(False, 1.76)
    coat = cloth("r3_coat", (0.13, 0.15, 0.13), "canvas", rough=0.6)
    pants = cloth("r3_pants", (0.1, 0.1, 0.09), "canvas")
    boot = cloth("r3_boot", (0.05, 0.05, 0.05), "plastic", rough=0.3)
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    belt = cloth("r3_belt", (0.14, 0.11, 0.08), "canvas")
    glass = mat("glass_a", (0.1, 0.13, 0.11), rough=0.04)
    lamp = mat("lamp", (0.9, 0.95, 1.0), emit=((0.85, 0.92, 1.0), 25))
    skin = skin_mat("skin_m3", os.path.join(BASE, "T_Superhero_Male_Dark.png"), (1.1, 1.0, 0.95))
    acc, led = accent(WHITE)
    c.dress(
        0.1,
        {"torso": coat, "uarm": coat, "farm": coat, "hips": coat, "thigh": pants, "calf": pants, "boot": boot,
         "hand": rubber, "head": skin},
        {"torso": 0.035, "uarm": 0.03, "farm": 0.028, "hips": 0.035, "thigh": 0.008, "calf": 0.008, "boot": 0.016,
         "hand": 0.008},
        boot_top=0.38,
    )
    zw = c.bone_head("spine_01").z
    skirt(c, zw + 0.02, 0.5, coat, flare=1.18, extra=0.045, verts=16, roundness=0.8)
    w = c.slice(zw)
    rings([(zw - 0.025, w[0] + 0.05, w[1] + 0.05, w[2]), (zw + 0.025, w[0] + 0.05, w[1] + 0.05, w[2])], belt, 12,
          cap=(False, False))
    for x, wd in ((-0.14, 0.07), (-0.05, 0.06), (0.14, 0.08)):
        box((x, w[2] + w[1] + 0.07, zw - 0.04), (wd, 0.06, 0.1), belt)
    box((0.22, w[2] + 0.06, zw - 0.12), (0.035, 0.035, 0.22), metal)
    c.piece("pelvis")
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z + 0.05)
    for z in (zw - 0.05, ch.z - 0.05, ch.z + 0.1):
        ball((0.0, cy + ry + 0.04, z), 0.012, metal)
    ball((-0.12, cy + ry + 0.045, ch.z + 0.1), 0.013, led)
    c.piece("spine_03")
    hy, hz = c.head.y, c.head.z
    rings([(hz - 0.17, 0.1, 0.11, hy - 0.03), (hz - 0.09, 0.118, 0.132, hy - 0.035), (hz, 0.122, 0.137, hy - 0.035),
           (hz + 0.06, 0.12, 0.134, hy - 0.04), (hz + 0.11, 0.102, 0.117, hy - 0.045),
           (hz + 0.15, 0.072, 0.086, hy - 0.05), (hz + 0.172, 0.035, 0.045, hy - 0.052),
           (hz + 0.18, 0.005, 0.005, hy - 0.052)], coat, 12)  # Hood up.
    fy = hy + 0.078  # Full-face mask.
    rings([(hz - 0.115, 0.058, 0.04, fy), (hz - 0.075, 0.076, 0.052, fy + 0.005), (hz - 0.01, 0.083, 0.052, fy + 0.003),
           (hz + 0.04, 0.078, 0.047, fy), (hz + 0.068, 0.056, 0.036, fy - 0.006)], rubber, 12)
    for s in (-1, 1):
        loft([(0.036 * s, fy + 0.045, hz + 0.018), (0.037 * s, fy + 0.058, hz + 0.02)], [(0.027, 0.025)] * 2, metal, 10)
        loft([(0.037 * s, fy + 0.056, hz + 0.02), (0.037 * s, fy + 0.06, hz + 0.021)], [(0.022, 0.02)] * 2, glass, 10)
        loft([(0.05 * s, fy + 0.035, hz - 0.07), (0.105 * s, fy + 0.07, hz - 0.11)], [(0.035, 0.035), (0.04, 0.04)],
             metal, 10)
    loft([(0, fy + 0.045, hz - 0.07), (0, fy + 0.075, hz - 0.085)], [(0.028, 0.028), (0.032, 0.03)], rubber, 8)
    rings([(hz + 0.085, 0.124, 0.139, hy - 0.035), (hz + 0.105, 0.121, 0.136, hy - 0.037)], rubber, 12,
          cap=(False, False))  # Headlamp.
    box((0, hy + 0.1, hz + 0.095), (0.05, 0.04, 0.04), rubber)
    ball((0, hy + 0.122, hz + 0.095), 0.015, lamp)
    c.piece("Head")
    rb = cy - ry - 0.05  # Battery pack and hose.
    rings([(ch.z - 0.3, 0.15, 0.09, rb - 0.09), (ch.z + 0.02, 0.15, 0.09, rb - 0.09),
           (ch.z + 0.06, 0.13, 0.07, rb - 0.075)], metal, 8)
    loft([(0.1, rb - 0.05, ch.z + 0.04), (0.17, cy - 0.04, hz - 0.2), (0.11, fy + 0.03, hz - 0.11)],
         [(0.011, 0.011)] * 3, rubber, 6)
    c.piece("spine_03")
    armband_on(c, acc, "l", 0.08)
    for s in ("l", "r"):  # Gauntlets.
        h = c.bone_head(f"lowerarm_{s}")
        t = c.bone_tail(f"lowerarm_{s}")
        loft([t.lerp(h, 0.25), t], [(0.055, 0.055), (0.05, 0.05)], rubber, 8, front=(0, 0, 1))
        c.piece(f"lowerarm_{s}")
    return c


ROLES = {"ambulancier": mk_ambulancier, "parka": mk_parka, "masque": mk_masque}

# ------------------------------------------------------------ animations
# Keys are built in world space, as rotations about the joints (+X swings a
# hanging limb forward, the character facing +Y at this stage), then read
# back as local bone rotations.

KEYED = [
    "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
    "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
    "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
]
for _s in ("l", "r"):
    for _f in ("index", "middle", "ring", "pinky"):
        for _j in ("01", "02", "03"):
            KEYED.append(f"{_f}_{_j}_{_s}")

# name: (seconds, legs swing deg, knee base, knee lift, arm swing, forearm bend, lean, crouch thigh, crouch knee)
CYCLES = {
    "idle": (2.0, 0, 3, 0, 0, 12, 0, 0, 0),
    "walk": (0.8, 30, 4, 45, 18, 16, 5, 0, 0),
    "run": (0.6, 40, 12, 80, 36, 70, 14, 0, 0),
    "crouch": (0.9, 20, 0, 22, 6, 24, 26, 58, 100),
    "crouch_idle": (2.0, 0, 0, 0, 0, 24, 26, 58, 100),
    "kneel": (2.0, 0, 0, 0, 0, 30, 6, 4, 92),
}


class Rig:
    """Keys cycles on the skeleton. cycles: name -> parameters (see CYCLES);
    a subclass may add to each pose in finish() (the hunter, hunter.py)."""

    cycles = CYCLES
    scaled = ()  # Bones whose scale is keyed too.

    def __init__(self, c):
        self.arm = c.arm
        b = c.arm.data.bones
        self.thigh = (b["thigh_l"].head_local - b["calf_l"].head_local).length
        self.shin = (b["calf_l"].head_local - b["foot_l"].head_local).length
        self.ankle = b["foot_l"].head_local.z

    def rot(self, bone, axis, deg):
        pb = self.arm.pose.bones[bone]
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()

    def move(self, bone, dz):
        pb = self.arm.pose.bones[bone]
        pb.matrix = Matrix.Translation((0, 0, dz)) @ pb.matrix
        bpy.context.view_layer.update()

    def leg_height(self, a, b):
        return self.thigh * math.cos(math.radians(a)) + self.shin * math.cos(math.radians(a - b)) + self.ankle

    def pose(self, name, t):
        """Pose of a cycle at time t (seconds)."""
        sec, swing, k0, k1, arm_sw, fore, lean, ca, cb = self.cycles[name]
        p = 2 * math.pi * t / sec
        for pb in self.arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        legs = {}
        for s, ph in (("l", p), ("r", p + math.pi)):
            a = ca + swing * math.sin(ph)
            b = cb + k0 + k1 * max(0.0, math.cos(ph))
            legs[s] = (a, b)
        rest = self.thigh + self.shin + self.ankle
        if name == "kneel":
            dz = self.thigh * math.cos(math.radians(ca)) + 0.06 - rest
        else:
            dz = max(self.leg_height(*legs["l"]), self.leg_height(*legs["r"])) - rest
        breath = math.sin(p) if name in ("idle", "crouch_idle", "kneel") else 0.0
        self.move("pelvis", dz + (0.012 * abs(math.sin(p)) if name == "run" else 0.0))
        if name in ("walk", "run", "crouch"):
            self.rot("pelvis", "Z", 4 * math.sin(p))
        self.rot("spine_01", "X", -lean * 0.6)
        self.rot("spine_03", "X", -lean * 0.4 - 1.5 * breath)
        self.rot("neck_01", "X", lean * 0.7 + (14 if name == "kneel" else 0))
        for s, sign, ph in (("l", 1, p), ("r", -1, p + math.pi)):
            a, b = legs[s]
            self.rot(f"thigh_{s}", "X", a)
            self.rot(f"calf_{s}", "X", -b)
            foot = -(a - b) if name != "kneel" else 40
            self.rot(f"foot_{s}", "X", foot)
            # Arms: down from the T-pose, swinging against the leg of their side.
            self.rot(f"upperarm_{s}", "Y", -70 * sign)
            fwd = 6 + (24 if name == "kneel" else 0) + (4 if name.startswith("crouch") else 0)
            self.rot(f"upperarm_{s}", "X", fwd - arm_sw * math.sin(ph))
            self.rot(f"lowerarm_{s}", "X", fore + (fore * 0.3 * max(0.0, -math.sin(ph)) if swing else 0.0))
            for f in ("index", "middle", "ring", "pinky"):
                for j in ("01", "02", "03"):
                    self.rot(f"{f}_{j}_{s}", "Y", -28 * sign)
        self.finish(name, p)

    def finish(self, name, p):
        """Extra keys of a subclass, after the base pose."""

    def bake(self, name):
        sec = self.cycles[name][0]
        frames = round(sec * FPS)
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        self.arm.animation_data_create()
        self.arm.animation_data.action = act
        step = 2 if frames > 30 else 1
        for f in list(range(0, frames, step)) + [frames]:
            self.pose(name, f / FPS)
            for bone in KEYED:
                pb = self.arm.pose.bones[bone]
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if bone == "pelvis":
                    pb.keyframe_insert("location", frame=f)
                if bone in self.scaled:
                    pb.keyframe_insert("scale", frame=f)
        self.arm.animation_data.action = None
        return act


# ------------------------------------------------------------ build


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS.clear()
    FABRIC.clear()
    bpy.context.scene.render.fps = FPS


def build(role):
    reset()
    c = ROLES[role]()
    body = c.merge()
    rig = Rig(c)
    for name in rig.cycles:
        rig.bake(name)
    for pb in c.arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    c.arm.name = "hunted_" + role
    body.name = "hunted_" + role + "_mesh"
    for m in bpy.data.materials:  # The eyes of the base too: pixels stay sharp.
        for node in m.node_tree.nodes if m.node_tree else []:
            if node.type == "TEX_IMAGE":
                node.interpolation = "Closest"
    n = tris(body)
    print(f"{role}: {n} triangles, {len(body.material_slots)} materials")
    assert n <= BUDGET, f"{role} over budget: {n}"
    return c.arm, body


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    blend_dir, out_dir = args[0], args[1]
    for role in args[2:] or list(ROLES):
        arm, body = build(role)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, f"hunted_{role}.blend"))
        select([arm, body], arm)
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(out_dir, f"hunted_{role}.glb"),
            export_format="GLB",
            use_selection=True,
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_skins=True,
            export_def_bones=False,
            export_apply=False,
        )
