"""The three hunted of "Le Reseau" on a CC0 base (S-011 round 4). Run with bpy 5.2.

Usage: python hunted4.py UBC_DIR OUT_DIR [shot ...]
UBC_DIR = "Universal Base Characters[Standard]" folder (Quaternius, CC0).
Each character: base body (rigged, UE-style 65-bone skeleton) decimated to a
PS1 budget, clothing made by recolouring and inflating body regions picked
from the skin weights, extra garments (coat skirts, hood, plate, mask, packs)
lofted and bound to the skeleton, skin texture reduced to 256 px Closest.
Arms posed down from the T-pose for the renders. No names: roles only.
"""
import math
import os
import sys

UBC = sys.argv[1]
sys.argv = [sys.argv[0]] + sys.argv[2:]
_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "hunted3.py")).read()
_src = _src[:_src.index("CHARS = [r_ambulancier")]
exec(_src)  # kit, textures, loft(), rings(), scenes (OUT, WANT)
import bmesh
from mathutils import Matrix

BASE = os.path.join(UBC, "Base Characters", "Godot - UE")
HAIR = os.path.join(UBC, "Hairstyles", "Origin at 0", "glTF (Godot)")

REGION_OF = {}
for b in ("pelvis",):
    REGION_OF[b] = "hips"
for b in ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"):
    REGION_OF[b] = "torso"
for b in ("neck_01", "Head"):
    REGION_OF[b] = "head"
for s in ("l", "r"):
    REGION_OF["upperarm_" + s] = "uarm"
    REGION_OF["lowerarm_" + s] = "farm"
    REGION_OF["thigh_" + s] = "thigh"
    REGION_OF["calf_" + s] = "calf"
    REGION_OF["foot_" + s] = "foot"
    REGION_OF["ball_" + s] = "foot"


def region_name(bone):
    if bone in REGION_OF:
        return REGION_OF[bone]
    if bone.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")):
        return "hand"
    return "torso"


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def skin_texture(path, size=256):
    from PIL import Image
    out = f"/tmp/claude-0/hr4/{os.path.basename(path)[:-4]}_{size}.png"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if not os.path.exists(out):
        Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS).save(out)
    im = bpy.data.images.load(out)
    return im


def skin_mat(name, img, tint=(1, 1, 1)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.6
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Closest"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = (*tint, 1)
    nt.links.new(tx.outputs["Color"], mix.inputs["A"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    return m


def decimate(o, ratio):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("dec", "DECIMATE")
    md.ratio = ratio
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
    bpy.ops.object.modifier_apply(modifier="dec")


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


class Char:
    """A base body ready to dress: armature + body mesh, facing +Y, T-pose."""

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
        # face +Y and scale to height, applied to armature and meshes
        top = max((self.body.matrix_world @ v.co).z for v in self.body.data.vertices)
        root = self.arm
        while root.parent:
            root = root.parent
        self.root = root
        root.rotation_mode = "XYZ"
        root.rotation_euler.z += math.pi
        k = height / top
        self.k = k
        root.scale = [s * k for s in root.scale]
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action="DESELECT")
        for o in [root] + list(root.children_recursive):
            o.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        self.extras = []
        self.female = female
        gi = {g.name: g.index for g in self.body.vertex_groups}["Head"]
        hp = [self.body.matrix_world @ v.co for v in self.body.data.vertices
              if v.groups and max(v.groups, key=lambda g: g.weight).group == gi]
        xs, ys, zs = [p.x for p in hp], [p.y for p in hp], [p.z for p in hp]
        self.head = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2))
        self.head_top, self.head_bot = max(zs), min(zs)
        self.head_front, self.head_back = max(ys), min(ys)
        self.head_rx = (max(xs) - min(xs)) / 2
        print("HEAD", female, tuple(round(c, 3) for c in self.head), round(self.head_top, 3), round(self.head_bot, 3),
              round(self.head_front, 3), round(self.head_back, 3), round(self.head_rx, 3),
              "bone", tuple(round(c, 3) for c in self.bone_head("Head")))

    def bone_head(self, name):
        return self.arm.matrix_world @ self.arm.data.bones[name].head_local

    def bone_tail(self, name):
        return self.arm.matrix_world @ self.arm.data.bones[name].tail_local

    def slice(self, z, xmax=0.32, dz=0.025):
        """Extent of the body around height z (rest pose, arms out of the way)."""
        pts = [self.body.matrix_world @ v.co for v in self.body.data.vertices]
        pts = [p for p in pts if abs(p.z - z) < dz and abs(p.x) < xmax]
        xs = [p.x for p in pts]
        ys = [p.y for p in pts]
        return (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2, (max(ys) + min(ys)) / 2

    def dress(self, ratio, mats, inflate, boot_top=0.0, glove=False, skin=None, smooth=0, smooth_min=0.015):
        """mats/inflate: dict region -> material / metres. 'boot' covers calf below boot_top."""
        decimate(self.body, ratio)
        me = self.body.data
        groups = {g.index: g.name for g in self.body.vertex_groups}
        vreg = []
        mw = self.body.matrix_world
        for v in me.vertices:
            best = max(v.groups, key=lambda g: g.weight, default=None)
            r = region_name(groups[best.group]) if best else "torso"
            z = (mw @ v.co).z
            if r in ("calf", "foot") and z < boot_top:
                r = "boot"
            if r == "foot":
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
        bm.verts.ensure_lookup_table()
        offs = [inflate.get(vreg[v.index], 0.0) for v in bm.verts]
        for v, d in zip(bm.verts, offs):
            if d:
                v.co += v.normal * d
        soft = [v for v in bm.verts if vreg[v.index] in ("torso", "uarm", "farm", "hips", "thigh")
                and inflate.get(vreg[v.index], 0) >= smooth_min]
        for _ in range(smooth):
            bmesh.ops.smooth_vert(bm, verts=soft, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.to_mesh(me)
        bm.free()
        for e in self.eyes:
            decimate(e, 0.12)

    def bind(self, obj, bone=None):
        """Attach a garment: to one bone, or with automatic weights."""
        mw = obj.matrix_world.copy()
        if bone:
            obj.parent = self.arm
            obj.parent_type = "BONE"
            obj.parent_bone = bone
            bpy.context.view_layer.update()
            obj.matrix_world = mw
        else:
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            self.arm.select_set(True)
            bpy.context.view_layer.objects.active = self.arm
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        self.extras.append(obj)

    def piece(self, bone=None):
        """Join the PARTS built so far into one garment and bind it."""
        global PARTS
        if not PARTS:
            return None
        bpy.ops.object.select_all(action="DESELECT")
        for p in PARTS:
            p.select_set(True)
        bpy.context.view_layer.objects.active = PARTS[0]
        bpy.ops.object.join()
        o = bpy.context.object
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        PARTS.clear()
        self.bind(o, bone)
        return o

    def hair(self, name, mat_, ratio=0.3):
        objs = import_gltf(os.path.join(HAIR, name + ".gltf"))
        m = [o for o in objs if o.type == "MESH"][0]
        for o in objs:
            if o is not m:
                bpy.data.objects.remove(o)
        m.parent = None
        # same 180 deg turn and scale as the body
        m.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(self.k, 4) @ m.matrix_world
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        decimate(m, ratio)
        m.data.materials.clear()
        m.data.materials.append(mat_)
        self.bind(m, "Head")
        return m

    def pose_arms(self, down=68, bend=12, fwd=6):
        bpy.context.view_layer.objects.active = self.arm
        for s in ("l", "r"):
            for bone, ang, axis in ((f"upperarm_{s}", down, "Y"), (f"lowerarm_{s}", bend, "X")):
                pb = self.arm.pose.bones[bone]
                h = pb.head.copy()
                sign = 1 if pb.tail.x > pb.head.x else -1
                a = math.radians(ang) * (sign if axis == "Y" else 1)
                R = Matrix.Rotation(a, 4, axis)
                pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
                bpy.context.view_layer.update()
            pb = self.arm.pose.bones[f"upperarm_{s}"]
            sign = 1 if pb.tail.x > pb.head.x else -1
            h = pb.head.copy()
            R = Matrix.Rotation(math.radians(fwd), 4, "X")
            pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
            bpy.context.view_layer.update()
            for f in ("index", "middle", "ring", "pinky"):
                for j in ("01", "02", "03"):
                    pb = self.arm.pose.bones[f"{f}_{j}_{s}"]
                    h = pb.head.copy()
                    R = Matrix.Rotation(math.radians(28 * sign), 4, "Y")
                    pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
                    bpy.context.view_layer.update()

    def total_tris(self):
        n = tris(self.body) + sum(tris(e) for e in self.eyes)
        return n + sum(tris(e) for e in self.extras)

    def finish(self, name):
        self.arm.name = name
        return self


def armband_on(c, m, s="l", r=0.068):
    """Band round the posed upper arm (call after pose_arms)."""
    pb = c.arm.pose.bones[f"upperarm_{s}"]
    h = c.arm.matrix_world @ pb.head
    t = c.arm.matrix_world @ pb.tail
    a = h.lerp(t, 0.42)
    b = h.lerp(t, 0.58)
    loft([a, b], [(r, r)] * 2, m, 8, cap=(False, False))
    c.piece(f"upperarm_{s}")


def skirt(c, z_top, z_hem, m, flare=1.25, extra=0.03, verts=14, yoff=0.0, roundness=0.72):
    """Coat skirt from waist to hem, wrapped round both legs."""
    zs = [z_top - (z_top - z_hem) * i / 4 for i in range(5)]
    rad, pts = [], []
    for i, z in enumerate(zs):
        rx, ry, cy = c.slice(max(z, 0.3), 0.3)
        ry = max(ry, rx * roundness)
        f = 1 + (flare - 1) * i / 4
        rad.append(((rx + extra) * f, (ry + extra) * (1 + (f - 1) * 0.6)))
        pts.append((0, cy + yoff, z))
    loft(pts, rad, m, verts, cap=(False, False))
    return c.piece("pelvis")


# ------------------------------------------------------------ the three hunted

def mk_ambulancier():
    c = Char(False, 1.8)
    c.k_hair = 1.8 / 1.82
    jack = cloth("r1_jacket", (0.24, 0.29, 0.34), "canvas")
    pants = cloth("r1_cargo", (0.17, 0.17, 0.14), "canvas")
    boot = cloth("r1_boot", (0.08, 0.07, 0.06), "plastic", rough=0.5)
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    plate = cloth("r1_plate", (0.33, 0.34, 0.33), "plate", rough=0.4)
    strap = cloth("r1_strap", (0.06, 0.06, 0.06), "canvas")
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    glass = mat("glass", (0.05, 0.08, 0.08), rough=0.1)
    skin = skin_mat("skin_m", skin_texture(os.path.join(BASE, "T_Superhero_Male_Dark.png")), (0.95, 0.9, 0.85))
    acc, led = accent(BLUE)
    c.dress(0.12, {"torso": jack, "uarm": jack, "farm": jack, "hips": pants, "thigh": pants, "calf": pants,
                   "boot": boot, "hand": glove, "head": skin},
            {"torso": 0.02, "uarm": 0.016, "farm": 0.014, "hips": 0.012, "thigh": 0.01, "calf": 0.008,
             "boot": 0.012, "hand": 0.004}, boot_top=0.2)
    hd = c.bone_head("Head")
    H = c.head
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z, 0.2)
    rx = min(rx, 0.15)
    # collar
    rings([(hd.z - 0.07, 0.085, 0.08, cy - 0.01), (hd.z + 0.0, 0.075, 0.072, cy - 0.015)], jack, 10, cap=(False, False))
    c.piece("neck_01")
    # scrap plate on the chest, straps, mask hanging below the chin
    zc = ch.z - 0.02
    fy = cy + ry + 0.03
    loft([(-0.13, fy - 0.012, zc), (0, fy + 0.004, zc), (0.13, fy - 0.012, zc)], [(0.006, 0.14)] * 3,
         plate, 4, front=(0, 0, 1))
    for z in (zc + 0.09, zc - 0.1):
        r2 = c.slice(z, 0.2)
        rings([(z - 0.018, r2[0] + 0.035, r2[1] + 0.045, r2[2]), (z + 0.018, r2[0] + 0.035, r2[1] + 0.045, r2[2])],
              strap, 12, cap=(False, False))
    ball((-0.1, fy + 0.008, zc + 0.08), 0.013, led, seg=6, rings=3)
    zm = hd.z - 0.12
    loft([(0, fy - 0.03, zm + 0.04), (0, fy + 0.03, zm), (0, fy + 0.05, zm - 0.03)],
         [(0.06, 0.05), (0.065, 0.055), (0.04, 0.035)], rubber, 8)
    for s in (-1, 1):
        loft([(0.03 * s, fy + 0.035, zm + 0.02), (0.031 * s, fy + 0.045, zm + 0.022)], [(0.022, 0.022)] * 2, glass, 8)
    loft([(0, fy + 0.04, zm - 0.04), (0, fy + 0.08, zm - 0.07)], [(0.03, 0.03), (0.034, 0.034)], metal, 8)
    c.piece("spine_03")
    # belt + pouches, backpack
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
    # knee pads
    for s in ("l", "r"):
        k = c.bone_head(f"calf_{s}")
        box((k.x, k.y + 0.075, k.z), (0.11, 0.035, 0.12), strap)
    c.piece("pelvis")
    # head: beard, short hair under a beanie
    c.hair("Hair_Beard", cloth("r1_beard", (0.05, 0.04, 0.035), "hair"), 0.35)
    rings([(H.z + 0.03, 0.097, 0.118, H.y - 0.012), (H.z + 0.065, 0.095, 0.114, H.y - 0.014),
           (H.z + 0.098, 0.079, 0.095, H.y - 0.018), (H.z + 0.122, 0.046, 0.056, H.y - 0.02),
           (H.z + 0.13, 0.005, 0.005, H.y - 0.02)],
          cloth("r1_beanie", (0.09, 0.09, 0.09), "knit"), 12)
    c.piece("Head")
    c.pose_arms()
    armband_on(c, acc, "l")
    return c.finish("ambulancier")


def mk_parka():
    c = Char(True, 1.7)
    c.k_hair = 1.7 / 1.775
    parka = cloth("r2_parka", (0.21, 0.23, 0.15), "canvas")
    fur = cloth("r2_fur", (0.32, 0.29, 0.24), "hair")
    pants = cloth("r2_pants", (0.08, 0.08, 0.09), "canvas")
    boot = cloth("r2_boot", (0.1, 0.075, 0.05), "plastic", rough=0.45)
    scarf = cloth("r2_scarf", (0.29, 0.26, 0.21), "canvas")
    strap = cloth("r2_strap", (0.08, 0.07, 0.06), "canvas")
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    glass = mat("glass_g", (0.08, 0.13, 0.11), rough=0.05)
    hairm = cloth("r2_hair", (0.06, 0.04, 0.03), "hair")
    skin = skin_mat("skin_f", skin_texture(os.path.join(BASE, "T_Superhero_Female_Dark_BaseColor.png")), (1.05, 0.98, 0.92))
    acc, led = accent(GREEN)
    c.dress(0.1, {"torso": parka, "uarm": parka, "farm": parka, "hips": pants, "thigh": pants, "calf": pants,
                   "boot": boot, "hand": glove, "head": skin},
            {"torso": 0.03, "uarm": 0.024, "farm": 0.02, "hips": 0.01, "thigh": 0.006, "calf": 0.006,
             "boot": 0.012, "hand": 0.004}, boot_top=0.42)
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
    # hood down with fur trim, behind the neck
    back = cy - ry - 0.03
    loft([(-0.13, back + 0.06, hd.z - 0.05), (0, back - 0.02, hd.z - 0.02), (0.13, back + 0.06, hd.z - 0.05)],
         [(0.05, 0.06), (0.06, 0.08), (0.05, 0.06)], parka, 8)
    loft([(-0.14, back + 0.08, hd.z - 0.02), (0, back + 0.0, hd.z + 0.02), (0.14, back + 0.08, hd.z - 0.02)],
         [(0.03, 0.035)] * 3, fur, 6)
    c.piece("spine_03")
    # scarf round the neck, pulled up over the nose
    H = c.head
    rings([(H.z - 0.15, 0.075, 0.08, H.y - 0.005), (H.z - 0.1, 0.086, 0.1, H.y + 0.008),
           (H.z - 0.05, 0.09, 0.113, H.y + 0.012), (H.z - 0.02, 0.091, 0.114, H.y + 0.01)], scarf, 12,
          cap=(False, False))
    loft([(0.06, cy + ry + 0.03, hd.z - 0.06), (0.08, cy + ry + 0.06, ch.z + 0.05), (0.09, cy + ry + 0.05, ch.z - 0.05)],
         [(0.04, 0.012)] * 3, scarf, 6)
    c.piece("Head")
    # goggles on the forehead, strap round the head
    gz = H.z + 0.075
    rings([(gz - 0.01, 0.092, 0.112, H.y - 0.006), (gz + 0.008, 0.09, 0.11, H.y - 0.008)], strap, 12,
          cap=(False, False))
    for s in (-1, 1):
        loft([(0.034 * s, H.y + 0.085, gz + 0.004), (0.035 * s, H.y + 0.112, gz + 0.012)], [(0.024, 0.021), (0.022, 0.02)],
             strap, 8)
        loft([(0.035 * s, H.y + 0.111, gz + 0.012), (0.035 * s, H.y + 0.116, gz + 0.013)], [(0.018, 0.016)] * 2, glass, 8)
    c.piece("Head")
    c.hair("Hair_Long", hairm, 0.16)
    # crossbody strap and bag
    loft([(-0.16, cy, ch.z + 0.15), (0.0, cy + ry + 0.04, ch.z - 0.05), (0.19, cy + 0.06, zw - 0.08)], [(0.025, 0.008)] * 3,
         strap, 4)
    loft([(-0.16, cy, ch.z + 0.15), (0.0, cy - ry - 0.04, ch.z - 0.05), (0.19, cy - 0.04, zw - 0.08)], [(0.025, 0.008)] * 3,
         strap, 4)
    box((0.21, cy + 0.02, zw - 0.14), (0.08, 0.2, 0.17), strap)
    ball((-0.1, cy + ry + 0.035, ch.z + 0.08), 0.013, led, seg=6, rings=3)
    c.piece("spine_03")
    c.pose_arms(down=70)
    armband_on(c, acc, "l", 0.07)
    return c.finish("parka")


def mk_masque():
    c = Char(False, 1.76)
    c.k_hair = 1.76 / 1.82
    coat = cloth("r3_coat", (0.13, 0.15, 0.13), "canvas", rough=0.6)
    pants = cloth("r3_pants", (0.1, 0.1, 0.09), "canvas")
    boot = cloth("r3_boot", (0.05, 0.05, 0.05), "plastic", rough=0.3)
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    belt = cloth("r3_belt", (0.14, 0.11, 0.08), "canvas")
    glass = mat("glass_a", (0.1, 0.13, 0.11), rough=0.04)
    lamp = mat("lamp", (0.9, 0.95, 1.0), emit=((0.85, 0.92, 1.0), 25))
    skin = skin_mat("skin_m3", skin_texture(os.path.join(BASE, "T_Superhero_Male_Dark.png")), (1.1, 1.0, 0.95))
    acc, led = accent(WHITE)
    c.dress(0.1, {"torso": coat, "uarm": coat, "farm": coat, "hips": coat, "thigh": pants, "calf": pants,
                   "boot": boot, "hand": rubber, "head": skin},
            {"torso": 0.035, "uarm": 0.03, "farm": 0.028, "hips": 0.035, "thigh": 0.008, "calf": 0.008,
             "boot": 0.016, "hand": 0.008}, boot_top=0.38)
    zw = c.bone_head("spine_01").z
    skirt(c, zw + 0.02, 0.42, coat, flare=1.3, extra=0.045, verts=16)
    w = c.slice(zw)
    rings([(zw - 0.025, w[0] + 0.05, w[1] + 0.05, w[2]), (zw + 0.025, w[0] + 0.05, w[1] + 0.05, w[2])], belt, 12,
          cap=(False, False))
    for x, wd in ((-0.14, 0.07), (-0.05, 0.06), (0.14, 0.08)):
        box((x, w[2] + w[1] + 0.07, zw - 0.04), (wd, 0.06, 0.1), belt)
    box((0.22, w[2] + 0.06, zw - 0.12), (0.035, 0.035, 0.22), metal)
    c.piece("pelvis")
    hd = c.bone_head("Head")
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z + 0.05)
    for z in (zw - 0.25, zw - 0.05, ch.z - 0.05, ch.z + 0.1):
        ball((0.0, cy + ry + 0.04, z), 0.012, metal, seg=6, rings=3)
    ball((-0.12, cy + ry + 0.045, ch.z + 0.1), 0.013, led, seg=6, rings=3)
    c.piece("spine_03")
    H = c.head
    hy, hz = H.y, H.z
    # hood up
    rings([(hz - 0.17, 0.1, 0.11, hy - 0.03), (hz - 0.09, 0.118, 0.132, hy - 0.035), (hz + 0.0, 0.122, 0.137, hy - 0.035),
           (hz + 0.06, 0.12, 0.134, hy - 0.04), (hz + 0.11, 0.102, 0.117, hy - 0.045), (hz + 0.15, 0.072, 0.086, hy - 0.05),
           (hz + 0.172, 0.035, 0.045, hy - 0.052), (hz + 0.18, 0.005, 0.005, hy - 0.052)], coat, 12)
    # full-face mask
    fy = hy + 0.078
    rings([(hz - 0.115, 0.058, 0.04, fy), (hz - 0.075, 0.076, 0.052, fy + 0.005), (hz - 0.01, 0.083, 0.052, fy + 0.003),
           (hz + 0.04, 0.078, 0.047, fy), (hz + 0.068, 0.056, 0.036, fy - 0.006)], rubber, 12)
    for s in (-1, 1):
        loft([(0.036 * s, fy + 0.045, hz + 0.018), (0.037 * s, fy + 0.058, hz + 0.02)], [(0.027, 0.025)] * 2, metal, 10)
        loft([(0.037 * s, fy + 0.056, hz + 0.02), (0.037 * s, fy + 0.06, hz + 0.021)], [(0.022, 0.02)] * 2, glass, 10)
        loft([(0.05 * s, fy + 0.035, hz - 0.07), (0.105 * s, fy + 0.07, hz - 0.11)], [(0.035, 0.035), (0.04, 0.04)], metal, 10)
    loft([(0, fy + 0.045, hz - 0.07), (0, fy + 0.075, hz - 0.085)], [(0.028, 0.028), (0.032, 0.03)], rubber, 8)
    # headlamp
    rings([(hz + 0.085, 0.124, 0.139, hy - 0.035), (hz + 0.105, 0.121, 0.136, hy - 0.037)], rubber, 12, cap=(False, False))
    box((0, hy + 0.1, hz + 0.095), (0.05, 0.04, 0.04), rubber)
    ball((0, hy + 0.122, hz + 0.095), 0.015, lamp, seg=6, rings=3)
    c.piece("Head")
    # battery pack and hose
    rb = cy - ry - 0.05
    rings([(ch.z - 0.3, 0.15, 0.09, rb - 0.09), (ch.z + 0.02, 0.15, 0.09, rb - 0.09), (ch.z + 0.06, 0.13, 0.07, rb - 0.075)],
          metal, 8)
    loft([(0.1, rb - 0.05, ch.z + 0.04), (0.17, cy - 0.04, hz - 0.2), (0.11, fy + 0.03, hz - 0.11)], [(0.011, 0.011)] * 3,
         rubber, 6)
    c.piece("spine_03")
    c.pose_arms(down=66)
    armband_on(c, acc, "l", 0.08)
    for s in ("l", "r"):  # gauntlets
        pb = c.arm.pose.bones[f"lowerarm_{s}"]
        t = c.arm.matrix_world @ pb.tail
        h = c.arm.matrix_world @ pb.head
        a = t.lerp(h, 0.25)
        loft([a, t], [(0.055, 0.055), (0.05, 0.05)], rubber, 8)
        c.piece(f"lowerarm_{s}")
    return c.finish("masque")


CHARS = [mk_ambulancier, mk_parka, mk_masque]


def build(fn, x=0.0, yaw=0.0):
    c = fn()
    for o in [c.arm] + [c.body] + c.extras + c.eyes:
        if o.type == "MESH" and o.material_slots:
            apply_textures(o)
    root = c.root if c.root.name in bpy.data.objects else c.arm
    root.location.x += x
    root.rotation_mode = "XYZ"
    root.rotation_euler.z = math.radians(yaw)
    global LAST
    LAST = c
    n = c.total_tris()
    print(f"{c.arm.name}: {n} tris (body {tris(c.body)})")
    return root, n


_h3 = open(os.path.join(_here, "hunted3.py")).read()
exec(_h3[_h3.index("def shot_turn"):_h3.index("if True:")])
DIRS = {"R": CHARS}


def shot_portraits(d):
    for i, fn in enumerate(DIRS[d]):
        reset()
        build(fn)
        world(0.004)
        hz = LAST.head.z - 0.02
        spot((-1.8, 2.4, 3.2), (0, 0, hz), 900, (1.0, 0.64, 0.32), 50)
        spot((1.8, 1.5, 2.0), (0, 0, hz), 260, (0.75, 0.82, 1.0), 60, 0.6, cam=False)
        spot((0.4, -2.5, 2.4), (0, 0, hz), 500, (0.5, 0.62, 1.0), 60, 0.3, cam=False)
        camera((0.45, 1.1, hz + 0.03), (0, 0, hz - 0.08), 50)
        render(f"{OUT}/{d}-p{i + 1}.png", 240, 300)

shots = WANT or ["turn:1", "turn:2", "turn:3", "trio:R", "port:R", "scene:R", "ingame:0"]
for s in shots:
    kind, d = s.split(":")
    if kind == "turn":
        shot_turn(int(d))
    elif kind == "ingame":
        shot_ingame()
    else:
        {"trio": shot_trio, "port": shot_portraits, "scene": shot_scene}[kind](d)
