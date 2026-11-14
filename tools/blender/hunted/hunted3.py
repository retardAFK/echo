"""Realistic low-poly models of the hunted, direction "Le Reseau" (S-011 round 3).

Usage: python hunted3.py OUT_DIR [shot ...]
shots: turn:N (N = 1..3, front/side/back), trio, scene, port, ingame
Bodies are lofted rings (continuous limbs and torso, sculpted head with a
face painted in a 64 px texture projected from the front, mitten hands with
thumbs). Clothes are the outer surface, as in PS1-era characters.
The characters have no names: refer to them by role.
"""
import math
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "hunted2.py")).read()
_src = _src[:_src.index("shots = WANT or")]
exec(_src)  # kit, grimy textures, scenes, accent(), Body(...)


# ------------------------------------------------------------ loft

def loft(points, radii, m, verts=8, front=(0, 1, 0), cap=(True, True), yoffs=None):
    """Tube through points; radii[i] = (rx side, ry front). Returns object."""
    P = [Vector(p) for p in points]
    F = Vector(front)
    vs, fs = [], []
    n = len(P)
    for i, c in enumerate(P):
        a = P[max(i - 1, 0)]
        b = P[min(i + 1, n - 1)]
        t = (b - a).normalized()
        f = F - t * F.dot(t)
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


def rings(z_r, m, verts=10, x=0.0, cap=(True, True)):
    """Vertical loft from (z, rx, ry, yoff) tuples."""
    return loft([(x, r[3] if len(r) > 3 else 0, r[0]) for r in z_r],
                [(r[1], r[2]) for r in z_r], m, verts, cap=cap)


# ------------------------------------------------------------ face texture

def face_image(name, skin, beard=None, brows=(0.07, 0.05, 0.04), lips=None):
    W = 64
    sk_ = np.array(skin)
    img = np.ones((W, W, 3)) * sk_ * (0.94 + 0.1 * texmod.fbm(4, 2)[..., None])
    def px(u, v, w, h, rgb, a=1.0):
        x0, y0 = int(u * W), int((1 - v) * W)
        img[y0:y0 + h, x0:x0 + w] = img[y0:y0 + h, x0:x0 + w] * (1 - a) + np.array(rgb) * a
    # eye sockets, eyes, brows (eyes at v 0.58, x +-0.033 -> u 0.5 +- 0.165)
    for s in (-1, 1):
        cu = 0.5 + 0.165 * s
        px(cu - 0.06, 0.62, 8, 4, sk_ * 0.62, 0.8)
        px(cu - 0.04, 0.6, 5, 2, (0.75, 0.72, 0.66))
        px(cu - 0.01 if s < 0 else cu - 0.03, 0.6, 2, 2, (0.06, 0.04, 0.03))
        px(cu - 0.06, 0.66, 8, 2, brows)
    px(0.47, 0.52, 3, 6, sk_ * 0.75, 0.6)  # nose shadow
    px(0.44, 0.42, 7, 2, sk_ * 0.65, 0.8)  # nostrils
    px(0.42, 0.33, 11, 2, lips or (sk_ * 0.62 + np.array([0.06, 0.0, 0.0])), 0.9)
    px(0.43, 0.3, 9, 1, sk_ * 0.8, 0.6)
    for s in (-1, 1):  # cheek shadow
        px(0.5 + 0.28 * s - 0.04, 0.48, 5, 8, sk_ * 0.82, 0.5)
    if beard is not None:
        mask = np.zeros((W, W), bool)
        mask[int(W * 0.58):, :] = True
        mask[int(W * 0.58):int(W * 0.66), int(W * 0.38):int(W * 0.62)] = False  # upper lip skin
        noise = texmod.fbm(16, 2) > 0.35
        img[mask & noise] = np.array(beard) * 1.1
        img[mask & ~noise] = np.array(beard) * 0.7 + sk_ * 0.3
        px(0.42, 0.33, 11, 2, (0.2, 0.1, 0.08), 0.9)
    return texmod.make("face_" + name, np.clip(img, 0, 1)) if False else _make64(name, img)


def _make64(name, img):
    img = np.clip(img, 0, 1)
    im = bpy.data.images.new("face_" + name, 64, 64)
    rgba = np.concatenate([img, np.ones((64, 64, 1))], axis=2)
    im.pixels = rgba[::-1].ravel()
    return im


def face_mat(name, skin, k=1.0, w=1.0, **kw):
    z0, h = 1.53 * k, 0.26 * k
    m = bpy.data.materials.new("faceM_" + name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    u = nt.nodes.new("ShaderNodeMath"); u.operation = "MULTIPLY_ADD"
    u.inputs[1].default_value = 5.0 / w; u.inputs[2].default_value = 0.5
    nt.links.new(sep.outputs[0], u.inputs[0])
    v = nt.nodes.new("ShaderNodeMath"); v.operation = "MULTIPLY_ADD"
    v.inputs[1].default_value = 1 / h; v.inputs[2].default_value = -z0 / h
    nt.links.new(sep.outputs[2], v.inputs[0])
    cmb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(u.outputs[0], cmb.inputs[0])
    nt.links.new(v.outputs[0], cmb.inputs[1])
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = face_image(name, skin, **kw)
    tx.interpolation = "Closest"
    tx.extension = "EXTEND"
    nt.links.new(cmb.outputs[0], tx.inputs["Vector"])
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# ------------------------------------------------------------ body parts (1.78 m)

HZ = 1.53  # head base (top of neck)


def head_mesh(fm, skin_m):
    rings([(1.47, 0.056, 0.058, -0.005), (1.53, 0.052, 0.054, 0.0),
           (1.565, 0.06, 0.068, 0.012), (1.595, 0.067, 0.082, 0.02),
           (1.63, 0.073, 0.09, 0.016), (1.665, 0.077, 0.094, 0.008),
           (1.7, 0.078, 0.094, 0.0), (1.735, 0.074, 0.09, -0.008),
           (1.765, 0.06, 0.074, -0.013), (1.785, 0.035, 0.045, -0.015),
           (1.792, 0.006, 0.006, -0.015)], fm, verts=12)
    loft([(0, 0.088, 1.67), (0, 0.112, 1.625)], [(0.013, 0.008), (0.017, 0.014)], fm, 6)  # nose
    for s in (-1, 1):
        loft([(0.072 * s, -0.005, 1.68), (0.088 * s, -0.012, 1.68)], [(0.012, 0.022), (0.006, 0.026)], skin_m, 6)


def hand_mesh(s, m, glove=False):
    g = 1.15 if glove else 1.0
    loft([(0.252 * s, 0.045, 0.935), (0.256 * s, 0.055, 0.875), (0.256 * s, 0.06, 0.82), (0.253 * s, 0.065, 0.78)],
         [(0.02 * g, 0.032 * g), (0.022 * g, 0.044 * g), (0.019 * g, 0.042 * g), (0.012 * g, 0.03 * g)], m, 8)
    loft([(0.246 * s, 0.075, 0.905), (0.238 * s, 0.098, 0.86)], [(0.012 * g, 0.012 * g), (0.009 * g, 0.009 * g)], m, 6)


def arm_mesh(s, m, thick=1.0, cuff=None):
    t = thick
    ball((0.185 * s, -0.004, 1.415), 0.072 * t, m, scale=(1, 0.95, 0.9), seg=8, rings=5)  # deltoid
    pts = [(0.19 * s, -0.006, 1.42), (0.205 * s, -0.01, 1.38), (0.222 * s, -0.018, 1.3),
           (0.236 * s, -0.03, 1.185), (0.244 * s, -0.005, 1.06), (0.25 * s, 0.035, 0.95)]
    rad = [(0.064 * t, 0.066 * t), (0.062 * t, 0.064 * t), (0.056 * t, 0.058 * t),
           (0.048 * t, 0.05 * t), (0.046 * t, 0.044 * t), (0.04 * t, 0.037 * t)]
    loft(pts, rad, m, 8)
    if cuff:
        loft([(0.248 * s, 0.025, 0.975), (0.251 * s, 0.04, 0.94)], [(0.045 * t, 0.042 * t)] * 2, cuff, 8)


def leg_mesh(s, m, thick=1.0, flare=1.0):
    t = thick
    x = 0.095 * s
    loft([(x, 0.0, 0.97), (x * 1.04, 0.008, 0.74), (x * 1.04, 0.016, 0.5), (x * 1.03, -0.008, 0.32), (x * 1.02, -0.012, 0.11)],
         [(0.088 * t, 0.094 * t), (0.076 * t, 0.082 * t), (0.058 * t, 0.064 * t), (0.058 * t, 0.064 * t), (0.046 * flare, 0.052 * flare)], m, 8)


def boot_mesh(s, m, shaft=0.18):
    x = 0.098 * s
    loft([(x, -0.01, 0.05), (x, -0.012, shaft)], [(0.056, 0.062), (0.054, 0.06)], m, 8)
    loft([(x, -0.065, 0.045), (x, 0.03, 0.05), (x, 0.13, 0.042), (x * 1.0, 0.175, 0.035)],
         [(0.05, 0.045), (0.055, 0.05), (0.05, 0.04), (0.035, 0.028)], m, 8)
    loft([(x, -0.07, 0.012), (x, 0.18, 0.012)], [(0.056, 0.012), (0.056, 0.012)], m, 6)  # sole


def hips_mesh(m):
    rings([(0.86, 0.15, 0.1), (0.95, 0.17, 0.115), (1.06, 0.16, 0.11)], m, 10)


def scale_char(o, h=1.78, wide=1.0):
    k = h / 1.78
    o.scale = (wide, wide, k)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


# ------------------------------------------------------------ the three hunted

def r_ambulancier():
    """Former paramedic: work jacket, scrap chest plate, gas mask on the chest, beanie, beard."""
    jack = cloth("r1_jacket", (0.19, 0.23, 0.27), "canvas")
    collar = cloth("r1_collar", (0.13, 0.15, 0.17), "canvas")
    pants = cloth("r1_cargo", (0.17, 0.17, 0.14), "canvas")
    boot = cloth("r1_boot", (0.08, 0.07, 0.06), "plastic", rough=0.5)
    plate = cloth("r1_plate", (0.33, 0.34, 0.33), "plate", rough=0.4)
    strap = cloth("r1_strap", (0.06, 0.06, 0.06), "canvas")
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    glass = mat("glass", (0.05, 0.08, 0.08), rough=0.1)
    skin = SKIN["e"]
    skin_m = cloth("skin_e", skin, "skin", rough=0.6)
    beard = (0.05, 0.04, 0.035)
    fm = face_mat("r1", skin, 1.8 / 1.78, 1.04, beard=beard, brows=(0.04, 0.03, 0.025))
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    acc, led = accent(BLUE)
    for s in (-1, 1):
        leg_mesh(s, pants)
        boot_mesh(s, boot, 0.17)
        loft([(0.15 * s, 0.03, 0.72), (0.155 * s, 0.03, 0.6)], [(0.03, 0.06), (0.03, 0.06)], pants, 6)  # cargo pocket
        loft([(0.098 * s, 0.05, 0.53), (0.098 * s, 0.055, 0.45)], [(0.055, 0.025), (0.055, 0.025)], strap, 6)  # knee pad
    hips_mesh(pants)
    rings([(0.88, 0.178, 0.128, 0.0), (1.0, 0.17, 0.12, 0.005), (1.12, 0.168, 0.118, 0.008),
           (1.25, 0.184, 0.128, 0.012), (1.36, 0.198, 0.134, 0.01), (1.44, 0.192, 0.124, 0.0),
           (1.49, 0.14, 0.095, -0.01), (1.515, 0.075, 0.07, -0.01)], jack, 12)
    rings([(1.46, 0.085, 0.085, -0.01), (1.54, 0.078, 0.078, -0.012)], collar, 10, cap=(False, False))
    for s in (-1, 1):
        arm_mesh(s, jack, 1.06, cuff=collar)
        hand_mesh(s, glove, glove=True)
    head_mesh(fm, skin_m)
    rings([(1.7, 0.083, 0.099, -0.004), (1.74, 0.08, 0.095, -0.01), (1.775, 0.066, 0.08, -0.015),
           (1.8, 0.035, 0.045, -0.018), (1.808, 0.005, 0.005, -0.018)], cloth("r1_beanie", (0.09, 0.09, 0.09), "knit"), 12)
    # scrap plate: two bent sheets with straps
    loft([(-0.15, 0.142, 1.33), (0.0, 0.152, 1.33), (0.15, 0.142, 1.33)], [(0.006, 0.16), (0.006, 0.16), (0.006, 0.16)],
         plate, 4, front=(0, 0, 1))
    for z in (1.42, 1.22):
        rings([(z - 0.018, 0.2, 0.14, 0.008), (z + 0.018, 0.2, 0.14, 0.008)], strap, 12, cap=(False, False))
    for s in (-1, 1):
        loft([(0.12 * s, 0.1, 1.44), (0.14 * s, -0.02, 1.5), (0.13 * s, -0.13, 1.42)], [(0.02, 0.006)] * 3, strap, 4)
    # gas mask hanging under the chin
    loft([(0, 0.15, 1.47), (0, 0.2, 1.46), (0, 0.215, 1.44)], [(0.06, 0.05), (0.065, 0.055), (0.04, 0.035)], rubber, 8)
    for s in (-1, 1):
        loft([(0.03 * s, 0.205, 1.475), (0.032 * s, 0.215, 1.478)], [(0.022, 0.022)] * 2, glass, 8)
    loft([(0, 0.21, 1.43), (0, 0.25, 1.4)], [(0.03, 0.03), (0.034, 0.034)], metal, 8)
    # belt pouches, backpack
    rings([(1.02, 0.172, 0.123, 0.006), (1.06, 0.172, 0.123, 0.006)], strap, 12, cap=(False, False))
    for x in (-0.13, 0.13):
        box((x, 0.1, 1.0), (0.07, 0.05, 0.09), strap)
    rings([(1.1, 0.15, 0.08, -0.22), (1.25, 0.165, 0.09, -0.225), (1.42, 0.15, 0.08, -0.215),
           (1.46, 0.12, 0.05, -0.2)], cloth("r1_pack", (0.17, 0.19, 0.14), "canvas"), 10)
    # player colour: armband on the left arm, small LED on the plate
    loft([(-0.21, -0.012, 1.36), (-0.216, -0.016, 1.3)], [(0.064, 0.066)] * 2, acc, 8)
    ball((-0.11, 0.152, 1.4), 0.014, led, seg=6, rings=3)
    return scale_char(finish("r1_ambulancier")[0], 1.8, 1.04)


def r_parka():
    """Young woman in a long belted parka, scarf over the nose, goggles on the forehead."""
    parka = cloth("r2_parka", (0.21, 0.23, 0.15), "canvas")
    fur = cloth("r2_fur", (0.32, 0.29, 0.24), "hair")
    pants = cloth("r2_pants", (0.08, 0.08, 0.09), "canvas")
    boot = cloth("r2_boot", (0.1, 0.075, 0.05), "plastic", rough=0.45)
    scarf = cloth("r2_scarf", (0.29, 0.26, 0.21), "canvas")
    strap = cloth("r2_strap", (0.08, 0.07, 0.06), "canvas")
    hair = cloth("r2_hair", (0.06, 0.04, 0.03), "hair")
    glass = mat("glass_g", (0.08, 0.13, 0.11), rough=0.05)
    skin = SKIN["a"]
    skin_m = cloth("skin_a", skin, "skin", rough=0.6)
    fm = face_mat("r2", skin, 1.7 / 1.78, 0.95, brows=(0.09, 0.06, 0.04), lips=(0.4, 0.24, 0.22))
    glove = cloth("glove", (0.07, 0.07, 0.07), "canvas")
    acc, led = accent(GREEN)
    for s in (-1, 1):
        leg_mesh(s, pants, 0.92, 0.95)
        boot_mesh(s, boot, 0.4)
        loft([(0.098 * s, -0.012, 0.38), (0.098 * s, -0.012, 0.41)], [(0.06, 0.066)] * 2, strap, 8)
    hips_mesh(pants)
    # parka: flared hem at mid-thigh, belted waist
    rings([(0.6, 0.2, 0.14, 0.0), (0.75, 0.19, 0.135, 0.0), (0.92, 0.19, 0.13, 0.005),
           (1.06, 0.165, 0.115, 0.008), (1.13, 0.17, 0.12, 0.01), (1.25, 0.18, 0.125, 0.014),
           (1.35, 0.188, 0.13, 0.012), (1.44, 0.182, 0.12, 0.0), (1.49, 0.13, 0.09, -0.01),
           (1.515, 0.075, 0.07, -0.01)], parka, 12)
    rings([(1.06, 0.172, 0.122, 0.008), (1.1, 0.172, 0.122, 0.008)], strap, 12, cap=(False, False))
    box((0, 0.128, 1.08), (0.05, 0.02, 0.05), mat("buckle", (0.4, 0.4, 0.38), rough=0.3))
    box((0, 0.133, 0.95), (0.012, 0.012, 0.65), strap)  # zip
    for s in (-1, 1):
        box((0.11 * s, 0.135, 0.88), (0.1, 0.02, 0.11), parka)
        arm_mesh(s, parka, 1.12, cuff=strap)
        hand_mesh(s, glove, glove=True)
    # hood down, fur trim, behind the neck
    loft([(-0.13, -0.08, 1.5), (0, -0.14, 1.53), (0.13, -0.08, 1.5)], [(0.05, 0.06), (0.06, 0.08), (0.05, 0.06)], parka, 8)
    loft([(-0.14, -0.06, 1.53), (0, -0.12, 1.57), (0.14, -0.06, 1.53)], [(0.03, 0.035)] * 3, fur, 6)
    head_mesh(fm, skin_m)
    rings([(1.705, 0.08, 0.097, -0.006), (1.725, 0.081, 0.097, -0.006), (1.75, 0.078, 0.092, -0.01),
           (1.78, 0.06, 0.072, -0.016), (1.8, 0.03, 0.04, -0.018), (1.806, 0.004, 0.004, -0.018)], hair, 12)
    loft([(0, -0.09, 1.72), (0, -0.13, 1.66), (0, -0.14, 1.56), (0, -0.13, 1.48)],
         [(0.03, 0.03), (0.035, 0.03), (0.028, 0.025), (0.012, 0.012)], hair, 6)  # ponytail
    # scarf: wrapped round the neck and pulled over the nose
    rings([(1.48, 0.1, 0.1, 0.0), (1.53, 0.09, 0.098, 0.01), (1.58, 0.082, 0.104, 0.025),
           (1.62, 0.08, 0.102, 0.022), (1.645, 0.079, 0.099, 0.018)], scarf, 12, cap=(False, False))
    loft([(0.06, 0.1, 1.5), (0.08, 0.13, 1.38), (0.09, 0.12, 1.28)], [(0.04, 0.012)] * 3, scarf, 6)
    # goggles pushed up on the forehead
    rings([(1.745, 0.083, 0.097, -0.007), (1.762, 0.08, 0.094, -0.008)], strap, 12, cap=(False, False))
    for s in (-1, 1):
        loft([(0.034 * s, 0.075, 1.765), (0.035 * s, 0.1, 1.775)], [(0.024, 0.021), (0.022, 0.02)], strap, 8)
        loft([(0.035 * s, 0.098, 1.775), (0.035 * s, 0.103, 1.777)], [(0.018, 0.016)] * 2, glass, 8)
    # crossbody strap and bag on the right hip
    loft([(-0.17, 0.0, 1.47), (0.0, 0.13, 1.25), (0.2, 0.08, 1.0)], [(0.025, 0.008)] * 3, strap, 4)
    loft([(-0.17, 0.0, 1.47), (0.0, -0.13, 1.25), (0.2, -0.05, 1.0)], [(0.025, 0.008)] * 3, strap, 4)
    box((0.22, 0.03, 0.93), (0.08, 0.2, 0.17), strap)
    loft([(-0.215, -0.012, 1.36), (-0.22, -0.016, 1.3)], [(0.07, 0.072)] * 2, acc, 8)
    ball((-0.1, 0.14, 1.36), 0.014, led, seg=6, rings=3)
    return scale_char(finish("r2_parka")[0], 1.7, 0.95)


def r_masque():
    """Old lineman: hood up, full-face gas mask with twin filters, rubber coat, headlamp."""
    coat = cloth("r3_coat", (0.13, 0.15, 0.13), "plastic", rough=0.35)
    pants = cloth("r3_pants", (0.1, 0.1, 0.09), "canvas")
    boot = cloth("r3_boot", (0.05, 0.05, 0.05), "plastic", rough=0.3)
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    belt = cloth("r3_belt", (0.14, 0.11, 0.08), "canvas")
    glass = mat("glass_a", (0.1, 0.13, 0.11), rough=0.04)
    lamp = mat("lamp", (0.9, 0.95, 1.0), emit=((0.85, 0.92, 1.0), 25))
    skin = SKIN["d"]
    fm = face_mat("r3", skin, 1.76 / 1.78, 1.1)
    acc, led = accent(WHITE)
    for s in (-1, 1):
        leg_mesh(s, pants, 1.05)
        boot_mesh(s, boot, 0.36)
    hips_mesh(pants)
    # long rubber coat to below the knee
    rings([(0.42, 0.23, 0.16, 0.0), (0.6, 0.215, 0.15, 0.0), (0.85, 0.2, 0.14, 0.005),
           (1.05, 0.19, 0.135, 0.012), (1.2, 0.195, 0.138, 0.016), (1.33, 0.205, 0.14, 0.012),
           (1.43, 0.2, 0.13, 0.0), (1.49, 0.14, 0.1, -0.012), (1.515, 0.08, 0.075, -0.012)], coat, 12)
    for z in (0.75, 0.95, 1.15, 1.3):
        ball((0.0, 0.142 + (0.01 if z > 1.0 else 0.0), z), 0.012, metal, seg=6, rings=3)  # clasps
    rings([(1.02, 0.197, 0.142, 0.012), (1.07, 0.197, 0.142, 0.012)], belt, 12, cap=(False, False))
    for x, w in ((-0.15, 0.07), (-0.05, 0.06), (0.15, 0.08)):
        box((x, 0.135, 0.99), (w, 0.06, 0.1), belt)
    box((0.21, 0.06, 0.93), (0.035, 0.035, 0.22), metal)  # wrench
    for s in (-1, 1):
        arm_mesh(s, coat, 1.16)
        hand_mesh(s, rubber, glove=True)
        loft([(0.25 * s, 0.035, 0.99), (0.25 * s, 0.045, 0.93)], [(0.05, 0.048), (0.048, 0.046)], rubber, 8)  # gauntlet
    head_mesh(fm, fm)
    # hood up, deep, face pushed forward out of it by the mask
    rings([(1.5, 0.1, 0.105, -0.03), (1.56, 0.105, 0.115, -0.03), (1.62, 0.106, 0.118, -0.03),
           (1.68, 0.104, 0.118, -0.03), (1.74, 0.097, 0.11, -0.035), (1.79, 0.075, 0.088, -0.04),
           (1.82, 0.04, 0.05, -0.045), (1.83, 0.006, 0.006, -0.045)], coat, 12)
    # full-face mask
    rings([(1.56, 0.06, 0.04, 0.085), (1.6, 0.074, 0.05, 0.09), (1.66, 0.08, 0.05, 0.088),
           (1.71, 0.075, 0.045, 0.084), (1.735, 0.055, 0.035, 0.078)], rubber, 12)
    for s in (-1, 1):
        loft([(0.035 * s, 0.13, 1.68), (0.036 * s, 0.142, 1.682)], [(0.026, 0.024)] * 2, metal, 10)
        loft([(0.036 * s, 0.14, 1.682), (0.036 * s, 0.144, 1.683)], [(0.021, 0.019)] * 2, glass, 10)
        loft([(0.05 * s, 0.12, 1.6), (0.105 * s, 0.155, 1.56)], [(0.035, 0.035), (0.04, 0.04)], metal, 10)  # filters
    loft([(0, 0.13, 1.6), (0, 0.16, 1.585)], [(0.028, 0.028), (0.032, 0.03)], rubber, 8)
    # headlamp over the hood
    rings([(1.745, 0.112, 0.124, -0.028), (1.765, 0.11, 0.122, -0.03)], rubber, 12, cap=(False, False))
    box((0, 0.1, 1.755), (0.05, 0.04, 0.04), rubber)
    ball((0, 0.122, 1.755), 0.015, lamp, seg=6, rings=3)
    # battery pack and hose to the mask
    rings([(1.08, 0.15, 0.09, -0.24), (1.4, 0.15, 0.09, -0.24), (1.44, 0.13, 0.07, -0.225)], metal, 8)
    loft([(0.1, -0.2, 1.42), (0.16, -0.05, 1.5), (0.14, 0.08, 1.56), (0.1, 0.15, 1.57)], [(0.011, 0.011)] * 4, rubber, 6)
    loft([(-0.222, -0.012, 1.36), (-0.228, -0.016, 1.3)], [(0.075, 0.077)] * 2, acc, 8)
    ball((-0.13, 0.15, 1.38), 0.014, led, seg=6, rings=3)
    return scale_char(finish("r3_masque")[0], 1.76, 1.1)


CHARS = [r_ambulancier, r_parka, r_masque]
DIRS = {"R": CHARS}


def build(fn, x=0.0, yaw=0.0):
    o = fn()
    apply_textures(o)
    o.location.x = x
    o.rotation_mode = "XYZ"
    o.rotation_euler.z = math.radians(yaw)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    return o, tris


def shot_turn(i):
    """Front / three-quarter / side / back of one character, 4 panels."""
    from PIL import Image
    paths = []
    for j, yaw in enumerate((0, 35, 90, 180)):
        reset()
        o, t = build(CHARS[i - 1], 0, -yaw)
        world(0.004)
        spot((-2.2, 2.8, 3.8), (0, 0, 1.0), 1300, (1.0, 0.64, 0.32), 60)
        spot((2.4, 2.0, 2.2), (0, 0, 1.1), 420, (0.75, 0.82, 1.0), 70, 0.6, cam=False)
        spot((0.4, -3.0, 2.8), (0, 0, 1.3), 700, (0.5, 0.62, 1.0), 60, 0.3, cam=False)
        camera((0, 2.9, 1.1), (0, 0, 0.92), 42)
        p = f"{OUT}/R{i}-t{j}.png"
        render(p, 300, 520)
        paths.append(p)
    W = Image.new("RGB", (1200, 520))
    for j, p in enumerate(paths):
        W.paste(Image.open(p), (j * 300, 0))
    W.save(f"{OUT}/R{i}-turn.png")
    with open(f"{OUT}/R{i}.tris", "w") as f:
        f.write(str(t))


def shot_ingame():
    """What a teammate sees: 8 m away under a sodium lamp, low resolution, upscaled."""
    from PIL import Image
    reset()
    for i, fn in enumerate(CHARS):
        o, _ = build(fn, (-1.4, 0.2, 2.1)[i], (200, 150, 165)[i])
        o.location.y = (-2.0, 0.5, -3.0)[i]
    world(0.02)
    m = BOUCHER()
    m.location = (-2.4, -10.0, 0)
    m.rotation_euler.z = math.radians(30)
    spot((0.5, 1.0, 5.0), (0, -1, 0.0), 1600, (1.0, 0.6, 0.26), 70, 0.05)
    spot((-1.7, -8.5, 5.0), (-2.4, -10.0, 1.0), 1800, (1.0, 0.6, 0.26), 50, 0.05)
    camera((1.0, 7.0, 1.6), (-0.4, -2.0, 1.1), 32)
    p = f"{OUT}/R-ingame-raw.png"
    render(p, 320, 180)
    Image.open(p).resize((1280, 720), Image.NEAREST).save(f"{OUT}/R-ingame.png")


if True:
    shots = WANT or ["turn:1", "turn:2", "turn:3", "trio:R", "port:R", "scene:R", "ingame:0"]
    for s in shots:
        kind, d = s.split(":")
        if kind == "turn":
            shot_turn(int(d))
        elif kind == "ingame":
            shot_ingame()
        else:
            {"trio": shot_trio, "port": shot_portraits, "scene": shot_scene}[kind](d)
