"""Hunted concepts round 2 for Echo: grounded, tactical, adult (HL / MGS mood).

Usage: python hunted2.py OUT_DIR [shot ...]  (shots: trio:X, port:X, scene:X)
Reuses the kit, textures and scenes of hunted.py; redefines proportions
(about 7.5 heads tall), faces, grimier textures and the three directions.
No weapons anywhere: Echo is not a shooter (constitution 1.3).
"""
import math
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "hunted.py")).read()
_src = _src[:_src.index('if __name__ == "__main__" or True:')]
exec(_src)  # kit, scenes, WANT, OUT, DIRS (replaced below)

_tex_v1 = tex_for


def tex_for(rgb, kind):
    """Grimier version: darker wear, lighter scuffs, stains."""
    img = _tex_v1(rgb, kind)
    if kind in ("skin", "glass"):
        return img
    wear = texmod.fbm(5, 3)
    img *= (0.86 + 0.2 * wear)[..., None]
    scuff = texmod.lines(10) > 0
    img[scuff] = img[scuff] * 0.6 + 0.12
    stain = texmod.fbm(3, 2) > 0.62
    img[stain] = img[stain] * 0.85 + np.array([0.012, 0.01, 0.005])
    if kind == "plate":
        edge = np.zeros((N, N), bool)
        edge[:2, :] = edge[-2:, :] = edge[:, :2] = edge[:, -2:] = True
        img[edge] = img[edge] * 0.4 + 0.25
        for x, y in ((6, 6), (6, 57), (57, 6), (57, 57)):
            img[y - 1:y + 2, x - 1:x + 2] = (0.5, 0.5, 0.48)  # rivets
    return np.clip(img, 0, 1)


class Body:
    """Adult proportions, about 7.5 heads, facing +Y."""

    def __init__(self, h=1.78, wide=1.0, hips=1.0):
        k = h / 1.78
        self.k, self.w = k, wide
        self.hip_z = 0.93 * k
        self.knee_z = 0.5 * k
        self.waist_z = 1.08 * k
        self.chest_z = 1.33 * k
        self.sh_z = 1.48 * k
        self.neck_z = 1.54 * k
        self.head_z = 1.665 * k
        self.hip_x = 0.1 * hips
        self.sh_x = 0.215 * wide

    def arm(self, s, out=1.0, fwd=0.0):
        k = self.k
        sh = (self.sh_x * s, -0.01, self.sh_z - 0.03)
        el = ((self.sh_x + 0.045 * out) * s, -0.04, self.sh_z - 0.3 * k)
        wr = ((self.sh_x + 0.04 * out) * s, 0.09 + fwd, self.sh_z - 0.55 * k)
        return sh, el, wr


def chest(b, m, depth=0.26, width=1.0, z=None):
    """Broad ribcage block giving the V shape."""
    z = z or b.chest_z + 0.02
    box((0, 0.0, z), (0.4 * b.w * width, depth, 0.3), m)


def head(b, skin, hair=None, style="short", eye=None, beard=None):
    k = b.k
    hz = b.head_z
    seg((0, 0, b.neck_z - 0.05), (0, 0.01, hz - 0.05), 0.055, 0.05, skin)
    ball((0, 0.0, hz + 0.01), 0.095, skin, scale=(0.82, 0.95, 1.12), seg=10, rings=6)
    box((0, 0.035, hz - 0.075), (0.105, 0.09, 0.05), skin)  # jaw
    box((0, 0.092, hz + 0.035), (0.13, 0.025, 0.022), skin)  # brow ridge
    box((0, 0.1, hz - 0.005), (0.026, 0.035, 0.055), skin, rot=(-12, 0, 0))  # nose
    eye = eye or mat("eye", (0.02, 0.015, 0.015))
    for s in (-1, 1):
        box((0.034 * s, 0.083, hz + 0.012), (0.03, 0.02, 0.016), eye)
        box((0.055 * s, 0.07, hz - 0.03), (0.03, 0.03, 0.03), skin)  # cheekbone
        ball((0.082 * s, -0.005, hz), 0.02, skin, scale=(0.5, 1, 1.35), seg=6, rings=3)
    box((0, 0.088, hz - 0.058), (0.04, 0.012, 0.007), eye)
    if beard:
        box((0, 0.06, hz - 0.075), (0.115, 0.08, 0.07), beard)
    if hair is None:
        return
    if style == "short":
        ball((0, -0.01, hz + 0.035), 0.098, hair, scale=(0.86, 0.98, 0.92), seg=10, rings=5)
    elif style == "tied":
        ball((0, -0.01, hz + 0.035), 0.099, hair, scale=(0.87, 0.99, 0.93), seg=10, rings=5)
        seg((0, -0.08, hz + 0.02), (0, -0.12, hz - 0.14), 0.035, 0.02, hair, verts=6)
    elif style == "buzz":
        ball((0, -0.01, hz + 0.02), 0.096, hair, scale=(0.84, 0.97, 0.9), seg=10, rings=5)


def armband(b, m, s=1):
    sh, el, _ = b.arm(s)
    p = Vector(sh).lerp(Vector(el), 0.45)
    seg((p.x, p.y, p.z + 0.03), (p.x, p.y, p.z - 0.03), 0.066, 0.066, m)


def tag_light(b, m, x=0.12):
    ball((-x, 0.13, b.chest_z + 0.08), 0.018, m, seg=6, rings=3)


def accent(rgb):
    """Player colour: matte armband + small LED, never orange or red."""
    return cloth("acc_%d%d%d" % tuple(int(c * 9) for c in rgb), rgb, "fabric"), \
        mat("led_%d%d%d" % tuple(int(c * 9) for c in rgb), rgb, emit=(rgb, 18))


def gasmask(b, rubber, glass, metal, worn=True):
    hz = b.head_z
    if worn:
        ball((0, 0.035, hz - 0.01), 0.1, rubber, scale=(0.9, 0.95, 1.1), seg=10, rings=6)
        for s in (-1, 1):
            seg((0.04 * s, 0.1, hz + 0.02), (0.042 * s, 0.115, hz + 0.02), 0.03, 0.03, glass, verts=8)
            seg((0.05 * s, 0.1, hz - 0.07), (0.1 * s, 0.13, hz - 0.1), 0.035, 0.04, metal, verts=8)
        box((0, 0.12, hz - 0.06), (0.05, 0.04, 0.05), rubber)
    else:  # hanging on the chest
        z = b.chest_z + 0.02
        ball((0.0, 0.17, z), 0.07, rubber, scale=(0.9, 0.6, 1.0), seg=8, rings=5)
        for s in (-1, 1):
            box((0.03 * s, 0.205, z + 0.02), (0.035, 0.01, 0.03), glass)
        seg((0, 0.2, z - 0.05), (0, 0.24, z - 0.08), 0.03, 0.035, metal, verts=8)


def boots(b, m, h=0.2):
    for s in (-1, 1):
        x = b.hip_x * s * 0.95
        seg((x, -0.01, 0.08), (x, -0.01, 0.08 + h), 0.068, 0.064, m)
        box((x, 0.045, 0.055), (0.115, 0.29, 0.11), m)


def pouches(b, m, xs=(-0.12, -0.04, 0.04, 0.12), z=None, y=0.15):
    z = z or b.waist_z + 0.08
    for x in xs:
        box((x, y, z), (0.07, 0.06, 0.1), m)


def kneepads(b, m):
    for s in (-1, 1):
        box((b.hip_x * s * 0.95, 0.065, b.knee_z), (0.11, 0.05, 0.13), m)


def plates_on_arms(b, m):
    for s in (-1, 1):
        sh, el, wr = b.arm(s)
        ball((sh[0] * 1.06, sh[1], sh[2] + 0.03), 0.075, m, scale=(1, 1, 0.7), seg=8, rings=4)
        p = Vector(el).lerp(Vector(wr), 0.5)
        box((p.x + 0.015 * s, p.y + 0.02, p.z), (0.05, 0.1, 0.16), m, rot=(-20, 0, 0))


# ------------------------------------------------------------ A: Le Réseau
# Residents who stayed when the cite was sealed, organised and patched up.

BLUE = (0.16, 0.34, 0.62)
GREEN = (0.22, 0.6, 0.38)
WHITE = (0.8, 0.82, 0.8)


def a_mehdi():
    """A1 Mehdi, 31, ex-paramedic: scrap chest plate, mask on the chest, beanie."""
    b = Body(1.8, 1.04)
    jack = cloth("a1_jacket", (0.2, 0.24, 0.28), "canvas")
    pants = cloth("a1_cargo", (0.16, 0.16, 0.13), "canvas")
    boot = cloth("a1_boot", (0.08, 0.07, 0.06), "plastic")
    plate = cloth("a1_plate", (0.32, 0.33, 0.33), "plate", rough=0.4)
    strap = cloth("a1_strap", (0.06, 0.06, 0.06), "canvas")
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    glass = mat("glass", (0.05, 0.08, 0.08), rough=0.1)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    acc, led = accent(BLUE)
    legs(b, pants, boot, r_thigh=0.088, r_calf=0.062)
    boots(b, boot, 0.16)
    kneepads(b, strap)
    torso(b, jack, 0.15, 0.2, flat=0.7)
    chest(b, jack)
    box((0, 0.155, b.chest_z), (0.34, 0.03, 0.34), plate, rot=(-5, 0, 0))  # scrap plate
    for z in (b.chest_z + 0.12, b.chest_z - 0.12):
        box((0, 0.0, z), (0.44, 0.3, 0.025), strap)
    gasmask(b, rubber, glass, metal, worn=False)
    pouches(b, strap, (-0.13, 0.13), b.waist_z - 0.02, 0.13)
    arms(b, jack, sk("e"), r=0.06, gloves=cloth("glove", (0.07, 0.07, 0.07), "canvas"))
    armband(b, acc, -1)
    tag_light(b, led, -0.14)
    head(b, sk("e"), None, beard=cloth("a1_beard", (0.05, 0.04, 0.035), "hair"))
    beanie(b, cloth("a1_beanie", (0.1, 0.1, 0.1), "knit"))
    box((0, -0.25, b.chest_z - 0.04), (0.3, 0.16, 0.4), cloth("a1_pack", (0.18, 0.2, 0.15), "canvas"))
    return finish("a1_mehdi")


def a_nadia():
    """A2 Nadia, 27: long field parka, scarf over the nose, goggles up."""
    b = Body(1.7, 0.95, 1.08)
    parka = cloth("a2_parka", (0.22, 0.24, 0.16), "canvas")
    pants = cloth("a2_pants", (0.08, 0.08, 0.09), "canvas")
    boot = cloth("a2_boot", (0.09, 0.07, 0.05), "plastic")
    scarf = cloth("a2_scarf", (0.3, 0.27, 0.22), "knit")
    strap = cloth("a2_strap", (0.08, 0.07, 0.06), "canvas")
    glass = mat("glass_g", (0.08, 0.12, 0.1), rough=0.05)
    acc, led = accent(GREEN)
    legs(b, pants, boot, r_thigh=0.08, r_calf=0.058)
    boots(b, boot, 0.24)
    seg((0, 0.01, b.knee_z + 0.08), (0, 0.0, b.sh_z + 0.02), 0.2, 0.19, parka, flat=0.7)
    chest(b, parka, 0.24, 0.95)
    box((0, 0.145, b.waist_z - 0.1), (0.02, 0.015, 0.6), strap)  # zip
    seg((0, 0, b.waist_z - 0.03), (0, 0, b.waist_z + 0.02), 0.175, 0.175, strap, flat=0.72)  # belt
    for s in (-1, 1):
        box((0.12 * s, 0.15, b.waist_z - 0.18), (0.11, 0.03, 0.12), parka)
    box((0.02, 0.0, b.chest_z), (0.06, 0.32, 0.5), strap, rot=(0, 38, 0))  # crossbody strap
    box((0.2, 0.04, b.waist_z - 0.12), (0.08, 0.22, 0.2), strap)  # bag
    arms(b, parka, sk("a"), r=0.06, gloves=cloth("glove", (0.07, 0.07, 0.07), "canvas"))
    armband(b, acc, -1)
    tag_light(b, led, -0.12)
    head(b, sk("a"), cloth("a2_hair", (0.06, 0.04, 0.03), "hair"), "tied")
    hz = b.head_z
    ball((0, 0.03, hz - 0.06), 0.095, scarf, scale=(0.95, 1.0, 0.75), seg=10, rings=5)  # scarf over nose
    seg((0, 0, b.neck_z - 0.04), (0, 0, b.neck_z + 0.05), 0.11, 0.1, scarf, flat=0.9)
    seg((-0.095, 0, hz + 0.06), (0.095, 0, hz + 0.06), 0.012, 0.012, strap, verts=6)
    for s in (-1, 1):  # goggles pushed up on the forehead
        seg((0.035 * s, 0.07, hz + 0.075), (0.035 * s, 0.11, hz + 0.085), 0.03, 0.03, strap, verts=8)
        seg((0.035 * s, 0.1, hz + 0.083), (0.035 * s, 0.112, hz + 0.086), 0.024, 0.024, glass, verts=8)
    return finish("a2_nadia")


def a_bernard():
    """A3 Bernard, 58, ex-lineman: hood, full gas mask, rubber coat, headlamp."""
    b = Body(1.76, 1.12)
    coat = cloth("a3_coat", (0.13, 0.15, 0.13), "plastic", rough=0.35)
    pants = cloth("a3_pants", (0.1, 0.1, 0.09), "canvas")
    boot = cloth("a3_boot", (0.05, 0.05, 0.05), "plastic", rough=0.3)
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    glass = mat("glass_a", (0.1, 0.12, 0.1), rough=0.05)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    belt = cloth("a3_belt", (0.14, 0.11, 0.08), "canvas")
    lamp = mat("lamp", (0.9, 0.95, 1.0), emit=((0.85, 0.92, 1.0), 25))
    acc, led = accent(WHITE)
    legs(b, pants, boot, r_thigh=0.095, r_calf=0.066)
    boots(b, boot, 0.3)
    seg((0, 0.02, b.knee_z - 0.02), (0, 0.0, b.sh_z + 0.02), 0.24, 0.21, coat, flat=0.72)
    chest(b, coat, 0.3, 1.02)
    seg((0, 0.02, b.waist_z - 0.04), (0, 0.02, b.waist_z + 0.02), 0.2, 0.2, belt, flat=0.8)
    pouches(b, belt, (-0.14, -0.05, 0.14), b.waist_z - 0.07, 0.16)
    box((0.22, 0.0, b.waist_z - 0.18), (0.04, 0.04, 0.24), metal)  # wrench
    arms(b, coat, sk("d"), r=0.068, gloves=rubber)
    armband(b, acc, -1)
    tag_light(b, led, -0.15)
    head(b, sk("d"), None)
    gasmask(b, rubber, glass, metal, worn=True)
    hz = b.head_z
    ball((0, -0.03, hz + 0.02), 0.125, coat, scale=(0.98, 1.0, 1.08), seg=10, rings=6)  # hood
    seg((0, -0.05, b.sh_z), (0, -0.03, hz), 0.12, 0.1, coat)
    box((0, 0.105, hz + 0.075), (0.05, 0.04, 0.035), rubber)
    ball((0, 0.13, hz + 0.075), 0.015, lamp, seg=6, rings=3)
    seg((-0.11, 0.06, hz + 0.075), (0.11, 0.06, hz + 0.075), 0.01, 0.01, rubber, verts=4)
    seg((0.08, -0.12, b.chest_z), (0.13, 0.05, b.waist_z - 0.2), 0.02, 0.02, rubber, verts=6)  # hose
    box((0, -0.27, b.chest_z), (0.3, 0.18, 0.42), metal)  # battery pack
    return finish("a3_bernard")


# ------------------------------------------------------------ B: Protocole
# Staff of the site that caused the incident: a lab, its hazmat crew, its guard.

def b_claire():
    """B1 Dr Claire Morel, 39, researcher: stained lab coat over a light vest, glasses, badge."""
    b = Body(1.7, 0.95, 1.05)
    coat = cloth("b1_coat", (0.6, 0.6, 0.57), "canvas")
    shirt = cloth("b1_shirt", (0.15, 0.17, 0.2), "canvas")
    pants = cloth("b1_pants", (0.12, 0.12, 0.13), "canvas")
    shoe = cloth("b1_shoe", (0.06, 0.05, 0.05), "plastic")
    vest = cloth("b1_vest", (0.14, 0.15, 0.13), "canvas")
    frame = mat("frame", (0.03, 0.03, 0.03))
    glass = mat("lens", (0.3, 0.35, 0.35), rough=0.05)
    acc, led = accent(BLUE)
    legs(b, pants, shoe, r_thigh=0.08, r_calf=0.056)
    torso(b, shirt, 0.15, 0.19, flat=0.68)
    chest(b, vest, 0.25, 0.95)
    pouches(b, vest, (-0.08, 0.08), b.chest_z - 0.06, 0.14)
    for s in (-1, 1):  # open coat panels to the knee
        box((0.15 * s, 0.02, b.waist_z - 0.15), (0.13, 0.28, 0.9), coat, rot=(0, 3 * s, 0))
    box((0, -0.12, b.waist_z - 0.15), (0.4, 0.06, 0.9), coat)
    box((0.11, 0.165, b.chest_z + 0.06), (0.05, 0.01, 0.07), mat("badge", (0.8, 0.82, 0.8)))
    arms(b, coat, sk("d"), r=0.058, fwd=0.04)
    armband(b, acc, -1)
    tag_light(b, led, -0.1)
    head(b, sk("d"), cloth("b1_hair", (0.2, 0.13, 0.08), "hair"), "tied")
    hz = b.head_z
    for s in (-1, 1):
        box((0.034 * s, 0.098, hz + 0.012), (0.045, 0.006, 0.03), glass)
    box((0, 0.1, hz + 0.03), (0.11, 0.008, 0.006), frame)
    wr = b.arm(1, 1.0, 0.04)[2]
    box((wr[0] - 0.02, wr[1] + 0.06, wr[2] - 0.05), (0.03, 0.17, 0.24), cloth("b1_tablet", (0.08, 0.08, 0.09), "plastic"))  # clipboard
    return finish("b1_claire")


def b_ilyes():
    """B2 Ilyes, 30, hazmat technician: sealed grey-green suit, visor hood, filter tank."""
    b = Body(1.8, 1.12, 1.05)
    suit = cloth("b2_suit", (0.38, 0.42, 0.34), "plastic", rough=0.35)
    tape = cloth("b2_tape", (0.12, 0.12, 0.12), "plastic", rough=0.5)
    visor = mat("visor", (0.04, 0.06, 0.06), rough=0.03)
    tank = cloth("b2_tank", (0.26, 0.27, 0.27), "plate", rough=0.35)
    acc, led = accent(GREEN)
    legs(b, suit, tape, r_thigh=0.1, r_calf=0.08, flare=1.05)
    boots(b, tape, 0.28)
    torso(b, suit, 0.19, 0.22, flat=0.75)
    chest(b, suit, 0.3, 1.05)
    for s in (-1, 1):  # taped wrists and ankles
        x = b.hip_x * s * 0.95
        seg((x, -0.01, 0.34), (x, -0.01, 0.4), 0.085, 0.085, tape)
    arms(b, suit, tape, r=0.075, out=1.2, gloves=tape)
    for s in (-1, 1):
        wr = b.arm(s, 1.2)[2]
        seg((wr[0], wr[1], wr[2]), (wr[0], wr[1] - 0.01, wr[2] + 0.06), 0.07, 0.07, tape)
    armband(b, acc, -1)
    tag_light(b, led, -0.12)
    hz = b.head_z
    ball((0, 0.0, hz + 0.01), 0.15, suit, scale=(0.95, 1.0, 1.05), seg=12, rings=7)  # hood
    box((0, 0.115, hz + 0.02), (0.19, 0.06, 0.14), visor, rot=(-8, 0, 0))
    seg((0, 0.13, hz - 0.1), (0, 0.17, hz - 0.12), 0.04, 0.045, tape, verts=8)  # exhale valve
    for s in (-1, 1):  # twin tanks
        seg((0.08 * s, -0.24, b.waist_z), (0.08 * s, -0.24, b.sh_z), 0.075, 0.075, tank, verts=10)
        ball((0.08 * s, -0.24, b.sh_z), 0.075, tank, seg=8, rings=4)
    seg((0.08, -0.24, b.sh_z + 0.03), (0.12, -0.05, hz - 0.05), 0.02, 0.02, tape, verts=6)
    seg((0.12, -0.05, hz - 0.05), (0.06, 0.12, hz - 0.1), 0.02, 0.02, tape, verts=6)
    box((0, 0.15, b.chest_z + 0.04), (0.2, 0.05, 0.14), tape)  # dosimeter panel
    return finish("b2_ilyes")


def b_franck():
    """B3 Franck, 45, site security: helmet visor up, padded vest, shoulder radio, torch."""
    b = Body(1.84, 1.1)
    shirt = cloth("b3_shirt", (0.2, 0.25, 0.33), "canvas")
    vest = cloth("b3_vest", (0.1, 0.11, 0.12), "canvas")
    pants = cloth("b3_pants", (0.07, 0.07, 0.08), "canvas")
    boot = cloth("b3_boot", (0.04, 0.04, 0.04), "plastic", rough=0.35)
    helm = cloth("b3_helmet", (0.16, 0.17, 0.19), "plate", rough=0.35)
    visor = mat("visor_b", (0.15, 0.17, 0.17), rough=0.05)
    acc, led = accent(WHITE)
    legs(b, pants, boot, r_thigh=0.092, r_calf=0.064)
    boots(b, boot, 0.2)
    kneepads(b, vest)
    torso(b, shirt, 0.16, 0.21, flat=0.72)
    chest(b, vest, 0.32, 1.08)
    box((0, 0.0, b.waist_z + 0.03), (0.42, 0.32, 0.12), vest)
    pouches(b, vest, (-0.13, -0.045, 0.045, 0.13), b.waist_z + 0.03, 0.17)
    seg((0, 0, b.waist_z - 0.06), (0, 0, b.waist_z - 0.01), 0.17, 0.17, vest, flat=0.75)
    box((-0.2, 0.0, b.waist_z - 0.12), (0.05, 0.05, 0.2), helm)  # torch
    arms(b, shirt, sk("b"), r=0.066, gloves=cloth("glove", (0.07, 0.07, 0.07), "canvas"))
    plates_on_arms(b, vest)
    armband(b, acc, -1)
    tag_light(b, led, -0.15)
    box((0.15, 0.1, b.sh_z - 0.02), (0.05, 0.04, 0.09), vest)  # radio
    seg((0.165, 0.1, b.sh_z + 0.02), (0.165, 0.1, b.sh_z + 0.14), 0.006, 0.004, vest, verts=4)
    head(b, sk("b"), None)
    hz = b.head_z
    ball((0, -0.005, hz + 0.04), 0.118, helm, scale=(0.92, 1.0, 0.86), seg=10, rings=6)
    seg((0, 0, hz - 0.02), (0, 0, hz + 0.03), 0.11, 0.11, helm, verts=10, flat=1.05)
    box((0, 0.1, hz + 0.1), (0.18, 0.05, 0.06), visor, rot=(-35, 0, 0))  # visor up
    return finish("b3_franck")


# ------------------------------------------------------------ C: Infiltration
# A small team sent in to get people out: sneaking suits, no firearms.

def c_suit(b, suit, plate, rib=True):
    legs(b, suit, cloth("c_boot", (0.04, 0.04, 0.04), "plastic", rough=0.4), r_thigh=0.085, r_calf=0.058)
    boots(b, cloth("c_boot", (0.04, 0.04, 0.04), "plastic", rough=0.4), 0.16)
    torso(b, suit, 0.145, 0.2, flat=0.68)
    chest(b, suit, 0.24, 0.96)
    if rib:  # segmented ribs on the abdomen
        for i in range(4):
            box((0, 0.11, b.waist_z - 0.04 + i * 0.07), (0.2, 0.03, 0.04), plate)
    kneepads(b, plate)
    for s in (-1, 1):
        box((b.hip_x * s * 1.1, 0.04, b.knee_z + 0.2), (0.07, 0.08, 0.16), plate)  # thigh plates


def c_vipere():
    """C1 'Vipere', 33, scout: hood, triple-lens night goggles, long bandana tails."""
    b = Body(1.78, 1.0)
    suit = cloth("c1_suit", (0.1, 0.11, 0.12), "knit", rough=0.5)
    plate = cloth("c_plate", (0.18, 0.19, 0.2), "plate", rough=0.35)
    band = cloth("c1_bandana", (0.24, 0.24, 0.22), "canvas")
    nv = mat("nv", (0.1, 0.4, 0.15), emit=((0.3, 1.0, 0.35), 6))
    acc, led = accent(BLUE)
    c_suit(b, suit, plate)
    pouches(b, plate, (-0.14, 0.14), b.waist_z - 0.02, 0.1)
    arms(b, suit, sk("a"), r=0.056, gloves=cloth("glove", (0.07, 0.07, 0.07), "canvas"))
    plates_on_arms(b, plate)
    armband(b, acc, -1)
    tag_light(b, led, -0.13)
    head(b, sk("a"), cloth("c1_hair", (0.05, 0.04, 0.03), "hair"), "buzz")
    hz = b.head_z
    seg((-0.1, 0.0, hz + 0.05), (0.1, 0.0, hz + 0.05), 0.08, 0.08, band, verts=8, flat=1.2)
    for s, d in ((1, 0.0), (1, 0.05)):  # bandana tails
        seg((0.03, -0.09, hz + 0.05), (0.09 + d, -0.24, hz - 0.12 - d), 0.018, 0.012, band, verts=4)
    box((0, 0.07, hz + 0.1), (0.08, 0.06, 0.04), plate)  # goggle mount
    for x, z in ((-0.03, 0.03), (0.03, 0.03), (0.0, 0.065)):
        seg((x, 0.08, hz + z), (x, 0.14, hz + z), 0.019, 0.016, plate, verts=8)
        ball((x, 0.142, hz + z), 0.013, nv, seg=6, rings=3)
    box((0.085, 0.03, hz), (0.02, 0.05, 0.05), plate)  # earpiece
    seg((0.09, 0.05, hz - 0.02), (0.04, 0.1, hz - 0.06), 0.006, 0.006, plate, verts=4)
    box((0, -0.18, b.chest_z), (0.24, 0.08, 0.3), plate)
    return finish("c1_vipere")


def c_sana():
    """C2 'Sana', 29, signals: balaclava, chest rig, radio pack with antenna."""
    b = Body(1.68, 0.94, 1.06)
    suit = cloth("c2_suit", (0.13, 0.14, 0.12), "knit", rough=0.5)
    plate = cloth("c_plate", (0.18, 0.19, 0.2), "plate", rough=0.35)
    rig = cloth("c2_rig", (0.2, 0.2, 0.16), "canvas")
    bala = cloth("c2_bala", (0.06, 0.06, 0.06), "knit")
    acc, led = accent(GREEN)
    c_suit(b, suit, plate, rib=False)
    box((0, 0.02, b.chest_z - 0.02), (0.36, 0.28, 0.32), rig)
    pouches(b, rig, (-0.1, -0.035, 0.035, 0.1), b.chest_z - 0.08, 0.15)
    arms(b, suit, sk("c"), r=0.054, gloves=cloth("glove", (0.07, 0.07, 0.07), "canvas"))
    armband(b, acc, -1)
    tag_light(b, led, -0.11)
    head(b, sk("c"), None)
    hz = b.head_z
    ball((0, 0.0, hz + 0.01), 0.104, bala, scale=(0.86, 0.98, 1.15), seg=10, rings=6)
    box((0, 0.088, hz + 0.012), (0.1, 0.02, 0.035), sk("c"))  # eye slot
    for s in (-1, 1):
        box((0.034 * s, 0.098, hz + 0.012), (0.03, 0.01, 0.016), mat("eye", (0.02, 0.015, 0.015)))
    box((0.075, 0.02, hz + 0.02), (0.035, 0.06, 0.07), plate)  # headset
    box((0, -0.22, b.chest_z - 0.06), (0.28, 0.14, 0.36), rig)
    box((0, -0.22, b.chest_z - 0.06), (0.2, 0.15, 0.16), plate)
    seg((0.1, -0.24, b.chest_z + 0.1), (0.13, -0.28, b.chest_z + 0.75), 0.008, 0.004, plate, verts=4)
    return finish("c2_sana")


def c_gros():
    """C3 'Bastion', 40, breacher: heavy helmet, gas mask, armour, bolt cutters on the back."""
    b = Body(1.86, 1.18, 1.05)
    suit = cloth("c3_suit", (0.11, 0.12, 0.11), "knit", rough=0.5)
    plate = cloth("c_plate", (0.18, 0.19, 0.2), "plate", rough=0.35)
    armor = cloth("c3_armor", (0.17, 0.18, 0.15), "plate", rough=0.4)
    rubber = cloth("rubber", (0.05, 0.05, 0.05), "plastic", rough=0.4)
    glass = mat("glass_c", (0.06, 0.09, 0.08), rough=0.05)
    metal = cloth("metal", (0.3, 0.3, 0.29), "plate", rough=0.35)
    acc, led = accent(WHITE)
    c_suit(b, suit, plate, rib=False)
    box((0, 0.02, b.chest_z - 0.02), (0.46, 0.34, 0.42), armor)
    box((0, 0.0, b.waist_z - 0.06), (0.4, 0.3, 0.14), armor)
    pouches(b, armor, (-0.14, -0.05, 0.05, 0.14), b.waist_z - 0.06, 0.17)
    for s in (-1, 1):
        box((0.17 * s, 0.0, b.sh_z + 0.02), (0.14, 0.3, 0.06), armor, rot=(0, 18 * s, 0))
    arms(b, suit, rubber, r=0.07, out=1.25, gloves=rubber)
    plates_on_arms(b, armor)
    armband(b, acc, -1)
    tag_light(b, led, -0.16)
    head(b, sk("b"), None)
    gasmask(b, rubber, glass, metal, worn=True)
    hz = b.head_z
    ball((0, -0.01, hz + 0.045), 0.125, armor, scale=(0.94, 1.0, 0.85), seg=10, rings=6)
    seg((0, 0, hz - 0.03), (0, 0, hz + 0.03), 0.12, 0.12, armor, verts=10)
    for s in (-1, 1):  # bolt cutters across the back
        seg((0.05 * s - 0.12, -0.24, b.waist_z - 0.1), (0.05 * s + 0.15, -0.24, b.sh_z + 0.25), 0.015, 0.015, metal, verts=6)
    box((0.17, -0.24, b.sh_z + 0.28), (0.07, 0.04, 0.12), rubber, rot=(0, -40, 0))
    return finish("c3_bastion")


def shot_portraits(d):
    for i, fn in enumerate(DIRS[d]):
        reset()
        o, t = build(fn)
        world(0.004)
        zs = sorted((o.matrix_world @ v.co).z for v in o.data.vertices)
        hz = zs[int(len(zs) * 0.97)] - 0.12
        spot((-1.8, 2.4, 3.2), (0, 0, hz), 900, (1.0, 0.64, 0.32), 50)
        spot((1.8, 1.5, 2.0), (0, 0, hz), 260, (0.75, 0.82, 1.0), 60, 0.6, cam=False)
        spot((0.4, -2.5, 2.4), (0, 0, hz), 500, (0.5, 0.62, 1.0), 60, 0.3, cam=False)
        camera((0.55, 1.35, hz + 0.05), (0, 0, hz - 0.08), 50)
        render(f"{OUT}/{d}-p{i + 1}.png", 240, 300)


DIRS = {
    "A": [a_mehdi, a_nadia, a_bernard],
    "B": [b_claire, b_ilyes, b_franck],
    "C": [c_vipere, c_sana, c_gros],
}

shots = WANT or ["trio:A", "trio:B", "trio:C", "port:A", "port:B", "port:C",
                 "scene:A", "scene:B", "scene:C"]
for s in shots:
    kind, d = s.split(":")
    {"trio": shot_trio, "port": shot_portraits, "scene": shot_scene}[kind](d)
