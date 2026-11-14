"""64 px procedural textures for the Boucher, applied by box projection."""
import bpy
import numpy as np

RNG = np.random.default_rng(7)
N = 64


def vnoise(cells):
    g = RNG.random((cells + 1, cells + 1))
    x = np.linspace(0, cells, N, endpoint=False)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    a = g[i][:, i]; b = g[i][:, i + 1]; c = g[i + 1][:, i]; d = g[i + 1][:, i + 1]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(base=4, oct=4):
    out, amp, tot = np.zeros((N, N)), 1.0, 0.0
    for o in range(oct):
        out += vnoise(min(base * 2 ** o, N // 2)) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def lines(count, width_mask=0.5, wobble=6):
    """Random wandering dark lines (veins, cracks, scratches)."""
    m = np.zeros((N, N))
    for _ in range(count):
        x, y = RNG.integers(0, N, 2).astype(float)
        ang = RNG.random() * 6.28
        for _ in range(RNG.integers(15, 40)):
            m[int(y) % N, int(x) % N] = 1
            ang += RNG.normal(0, 0.5)
            x += np.cos(ang); y += np.sin(ang)
    return m


def lerp(c1, c2, t):
    return np.array(c1)[None, None, :] * (1 - t[..., None]) + np.array(c2)[None, None, :] * t[..., None]


def make(name, rgb):
    img = bpy.data.images.new(name, N, N)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((N, N, 1))], axis=2)
    img.pixels = rgba[::-1].ravel()  # blender rows start at the bottom
    return img


def textures():
    T = {}
    n = fbm(3, 4)
    flesh = lerp((0.36, 0.25, 0.21), (0.22, 0.13, 0.12), n)
    spots = fbm(8, 2) > 0.66
    flesh[spots] *= 0.6
    flesh[spots] += np.array([0.06, 0, 0])
    v = lines(10)
    flesh[v > 0] = flesh[v > 0] * 0.4 + np.array([0.18, 0.03, 0.05])
    st = np.zeros((N, N), bool)  # stitches
    for k in range(18, 46, 3):
        st[k, 30:34] = True
    st[18:46, 32] = True
    flesh[st] = (0.06, 0.03, 0.03)
    T["flesh"] = flesh
    n = fbm(4, 4)
    raw = lerp((0.42, 0.04, 0.04), (0.14, 0.01, 0.02), n)
    raw[lines(14) > 0] = (0.55, 0.3, 0.25)  # fat / tendons
    T["raw"] = raw
    n = fbm(3, 4)
    metal = lerp((0.36, 0.36, 0.37), (0.2, 0.2, 0.21), fbm(6, 3))
    rust = np.clip((n - 0.45) * 4, 0, 1)
    metal = metal * (1 - rust[..., None]) + lerp((0.3, 0.14, 0.07), (0.16, 0.07, 0.04), fbm(10, 2)) * rust[..., None]
    metal[lines(16) > 0] *= 1.6  # scratches
    blood = fbm(5, 3) > 0.68
    metal[blood] = (0.18, 0.02, 0.02)
    T["metal"] = metal
    bone = lerp((0.66, 0.6, 0.47), (0.38, 0.32, 0.22), fbm(4, 4))
    bone[lines(8) > 0] = (0.2, 0.15, 0.1)
    tip = np.linspace(0, 1, N)[:, None] * np.ones((1, N))
    bone = bone * (1 - 0.6 * tip[..., None] ** 3) + np.array([0.25, 0.02, 0.02]) * (0.6 * tip[..., None] ** 3)
    T["bone"] = bone
    dark = lerp((0.05, 0.05, 0.055), (0.015, 0.015, 0.02), fbm(6, 3))
    dark[lines(6) > 0] = (0.1, 0.1, 0.1)
    T["dark"] = dark
    return {k: make("tx_" + k, v) for k, v in T.items()}


def apply(obj, scale=4.0):
    imgs = textures()
    keymap = {"b2_flesh": "flesh", "b2_raw": "raw", "b2_metal": "metal", "b2_bone": "bone", "b2_dark": "dark"}
    rough = {"flesh": 0.5, "raw": 0.2, "metal": 0.45, "bone": 0.6, "dark": 0.7}
    for slot in obj.material_slots:
        m = slot.material
        k = keymap.get(m.name)
        if not k:
            continue
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (scale, scale, scale)
        tx = nt.nodes.new("ShaderNodeTexImage")
        tx.image = imgs[k]
        tx.interpolation = "Closest"
        tx.projection = "BOX"
        tx.projection_blend = 0.0
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], tx.inputs["Vector"])
        nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.35
        bump.inputs["Distance"].default_value = 0.01
        nt.links.new(tx.outputs["Color"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        bsdf.inputs["Roughness"].default_value = rough[k]
