"""Builds the hunter, the monster of S-011 (T-122, T-123), rigged and animated.

Track B chosen by Maxime on 14/11/2026: a gaunt 2.3 m figure on the same CC0
base as the hunted (Quaternius, art_src/quaternius_ubc), arms stretched to
the knees, long claws, hunched; a cracked white faceplate with two glowing
red eyes, two listening dishes on the sides of the head (it hunts by ear),
cables from the nape to the shoulders, bare stitched torso under an open,
tattered coat with a high collar. An original creature (constitution 2.7).
Red is the monster's accent; orange (noise) is never used.

Animations (Godot plays them by name, MonsterBody): idle, prowl, walk, run,
scan (listening, the head sweeping), reach (opening a hiding spot).
Same pipeline as tools/blender/hunted.py (one skinned mesh, 64 px Nearest
cloth tiles on cube UVs). Front is +Y in Blender: forward (-Z) in Godot.

    python tools/blender/hunter.py -- <out_blend_dir> <out_dir>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hunted as H  # noqa: E402  (also imports bpy first)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RED = (0.85, 0.04, 0.03)
HEIGHT = 2.3
THIN = (0.8, 0.86)  # Width and depth of the base body.
ARM_STRETCH = (1.3, 1.55)  # Upper arm, forearm.


def thin(c, sx, sy):
    """Narrower and flatter, height kept."""
    objs = [c.arm, c.body] + c.eyes
    for o in objs:
        if o.parent not in objs:
            o.scale = (sx, sy, 1)
    bpy.context.view_layer.update()
    H.select(objs, c.arm)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def stretch_arms(c, k_upper, k_lower):
    """Longer arms in the rest pose: everything past the elbow (then the
    wrist) slides out along the arm, bones and skin alike."""
    b = c.arm.data.bones
    for s in ("l", "r"):
        shoulder = b[f"upperarm_{s}"].head_local.copy()
        elbow = b[f"lowerarm_{s}"].head_local.copy()
        wrist = b[f"hand_{s}"].head_local.copy()
        up = (elbow - shoulder).normalized()
        low = (wrist - elbow).normalized()
        l_up = (elbow - shoulder).length
        l_low = (wrist - elbow).length

        def shift(p, up=up, low=low, shoulder=shoulder, elbow=elbow, l_up=l_up, l_low=l_low):
            a = min(max((p - shoulder).dot(up), 0.0), l_up)
            d = up * a * (k_upper - 1)
            e = min(max((p - elbow).dot(low), 0.0), l_low)
            return d + low * e * (k_lower - 1)

        side = 1 if shoulder.x > 0 else -1
        for v in c.body.data.vertices:
            p = c.body.matrix_world @ v.co
            if p.x * side > abs(shoulder.x) and p.z > shoulder.z - 0.35:
                v.co += c.body.matrix_world.inverted().to_3x3() @ shift(p)
        H.select([c.arm], c.arm)
        bpy.ops.object.mode_set(mode="EDIT")
        for eb in c.arm.data.edit_bones:
            if eb.name.endswith("_" + s) and eb.name.split("_")[0] in (
                "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky",
            ):
                head = eb.head.copy()
                tail = eb.tail.copy()
                eb.head = head + shift(head)
                eb.tail = tail + shift(tail)
            elif eb.name == f"upperarm_{s}":
                eb.tail = eb.tail + shift(eb.tail.copy())
        bpy.ops.object.mode_set(mode="OBJECT")


def claws(c, m, length=0.14):
    """Long thin claws on the finger tips, each on its last finger bone."""
    for s in ("l", "r"):
        for f in ("index", "middle", "ring", "pinky"):
            bone = f"{f}_03_{s}"
            h = c.bone_head(bone)
            t = c.bone_tail(bone)
            d = (t - h).normalized()
            H.loft([t, t + d * length * 0.6, t + d * length], [(0.009, 0.009), (0.006, 0.006), (0.001, 0.001)], m, 4)
            c.piece(bone)


def tattered_skirt(c, z_top, z_hem, m, flare, open_front, seed=3):
    """Coat skirt, open in front, its hem torn at random."""
    pts, rad = [], []
    for i in range(6):
        z = z_top - (z_top - z_hem) * i / 5
        rx, ry, cy = c.slice(max(z, 0.35), 0.3, 0.05)
        ry = max(ry, rx * 0.85)
        f = 1 + (flare - 1) * i / 5
        rad.append(((rx + 0.05) * f, (ry + 0.05) * (1 + (f - 1) * 0.6)))
        pts.append((0, cy, z))
    o = H.loft(pts, rad, m, 14, cap=(False, False))
    bm = bmesh.new()
    bm.from_mesh(o.data)
    if open_front:
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.calc_center_median().y - pts[0][1] > rad[0][1] * 0.6]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
    rnd = random.Random(seed)
    for v in bm.verts:
        if v.co.z < z_hem + 0.2:
            v.co.z += rnd.random() * 0.3
            v.co.x *= 1 + rnd.uniform(-0.06, 0.06)
    bm.to_mesh(o.data)
    bm.free()
    c.piece("pelvis")


def mk_hunter():
    c = H.Char(False, HEIGHT)
    thin(c, *THIN)
    stretch_arms(c, *ARM_STRETCH)
    coat = H.cloth("h_coat", (0.05, 0.048, 0.045), "canvas", rough=0.7)
    flesh = H.cloth("h_flesh", (0.36, 0.33, 0.31), "fabric", rough=0.45)
    porcelain = H.cloth("h_mask", (0.78, 0.76, 0.7), "plastic", rough=0.25)
    iron = H.cloth("h_iron", (0.2, 0.19, 0.18), "plate", rough=0.45)
    rubber = H.cloth("h_rubber", (0.03, 0.03, 0.03), "plastic", rough=0.35)
    pants = H.cloth("h_pants", (0.07, 0.065, 0.06), "canvas")
    stitch = H.mat("h_stitch", (0.04, 0.02, 0.02), rough=0.6)
    red = H.mat("h_red", RED, rough=0.2, emit=(RED, 30))
    eyecore = H.mat("h_eyecore", (1.0, 0.35, 0.3), rough=0.1, emit=((1.0, 0.3, 0.25), 80))
    c.dress(
        0.1,
        {"torso": flesh, "uarm": coat, "farm": flesh, "hips": pants, "thigh": pants, "calf": pants, "boot": rubber,
         "hand": flesh, "head": rubber},
        {"uarm": 0.025, "farm": 0.003, "hips": 0.01, "thigh": 0.006, "calf": 0.006, "boot": 0.014, "hand": 0.002,
         "head": 0.006},
        boot_top=0.32,
    )
    zw = c.bone_head("spine_01").z
    ch = c.bone_head("spine_03")
    rx, ry, cy = c.slice(ch.z)
    # Open coat: torso shell open in front, high collar, long torn skirt.
    pts, rad = [], []
    for z in (ch.z + 0.2, ch.z, zw + 0.1, zw):
        a, b, y = c.slice(z, 0.26, 0.05)
        pts.append((0, y, z))
        rad.append((a + 0.04, b + 0.045))
    o = H.loft(pts, rad, coat, 12, cap=(False, False))
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y - cy > ry * 0.55], context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    hb = c.head
    H.rings([(ch.z + 0.1, 0.16, 0.13, cy - 0.02), (hb.z - 0.13, 0.12, 0.12, hb.y - 0.035),
             (hb.z - 0.06, 0.13, 0.13, hb.y - 0.05)], coat, 12, cap=(False, False))
    c.piece("spine_03")
    tattered_skirt(c, zw + 0.02, 0.2, coat, 1.12, open_front=True)
    # Stitches across the bare torso.
    for z in (ch.z - 0.02, ch.z - 0.16, zw + 0.12):
        a, b, y = c.slice(z, 0.25, 0.05)
        H.box((0, y + b + 0.004, z), (0.16, 0.006, 0.008), stitch)
        for x in (-0.06, -0.02, 0.02, 0.06):
            H.box((x, y + b + 0.005, z), (0.006, 0.006, 0.03), stitch)
    H.box((0, cy + ry + 0.004, ch.z - 0.1), (0.008, 0.006, 0.3), stitch)
    c.piece("spine_03")
    hy, hz = hb.y, hb.z
    fy = hy + 0.06  # Cracked white faceplate.
    H.rings([(hz - 0.13, 0.05, 0.035, fy - 0.01), (hz - 0.08, 0.085, 0.06, fy), (hz, 0.1, 0.07, fy - 0.004),
             (hz + 0.08, 0.098, 0.068, fy - 0.012), (hz + 0.14, 0.072, 0.05, fy - 0.025),
             (hz + 0.17, 0.02, 0.02, fy - 0.03)], porcelain, 14)
    H.loft([(-0.085, fy + 0.035, hz + 0.03), (0, fy + 0.07, hz + 0.03), (0.085, fy + 0.035, hz + 0.03)],
           [(0.004, 0.028)] * 3, rubber, 4, front=(0, 0, 1))
    for s in (-1, 1):  # The two red eyes.
        H.ball((0.036 * s, fy + 0.07, hz + 0.03), 0.019, red, seg=6, rings_=4)
        H.ball((0.036 * s, fy + 0.074, hz + 0.03), 0.009, eyecore, seg=4, rings_=2)
    for (x0, z0), (x1, z1) in (((0.02, 0.1), (0.06, 0.03)), ((0.06, 0.03), (0.05, -0.05)),
                               ((-0.03, -0.02), (-0.07, -0.09))):
        H.loft([(x0, fy + 0.067, hz + z0), (x1, fy + 0.066, hz + z1)], [(0.003, 0.003)] * 2, stitch, 4)
    for s in (-1, 1):  # Listening dishes.
        base = Vector((0.1 * s, hy - 0.01, hz + 0.02))
        H.loft([base, base + Vector((0.05 * s, -0.01, 0.02)), base + Vector((0.07 * s, -0.015, 0.03))],
               [(0.02, 0.02), (0.06, 0.06), (0.085, 0.085)], iron, 8, front=(0, 1, 0), cap=(True, False))
        H.ball(tuple(base + Vector((0.075 * s, -0.015, 0.03))), 0.008, red)
    c.piece("Head")
    for k, x in enumerate((-0.09, -0.03, 0.03, 0.09)):  # Cables from the nape.
        p0 = Vector((x * 0.6, hy - 0.11, hz - 0.03))
        p2 = Vector((x * 1.4, cy - ry - 0.02, ch.z - 0.12 - 0.03 * k))
        H.loft([p0, p0.lerp(p2, 0.5) + Vector((0, -0.12, -0.06)), p2], [(0.012, 0.012)] * 3, rubber, 4)
    c.piece("spine_03")
    claws(c, iron)
    return c


# name: (seconds, legs swing, knee base, knee lift, arm swing, forearm bend, lean, crouch thigh, crouch knee)
CYCLES = {
    "idle": (2.4, 0, 10, 0, 0, 10, 24, 6, 6),
    "prowl": (1.4, 18, 10, 30, 6, 12, 30, 14, 22),
    "walk": (0.9, 28, 8, 45, 12, 14, 24, 0, 0),
    "run": (0.62, 42, 15, 85, 30, 50, 32, 0, 0),
    "scan": (2.0, 0, 10, 0, 0, 20, 14, 4, 6),
    "reach": (1.2, 0, 12, 0, 0, 10, 34, 10, 14),
    # One-shots (T-127): catch, a lunge that grabs with both hands; crush, a
    # stomp of the right foot on a ringing alarm clock.
    "catch": (0.9, 0, 10, 0, 0, 10, 24, 6, 6),
    "crush": (0.8, 0, 10, 0, 0, 10, 24, 6, 6),
}


class HunterRig(H.Rig):
    cycles = CYCLES

    def params(self, name, t):
        values = self.cycles[name]
        if name != "catch":
            return values
        # The lunge: it drops low and leans in, then straightens with its prey.
        k = H.track(t / values[0], [(0, 0), (0.3, 1), (0.6, 1), (1, 0.3)])
        return values[:6] + (values[6] + 26 * k, values[7] + 24 * k, values[8] + 30 * k)

    def finish(self, name, p):
        self.rot("Head", "X", 18)  # The face juts forward, the eyes on the prey.
        if name == "scan":  # Listening: the head sweeps, slowly, tilted.
            self.rot("Head", "Z", 28 * math.sin(p))
            self.rot("Head", "Y", 10 * math.sin(p * 0.5))
        if name == "reach":  # Both arms forward, claws open and closing.
            for s in ("l", "r"):
                self.rot(f"upperarm_{s}", "X", 70 + 6 * math.sin(p))
                self.rot(f"lowerarm_{s}", "X", 10 + 10 * math.sin(p))
        u = p / (2 * math.pi)
        if name == "catch":  # Arms shoot out, then the claws close on the prey.
            for s in ("l", "r"):
                self.rot(f"upperarm_{s}", "X", H.track(u, [(0, 0), (0.3, 70), (0.55, 45), (1, 25)]))
                self.rot(f"lowerarm_{s}", "X", H.track(u, [(0, 0), (0.3, 0), (0.55, 35), (1, 25)]))
                for f in ("index", "middle", "ring", "pinky"):
                    self.rot(f"{f}_01_{s}", "Y", H.track(u, [(0, 0), (0.4, 0), (0.55, 1), (1, 1)]) * 40 * (-1 if s == "l" else 1))
        if name == "crush":  # The right foot rises, then slams down.
            lift = H.track(u, [(0, 0), (0.35, 1), (0.48, 0), (1, 0)])
            self.rot("thigh_r", "X", 75 * lift)
            self.rot("calf_r", "X", -95 * lift)
            self.rot("Head", "X", H.track(u, [(0, 0), (0.35, 12), (0.5, 22), (1, 0)]))
            for s, sign in (("l", 1), ("r", -1)):
                self.rot(f"upperarm_{s}", "Y", 25 * sign * H.track(u, [(0, 0), (0.35, 1), (0.6, 1), (1, 0)]))


def build():
    H.reset()
    c = mk_hunter()
    body = c.merge()
    rig = HunterRig(c)
    for name in rig.cycles:
        rig.bake(name)
    for pb in c.arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    c.arm.name = "hunter"
    body.name = "hunter_mesh"
    for m in bpy.data.materials:
        for node in m.node_tree.nodes if m.node_tree else []:
            if node.type == "TEX_IMAGE":
                node.interpolation = "Closest"
    n = H.tris(body)
    print(f"hunter: {n} triangles, {len(body.material_slots)} materials")
    assert n <= H.BUDGET, f"hunter over budget: {n}"
    return c.arm, body


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    blend_dir, out_dir = args[0], args[1]
    arm, body = build()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, "hunter.blend"))
    H.select([arm, body], arm)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, "hunter.glb"),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_apply=False,
    )
