"""Concept renders for the 3 hunted of Echo (S-011 proposals). Run with bpy 5.2.

Usage: python hunted.py OUT_DIR [shot ...]
Three directions (A voisins, B nuit, C bande), three hunted each, built from
low-poly primitives with 64 px procedural textures (Closest filtering), plus
line-ups with the Boucher (colosse.py boucher2) in the night scene.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], sys.argv[1], "__none__"] + sys.argv[2:]
OUT = sys.argv[1]
WANT = sys.argv[3:]
_src = open(os.path.join(HERE, "monsters.py")).read().replace("\nmain()\n", "\n")
exec(_src)  # helpers: mat, add, limb, box, ball, finish, reset (and bpy, Vector)
import importlib.util

_sp = importlib.util.spec_from_file_location("texmod", os.path.join(HERE, "textures.py"))
texmod = importlib.util.module_from_spec(_sp)
_sp.loader.exec_module(texmod)
RNG = texmod.RNG
N = texmod.N

# ------------------------------------------------------------ textures

FABRIC = {}  # material name -> (rgb, kind)


def cloth(name, rgb, kind="fabric", rough=0.85):
    FABRIC[name] = (rgb, kind)
    return mat(name, rgb, rough=rough)


def tex_for(rgb, kind):
    c = np.array(rgb)
    n = texmod.fbm(4, 3)
    img = c[None, None, :] * (0.82 + 0.36 * n[..., None])
    if kind == "skin":
        img = c[None, None, :] * (0.92 + 0.16 * texmod.fbm(3, 2)[..., None])
    elif kind == "hair":
        streak = np.tile(RNG.random((1, N)), (N, 1))
        img *= (0.75 + 0.5 * streak)[..., None]
    elif kind == "denim":
        diag = ((np.add.outer(np.arange(N), np.arange(N)) % 3) == 0)
        img[diag] *= 1.2
        img[:, 31] *= 0.6  # seam
    elif kind == "knit":
        rib = (np.arange(N) % 4 < 2)[None, :]
        img *= np.where(rib, 1.1, 0.85)[..., None]
    elif kind == "puffer":
        band = (np.arange(N) % 16 == 0)[:, None] * np.ones((1, N), bool)
        img[band] *= 0.45
        img *= (0.9 + 0.2 * np.sin(np.arange(N) / 16 * math.pi)[:, None, None])
    elif kind == "stripe":
        img[:, 28:30] = (0.75, 0.75, 0.72)
        img[:, 34:36] = (0.75, 0.75, 0.72)
    elif kind == "canvas":
        weave = ((np.arange(N)[:, None] + np.arange(N)[None, :] * 0) % 2 == 0)
        img *= np.where(weave, 1.05, 0.95)[..., None]
        img[:, 20] *= 0.6
        img[44, :] *= 0.6
    elif kind == "plastic":
        img = c[None, None, :] * (0.95 + 0.1 * n[..., None])
    # dirt from the cité: darker bottom edge + specks
    dirt = texmod.fbm(8, 2) > 0.7
    img[dirt] *= 0.78
    return np.clip(img, 0, 1)


def apply_textures(obj, scale=3.0):
    for slot in obj.material_slots:
        m = slot.material
        if m.name not in FABRIC or m.get("tex"):
            continue
        m["tex"] = 1
        rgb, kind = FABRIC[m.name]
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        s = scale * (2 if kind in ("skin", "hair") else 1)
        mp.inputs["Scale"].default_value = (s, s, s)
        tx = nt.nodes.new("ShaderNodeTexImage")
        tx.image = texmod.make("tx_" + m.name, tex_for(rgb, kind))
        tx.interpolation = "Closest"
        tx.projection = "BOX"
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], tx.inputs["Vector"])
        nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])


# ------------------------------------------------------------ body kit

def seg(p1, p2, r1, r2, m, verts=8, flat=1.0):
    o = limb(p1, p2, r1, r2, m, verts)
    o.scale = (1, flat, 1)
    return o


class Body:
    """Joint positions for a person of height h (m), facing +Y."""

    def __init__(self, h=1.75, wide=1.0, hips=1.0):
        k = h / 1.75
        self.k, self.w = k, wide
        self.hip_z = 0.9 * k
        self.knee_z = 0.48 * k
        self.waist_z = 1.05 * k
        self.chest_z = 1.32 * k
        self.sh_z = 1.45 * k
        self.neck_z = 1.5 * k
        self.head_z = 1.64 * k
        self.hip_x = 0.095 * hips * wide
        self.sh_x = 0.2 * wide

    def arm(self, s, out=1.0, fwd=0.0):
        k = self.k
        sh = (self.sh_x * s, 0, self.sh_z - 0.02)
        el = ((self.sh_x + 0.05 * out) * s, 0.0 + fwd * 0.5, self.sh_z - 0.28 * k)
        wr = ((self.sh_x + 0.08 * out) * s, 0.05 + fwd, self.sh_z - 0.53 * k)
        return sh, el, wr


def legs(b, pants, shoe, sole=None, r_thigh=0.085, r_calf=0.06, flare=1.0, boots=0.0):
    for s in (-1, 1):
        x = b.hip_x * s
        seg((x, 0, b.hip_z + 0.05), (x * 0.95, 0.01, b.knee_z), r_thigh * b.w, r_calf * 1.1, pants)
        seg((x * 0.95, 0.01, b.knee_z), (x * 0.95, -0.01, 0.1), r_calf * 1.1, r_calf * flare, pants)
        if boots:
            seg((x * 0.95, -0.01, 0.1), (x * 0.95, -0.01, 0.1 + boots), 0.065, 0.065, shoe)
        box((x * 0.95, 0.04, 0.05), (0.11, 0.27, 0.1), shoe)
        if sole:
            box((x * 0.95, 0.045, 0.012), (0.115, 0.28, 0.025), sole)
    seg((0, 0, b.hip_z - 0.02), (0, 0, b.waist_z + 0.03), 0.15 * b.w, 0.15 * b.w, pants, flat=0.7)


def torso(b, top, r_low=0.15, r_high=0.19, low=None, flat=0.62, length=0.0):
    z0 = (low if low is not None else b.waist_z - 0.06) - length
    return seg((0, 0, z0), (0, 0.0, b.sh_z + 0.02), r_low * b.w, r_high * b.w, top, flat=flat)


def arms(b, sleeve, skin, r=0.055, out=1.0, fwd=0.0, cuff=None, gloves=None):
    for s in (-1, 1):
        sh, el, wr = b.arm(s, out, fwd)
        ball(sh, r * 1.25, sleeve, scale=(1, 0.9, 1), seg=8, rings=4)
        seg(sh, el, r * 1.1, r, sleeve)
        seg(el, wr, r, r * 0.85, sleeve)
        if cuff:
            seg(wr, (wr[0], wr[1] + 0.005, wr[2] + 0.04), r * 0.9, r * 0.9, cuff)
        hand = gloves or skin
        box((wr[0], wr[1] + 0.01, wr[2] - 0.07), (0.05, 0.08, 0.11), hand)


def head(b, skin, hair=None, style="short", eye=None, beard=None):
    k = b.k
    hz = b.head_z
    seg((0, 0, b.neck_z - 0.04), (0, 0.01, hz - 0.06), 0.05, 0.048, skin)
    ball((0, 0.01, hz), 0.105 * k, skin, scale=(0.86, 0.98, 1.12), seg=10, rings=6)
    box((0, 0.105 * k, hz - 0.01), (0.03, 0.04, 0.05), skin, rot=(-15, 0, 0))  # nose
    eye = eye or mat("eye", (0.03, 0.02, 0.02))
    for s in (-1, 1):
        box((0.037 * s, 0.088 * k, hz + 0.022), (0.026, 0.02, 0.014), eye)
        ball((0.09 * s, 0.0, hz), 0.022, skin, scale=(0.5, 1, 1.3), seg=6, rings=3)  # ears
    box((0, 0.093 * k, hz - 0.055), (0.04, 0.02, 0.008), eye)  # mouth
    if beard:
        ball((0, 0.05, hz - 0.06), 0.085 * k, beard, scale=(0.95, 0.75, 0.75), seg=8, rings=4)
    if hair is None:
        return
    if style == "short":
        ball((0, -0.005, hz + 0.03), 0.108 * k, hair, scale=(0.9, 1.0, 0.95), seg=10, rings=5)
    elif style == "bun":
        ball((0, -0.005, hz + 0.03), 0.108 * k, hair, scale=(0.9, 1.0, 0.95), seg=10, rings=5)
        ball((0, -0.06, hz + 0.13), 0.06, hair, seg=8, rings=4)
    elif style == "buns":
        ball((0, -0.005, hz + 0.03), 0.108 * k, hair, scale=(0.9, 1.0, 0.95), seg=10, rings=5)
        for s in (-1, 1):
            ball((0.07 * s, -0.02, hz + 0.12), 0.05, hair, seg=8, rings=4)
    elif style == "long":
        ball((0, -0.01, hz + 0.03), 0.112 * k, hair, scale=(0.92, 1.0, 0.96), seg=10, rings=5)
        box((0, -0.06, hz - 0.12), (0.2, 0.1, 0.28), hair)
    elif style == "bald":
        ball((0, -0.03, hz - 0.01), 0.104 * k, hair, scale=(0.9, 0.9, 0.6), seg=10, rings=5)


def hood_up(b, m, big=1.0):
    hz = b.head_z
    ball((0, -0.045, hz + 0.03), 0.13 * big, m, scale=(0.98, 1.0, 1.08), seg=10, rings=6)
    for s in (-1, 1):  # hood rim framing the face
        seg((0.1 * s, 0.07, hz - 0.1), (0.075 * s, 0.07, hz + 0.12), 0.025, 0.025, m, verts=6)
    seg((-0.08, 0.06, hz + 0.13), (0.08, 0.06, hz + 0.13), 0.025, 0.025, m, verts=6)
    seg((0, -0.04, b.sh_z), (0, -0.02, hz), 0.11, 0.1, m)


def hood_down(b, m):
    ball((0, -0.13, b.sh_z + 0.02), 0.11, m, scale=(1.4, 0.7, 0.8), seg=8, rings=4)


def cap(b, m, back=False, flat=False):
    hz = b.head_z
    ball((0, 0, hz + 0.05), 0.112, m, scale=(0.95, 1.05, 0.7), seg=10, rings=5)
    d = -1 if back else 1
    box((0, 0.11 * d, hz + 0.06 - (0.0 if flat else 0.01)), (0.17, 0.12, 0.012), m, rot=(-8 * d, 0, 0))


def beanie(b, m, pompom=None):
    hz = b.head_z
    ball((0, -0.005, hz + 0.05), 0.118, m, scale=(0.92, 1.0, 1.0), seg=10, rings=5)
    seg((0, 0, hz + 0.0), (0, 0, hz + 0.05), 0.105, 0.11, m, verts=10)
    if pompom:
        ball((0, -0.005, hz + 0.17), 0.04, pompom, seg=6, rings=4)


def bucket(b, m):
    hz = b.head_z
    seg((0, 0, hz + 0.02), (0, 0, hz + 0.14), 0.13, 0.11, m, verts=10)
    seg((0, 0, hz + 0.0), (0, 0, hz + 0.03), 0.19, 0.135, m, verts=10)


def backpack(b, m, strap, size=(0.3, 0.14, 0.38), z=None):
    z = z or b.chest_z - 0.06
    box((0, -0.17 - size[1] / 2 + 0.07, z), size, m)
    for s in (-1, 1):
        box((0.1 * s, 0.07, b.chest_z), (0.04, 0.03, 0.3), strap)


# ------------------------------------------------------------ characters
# Player accents are kept away from orange (noise) and red (monster).

SKIN = {
    "a": (0.62, 0.45, 0.35), "b": (0.4, 0.27, 0.19), "c": (0.24, 0.15, 0.11),
    "d": (0.7, 0.55, 0.45), "e": (0.52, 0.36, 0.26),
}


def sk(key):
    return cloth("skin_" + key, SKIN[key], "skin", rough=0.6)


def a_ines():
    """A1 Ines, 16, high-school girl: blue hood up, backpack, joggers."""
    b = Body(1.62, 0.92, 1.05)
    hood = cloth("a1_hood", (0.08, 0.18, 0.45), "knit")
    jog = cloth("a1_jog", (0.25, 0.25, 0.27), "knit")
    shoe = cloth("a1_shoe", (0.75, 0.74, 0.7), "plastic")
    bag = cloth("a1_bag", (0.06, 0.06, 0.07), "canvas")
    legs(b, jog, shoe, r_thigh=0.08, r_calf=0.055, flare=0.8)
    torso(b, hood, 0.17, 0.18, length=0.12, flat=0.7)
    box((0, 0.11, b.waist_z), (0.24, 0.04, 0.12), hood)  # kangaroo pocket
    arms(b, hood, sk("b"), r=0.058, cuff=hood)
    head(b, sk("b"), cloth("a1_hair", (0.04, 0.03, 0.03), "hair"), "long")
    hood_up(b, hood)
    backpack(b, bag, bag, (0.28, 0.13, 0.34))
    for s in (-1, 1):  # hood strings
        box((0.04 * s, 0.11, b.sh_z - 0.08), (0.008, 0.008, 0.12), shoe)
    return finish("a1_ines")


def a_karim():
    """A2 Karim, 34, delivery rider stuck in the cite: green box bag, cap."""
    b = Body(1.78, 1.02)
    jack = cloth("a2_jacket", (0.12, 0.3, 0.16), "canvas")
    pants = cloth("a2_jeans", (0.1, 0.13, 0.2), "denim")
    shoe = cloth("a2_shoe", (0.05, 0.05, 0.05), "plastic", rough=0.5)
    cube = cloth("a2_cube", (0.15, 0.42, 0.24), "plastic", rough=0.5)
    capm = cloth("a2_cap", (0.05, 0.05, 0.06), "canvas")
    legs(b, pants, shoe, sole=cloth("sole_w", (0.7, 0.7, 0.68), "plastic"))
    torso(b, jack, 0.17, 0.2, length=0.06)
    box((0, 0.12, b.chest_z), (0.02, 0.02, 0.32), capm)  # zip
    arms(b, jack, sk("e"), r=0.06)
    head(b, sk("e"), capm, "short", beard=cloth("a2_beard", (0.05, 0.04, 0.035), "hair"))
    cap(b, capm)
    box((0, -0.36, b.chest_z - 0.02), (0.44, 0.4, 0.44), cube)  # insulated box
    box((0, -0.36, b.chest_z + 0.205), (0.42, 0.38, 0.02), capm)
    for s in (-1, 1):
        box((0.11 * s, 0.07, b.chest_z), (0.05, 0.03, 0.3), capm)
    return finish("a2_karim")


def a_jo():
    """A3 Jo, 67, retired factory worker: grey wool coat, flat cap, lilac scarf."""
    b = Body(1.7, 1.08)
    coat = cloth("a3_coat", (0.27, 0.26, 0.25), "canvas")
    pants = cloth("a3_pants", (0.12, 0.11, 0.1), "canvas")
    shoe = cloth("a3_shoe", (0.12, 0.07, 0.04), "plastic", rough=0.4)
    scarf = cloth("a3_scarf", (0.36, 0.22, 0.45), "knit")
    capm = cloth("a3_cap", (0.22, 0.2, 0.17), "knit")
    legs(b, pants, shoe)
    seg((0, 0.02, b.knee_z + 0.05), (0, 0.0, b.sh_z + 0.02), 0.22, 0.2, coat, flat=0.68)  # long coat
    seg((0, 0.03, b.waist_z), (0, 0.03, b.waist_z + 0.12), 0.18, 0.19, coat, flat=0.8)  # belly
    for i in range(3):
        ball((0.0, 0.135, b.waist_z - 0.12 + i * 0.13), 0.012, shoe, seg=6, rings=3)
    arms(b, coat, sk("d"), r=0.065, fwd=0.04)
    head(b, sk("d"), cloth("a3_hair", (0.6, 0.6, 0.58), "hair"), "bald",
         beard=None)
    box((0, 0.098, b.head_z - 0.03), (0.08, 0.025, 0.02), cloth("a3_stache", (0.55, 0.55, 0.52), "hair"))
    hz = b.head_z  # flat cap
    ball((0, -0.01, hz + 0.06), 0.12, capm, scale=(0.95, 1.1, 0.45), seg=10, rings=5)
    box((0, 0.1, hz + 0.055), (0.17, 0.08, 0.015), capm, rot=(-12, 0, 0))
    seg((0, 0, b.neck_z - 0.04), (0, 0, b.neck_z + 0.04), 0.1, 0.09, scarf, flat=0.9)
    box((0.06, 0.13, b.chest_z - 0.05), (0.07, 0.025, 0.3), scarf, rot=(0, -8, 0))
    return finish("a3_jo")


def b_yanis():
    """B1 Yanis, 28, electrician on night call: white helmet + headlamp, overalls."""
    b = Body(1.8, 1.0)
    ov = cloth("b1_overall", (0.08, 0.1, 0.16), "canvas")
    band = cloth("b1_band", (0.65, 0.68, 0.7), "plastic", rough=0.3)  # reflective, grey
    helm = cloth("b1_helmet", (0.78, 0.78, 0.75), "plastic", rough=0.35)
    boot = cloth("b1_boot", (0.07, 0.06, 0.05), "plastic", rough=0.5)
    belt = cloth("b1_belt", (0.12, 0.1, 0.08), "canvas")
    lamp = mat("b1_lamp", (0.9, 0.95, 1.0), emit=((0.85, 0.92, 1.0), 25))
    legs(b, ov, boot, boots=0.18)
    for s in (-1, 1):
        box((b.hip_x * s * 0.95, 0.0, b.knee_z - 0.12), (0.135, 0.13, 0.04), band)
    torso(b, ov, 0.17, 0.2, length=0.04)
    seg((0, 0, b.chest_z - 0.06), (0, 0, b.chest_z - 0.02), 0.205, 0.205, band, flat=0.66)
    seg((0, 0, b.waist_z - 0.06), (0, 0, b.waist_z), 0.18, 0.18, belt, flat=0.75)
    for s, z in ((-1, 0.0), (1, 0.0)):
        box((0.17 * s, 0.04, b.waist_z - 0.12), (0.06, 0.1, 0.14), belt)  # pouches
    box((0.2, 0.0, b.waist_z - 0.2), (0.025, 0.025, 0.16), helm)  # screwdriver
    arms(b, ov, sk("c"), r=0.06, gloves=cloth("b1_glove", (0.2, 0.2, 0.18), "canvas"))
    head(b, sk("c"), None)
    hz = b.head_z
    ball((0, 0, hz + 0.05), 0.125, helm, scale=(0.95, 1.08, 0.82), seg=10, rings=5)
    seg((0, 0, hz + 0.02), (0, 0, hz + 0.04), 0.15, 0.14, helm, verts=10, flat=1.1)
    box((0, 0.13, hz + 0.06), (0.06, 0.04, 0.04), boot)
    ball((0, 0.152, hz + 0.06), 0.017, lamp, seg=6, rings=3)
    return finish("b1_yanis")


def b_awa():
    """B2 Awa, 45, care assistant back from her shift: green scrubs, long cardigan."""
    b = Body(1.66, 1.0, 1.15)
    scrub = cloth("b2_scrubs", (0.1, 0.38, 0.3), "canvas")
    card = cloth("b2_cardigan", (0.2, 0.19, 0.2), "knit")
    shoe = cloth("b2_clogs", (0.72, 0.72, 0.7), "plastic", rough=0.4)
    wrap = cloth("b2_wrap", (0.28, 0.15, 0.35), "canvas")
    badge = mat("b2_badge", (0.8, 0.82, 0.8))
    legs(b, scrub, shoe, r_thigh=0.09, r_calf=0.065)
    torso(b, scrub, 0.17, 0.19, length=0.06)
    box((0, 0.11, b.sh_z - 0.08), (0.12, 0.03, 0.08), scrub, rot=(0, 0, 45))  # V neck
    for s in (-1, 1):  # open cardigan panels, down to the thighs
        box((0.12 * s, 0.03, b.waist_z - 0.05), (0.12, 0.26, 0.72), card, rot=(0, 4 * s, 0))
    box((0, -0.1, b.waist_z - 0.05), (0.36, 0.06, 0.72), card)
    box((-0.08, 0.135, b.chest_z), (0.04, 0.01, 0.06), badge)
    arms(b, card, sk("c"), r=0.062)
    head(b, sk("c"), wrap, "bun")
    hz = b.head_z
    ball((0, -0.02, hz + 0.07), 0.12, wrap, scale=(0.95, 1.05, 0.8), seg=10, rings=5)
    box((0.0, -0.11, b.waist_z), (0.08, 0.08, 0.24), card)  # tote strap
    box((0.24, 0.0, b.waist_z - 0.2), (0.08, 0.26, 0.26), cloth("b2_tote", (0.6, 0.58, 0.5), "canvas"))
    return finish("b2_awa")


def b_serge():
    """B3 Serge, 52, the estate's caretaker: blue-grey parka, beanie, big keyring."""
    b = Body(1.76, 1.15)
    parka = cloth("b3_parka", (0.14, 0.2, 0.3), "canvas")
    fur = cloth("b3_fur", (0.38, 0.33, 0.27), "hair")
    pants = cloth("b3_pants", (0.08, 0.08, 0.08), "canvas")
    shoe = cloth("b3_shoe", (0.1, 0.08, 0.06), "plastic", rough=0.5)
    hat = cloth("b3_beanie", (0.06, 0.06, 0.07), "knit")
    metal = mat("b3_keys", (0.6, 0.58, 0.5), rough=0.3)
    legs(b, pants, shoe, r_thigh=0.095, r_calf=0.066)
    seg((0, 0.02, b.hip_z - 0.12), (0, 0.0, b.sh_z + 0.03), 0.21, 0.21, parka, flat=0.72)
    seg((0, 0.03, b.waist_z - 0.05), (0, 0.03, b.chest_z), 0.2, 0.2, parka, flat=0.8)
    for s in (-1, 1):
        box((0.12 * s, 0.15, b.waist_z - 0.1), (0.11, 0.03, 0.1), parka)  # pockets
    box((0, 0.155, b.chest_z), (0.02, 0.02, 0.4), pants)
    arms(b, parka, sk("a"), r=0.068)
    head(b, sk("a"), None, beard=cloth("b3_beard", (0.28, 0.24, 0.2), "hair"))
    seg((0, -0.04, b.sh_z - 0.02), (0, -0.02, b.neck_z + 0.08), 0.14, 0.12, fur)  # fur collar
    beanie(b, hat)
    wx = b.arm(1)[2]
    for i in range(5):
        a = i / 4 * math.pi
        box((wx[0] + 0.05 * math.cos(a), wx[1] + 0.03, wx[2] - 0.14 - 0.04 * math.sin(a)),
            (0.012, 0.004, 0.05), metal, rot=(0, 30 * i - 60, 0))
    seg((wx[0], wx[1] + 0.02, wx[2] - 0.1), (wx[0], wx[1] + 0.02, wx[2] - 0.12), 0.035, 0.035, metal)
    return finish("b3_serge")


def c_lamine():
    """C1 Lamine, 19, the tall one: long black puffer, white bucket hat."""
    b = Body(1.9, 0.95)
    puff = cloth("c1_puffer", (0.05, 0.05, 0.06), "puffer", rough=0.4)
    pants = cloth("c1_pants", (0.2, 0.2, 0.21), "knit")
    shoe = cloth("c1_shoe", (0.75, 0.75, 0.73), "plastic")
    hat = cloth("c1_hat", (0.78, 0.78, 0.74), "canvas")
    legs(b, pants, shoe, r_thigh=0.075, r_calf=0.05, flare=0.8)
    for i in range(6):  # puffer rings from knee to shoulders
        z0 = b.knee_z + 0.08 + i * 0.16 * b.k
        seg((0, 0, z0), (0, 0, z0 + 0.15 * b.k), 0.2 + 0.01 * (i % 2), 0.205 + 0.01 * (i % 2), puff, flat=0.74)
    seg((0, -0.02, b.sh_z - 0.02), (0, 0, b.neck_z + 0.07), 0.13, 0.12, puff)  # high collar
    for s in (-1, 1):
        sh, el, wr = b.arm(s, 1.4)
        for p, q in ((sh, el), (el, wr)):
            seg(p, q, 0.08, 0.075, puff)
        box((wr[0], wr[1] + 0.01, wr[2] - 0.07), (0.05, 0.08, 0.11), sk("c"))
        ball(sh, 0.09, puff, seg=8, rings=4)
    head(b, sk("c"), cloth("c1_hair", (0.03, 0.02, 0.02), "hair"), "short")
    bucket(b, hat)
    return finish("c1_lamine")


def c_jade():
    """C2 Jade, 17, the small one: oversized lilac bomber, two buns, headphones."""
    b = Body(1.56, 0.9, 1.05)
    bomb = cloth("c2_bomber", (0.4, 0.3, 0.55), "canvas", rough=0.5)
    rib = cloth("c2_rib", (0.08, 0.08, 0.09), "knit")
    pants = cloth("c2_cargo", (0.16, 0.17, 0.13), "canvas")
    shoe = cloth("c2_shoe", (0.06, 0.06, 0.06), "plastic", rough=0.5)
    phones = cloth("c2_phones", (0.75, 0.75, 0.73), "plastic", rough=0.3)
    legs(b, pants, shoe, sole=cloth("sole_w", (0.7, 0.7, 0.68), "plastic"), r_thigh=0.09, r_calf=0.07, flare=1.05, boots=0.1)
    for s in (-1, 1):
        box((b.hip_x * s * 1.6, 0.0, b.knee_z + 0.15), (0.05, 0.1, 0.12), pants)  # cargo pockets
    torso(b, bomb, 0.21, 0.23, flat=0.7, length=0.02)
    seg((0, 0, b.waist_z - 0.1), (0, 0, b.waist_z - 0.04), 0.19, 0.19, rib, flat=0.7)
    for s in (-1, 1):
        sh, el, wr = b.arm(s, 1.6)
        ball(sh, 0.085, bomb, seg=8, rings=4)
        seg(sh, el, 0.08, 0.08, bomb)
        seg(el, wr, 0.08, 0.06, bomb)
        seg(wr, (wr[0], wr[1], wr[2] + 0.04), 0.055, 0.055, rib)
        box((wr[0], wr[1] + 0.01, wr[2] - 0.06), (0.045, 0.07, 0.1), sk("a"))
    head(b, sk("a"), cloth("c2_hair", (0.07, 0.04, 0.03), "hair"), "buns")
    seg((0, 0, b.neck_z - 0.02), (0, 0.02, b.neck_z + 0.03), 0.09, 0.09, phones, verts=10)  # phones on neck
    for s in (-1, 1):
        seg((0.085 * s, 0.03, b.neck_z), (0.11 * s, 0.03, b.neck_z), 0.04, 0.04, rib, verts=8)
    return finish("c2_jade")


def c_rayan():
    """C3 Rayan, 18, the stocky one: green tracksuit, cap backwards, bum bag."""
    b = Body(1.74, 1.18)
    ts = cloth("c3_track", (0.08, 0.3, 0.2), "stripe", rough=0.45)
    shoe = cloth("c3_shoe", (0.78, 0.78, 0.76), "plastic")
    capm = cloth("c3_cap", (0.05, 0.05, 0.06), "canvas")
    bum = cloth("c3_bumbag", (0.06, 0.06, 0.07), "canvas")
    legs(b, ts, shoe, r_thigh=0.1, r_calf=0.07, flare=0.85)
    torso(b, ts, 0.19, 0.22, flat=0.68)
    box((0, 0.145, b.chest_z), (0.02, 0.02, 0.32), shoe)  # zip
    seg((0, 0, b.neck_z - 0.06), (0, 0, b.neck_z + 0.02), 0.09, 0.085, ts, flat=0.9)
    arms(b, ts, sk("b"), r=0.07, out=1.3)
    head(b, sk("b"), capm, "short")
    cap(b, capm, back=True)
    box((0.04, 0.03, b.chest_z + 0.03), (0.42, 0.04, 0.05), bum, rot=(0, -38, 0))  # across chest
    box((0.13, 0.13, b.chest_z - 0.04), (0.2, 0.08, 0.1), bum, rot=(0, -38, 0))
    return finish("c3_rayan")


DIRS = {
    "A": [a_ines, a_karim, a_jo],
    "B": [b_yanis, b_awa, b_serge],
    "C": [c_lamine, c_jade, c_rayan],
}

# ------------------------------------------------------------ scenes


def world(fog=0.012):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.view_settings.exposure = 0.4
    w = bpy.data.worlds.new("night")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes["Background"].inputs["Color"].default_value = (0.006, 0.007, 0.011, 1)
    vol = nt.nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Density"].default_value = fog
    vol.inputs["Color"].default_value = (0.3, 0.32, 0.38, 1)
    nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs["Volume"])
    bpy.ops.mesh.primitive_plane_add(size=60)
    bpy.context.object.data.materials.append(mat("asphalt", (0.05, 0.05, 0.055), rough=0.6))


def spot(loc, target, energy, color, size=50, soft=0.1, cam=True):
    bpy.ops.object.light_add(type="SPOT", location=loc)
    lt = bpy.context.object
    lt.data.energy = energy
    lt.data.color = color
    lt.data.spot_size = math.radians(size)
    lt.data.shadow_soft_size = soft
    lt.visible_camera = cam
    lt.rotation_euler = (Vector(target) - lt.location).to_track_quat("-Z", "Y").to_euler()
    return lt


def camera(loc, target, lens=35):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def build(fn, x=0.0, yaw=0.0):
    o, tris = fn()
    apply_textures(o)
    o.location.x = x
    o.rotation_mode = "XYZ"
    o.rotation_euler.z = math.radians(yaw)
    return o, tris


def shot_trio(d):
    """Three hunted of one direction, front 3/4 and back, readable light."""
    tris = {}
    for tag, yaw_cam in (("face", 18), ("dos", 200)):
        reset()
        for i, fn in enumerate(DIRS[d]):
            o, t = build(fn, (i - 1) * 0.95)
            tris[o.name] = t
        world(0.006)
        a = math.radians(yaw_cam)
        spot((-2.5, 3.0, 4.5), (0, 0, 1.0), 1800, (1.0, 0.62, 0.3), 70)  # sodium key
        spot((2.8, 2.2, 2.4), (0, 0, 1.1), 500, (0.75, 0.82, 1.0), 70, 0.6, cam=False)  # cool fill
        spot((0.5, -3.5, 3.0), (0, 0, 1.3), 900, (0.5, 0.62, 1.0), 60, 0.3, cam=False)  # rim
        camera((4.6 * math.sin(a), 4.6 * math.cos(a), 1.35), (0, 0, 0.95), 35)
        render(f"{OUT}/{d}-{tag}.png", 480, 360)
    with open(f"{OUT}/{d}.tris", "w") as f:
        f.write(repr(tris))


def shot_portraits(d):
    for i, fn in enumerate(DIRS[d]):
        reset()
        o, t = build(fn)
        world(0.004)
        hz = 1.6 * o.dimensions.z / 1.75
        spot((-1.8, 2.4, 3.2), (0, 0, hz), 900, (1.0, 0.64, 0.32), 50)
        spot((1.8, 1.5, 2.0), (0, 0, hz), 260, (0.75, 0.82, 1.0), 60, 0.6, cam=False)
        spot((0.4, -2.5, 2.4), (0, 0, hz), 500, (0.5, 0.62, 1.0), 60, 0.3, cam=False)
        camera((0.55, 1.35, hz + 0.05), (0, 0, hz - 0.08), 50)
        render(f"{OUT}/{d}-p{i + 1}.png", 240, 300)


def shot_scene(d):
    """The trio in the night fog, the Boucher looming behind under a lamp."""
    reset()
    for i, fn in enumerate(DIRS[d]):
        o, _ = build(fn, (-1.35, 0.95, 1.95)[i], (195, 170, 160)[i])
        o.location.y = (0.3, 0.0, 0.6)[i]
    world(0.03)
    m = BOUCHER()
    m.location = (-0.15, -5.0, 0)
    spot((-3, 3, 4.5), (0, 0, 1.0), 1100, (1.0, 0.62, 0.3), 70)
    spot((1.2, -3.6, 5.5), (-0.15, -5.0, 1.2), 3200, (1.0, 0.6, 0.26), 50, 0.05)
    spot((-3.0, -8.5, 3.0), (-0.15, -5.0, 1.8), 1500, (0.5, 0.62, 1.0), 40, 0.3, cam=False)
    camera((0.3, 4.4, 1.55), (0.0, -2.0, 1.3), 28)
    render(f"{OUT}/{d}-scene.png", 640, 360)


def BOUCHER():
    """boucher2 from colosse.py, textured and slumped like the v5 renders."""
    g = {}
    exec(_src, g)
    col = open(os.path.join(HERE, "colosse.py")).read()
    exec(col[col.index("def boucher2"):col.index("def scene3")], g)
    o = g["boucher2"]()[0]
    texmod.apply(o, 2.5)
    for v in o.data.vertices:
        if v.co.z > 1.2:
            kk = v.co.z - 1.2
            v.co.y += kk * 0.38
            v.co.z -= kk * 0.08
    return o


if __name__ == "__main__" or True:
    shots = WANT or ["trio:A", "trio:B", "trio:C", "port:A", "port:B", "port:C",
                     "scene:A", "scene:B", "scene:C"]
    for s in shots:
        kind, d = s.split(":")
        {"trio": shot_trio, "port": shot_portraits, "scene": shot_scene}[kind](d)
