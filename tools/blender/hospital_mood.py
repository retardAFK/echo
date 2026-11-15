"""Mood renders of the hospital of the cité des Tilleuls (D-019, before S-014).

Not game assets: four quick scenes, rendered with Cycles, to agree with Maxime
on what makes the hospital frightening before its spec is written.
- "facade": the abandoned hospital at night in the fog, one ward still lit,
- "couloir": a long ward corridor, dead green tubes, one flickering at the end,
- "morgue": the basement, cold-room drawers, one open, a single bulb,
- "isolement": an isolation room seen through its door (where the S-018
  prison could move).
Pixel textures with nearest filtering, dull colors, no orange (rule 2.3).
    python tools/blender/hospital_mood.py -- <out_dir> [scene ...]
"""

import math
import os
import random
import sys

import bpy  # isort: skip
import bmesh  # noqa: E402  (needs bpy first)

PPM = 32  # Texture pixels per meter.


# --- Helpers -------------------------------------------------------------------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.render.resolution_x = 640
    sc.render.resolution_y = 360
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.010, 0.012, 0.016, 1)
    bg.inputs[1].default_value = 1.0
    sc.world = world
    return sc


def image(name, w, h, shade):
    img = bpy.data.images.new(name, w, h)
    px = []
    for y in range(h):
        for x in range(w):
            r, g, b = shade(x, y)
            px += [min(max(r, 0.0), 1.0), min(max(g, 0.0), 1.0), min(max(b, 0.0), 1.0), 1.0]
    img.pixels = px
    return img


def noisy(name, base, spread, seed, size=32, stains=0.0, stain=(0.0, 0.0, 0.0)):
    rng = random.Random(seed)
    blobs = [(rng.randrange(size), rng.randrange(size), rng.uniform(2, 7)) for _ in range(int(stains))]

    def shade(x, y):
        n = rng.uniform(-spread, spread)
        c = [base[i] + n for i in range(3)]
        for bx, by, br in blobs:
            d = math.hypot(x - bx, y - by)
            if d < br:
                t = 0.6 * (1 - d / br)
                c = [c[i] * (1 - t) + stain[i] * t for i in range(3)]
        return c

    return image(name, size, size, shade)


def tiles(name, base, grout, seed, n=4, size=32, dirt=0.06):
    rng = random.Random(seed)
    cell = size // n
    tone = {(i, j): rng.uniform(-0.04, 0.03) for i in range(n) for j in range(n)}
    broken = {(rng.randrange(n), rng.randrange(n)) for _ in range(2)}

    def shade(x, y):
        if x % cell == 0 or y % cell == 0:
            return grout
        i, j = x // cell, y // cell
        if (i, j) in broken and rng.random() < 0.7:
            return [g * 0.5 for g in grout]
        t = tone[(i, j)] + rng.uniform(-dirt, dirt) * 0.5
        dark = 0.75 if y < size * 0.25 and rng.random() < 0.3 else 1.0
        return [(base[k] + t) * dark for k in range(3)]

    return image(name, size, size, shade)


def material(name, img=None, color=(0.5, 0.5, 0.5), emission=None, strength=0.0, rough=0.85):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    if img is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def box(name, x0, y0, z0, x1, y1, z1, mat, meters=1.0, rot_z=0.0, pivot=None):
    """An axis-aligned box with box-mapped UVs (meters per texture repeat)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        n = f.normal
        for loop in f.loops:
            c = loop.vert.co
            if abs(n.z) > 0.5:
                loop[uv].uv = (c.x / meters, c.y / meters)
            elif abs(n.x) > 0.5:
                loop[uv].uv = (c.y / meters, c.z / meters)
            else:
                loop[uv].uv = (c.x / meters, c.z / meters)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    if rot_z:
        px, py = pivot if pivot else ((x0 + x1) / 2, (y0 + y1) / 2)
        ob.location = (0, 0, 0)
        me.transform(
            __import__("mathutils").Matrix.Translation((-px, -py, 0))
        )
        ob.rotation_euler = (0, 0, rot_z)
        ob.location = (px, py, 0)
    return ob


def text(body, loc, size, mat):
    curve = bpy.data.curves.new("txt", "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = 0.03
    ob = bpy.data.objects.new("txt", curve)
    ob.location = loc
    ob.rotation_euler = (math.pi / 2, 0, 0)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def light(kind, loc, energy, color, size=0.1, name="light"):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == "POINT":
        data.shadow_soft_size = size
    elif kind == "AREA":
        data.size = size
    ob = bpy.data.objects.new(name, data)
    ob.location = loc
    bpy.context.scene.collection.objects.link(ob)
    return ob


def fog(x0, y0, z0, x1, y1, z1, density, color=(0.55, 0.62, 0.6)):
    mat = bpy.data.materials.new("fog")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = density
    vol.inputs["Color"].default_value = (*color, 1)
    nt.links.new(vol.outputs[0], nt.nodes["Material Output"].inputs["Volume"])
    box("fog", x0, y0, z0, x1, y1, z1, mat)


def camera(loc, look_at, lens=24):
    from mathutils import Vector

    data = bpy.data.cameras.new("cam")
    data.lens = lens
    data.clip_start = 0.05
    ob = bpy.data.objects.new("cam", data)
    ob.location = loc
    direction = Vector(look_at) - Vector(loc)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.scene.camera = ob


# Shared materials, built once per scene (read_factory_settings clears them).
def common():
    m = {}
    m["tile_floor"] = material("tile_floor", tiles("t_floor", (0.42, 0.45, 0.40), (0.18, 0.19, 0.17), 1, n=4))
    m["tile_wall"] = material(
        "tile_wall", tiles("t_wall", (0.50, 0.58, 0.52), (0.30, 0.33, 0.30), 2, n=8, dirt=0.1), rough=0.5
    )
    m["paint"] = material(
        "paint", noisy("t_paint", (0.40, 0.44, 0.38), 0.03, 3, stains=6, stain=(0.18, 0.17, 0.12))
    )
    m["ceiling"] = material("ceiling", noisy("t_ceil", (0.36, 0.37, 0.34), 0.03, 4, stains=5, stain=(0.2, 0.17, 0.1)))
    m["concrete"] = material("concrete", noisy("t_conc", (0.30, 0.30, 0.29), 0.05, 5, stains=8, stain=(0.1, 0.1, 0.1)))
    m["steel"] = material("steel", noisy("t_steel", (0.50, 0.52, 0.52), 0.04, 6), rough=0.35)
    m["dark"] = material("dark", color=(0.02, 0.02, 0.02))
    m["door"] = material("door", noisy("t_door", (0.30, 0.36, 0.33), 0.03, 7, stains=3, stain=(0.12, 0.1, 0.08)))
    m["neon"] = material("neon", color=(0.2, 0.3, 0.25), emission=(0.55, 1.0, 0.7), strength=12.0)
    m["neon_dead"] = material("neon_dead", color=(0.25, 0.27, 0.25))
    m["paper"] = material("paper", color=(0.55, 0.55, 0.5))
    m["sheet"] = material("sheet", noisy("t_sheet", (0.55, 0.57, 0.52), 0.03, 8, stains=3, stain=(0.25, 0.2, 0.12)))
    m["window_dark"] = material("window_dark", color=(0.02, 0.025, 0.03), rough=0.1)
    m["window_lit"] = material("window_lit", color=(0.1, 0.2, 0.15), emission=(0.45, 1.0, 0.6), strength=3.0)
    m["bulb"] = material("bulb", color=(0.8, 0.8, 0.7), emission=(1.0, 0.92, 0.75), strength=30.0)
    m["sign"] = material("sign", color=(0.1, 0.2, 0.15), emission=(0.4, 1.0, 0.55), strength=6.0)
    m["red"] = material("red", color=(0.25, 0.03, 0.03), emission=(1.0, 0.1, 0.08), strength=4.0)
    m["padding"] = material(
        "padding", noisy("t_pad", (0.52, 0.52, 0.46), 0.04, 9, stains=7, stain=(0.25, 0.22, 0.15))
    )
    return m


def scatter_papers(m, rng, x0, x1, y0, y1, count, z=0.005):
    for i in range(count):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        box(f"paper{i}", x, y, z, x + 0.21, y + 0.3, z + 0.004, m["paper"], rot_z=rng.uniform(0, 3.1))


def gurney(m, x, y, rot, tipped=False):
    if tipped:
        box("gurney_top", x - 0.3, y - 1.0, 0.0, x + 0.3, y + 1.0, 0.08, m["steel"], rot_z=rot, pivot=(x, y))
        box("gurney_mat", x - 0.28, y - 0.95, 0.08, x + 0.28, y + 0.95, 0.18, m["sheet"], rot_z=rot, pivot=(x, y))
        return
    for dx in (-0.25, 0.25):
        for dy in (-0.85, 0.85):
            box("leg", x + dx - 0.02, y + dy - 0.02, 0.0, x + dx + 0.02, y + dy + 0.02, 0.75, m["steel"], rot_z=rot, pivot=(x, y))
    box("gurney_top", x - 0.3, y - 1.0, 0.75, x + 0.3, y + 1.0, 0.8, m["steel"], rot_z=rot, pivot=(x, y))
    box("gurney_mat", x - 0.28, y - 0.95, 0.8, x + 0.28, y + 0.95, 0.9, m["sheet"], rot_z=rot, pivot=(x, y))


def wheelchair(m, x, y, rot):
    box("wc_seat", x - 0.25, y - 0.25, 0.45, x + 0.25, y + 0.25, 0.5, m["dark"], rot_z=rot, pivot=(x, y))
    box("wc_back", x - 0.25, y + 0.22, 0.5, x + 0.25, y + 0.27, 0.95, m["dark"], rot_z=rot, pivot=(x, y))
    for dx in (-0.3, 0.27):
        box("wc_wheel", x + dx, y - 0.3, 0.0, x + dx + 0.03, y + 0.3, 0.6, m["steel"], rot_z=rot, pivot=(x, y))


# --- Scenes --------------------------------------------------------------------


def couloir(m):
    rng = random.Random(11)
    length, width, height = 34.0, 2.6, 2.8
    box("floor", -width / 2, 0, -0.1, width / 2, length, 0, m["tile_floor"], meters=1.0)
    box("ceil", -width / 2, 0, height, width / 2, length, height + 0.1, m["ceiling"], meters=1.2)
    for side in (-1, 1):
        wx = side * width / 2
        x0, x1 = (wx - 0.1, wx) if side < 0 else (wx, wx + 0.1)
        y = 0.0
        while y < length:
            door = rng.random() < 0.45 and 2 < y < length - 3
            if door:
                box("lintel", x0, y, 2.1, x1, y + 1.2, height, m["paint"])
                box("void", x0 + side * 0.6, y, 0, x1 + side * 0.6, y + 1.2, 2.1, m["dark"])
                # Door leaf left ajar into the room.
                box("leaf", x0 + side * 0.05, y, 0, x1 + side * 0.05, y + 0.06, 2.1, m["door"])
                y += 1.2
            else:
                box("wall_tile", x0, y, 0, x1, y + 2.0, 1.4, m["tile_wall"], meters=1.0)
                box("wall_paint", x0, y, 1.4, x1, y + 2.0, height, m["paint"], meters=2.0)
                y += 2.0
        # Handrail.
        box("rail", wx - side * 0.06 - 0.03, 0, 0.9, wx - side * 0.06 + 0.03, length, 0.94, m["steel"])
    box("end_wall", -width / 2, length, 0, width / 2, length + 0.1, height, m["tile_wall"])
    box("end_door", -0.6, length - 0.02, 0, 0.6, length, 2.1, m["door"])
    box("end_window", -0.25, length - 0.03, 1.3, 0.25, length - 0.02, 1.8, m["window_lit"])
    # Tubes: most dead, one alive near the camera (dim), one at the far end.
    for i, y in enumerate(range(3, int(length), 4)):
        alive = y in (3, 31)
        box("tube", -0.08, y, height - 0.05, 0.08, y + 1.2, height - 0.01, m["neon"] if alive else m["neon_dead"])
    light("AREA", (0, 31.6, height - 0.1), 30, (0.55, 1.0, 0.7), size=1.0, name="far_tube")
    light("AREA", (0, 3.6, height - 0.1), 4, (0.55, 1.0, 0.7), size=1.0, name="near_tube")
    light("POINT", (0, length - 0.4, 1.6), 2, (0.5, 1.0, 0.6), name="end_glow")
    gurney(m, 0.55, 14.0, 0.25)
    wheelchair(m, -0.7, 22.0, 2.4)
    gurney(m, -0.4, 8.0, 1.3, tipped=True)
    scatter_papers(m, rng, -1.1, 1.1, 1, 30, 26)
    box("sign_exit", -0.3, 20.0, 2.45, 0.3, 20.05, 2.65, m["sign"])
    light("AREA", (0.5, 14.0, height - 0.1), 3, (0.55, 1.0, 0.7), size=0.6, name="mid_flicker")
    fog(-width / 2, 0, 0, width / 2, length, height, 0.018)
    camera((0.35, 0.3, 1.6), (0.0, 30.0, 1.3), lens=22)


def morgue(m):
    rng = random.Random(21)
    w, d, h = 7.0, 6.0, 2.7
    box("floor", 0, 0, -0.1, w, d, 0, m["tile_floor"], meters=0.8)
    box("ceil", 0, 0, h, w, d, h + 0.1, m["concrete"], meters=2.0)
    box("wall_back", 0, d, 0, w, d + 0.1, h, m["tile_wall"], meters=1.0)
    box("wall_left", -0.1, 0, 0, 0, d, h, m["tile_wall"], meters=1.0)
    box("wall_right", w, 0, 0, w + 0.1, d, h, m["tile_wall"], meters=1.0)
    # Wall of cold-room drawers: 4 columns x 3 rows, one open.
    for c in range(4):
        for r in range(3):
            x0, z0 = 1.0 + c * 0.95, 0.3 + r * 0.75
            box("drawer", x0, d - 0.05, z0, x0 + 0.85, d, z0 + 0.65, m["steel"])
            box("handle", x0 + 0.3, d - 0.1, z0 + 0.45, x0 + 0.55, d - 0.05, z0 + 0.5, m["dark"])
    box("drawer_hole", 2.9, d - 0.06, 1.05, 3.75, d - 0.05, 1.7, m["dark"])
    box("drawer_out", 2.95, d - 2.0, 1.1, 3.7, d - 0.06, 1.18, m["steel"])
    box("drawer_sheet", 3.0, d - 1.9, 1.18, 3.65, d - 0.3, 1.32, m["sheet"])
    # Steel autopsy table, a drain, plastic strip curtain at the door.
    box("table", 4.6, 1.6, 0.85, 5.4, 3.6, 0.92, m["steel"])
    box("table_foot", 4.9, 2.4, 0, 5.1, 2.8, 0.85, m["steel"])
    box("drain", 3.3, 2.5, 0.0, 3.5, 2.7, 0.005, m["dark"])
    for i in range(10):
        x = 0.3 + i * 0.12
        box("strip", x, 0.4, 0.1 + rng.uniform(0, 0.15), x + 0.1, 0.42, 2.1, m["window_dark"])
    # One bare bulb, swinging (off-centre), and the red standby light of the cooler.
    box("bulb", 3.4, 3.0, 2.3, 3.5, 3.1, 2.4, m["bulb"])
    box("wire", 3.44, 3.04, 2.4, 3.46, 3.06, h, m["dark"])
    light("POINT", (3.45, 3.05, 2.25), 40, (1.0, 0.9, 0.72), size=0.05, name="bulb")
    box("standby", 0.6, d - 0.03, 2.2, 0.66, d - 0.02, 2.26, m["red"])
    light("POINT", (0.63, d - 0.2, 2.23), 0.4, (1.0, 0.1, 0.08), name="standby")
    scatter_papers(m, rng, 0.5, 6.5, 0.6, 4.5, 6)
    fog(0, 0, 0, w, d, h, 0.04)
    camera((1.2, 0.6, 1.6), (3.6, 5.0, 1.1), lens=20)


def isolement(m):
    rng = random.Random(31)
    # Corridor side (camera) and the isolation room behind a door with a hatch.
    w, d, h = 3.0, 3.2, 2.6
    box("floor", -2, -2.5, -0.1, w + 2, d, 0, m["tile_floor"], meters=1.0)
    box("ceil", -2, -2.5, h, w + 2, d, h + 0.1, m["ceiling"], meters=1.2)
    # Front wall with a doorway, the heavy door pushed half open.
    box("front_l", -2, 0, 0, 0.9, 0.2, h, m["paint"], meters=2.0)
    box("front_r", 2.0, 0, 0, w + 2, 0.2, h, m["paint"], meters=2.0)
    box("front_top", 0.9, 0, 2.1, 2.0, 0.2, h, m["paint"])
    box("door", 2.0, 0.2, 0, 2.08, 1.25, 2.1, m["door"], rot_z=-0.5, pivot=(2.0, 0.2))
    box("hatch", 2.0, 0.25, 1.4, 2.09, 0.6, 1.6, m["window_dark"], rot_z=-0.5, pivot=(2.0, 0.2))
    # Padded room.
    box("back", 0, d, 0, w, d + 0.1, h, m["padding"], meters=0.5)
    box("left", -0.1, 0.2, 0, 0, d, h, m["padding"], meters=0.5)
    box("right", w, 0.2, 0, w + 0.1, d, h, m["padding"], meters=0.5)
    box("bed_frame", 0.2, 1.4, 0, 1.1, 3.1, 0.35, m["steel"])
    box("bed_mat", 0.22, 1.42, 0.35, 1.08, 3.08, 0.5, m["sheet"])
    # Straps hanging off the bed, a chair knocked over, writing on the wall.
    box("strap", 1.08, 2.0, 0.05, 1.12, 2.06, 0.48, m["dark"])
    box("strap2", 1.08, 2.7, 0.1, 1.12, 2.76, 0.48, m["dark"])
    box("chair_seat", 1.9, 2.2, 0.0, 2.35, 2.25, 0.45, m["steel"], rot_z=0.7)
    box("chair_back", 1.9, 2.2, 0.0, 2.35, 2.65, 0.04, m["steel"], rot_z=0.7)
    for i in range(18):
        x = rng.uniform(0.4, 2.6)
        z = rng.uniform(0.9, 2.0)
        box("tally", x, d - 0.01, z, x + 0.02, d, z + 0.18, m["dark"])
    # Light: one dying tube in the room, a cold corridor light behind the camera.
    box("tube", 1.0, 1.8, h - 0.05, 2.2, 1.95, h - 0.01, m["neon"])
    light("AREA", (1.6, 1.9, h - 0.1), 9, (0.55, 1.0, 0.7), size=0.8, name="room_tube")
    light("POINT", (1.2, -2.0, 2.3), 6, (0.6, 0.75, 0.8), name="corridor")
    fog(-2, -2.5, 0, w + 2, d, h, 0.02)
    camera((1.45, -0.6, 1.6), (1.2, 2.8, 0.7), lens=18)


def facade(m):
    rng = random.Random(41)
    m["facade"] = material(
        "facade", noisy("t_fac", (0.36, 0.37, 0.34), 0.05, 42, stains=10, stain=(0.14, 0.14, 0.12)), rough=0.95
    )
    m["ground"] = material("ground", noisy("t_ground", (0.12, 0.12, 0.12), 0.03, 43, stains=6, stain=(0.05, 0.05, 0.05)))
    W, D, floors, fh = 46.0, 14.0, 5, 3.2
    box("ground", -60, -40, -0.1, 60, 40, 0, m["ground"], meters=4.0)
    box("body", -W / 2, 0, 0, W / 2, D, floors * fh + 0.4, m["facade"], meters=6.0)
    box("wing", W / 2 - 12, -10, 0, W / 2, 0, 3 * fh, m["facade"], meters=6.0)
    # Windows: dark grid, a few broken boards, one lit ward high up.
    lit = {(3, 11)}
    for f in range(floors):
        for i in range(16):
            x = -W / 2 + 1.6 + i * 2.75
            z = f * fh + 1.0
            mat = m["window_lit"] if (f, i) in lit else m["window_dark"]
            if f == 0 and i in (5, 6, 7):
                continue
            box("win", x, -0.02, z, x + 1.4, 0, z + 1.4, mat)
            if (f, i) not in lit and rng.random() < 0.18:
                box("board", x - 0.05, -0.05, z + 0.4, x + 1.45, -0.02, z + 0.6, m["door"])
    light("AREA", (-W / 2 + 1.6 + 11 * 2.75 + 0.7, -0.6, 3 * fh + 1.7), 25, (0.45, 1.0, 0.6), size=1.4, name="ward")
    # Entrance: ambulance canopy, glass doors, the sign with dead letters.
    box("canopy", -6, -6, 3.4, 4, 0, 3.7, m["concrete"], meters=3.0)
    for x in (-5.6, 3.4):
        box("pillar", x, -5.8, 0, x + 0.3, -5.5, 3.4, m["concrete"])
    box("doors", -2.5, -0.02, 0, 1.5, 0, 2.6, m["window_dark"])
    box("sign_back", -4.4, -6.1, 3.7, 2.4, -6.0, 4.9, m["dark"])
    alive = {0, 1, 2, 4, 5, 6}
    for i, ch in enumerate("HOPITAL"):
        text(ch, (-4.1 + i * 0.92, -6.12, 3.85), 1.0, m["sign"] if i in alive else m["neon_dead"])
    light("AREA", (-1.0, -7.5, 3.0), 30, (0.4, 1.0, 0.55), size=5.0, name="sign")
    box("red_cross", 17.0, -0.05, 15.0, 19.0, -0.02, 17.0, m["neon_dead"])
    gurney(m, -9.0, -5.0, 1.1)
    wheelchair(m, 6.0, -8.0, 0.6)
    # Fence and a sodium lamppost far left, so it belongs to the cité.
    for i in range(30):
        x = -40 + i * 2.6
        box("post", x, -18, 0, x + 0.06, -17.94, 2.0, m["steel"])
    box("fence_top", -40, -18, 1.95, 38, -17.95, 2.0, m["steel"])
    box("pole", -30, -16, 0, -29.85, -15.85, 6.0, m["steel"])
    light("POINT", (-29.9, -15.9, 6.1), 300, (1.0, 0.62, 0.3), size=0.2, name="sodium")
    sun = light("SUN", (0, 0, 30), 0.12, (0.6, 0.7, 0.9), name="moon")
    sun.rotation_euler = (0.9, 0.2, 0.6)
    fog(-60, -40, 0, 60, 40, 25, 0.01)
    camera((-9.0, -24.0, 1.7), (1.0, 2.0, 7.0), lens=20)


SCENES = {"facade": facade, "couloir": couloir, "morgue": morgue, "isolement": isolement}


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = argv[0] if argv else "."
    names = argv[1:] or list(SCENES)
    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        sc = reset()
        SCENES[name](common())
        sc.render.filepath = os.path.join(out_dir, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", sc.render.filepath)


if __name__ == "__main__":
    main()
