"""Exports the three hunted of "Le Reseau" for the game (S-011). Run with bpy 5.2.

Usage: python export.py UBC_DIR OUT_DIR
UBC_DIR = "Universal Base Characters[Standard]" folder (Quaternius, CC0).
Writes OUT_DIR/hunted_ambulancier.glb, hunted_parka.glb, hunted_masque.glb:
the models of hunted4.py in their rest pose (T-pose), the box-projected cloth
textures turned into real UVs (glTF has no box projection), and four in-place
animations made by rotating the bones: Idle, Walk, Run (looping) and Kneel
(captured, held). Facing +Y in Blender, so -Z (forward) in Godot.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
UBC_DIR, OUT_DIR = sys.argv[1], sys.argv[2]
os.makedirs(OUT_DIR, exist_ok=True)
_h4 = os.path.join(HERE, "hunted4.py")
_src = open(_h4).read()
_src = _src[:_src.index("_h3 = open(")]
sys.argv = [_h4, UBC_DIR, OUT_DIR]
__file__ = _h4
exec(compile(_src, _h4, "exec"))  # Char, mk_*, CHARS, build(), reset(), apply_textures()

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

FPS = 24
NAMES = ["ambulancier", "parka", "masque"]


# ------------------------------------------------------------ box UVs

def bake_box_uvs(obj):
    """Gives the faces of the cloth materials UVs equal to the box projection
    of their texture node, then feeds the texture from the UVs instead."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    layer = me.uv_layers.active or me.uv_layers[0]
    me.uv_layers.active = layer
    uv = layer.data
    scale_of = {}
    for i, slot in enumerate(obj.material_slots):
        m = slot.material
        if m is None or not m.get("tex"):
            continue
        nt = m.node_tree
        mp = next((n for n in nt.nodes if n.type == "MAPPING"), None)
        if mp is None:
            continue
        scale_of[i] = mp.inputs["Scale"].default_value[0]
    for p in me.polygons:
        s = scale_of.get(p.material_index)
        if s is None:
            continue
        n = p.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co[a] * s, co[b] * s)
    for i in scale_of:
        nt = obj.material_slots[i].material.node_tree
        for n in [n for n in nt.nodes if n.type in ("MAPPING", "TEX_COORD")]:
            nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "TEX_IMAGE":
                n.projection = "FLAT"


# ------------------------------------------------------------ animation

class Poser:
    def __init__(self, c):
        self.c = c
        self.arm = c.arm
        self.pb = self.arm.pose.bones
        bones = self.arm.data.bones
        self.drop = bones["calf_l"].head_local.z * self.arm.matrix_world.to_scale().z - 0.09

    def clear(self):
        for pb in self.pb:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()

    def rot(self, bone, axis, deg):
        pb = self.pb[bone]
        h = pb.head.copy()
        r = Matrix.Rotation(math.radians(deg), 4, axis)
        pb.matrix = Matrix.Translation(h) @ r @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()

    def move(self, bone, offset):
        pb = self.pb[bone]
        pb.matrix = Matrix.Translation(Vector(offset)) @ pb.matrix
        bpy.context.view_layer.update()

    def key(self, frame):
        for pb in self.pb:
            pb.rotation_mode = "QUATERNION"
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)


def stride(p, t, legs, knee, arms, elbow, bob, lean, arms_down):
    """One frame of a walk or run cycle at phase t (0..1)."""
    a = 2 * math.pi * t
    p.clear()
    p.move("pelvis", (0, 0, bob * math.cos(2 * a) - bob))
    p.rot("spine_01", "X", -lean)
    p.c.pose_arms(down=arms_down, bend=elbow, fwd=4)
    for s, k in (("l", 1), ("r", -1)):
        swing = k * math.sin(a)
        forward = max(0.0, k * math.cos(a))
        p.rot(f"thigh_{s}", "X", legs * swing)
        p.rot(f"calf_{s}", "X", -(6 + knee * forward))
        p.rot(f"upperarm_{s}", "X", -arms * swing)
    p.rot("Head", "X", lean * 0.5)


def idle(p, t):
    a = 2 * math.pi * t
    p.clear()
    p.move("pelvis", (0, 0, -0.004 + 0.004 * math.cos(a)))
    p.rot("spine_03", "X", 1.5 * math.sin(a))
    p.c.pose_arms(down=68 + 2 * math.sin(a), bend=12, fwd=6)
    p.rot("Head", "Y", 3 * math.sin(a * 0.5))


def kneel(p, _t):
    p.clear()
    p.move("pelvis", (0, 0, -p.drop))
    for s in ("l", "r"):
        p.rot(f"thigh_{s}", "X", 8)
        p.rot(f"calf_{s}", "X", -96)
        p.rot(f"foot_{s}", "X", 20)
    p.rot("spine_01", "X", -14)
    p.c.pose_arms(down=74, bend=30, fwd=14)
    p.rot("Head", "X", -26)


ANIMS = [
    # name, frames (one cycle), pose(p, t)
    ("Idle", 48, idle),
    ("Walk", 26, lambda p, t: stride(p, t, 24, 34, 16, 14, 0.025, 3, 70)),
    ("Run", 16, lambda p, t: stride(p, t, 42, 80, 38, 70, 0.05, 12, 72)),
    ("Kneel", 1, kneel),
]


def animate(c):
    p = Poser(c)
    arm = c.arm
    arm.animation_data_create()
    for name, frames, fn in ANIMS:
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        for f in range(frames + 1):
            fn(p, (f % frames) / frames if frames > 1 else 0.0)
            p.key(f)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act)
        arm.animation_data.action = None
    p.clear()


# ------------------------------------------------------------ export

def export(i, fn):
    reset()
    c = fn()
    objs = [c.body] + c.extras + c.eyes
    for o in objs:
        if o.type == "MESH" and o.material_slots:
            apply_textures(o)
            bake_box_uvs(o)
    animate(c)
    root = c.root if c.root.name in bpy.data.objects else c.arm
    bpy.ops.object.select_all(action="DESELECT")
    for o in [root] + list(root.children_recursive):
        o.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = c.arm
    path = os.path.join(OUT_DIR, f"hunted_{NAMES[i]}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_frame_range=False,
        export_force_sampling=True,
        export_optimize_animation_size=True,
        export_def_bones=False,
        export_yup=True,
        export_apply=True,
    )
    print(f"EXPORTED {path} {c.total_tris()} tris")


bpy.context.scene.render.fps = FPS
for i, fn in enumerate(CHARS):
    export(i, fn)
