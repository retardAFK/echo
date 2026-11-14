"""Juggernaut cyborg concepts for Echo (round 3). Run with bpy 5.2."""
import math
import sys

sys.argv = [sys.argv[0], sys.argv[1], "__none__"] + sys.argv[2:]
OUT = sys.argv[1]
WANT = sys.argv[3:]
src = open(__file__.replace("colosse.py", "monsters.py")).read()
src = src.replace("\nmain()\n", "\n")
exec(src)  # helpers: mat, limb, box, ball, finish, human_ref, reset


def body(flesh, dark):
    """Shared massive frame, faces +Y, ~2.5 m."""
    for s in (-1, 1):
        limb((0.22 * s, 0, 1.15), (0.26 * s, 0.14, 0.62), 0.18, 0.15, flesh, 8)
        limb((0.26 * s, 0.14, 0.62), (0.26 * s, 0.0, 0.12), 0.14, 0.11, dark, 8)
        box((0.26 * s, 0.1, 0.08), (0.28, 0.46, 0.16), dark)
    box((0, 0, 1.18), (0.6, 0.38, 0.32), dark)
    limb((0, 0, 1.25), (0, 0.12, 1.9), 0.3, 0.42, flesh, 8)
    box((0, 0.2, 1.72), (0.86, 0.46, 0.55), flesh, rot=(12, 0, 0))
    box((0, -0.02, 2.06), (0.8, 0.45, 0.3), flesh, rot=(-10, 0, 0))  # traps
    for s in (-1, 1):
        ball((0.48 * s, 0.08, 1.98), 0.22, flesh, scale=(1, 1, 0.9))


def bruiser_arm(s, flesh, metal):
    sh, el, wr = (0.55 * s, 0.1, 1.95), (0.66 * s, 0.2, 1.42), (0.64 * s, 0.4, 0.98)
    limb(sh, el, 0.15, 0.13, flesh, 8)
    limb(el, wr, 0.13, 0.11, flesh, 8)
    box((wr[0], 0.46, 0.85), (0.22, 0.22, 0.26), flesh)
    for f in (-1, 0, 1):
        limb((wr[0] + 0.06 * f, 0.5, 0.75), (wr[0] + 0.07 * f, 0.58, 0.6), 0.04, 0.03, flesh, 5)
    for i in range(3):  # metal braces on the forearm
        box((wr[0], 0.25 + i * 0.07, 1.3 - i * 0.14), (0.3, 0.06, 0.06), metal, rot=(-20, 0, 0))


def hydraulic_arm(s, metal, dark, red):
    sh, el, wr = (0.55 * s, 0.1, 1.95), (0.72 * s, 0.25, 1.4), (0.7 * s, 0.55, 0.95)
    limb(sh, el, 0.14, 0.12, metal, 8)
    box(((sh[0] + el[0]) / 2, 0.1, 1.7), (0.3, 0.3, 0.38), dark, rot=(-15, 0, 0))
    ball(el, 0.13, dark)
    box(((el[0] + wr[0]) / 2, 0.42, 1.15), (0.34, 0.34, 0.6), metal, rot=(-35, 0, 0))
    for d in (-1, 1):  # pistons
        limb((el[0] + 0.17 * d, 0.2, 1.45), (wr[0] + 0.15 * d, 0.6, 0.95), 0.035, 0.035, dark, 6)
    ball((wr[0], 0.62, 0.88), 0.03, red, seg=6, rings=3)
    for f in (-1, 0, 1):  # 3 heavy claws
        a = (wr[0] + 0.12 * f, 0.68, 0.85)
        b = (wr[0] + 0.16 * f, 0.92, 0.55)
        limb(a, b, 0.06, 0.04, metal, 5)
        limb(b, (wr[0] + 0.14 * f, 0.95, 0.25), 0.04, 0.0, dark, 5)


def boucher():
    """Flesh juggernaut with a hydraulic arm, respirator jaw and ear implants."""
    flesh = mat("bo_flesh", (0.33, 0.24, 0.22), rough=0.45)
    scar = mat("bo_scar", (0.25, 0.04, 0.04), rough=0.3)
    metal = mat("bo_metal", (0.34, 0.33, 0.33), rough=0.3)
    dark = mat("bo_dark", (0.035, 0.035, 0.04), rough=0.6)
    red = mat("bo_red", (0.2, 0, 0), emit=((1, 0.04, 0.02), 30))
    body(flesh, dark)
    # stitched scars and straps
    for i in range(6):
        box((-0.15 + i * 0.05, 0.45, 1.55 + i * 0.05), (0.03, 0.02, 0.12), scar)
    box((0.05, 0.42, 1.6), (0.12, 0.04, 0.9), dark, rot=(0, 40, 0))
    # spine: plates + cables into the skull
    for i in range(5):
        box((0, -0.25, 1.35 + i * 0.16), (0.24, 0.12, 0.1), metal)
    for s in (-1, 1):
        limb((0.08 * s, -0.25, 1.9), (0.06 * s, 0.05, 2.25), 0.025, 0.025, dark, 4)
    # head sunk between the shoulders, plated skull
    ball((0, 0.3, 2.17), 0.15, flesh, scale=(1, 1.05, 1.15))
    ball((0, 0.26, 2.24), 0.155, metal, scale=(1.03, 1.05, 0.75), seg=8, rings=4)
    # respirator replaces the jaw, tubes to the chest
    box((0, 0.44, 2.07), (0.2, 0.14, 0.14), metal)
    for i in range(3):
        box((0, 0.515, 2.03 + i * 0.035), (0.16, 0.01, 0.012), dark)
    for s in (-1, 1):
        limb((0.09 * s, 0.48, 2.04), (0.22 * s, 0.48, 1.85), 0.025, 0.025, dark, 5)
        limb((0.22 * s, 0.48, 1.85), (0.2 * s, 0.46, 1.7), 0.025, 0.025, dark, 5)
    # cluster of red lenses on one side, the other eye stitched shut
    for p in ((0.06, 0.43, 2.2), (0.1, 0.42, 2.25), (0.11, 0.41, 2.17)):
        ball(p, 0.022, red, seg=6, rings=3)
    box((-0.06, 0.44, 2.2), (0.07, 0.01, 0.01), scar)
    # ear implants: microphones bolted into the temples
    for s in (-1, 1):
        for i in range(3):
            p = (0.15 * s, 0.26 - i * 0.06, 2.2 + i * 0.03)
            limb(p, (0.27 * s, 0.24 - i * 0.07, 2.24 + i * 0.05), 0.022, 0.018, metal, 6)
    bruiser_arm(-1, flesh, metal)
    hydraulic_arm(1, metal, dark, red)
    return finish("boucher")


def blinde():
    """Armoured juggernaut: plates, cage helmet, exhaust stacks, hammer fists."""
    raw = mat("bl_raw", (0.3, 0.07, 0.06), rough=0.35)
    steel = mat("bl_steel", (0.28, 0.29, 0.31), rough=0.25)
    rust = mat("bl_rust", (0.2, 0.12, 0.08), rough=0.8)
    dark = mat("bl_dark", (0.03, 0.03, 0.035), rough=0.6)
    red = mat("bl_red", (0.2, 0, 0), emit=((1, 0.04, 0.02), 40))
    body(raw, dark)
    # armour plates over the raw muscle
    box((0, 0.36, 1.72), (0.7, 0.12, 0.5), steel, rot=(12, 0, 0))
    box((0, 0.3, 1.38), (0.5, 0.1, 0.25), rust, rot=(5, 0, 0))
    for s in (-1, 1):
        box((0.5 * s, 0.08, 2.12), (0.42, 0.5, 0.14), steel, rot=(0, 25 * s, 0))
        box((0.58 * s, 0.08, 2.0), (0.36, 0.46, 0.12), rust, rot=(0, 40 * s, 0))
        box((0.26 * s, 0.24, 0.65), (0.2, 0.08, 0.3), steel)
    # exhaust stacks on the back with a red glow inside
    for s in (-1, 1):
        limb((0.18 * s, -0.3, 1.8), (0.22 * s, -0.36, 2.5), 0.07, 0.06, dark, 8)
        ball((0.22 * s, -0.36, 2.5), 0.045, red, seg=6, rings=3)
    # head: raw face behind a steel cage, glowing from inside
    ball((0, 0.28, 2.17), 0.15, raw, scale=(1, 1.05, 1.15))
    ball((0, 0.4, 2.17), 0.06, red, scale=(1.6, 0.5, 0.6), seg=6, rings=3)
    for i in range(5):
        x = -0.12 + i * 0.06
        limb((x, 0.47, 2.0), (x, 0.45, 2.36), 0.012, 0.012, steel, 4)
    for z in (2.06, 2.3):
        limb((-0.17, 0.42, z), (0.17, 0.42, z), 0.014, 0.014, steel, 4)
    box((0, 0.26, 2.37), (0.36, 0.42, 0.06), steel)
    # ear implants: two horn-like receivers on the cage
    for s in (-1, 1):
        limb((0.16 * s, 0.25, 2.3), (0.3 * s, 0.05, 2.55), 0.05, 0.02, steel, 5)
        ball((0.3 * s, 0.05, 2.55), 0.025, red, seg=6, rings=3)
    # hammer fists: arms end in steel blocks
    for s in (-1, 1):
        sh, el, wr = (0.55 * s, 0.1, 1.95), (0.68 * s, 0.22, 1.42), (0.66 * s, 0.42, 1.0)
        limb(sh, el, 0.15, 0.13, raw, 8)
        limb(el, wr, 0.13, 0.12, steel, 8)
        box((wr[0], 0.5, 0.82), (0.3, 0.32, 0.36), steel)
        box((wr[0], 0.5, 0.82), (0.34, 0.2, 0.2), rust)
        for i in range(3):
            ball((wr[0] + 0.1 * (i - 1), 0.67, 0.86), 0.035, dark, seg=6, rings=3)
    return finish("blinde")


def boucher2():
    """More monstrous Boucher: mutated mass, bone spikes, open jaw, dragging limbs."""
    flesh = mat("b2_flesh", (0.3, 0.2, 0.18), rough=0.4)
    raw = mat("b2_raw", (0.32, 0.03, 0.03), rough=0.25)
    bone = mat("b2_bone", (0.62, 0.58, 0.48), rough=0.6)
    metal = mat("b2_metal", (0.3, 0.29, 0.29), rough=0.3)
    dark = mat("b2_dark", (0.03, 0.03, 0.035), rough=0.6)
    red = mat("b2_red", (0.2, 0, 0), emit=((1, 0.04, 0.02), 30))
    # legs: bent, backward-jointed, wider stance
    for s in (-1, 1):
        hip, knee, ank = (0.26 * s, 0, 1.12), (0.36 * s, 0.3, 0.68), (0.34 * s, -0.1, 0.25)
        limb(hip, knee, 0.2, 0.15, flesh, 8)
        limb(knee, ank, 0.12, 0.09, raw, 8)
        limb(ank, (0.34 * s, 0.1, 0.05), 0.09, 0.08, dark, 6)
        for f in (-1, 0, 1):
            limb((0.34 * s, 0.1, 0.05), (0.34 * s + 0.09 * f, 0.38, 0.0), 0.05, 0.0, bone, 4)
        box((0.36 * s, 0.38, 0.7), (0.2, 0.06, 0.26), metal, rot=(-20, 0, 0))
    box((0, 0, 1.15), (0.62, 0.4, 0.32), dark)
    # torso: huge, asymmetric; left side swollen with growths
    limb((0, 0, 1.2), (0, 0.15, 1.95), 0.32, 0.46, flesh, 8)
    box((0, 0.22, 1.7), (0.92, 0.48, 0.6), flesh, rot=(12, 0, 0))
    box((0, -0.02, 2.08), (0.86, 0.5, 0.34), flesh, rot=(-10, 0, 0))
    for p, r in (((-0.55, 0.0, 2.15), 0.3), ((-0.4, -0.2, 2.35), 0.22), ((-0.7, 0.15, 1.9), 0.18),
                 ((-0.25, 0.1, 2.4), 0.15), ((0.45, -0.05, 2.0), 0.2)):
        ball(p, r, flesh, seg=7, rings=5)
    for p, r in (((-0.58, 0.22, 2.05), 0.1), ((-0.35, 0.0, 2.48), 0.07), ((-0.75, 0.05, 2.1), 0.08)):
        ball(p, r, raw, seg=6, rings=4)  # raw pustules
    # exposed ribs over a raw wound on the right flank
    box((0.3, 0.42, 1.55), (0.32, 0.06, 0.42), raw, rot=(12, 0, 0))
    for i in range(4):
        z = 1.4 + i * 0.1
        limb((0.12, 0.47, z), (0.46, 0.4, z + 0.04), 0.022, 0.018, bone, 4)
    # bone spikes through the back and shoulders
    for p, d, l in (((0, -0.25, 1.6), (0, -1, 0.5), 0.35), ((0, -0.28, 1.85), (0, -1, 0.7), 0.42),
                    ((0, -0.24, 2.1), (0, -0.7, 1), 0.45), ((-0.45, -0.2, 2.35), (-0.4, -0.6, 1), 0.4),
                    ((0.5, -0.1, 2.15), (0.6, -0.4, 1), 0.35), ((-0.65, 0.05, 2.2), (-1, -0.2, 0.6), 0.3)):
        v = Vector(d).normalized()
        limb(p, Vector(p) + v * l, 0.06, 0.0, bone, 5)
    # cables torn out of the back, hanging with hooks
    for s, x in ((-1, -0.2), (1, 0.15), (1, 0.3)):
        a = (x, -0.3, 1.95)
        b = (x * 1.3, -0.55, 1.2)
        c = (x * 1.4, -0.5, 0.5 + 0.2 * s)
        limb(a, b, 0.02, 0.02, dark, 4)
        limb(b, c, 0.02, 0.015, dark, 4)
        limb(c, (c[0], c[1] + 0.08, c[2] - 0.08), 0.02, 0.0, metal, 4)
    # head sunk LOW between the shoulders, jaw hanging open
    ball((0, 0.42, 2.02), 0.15, flesh, scale=(1, 1.1, 1.05))
    ball((0, 0.4, 2.1), 0.155, metal, scale=(1.05, 1.05, 0.65), seg=8, rings=4)
    box((0, 0.56, 1.98), (0.2, 0.12, 0.1), metal)  # respirator, upper half
    for i in range(3):
        box((0, 0.625, 1.95 + i * 0.03), (0.16, 0.01, 0.01), dark)
    # split lower jaw hanging on hinges, lined with teeth
    for s in (-1, 1):
        a, b = (0.1 * s, 0.5, 1.92), (0.14 * s, 0.68, 1.62)
        limb(a, b, 0.05, 0.03, raw, 5)
        for i in range(4):
            q = Vector(a).lerp(Vector(b), 0.15 + i * 0.22)
            limb(q, q + Vector((-0.05 * s, 0.03, 0.04)), 0.014, 0.0, bone, 3)
    ball((0, 0.55, 1.85), 0.07, dark, scale=(1.4, 0.7, 1.5))  # gullet
    for s in (-1, 1):
        limb((0.09 * s, 0.6, 1.96), (0.25 * s, 0.55, 1.75), 0.025, 0.025, dark, 5)
        limb((0.25 * s, 0.55, 1.75), (0.22 * s, 0.52, 1.55), 0.025, 0.025, dark, 5)
    for p in ((0.07, 0.55, 2.1), (0.11, 0.54, 2.15), (0.12, 0.53, 2.06), (0.04, 0.56, 2.16)):
        ball(p, 0.02, red, seg=6, rings=3)
    box((-0.07, 0.56, 2.09), (0.08, 0.01, 0.01), raw)
    for s in (-1, 1):  # ear microphones
        for i in range(3):
            q = (0.15 * s, 0.38 - i * 0.06, 2.1 + i * 0.03)
            limb(q, (0.28 * s, 0.36 - i * 0.07, 2.14 + i * 0.05), 0.022, 0.018, metal, 6)
    # right: hydraulic arm, longer, claws scraping the ground
    sh, el, wr = (0.58, 0.15, 1.95), (0.8, 0.35, 1.3), (0.78, 0.7, 0.75)
    limb(sh, el, 0.15, 0.13, metal, 8)
    ball(el, 0.14, dark)
    box(((el[0] + wr[0]) / 2, 0.52, 1.03), (0.36, 0.36, 0.7), metal, rot=(-40, 0, 0))
    for d in (-1, 1):
        limb((el[0] + 0.17 * d, 0.3, 1.33), (wr[0] + 0.15 * d, 0.75, 0.75), 0.035, 0.035, dark, 6)
    for f in (-1, 0, 1):
        a = (wr[0] + 0.12 * f, 0.82, 0.65)
        b = (wr[0] + 0.18 * f, 1.05, 0.35)
        limb(a, b, 0.06, 0.04, metal, 5)
        limb(b, (wr[0] + 0.2 * f, 1.1, 0.0), 0.04, 0.0, raw, 5)
    # left: swollen mutated arm, too long, bone fingers dragging
    sh, el, wr = (-0.62, 0.12, 1.95), (-0.88, 0.3, 1.3), (-0.85, 0.55, 0.6)
    limb(sh, el, 0.2, 0.17, flesh, 8)
    ball((-0.8, 0.22, 1.55), 0.17, flesh, seg=7, rings=5)
    limb(el, wr, 0.17, 0.13, raw, 8)
    for f in range(5):
        a = (wr[0] + 0.07 * (f - 2), 0.62, 0.5)
        limb(a, (wr[0] + 0.12 * (f - 2), 0.95, 0.02), 0.035, 0.008, bone, 4)
    return finish("boucher2")


def scene3(yaw, dist, cz, tz):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 360
    sc.render.resolution_y = 480
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - High Contrast"
    sc.view_settings.exposure = 0.3
    world = bpy.data.worlds.new("night")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes["Background"].inputs["Color"].default_value = (0.004, 0.005, 0.008, 1)
    vol = nt.nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Density"].default_value = 0.02
    vol.inputs["Color"].default_value = (0.3, 0.32, 0.38, 1)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])
    bpy.ops.mesh.primitive_plane_add(size=40)
    bpy.context.object.data.materials.append(mat("asphalt", (0.04, 0.04, 0.045), rough=0.6))
    # sodium lamp high on the side, from slightly behind: face half in shadow
    bpy.ops.object.light_add(type="SPOT", location=(2.6, -0.6, 5.2))
    lamp = bpy.context.object
    lamp.data.energy = 2200
    lamp.data.color = (1.0, 0.6, 0.26)
    lamp.data.spot_size = math.radians(60)
    lamp.data.shadow_soft_size = 0.05
    lamp.rotation_euler = (Vector((0.3, 0.2, 1.4)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
    # cold back rim to cut the silhouette out of the fog
    bpy.ops.object.light_add(type="SPOT", location=(-1.8, -3.2, 3.0))
    rim = bpy.context.object
    rim.data.energy = 900
    rim.data.spot_size = math.radians(35)
    rim.data.shadow_soft_size = 0.3
    rim.data.color = (0.5, 0.62, 1.0)
    rim.visible_camera = False
    rim.rotation_euler = (Vector((0, 0, 1.6)) - rim.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    sc.camera = cam
    cam.data.lens = 28
    a = math.radians(yaw)
    cam.location = (dist * math.sin(a), dist * math.cos(a), cz)
    cam.rotation_euler = (Vector((0, 0, tz)) - cam.location).to_track_quat("-Z", "Y").to_euler()


import os
TEX = os.environ.get("TEX") == "1"
if TEX:
    import importlib.util
    _sp = importlib.util.spec_from_file_location("texmod", __file__.replace("colosse.py", "textures.py"))
    texmod = importlib.util.module_from_spec(_sp)
    _sp.loader.exec_module(texmod)
SHOTS_HERO = True
SHOTS = {
    "boucher2": (boucher2, [("face", 22, 3.5, 0.7, 1.35), ("scene", 5, 7.0, 1.1, 1.3), ("dos", 150, 4.0, 1.4, 1.4), ("portrait", 18, 2.3, 1.7, 1.85)]),
    "boucher": (boucher, [("face", 22, 3.4, 0.7, 1.4), ("scene", 5, 7.0, 1.1, 1.3)]),
    "blinde": (blinde, [("face", -22, 3.4, 0.7, 1.4), ("scene", -5, 7.0, 1.1, 1.3)]),
}
for n in WANT or SHOTS:
    fn, shots = SHOTS[n]
    for tag, yaw, dist, cz, tz in shots:
        reset()
        h = human_ref()[0]
        h.location = (-1.25 if yaw > 0 else 1.25, -1.2, 0)
        if tag == "scene":  # hunted in the foreground, back to camera
            h.location = (1.15 if yaw > 0 else -1.15, 4.9, 0)
            h.rotation_euler.z = math.pi
        o = fn()[0]
        if TEX:
            texmod.apply(o, 2.5)
        for v in o.data.vertices:  # slump the upper body forward
            if v.co.z > 1.2:
                k = v.co.z - 1.2
                v.co.y += k * 0.38
                v.co.z -= k * 0.08
        scene3(yaw, dist, cz, tz)
        if n == "boucher2" and tag in ("face", "portrait"):  # dim sodium fill from the front-left
            bpy.ops.object.light_add(type="SPOT", location=(-2.0, 3.5, 3.2))
            fl = bpy.context.object
            fl.data.energy = 500
            fl.data.color = (1.0, 0.6, 0.3)
            fl.data.spot_size = math.radians(40)
            fl.rotation_euler = (Vector((0, 0.3, 1.6)) - fl.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.render.filepath = f"{OUT}/{n}-{tag}{'-tex' if TEX else ''}.png"
        bpy.ops.render.render(write_still=True)
