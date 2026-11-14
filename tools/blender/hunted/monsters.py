"""Concept renders for 4 monster proposals (Echo). Run with bpy 5.2.

Usage: python monsters.py OUT_DIR [concept ...]
Each concept is a low-poly mesh built from primitives, rendered next to a
1.75 m human reference in a night / sodium lamp / fog scene.
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[1]
ONLY = sys.argv[2:]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


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


PARTS = []


def add(obj, m):
    obj.data.materials.append(m)
    PARTS.append(obj)
    return obj


def limb(p1, p2, r1, r2, m, verts=6):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=d.length, location=(p1 + p2) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    return add(o, m)


def box(loc, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc,
                                    rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.scale = size
    return add(o, m)


def ball(loc, r, m, scale=(1, 1, 1), seg=8, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    return add(o, m)


def finish(name, x=0.0):
    """Join PARTS into one object, report triangles."""
    global PARTS
    bpy.ops.object.select_all(action="DESELECT")
    for p in PARTS:
        p.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.location.x += x
    PARTS = []
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print(f"{name}: {tris} tris")
    return o, tris


# ---------------------------------------------------------------- concepts

def human_ref():
    g = mat("ref", (0.18, 0.18, 0.2))
    limb((-0.1, 0, 0), (-0.1, 0, 0.85), 0.07, 0.08, g)
    limb((0.1, 0, 0), (0.1, 0, 0.85), 0.07, 0.08, g)
    limb((0, 0, 0.85), (0, 0, 1.45), 0.17, 0.2, g)
    limb((-0.24, 0, 1.42), (-0.27, 0, 0.8), 0.05, 0.04, g)
    limb((0.24, 0, 1.42), (0.27, 0, 0.8), 0.05, 0.04, g)
    ball((0, 0, 1.6), 0.12, g)
    return finish("human_ref")


def pavillon():
    """Tall thin biped whose head is a listening horn."""
    skin = mat("pav_skin", (0.42, 0.40, 0.36))
    dark = mat("pav_in", (0.05, 0.015, 0.015), rough=0.4)
    rag = mat("pav_rag", (0.12, 0.13, 0.12))
    # legs, backward knees
    for s in (-1, 1):
        x = 0.16 * s
        limb((x, 0.05, 0), (x, -0.15, 0.7), 0.035, 0.05, skin)
        limb((x, -0.15, 0.7), (x * 0.8, 0.1, 1.35), 0.05, 0.07, skin)
        limb((x, 0.05, 0), (x, 0.22, 0.0), 0.03, 0.02, skin)  # long foot
    # pelvis + torso hunched forward
    limb((0, 0.08, 1.3), (0, 0.32, 2.0), 0.13, 0.17, skin)
    box((0, 0.12, 1.4), (0.32, 0.22, 0.25), rag, rot=(15, 0, 0))  # rag
    # arms to below knees
    for s in (-1, 1):
        sh = (0.22 * s, 0.33, 1.95)
        el = (0.32 * s, 0.38, 1.25)
        wr = (0.3 * s, 0.45, 0.55)
        limb(sh, el, 0.04, 0.035, skin)
        limb(el, wr, 0.035, 0.025, skin)
        for f in (-1, 0, 1):
            limb(wr, (wr[0] + 0.04 * f, wr[1] + 0.05, 0.28), 0.012, 0.004, skin, 4)
    # neck + horn head turned to the side (listening)
    limb((0, 0.32, 1.98), (0.05, 0.5, 2.18), 0.06, 0.05, skin)
    horn_dir = Vector((-0.75, 0.55, 0.3)).normalized()
    base = Vector((0.05, 0.5, 2.18))
    limb(base, base + horn_dir * 0.55, 0.06, 0.34, skin, 10)
    limb(base + horn_dir * 0.08, base + horn_dir * 0.56, 0.02, 0.31, dark, 10)
    return finish("pavillon")


def encombrant():
    """Hunched mass made of the estate's discarded objects."""
    mattress = mat("enc_mat", (0.38, 0.33, 0.24))
    stain = mat("enc_stain", (0.2, 0.15, 0.1))
    metal = mat("enc_metal", (0.3, 0.3, 0.32), rough=0.5)
    bag = mat("enc_bag", (0.06, 0.06, 0.07), rough=0.3)
    skin = mat("enc_skin", (0.25, 0.22, 0.2))
    # short thick legs
    for s in (-1, 1):
        limb((0.3 * s, 0, 0), (0.33 * s, 0.05, 0.6), 0.13, 0.15, skin)
    # folded mattress body, hunched
    box((0, 0.1, 1.05), (1.0, 0.45, 0.9), mattress, rot=(25, 0, 0))
    box((0, 0.45, 1.55), (0.9, 0.4, 0.55), mattress, rot=(60, 0, 0))
    box((0.2, -0.13, 1.1), (0.4, 0.02, 0.3), stain, rot=(25, 0, 0))
    # radiator spine on the back
    for i in range(7):
        box((-0.36 + i * 0.12, -0.2, 1.3), (0.06, 0.12, 0.7), metal, rot=(25, 0, 0))
    # garbage bags clinging
    ball((-0.45, 0.3, 0.75), 0.25, bag, scale=(1, 1, 1.3))
    ball((0.5, -0.1, 1.6), 0.22, bag)
    # head: a bucket hanging low under the hump
    limb((0, 0.75, 1.45), (0, 0.85, 1.15), 0.16, 0.12, metal, 8)
    ball((0, 0.86, 1.14), 0.1, bag)
    # uneven arms: one huge pipe arm dragging, one small
    limb((0.5, 0.4, 1.5), (0.85, 0.7, 0.9), 0.08, 0.07, metal, 8)
    limb((0.85, 0.7, 0.9), (0.8, 1.0, 0.1), 0.07, 0.06, metal, 8)
    box((0.8, 1.05, 0.08), (0.35, 0.3, 0.12), skin)
    limb((-0.48, 0.45, 1.4), (-0.55, 0.65, 1.0), 0.05, 0.04, skin)
    limb((-0.55, 0.65, 1.0), (-0.5, 0.8, 0.75), 0.04, 0.02, skin)
    return finish("encombrant")


def rampant():
    """Low, long crawler with stilt legs and a vertical slit face."""
    skin = mat("ram_skin", (0.3, 0.29, 0.27))
    dark = mat("ram_in", (0.04, 0.01, 0.01), rough=0.3)
    # body: long tapered hull
    limb((0, -1.4, 0.75), (0, 0.9, 0.85), 0.16, 0.3, skin, 6)
    limb((0, -2.1, 0.55), (0, -1.4, 0.75), 0.04, 0.16, skin, 6)  # tail
    # face: two vertical plates with a slit
    for s in (-1, 1):
        box((0.07 * s, 1.12, 0.85), (0.1, 0.06, 0.6), skin, rot=(0, 0, 18 * s))
    box((0, 1.08, 0.85), (0.04, 0.03, 0.5), dark)
    # 6 legs, knees above the back
    for i, y in enumerate((0.6, -0.2, -1.0)):
        for s in (-1, 1):
            hip = (0.18 * s, y, 0.8)
            knee = (0.75 * s, y + 0.15, 1.45 - i * 0.1)
            foot = (1.05 * s, y + 0.3, 0)
            limb(hip, knee, 0.04, 0.03, skin, 5)
            limb(knee, foot, 0.03, 0.008, skin, 5)
    return finish("rampant")


def resident():
    """Almost-normal tenant in a hooded parka, too tall, head tilted."""
    parka = mat("res_parka", (0.12, 0.15, 0.12))
    jean = mat("res_jean", (0.08, 0.09, 0.14))
    skin = mat("res_skin", (0.55, 0.52, 0.48))
    shoe = mat("res_shoe", (0.5, 0.5, 0.5))
    dark = mat("res_void", (0.0, 0.0, 0.0), rough=1.0)
    for s in (-1, 1):
        limb((0.13 * s, 0, 0.08), (0.12 * s, 0, 1.1), 0.07, 0.085, jean)
        box((0.13 * s, 0.06, 0.05), (0.14, 0.32, 0.1), shoe)
    limb((0, 0, 1.0), (0, 0.04, 1.95), 0.21, 0.24, parka, 8)  # parka
    # head tilted 90 degrees on the shoulder, inside the hood
    limb((0, 0.04, 1.93), (0.2, 0.06, 1.98), 0.08, 0.07, parka)
    hood = ball((0.36, 0.06, 1.9), 0.17, parka, scale=(1.35, 1, 1))
    ball((0.38, 0.14, 1.9), 0.12, dark, scale=(1.3, 0.6, 0.9))
    # very long arms, hands at knee height
    for s in (-1, 1):
        sh = (0.28 * s, 0.03, 1.88)
        el = (0.33 * s, 0.05, 1.25)
        wr = (0.32 * s, 0.1, 0.62)
        limb(sh, el, 0.075, 0.07, parka)
        limb(el, wr, 0.07, 0.06, parka)
        for f in (-1, 0, 1):
            limb(wr, (wr[0] + 0.03 * f, wr[1] + 0.02, 0.3), 0.015, 0.006, skin, 4)
    del hood
    return finish("resident")


def ribs(center, rx, ry, z0, z1, n, m, open_front=False):
    """Arcs of thin bones around a vertical-ish axis."""
    cx, cy = center
    for i in range(n):
        z = z0 + (z1 - z0) * i / max(n - 1, 1)
        k = 1 - abs(i - n / 2) / n
        a0, a1 = (math.radians(40), math.radians(320)) if open_front else (0, 2 * math.pi)
        steps = 6
        pts = []
        for j in range(steps + 1):
            a = a0 + (a1 - a0) * j / steps - math.pi / 2 + math.pi
            pts.append((cx + math.sin(a) * rx * k, cy + math.cos(a) * ry * k, z))
        for a, b in zip(pts, pts[1:]):
            limb(a, b, 0.018, 0.018, m, 4)


def traqueur():
    """Armoured biped hunter with parabolic ears and a forearm blade."""
    flesh = mat("tq_flesh", (0.22, 0.12, 0.11), rough=0.6)
    steel = mat("tq_steel", (0.32, 0.33, 0.36), rough=0.35)
    black = mat("tq_black", (0.03, 0.03, 0.035), rough=0.5)
    red = mat("tq_red", (0.2, 0, 0), emit=((1, 0.05, 0.03), 25))
    # digitigrade legs
    for s in (-1, 1):
        hip = (0.2 * s, -0.05, 1.15)
        knee = (0.26 * s, 0.3, 0.75)
        ankle = (0.24 * s, -0.15, 0.3)
        foot = (0.24 * s, 0.1, 0.02)
        limb(hip, knee, 0.11, 0.08, flesh, 6)
        box((0.26 * s, 0.32, 0.8), (0.16, 0.08, 0.3), steel, rot=(-30, 0, 0))
        limb(knee, ankle, 0.07, 0.05, black, 6)
        limb(ankle, foot, 0.05, 0.04, steel, 6)
        for f in (-1, 0, 1):
            limb(foot, (foot[0] + 0.07 * f, 0.32, 0), 0.025, 0.004, black, 4)
    # pelvis + hunched torso
    limb((0, -0.05, 1.1), (0, 0.15, 1.45), 0.16, 0.2, black, 6)
    limb((0, 0.15, 1.4), (0, 0.55, 1.95), 0.24, 0.32, flesh, 7)
    # armour plates along the back
    for i in range(5):
        box((0, 0.05 + i * 0.1, 1.5 + i * 0.12), (0.5 - i * 0.03, 0.08, 0.2),
            steel, rot=(-50, 0, 0))
    # cables back -> head
    for s in (-1, 0, 1):
        limb((0.1 * s, 0.2, 1.55), (0.08 * s, 0.6, 2.25), 0.015, 0.015, black, 4)
        limb((0.08 * s, 0.6, 2.25), (0.05 * s, 0.85, 2.05), 0.015, 0.015, black, 4)
    # head: long eyeless skull pushed forward, metal faceplate, open jaw
    limb((0, 0.6, 1.95), (0, 0.85, 2.05), 0.1, 0.08, flesh, 6)
    limb((0, 0.8, 2.08), (0, 1.25, 1.95), 0.15, 0.05, steel, 6)
    limb((0, 0.82, 1.95), (0, 1.15, 1.72), 0.09, 0.03, flesh, 6)  # jaw
    for i in range(5):
        y = 0.9 + i * 0.05
        limb((0.05, y, 1.9 - i * 0.04), (0.05, y, 1.85 - i * 0.04), 0.01, 0.0, steel, 3)
        limb((-0.05, y, 1.9 - i * 0.04), (-0.05, y, 1.85 - i * 0.04), 0.01, 0.0, steel, 3)
    for i in range(3):
        ball((0, 1.04 + i * 0.07, 2.08 - i * 0.03), 0.022, red, seg=6, rings=3)
    # sensor fins swept back from the skull (its "ears")
    for s_ in (-1, 1):
        for i in range(3):
            root = Vector((0.1 * s_, 0.95 - i * 0.08, 2.08 - i * 0.03))
            tip = root + Vector((0.3 * s_, -0.55 + i * 0.05, 0.35 - i * 0.12))
            limb(root, tip, 0.05, 0.005, steel, 3)
            limb(root + (tip - root) * 0.1, root + (tip - root) * 0.5, 0.012, 0.012, red, 3)
    # right arm: forearm blade ; left arm: claws
    sh, el, wr = (0.38, 0.6, 1.85), (0.5, 0.75, 1.3), (0.42, 1.0, 0.95)
    limb(sh, el, 0.09, 0.07, flesh)
    limb(el, wr, 0.07, 0.06, steel)
    box((0.48, 1.25, 0.75), (0.02, 0.08, 1.0), steel, rot=(-55, 0, 0))
    sh, el, wr = (-0.38, 0.6, 1.85), (-0.55, 0.7, 1.25), (-0.5, 0.9, 0.8)
    limb(sh, el, 0.09, 0.07, flesh)
    limb(el, wr, 0.07, 0.05, flesh)
    for f in (-1, 0, 1):
        limb(wr, (-0.5 + 0.08 * f, 1.15, 0.45), 0.02, 0.003, black, 4)
    return finish("traqueur")


def sujet():
    """Lab-made mutant: one colossal arm, open ribcage, head split in ear flaps."""
    skin = mat("sj_skin", (0.4, 0.33, 0.3), rough=0.5)
    raw = mat("sj_raw", (0.35, 0.06, 0.06), rough=0.35)
    bone = mat("sj_bone", (0.6, 0.57, 0.5))
    gown = mat("sj_gown", (0.3, 0.36, 0.33))
    metal = mat("sj_metal", (0.4, 0.4, 0.42), rough=0.3)
    glow = mat("sj_glow", (0.3, 0, 0), emit=((1, 0.08, 0.05), 12))
    for s in (-1, 1):
        limb((0.22 * s, 0, 1.05), (0.25 * s, 0.12, 0.55), 0.14, 0.11, skin)
        limb((0.25 * s, 0.12, 0.55), (0.25 * s, 0, 0.05), 0.11, 0.08, skin)
        box((0.25 * s, 0.08, 0.04), (0.18, 0.32, 0.08), skin)
    box((0, 0, 1.0), (0.6, 0.38, 0.32), gown, rot=(5, 0, 0))  # torn gown
    limb((0, 0, 1.05), (0, 0.3, 1.8), 0.24, 0.38, skin, 7)
    # open chest: ribs + glowing organ
    ribs((0, 0.5), 0.3, 0.14, 1.3, 1.75, 5, bone, open_front=False)
    ball((0.0, 0.6, 1.5), 0.13, glow, seg=8, rings=5)
    ball((0.1, 0.58, 1.38), 0.09, raw)
    # IV tubes and staples
    for i in range(4):
        box((-0.26, 0.25, 1.4 + i * 0.12), (0.08, 0.02, 0.015), metal)
    limb((-0.1, -0.25, 1.7), (-0.25, -0.6, 0.0), 0.012, 0.012, metal, 4)
    limb((0.15, -0.25, 1.6), (0.4, -0.7, 0.0), 0.012, 0.012, metal, 4)
    # head split vertically into two ear flaps, teeth inside
    limb((0, 0.25, 1.85), (0, 0.38, 2.02), 0.1, 0.09, skin)
    for s in (-1, 1):
        limb((0.04 * s, 0.38, 2.0), (0.42 * s, 0.6, 2.4), 0.13, 0.02, skin, 6)
        limb((0.02 * s, 0.44, 2.0), (0.36 * s, 0.64, 2.34), 0.08, 0.01, raw, 6)
        for i in range(4):
            p = Vector((0.04 * s, 0.4, 2.02)).lerp(Vector((0.22 * s, 0.52, 2.32)), i / 4)
            limb(p, p + Vector((-0.06 * s, 0.03, 0)), 0.012, 0.0, bone, 3)
    # thin human right arm with a wrist tag
    limb((-0.4, 0.2, 1.8), (-0.45, 0.25, 1.3), 0.05, 0.045, skin)
    limb((-0.45, 0.25, 1.3), (-0.42, 0.35, 0.9), 0.045, 0.035, skin)
    box((-0.42, 0.33, 0.95), (0.08, 0.04, 0.03), gown)
    # colossal mutated left arm dragging
    limb((0.45, 0.2, 1.85), (0.75, 0.35, 1.25), 0.22, 0.2, skin, 8)
    limb((0.75, 0.35, 1.25), (0.8, 0.7, 0.35), 0.2, 0.26, raw, 8)
    ball((0.7, 0.3, 1.6), 0.16, raw)
    ball((0.88, 0.5, 0.9), 0.14, skin)
    for f in (-1, 0, 1, 2):
        limb((0.8, 0.75, 0.3), (0.8 + 0.12 * f, 1.1, 0.02), 0.06, 0.01, bone, 5)
    return finish("sujet")


def limier():
    """Skeletal quadruped hunter with a sensor-fin skull."""
    hide = mat("lm_hide", (0.12, 0.1, 0.1), rough=0.5)
    bone = mat("lm_bone", (0.5, 0.47, 0.42))
    steel = mat("lm_steel", (0.3, 0.31, 0.34), rough=0.3)
    black = mat("lm_black", (0.02, 0.02, 0.025))
    red = mat("lm_red", (0.2, 0, 0), emit=((1, 0.05, 0.03), 25))
    # spine and hull
    limb((0, -1.0, 1.05), (0, 0.8, 1.3), 0.12, 0.2, hide, 6)
    for i in range(7):
        y = -0.85 + i * 0.25
        limb((0, y, 1.2), (0, y - 0.08, 1.5), 0.04, 0.0, bone, 4)  # spikes
        for s in (-1, 1):
            limb((0, y, 1.15), (0.2 * s, y, 0.85), 0.018, 0.018, bone, 4)
            limb((0.2 * s, y, 0.85), (0.05 * s, y, 0.72), 0.018, 0.018, bone, 4)
    # legs: long digitigrade, front higher
    for y, hz, front in ((0.65, 1.25, True), (-0.85, 1.05, False)):
        for s in (-1, 1):
            hip = (0.2 * s, y, hz)
            knee = (0.3 * s, y + (0.35 if not front else -0.2), 0.7)
            ank = (0.28 * s, y + (-0.1 if not front else 0.1), 0.25)
            foot = (0.28 * s, y + 0.15, 0.02)
            limb(hip, knee, 0.09, 0.05, hide if not front else steel, 6)
            limb(knee, ank, 0.05, 0.035, black, 5)
            limb(ank, foot, 0.035, 0.03, bone, 5)
            for f in (-1, 1):
                limb(foot, (foot[0] + 0.05 * f, foot[1] + 0.18, 0), 0.02, 0.003, black, 4)
    # neck low, head forward: long skull + stacked sensor fins
    limb((0, 0.75, 1.25), (0, 1.25, 1.0), 0.13, 0.1, hide, 6)
    limb((0, 1.2, 1.05), (0, 1.85, 0.9), 0.14, 0.03, bone, 6)
    limb((0, 1.25, 0.92), (0, 1.75, 0.78), 0.07, 0.02, black, 6)  # jaw
    for i in range(5):
        y = 1.25 + i * 0.09
        box((0, y, 1.18 - i * 0.02), (0.6 - i * 0.08, 0.025, 0.2 - i * 0.02), steel, rot=(-15, 0, 0))
    for s in (-1, 1):
        for i in range(3):
            ball((0.07 * s, 1.45 + i * 0.09, 1.0 - i * 0.02), 0.018, red, seg=6, rings=3)
    # cable tail
    limb((0, -1.0, 1.05), (0, -1.6, 0.7), 0.05, 0.03, black, 5)
    limb((0, -1.6, 0.7), (0.2, -2.0, 0.05), 0.03, 0.02, black, 5)
    return finish("limier")


CONCEPTS = {
    "pavillon": (pavillon, 30),
    "encombrant": (encombrant, 20),
    "rampant": (rampant, 55),
    "resident": (resident, 15),
    "traqueur": (traqueur, 50),
    "sujet": (sujet, 25),
    "limier": (limier, 60),
}


# ---------------------------------------------------------------- scene

def scene(yaw):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 240
    sc.render.resolution_y = 320
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.6
    world = bpy.data.worlds.new("night")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes["Background"].inputs["Color"].default_value = (0.012, 0.014, 0.02, 1)
    vol = nt.nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Density"].default_value = 0.012
    vol.inputs["Color"].default_value = (0.35, 0.37, 0.45, 1)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])
    # ground
    bpy.ops.mesh.primitive_plane_add(size=40)
    g = bpy.context.object
    g.data.materials.append(mat("asphalt", (0.05, 0.05, 0.055)))
    # sodium lamp from the side, cold fill from behind (rim)
    bpy.ops.object.light_add(type="SPOT", location=(-2.5, 2.0, 5.5))
    lamp = bpy.context.object
    lamp.data.energy = 1800
    lamp.data.color = (1.0, 0.62, 0.28)
    lamp.data.spot_size = math.radians(80)
    lamp.data.shadow_soft_size = 0.1
    lamp.rotation_euler = (Vector((0.4, 0, 1)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="POINT", location=(2.5, -3.0, 2.2))
    rim = bpy.context.object
    rim.data.energy = 250
    rim.data.color = (0.55, 0.65, 1.0)
    # camera at eye height, slight low angle
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    sc.camera = cam
    cam.data.lens = 35
    r = 5.0 if yaw in (50, 25) else 5.6
    tx = 0.45 if yaw in (50, 25, 60) else 0.0
    a = math.radians(yaw)
    cam.location = (0.2 + tx + r * math.sin(a), r * math.cos(a), 1.45)
    target = Vector((tx, 0, 1.15))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    names = ONLY or list(CONCEPTS)
    for n in names:
        reset()
        fn, yaw = CONCEPTS[n]
        h = human_ref()[0]
        h.location.x = -1.3
        if n in ("traqueur", "sujet", "limier"):
            h.location = (-1.6, -1.0, 0)
        obj, tris = fn()
        obj.location.x = 0.6
        scene(yaw)
        bpy.context.scene.render.filepath = f"{OUT}/{n}.png"
        bpy.ops.render.render(write_still=True)
        with open(f"{OUT}/{n}.tris", "w") as f:
            f.write(str(tris))


main()
