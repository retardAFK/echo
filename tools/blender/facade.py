"""Builds the HLM facade modules (S-005, T-036) in the open Blender scene.

3 x 3 m prefab concrete panels, made to be repeated side by side and stacked
to make a block of flats. Every variant is dirty (Maxime, 05/11/2026):
- "plain": dark window,
- "lit": a window lit by the cold glow of a TV,
- "balcony": a French window with a concrete balcony and a rusty railing,
- "walled": a window bricked up with concrete blocks (ground floor, tagged),
- "door": the metal entrance door of the stairwell (ground floor, tagged),
- "open": a window without glass, a real hole the players see through, in
  front of the window openings of the visited storeys of the tower (S-006, T-045).
Upper floor panels share one texture, ground floor panels another one, with
tags in dull colors only (orange is the noise color, constitution 2.3).

Origin at the bottom-left corner of the outer face, the outside faces -Y.
Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/facade.py -- <out.blend> <out_dir>
1 Blender unit = 1 meter, 64 px per meter: each 256 x 256 px texture (the
building size of constitution 2.3) covers 4 m.
"""

import math
import os
import random
import sys

import bmesh
import bpy

NAME = "facade_hlm"
VARIANTS = ("plain", "lit", "balcony", "walled", "door", "open")
GROUND_VARIANTS = ("walled", "door")
TEX_SIZE = 256
METERS_PER_TEXTURE = 4.0
SIZE = 3.0
THICKNESS = 0.2
WINDOW = (0.9, 1.0, 2.1, 2.4)  # x0, z0, x1, z1 of a window opening.
FRENCH_WINDOW = (0.9, 0.0, 2.1, 2.4)  # Balcony door, down to the floor.
DOOR = (0.95, 0.0, 2.05, 2.2)
RECESS = 0.12
TAG_COLORS = ((0.06, 0.06, 0.07), (0.12, 0.17, 0.36), (0.38, 0.08, 0.09), (0.7, 0.7, 0.66))
TV_LIGHT = (0.32, 0.42, 0.7)
# Atlas regions (u0, v0, u1, v1) in the top band; concrete uses u, v < 0.75.
GLASS_REGION = (0.8, 0.8, 1.0, 1.0)
FRAME_REGION = (0.8, 0.76, 1.0, 0.79)
LIT_REGION = (0.6, 0.8, 0.8, 1.0)
BLOCKS_REGION = (0.4, 0.8, 0.6, 1.0)
DOOR_REGION = (0.2, 0.8, 0.4, 1.0)
RUST_REGION = (0.0, 0.95, 0.05, 1.0)


def _fill(px, region, shade):
    for y in range(int(region[1] * TEX_SIZE), int(region[3] * TEX_SIZE)):
        for x in range(int(region[0] * TEX_SIZE), int(region[2] * TEX_SIZE)):
            px[y][x] = shade(x, y)


def _darken(px, x, y, k):
    c = px[y % TEX_SIZE][x % TEX_SIZE]
    px[y % TEX_SIZE][x % TEX_SIZE] = [c[0] * k, c[1] * k, c[2] * k]


def _tag(px, rng, color, x0, y0):
    x, y = x0, y0
    heading = rng.uniform(-0.4, 0.4)
    for _ in range(rng.randint(70, 130)):
        heading += rng.uniform(-1.2, 1.2)
        x += math.cos(heading) * 1.4
        y += math.sin(heading) * 1.0
        for dx in (0, 1):
            ix, iy = int(x + dx), int(y)
            if 0 <= ix < 0.75 * TEX_SIZE and 0 <= iy < 0.75 * TEX_SIZE:
                px[iy][ix] = list(color)


def make_texture(ground):
    rng = random.Random(11 if ground else 3)
    ppm = TEX_SIZE / METERS_PER_TEXTURE
    px = []
    for y in range(TEX_SIZE):
        row = []
        for x in range(TEX_SIZE):
            g = 0.45 + rng.uniform(-0.04, 0.04)
            if rng.random() < 0.04:
                g -= 0.1
            row.append([g, g * 0.99, g * 0.95])
        px.append(row)
    # Dirt patches, darker towards the ground.
    for _ in range(40):
        bx, by, r = rng.randrange(192), rng.randrange(192), rng.uniform(6, 22)
        for y in range(int(by - r), int(by + r)):
            for x in range(int(bx - r), int(bx + r)):
                d = math.hypot(x - bx, (y - by) * 0.5)
                if d < r and 0 <= y < TEX_SIZE:
                    _darken(px, x, y, 1.0 - 0.3 * (1.0 - d / r))
    for y in range(int(0.75 * TEX_SIZE)):
        for x in range(int(0.75 * TEX_SIZE)):
            if y < 40 and rng.random() < 0.7 * (1 - y / 40):  # Splashes and moss.
                c = px[y][x]
                px[y][x] = [c[0] * 0.62, c[1] * 0.72, c[2] * 0.5]
    # Black run-off streaks under the window corners, and rain marks everywhere.
    for wx in (WINDOW[0], WINDOW[2], (WINDOW[0] + WINDOW[2]) / 2):
        x0 = int(wx * ppm)
        for dx in range(-4, 5):
            length = rng.randint(30, 64)
            for dy in range(length):
                y = int(WINDOW[1] * ppm) - dy
                if 0 <= y:
                    _darken(px, x0 + dx, y, 1.0 - 0.45 * (1 - dy / length) * (1 - abs(dx) / 5))
    for _ in range(60):
        x0, y0 = rng.randrange(192), rng.randrange(192)
        for dy in range(rng.randint(10, 50)):
            _darken(px, x0, y0 - dy, 0.82)
    # Panel joints every 3 m, so repeated panels tile.
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            if int(x % (SIZE * ppm)) < 2 or int(y % (SIZE * ppm)) < 2:
                px[y][x] = [0.16, 0.16, 0.17]
    if ground:  # Tags at hand height.
        for _ in range(9):
            color = TAG_COLORS[rng.randrange(len(TAG_COLORS))]
            _tag(px, rng, color, rng.uniform(5, 170), rng.uniform(20, 100))
    _fill(px, GLASS_REGION, lambda x, y: [0.04, 0.045, 0.065] if (x + y) % 23 > 2 else [0.08, 0.09, 0.12])
    _fill(px, FRAME_REGION, lambda x, y: [0.55, 0.55, 0.53] if rng.random() > 0.3 else [0.3, 0.29, 0.27])
    _fill(px, LIT_REGION, lambda x, y: [c * (0.75 + 0.25 * rng.random()) for c in TV_LIGHT])
    _fill(  # Grey concrete blocks with dark mortar.
        px,
        BLOCKS_REGION,
        lambda x, y: [0.18] * 3 if y % 10 == 0 or (x + (y // 10) * 8) % 16 == 0
        else [0.36 + rng.uniform(-0.04, 0.04)] * 3,
    )
    _fill(  # Dented green-grey metal door with rust.
        px,
        DOOR_REGION,
        lambda x, y: [0.3, 0.17, 0.08] if rng.random() < 0.08
        else [0.22, 0.26 + (0.03 if y % 12 < 2 else 0.0), 0.24],
    )
    _fill(px, RUST_REGION, lambda x, y: [0.3, 0.15, 0.07])
    img = bpy.data.images.new("%s_%s_tex" % (NAME, "ground" if ground else "upper"), TEX_SIZE, TEX_SIZE)
    img.pixels = [v for row in px for c in row for v in (c[0], c[1], c[2], 1.0)]
    img.pack()
    return img


def make_material(name, img, emission=None):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    if emission:
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def add_box(bm, x0, y0, z0, x1, y1, z1):
    before = set(bm.faces)
    box = bmesh.ops.create_cube(bm, size=1.0)
    for v in box["verts"]:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    return set(bm.faces) - before


def map_uv(bm, faces, region=None, rect=None):
    """World-scale box projection, or the face stretched over an atlas region."""
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            co = loop.vert.co
            if region is None:
                loop[uv].uv = (co[a] / METERS_PER_TEXTURE, co[b] / METERS_PER_TEXTURE)
                continue
            x0, z0, x1, z1 = rect or WINDOW
            u = (co.x - x0) / (x1 - x0)
            v = (co.z - z0) / (z1 - z0)
            u = region[0] + min(max(u, 0.0), 1.0) * (region[2] - region[0])
            v = region[1] + min(max(v, 0.0), 1.0) * (region[3] - region[1])
            loop[uv].uv = (u, v)


def wall_with_hole(bm, hole):
    x0, z0, x1, z1 = hole
    t = THICKNESS
    faces = set()
    if z0 > 0:
        faces |= add_box(bm, 0, 0, 0, SIZE, t, z0)
    faces |= add_box(bm, 0, 0, z1, SIZE, t, SIZE)
    faces |= add_box(bm, 0, 0, z0, x0, t, z1)
    faces |= add_box(bm, x1, 0, z0, SIZE, t, z1)
    return faces


def window_frame(bm, hole):
    x0, z0, x1, z1 = hole
    bar = 0.06
    fy0, fy1 = RECESS - 0.03, RECESS
    mid = (x0 + x1) / 2
    faces = set()
    faces |= add_box(bm, x0, fy0, z0, x1, fy1, z0 + bar)
    faces |= add_box(bm, x0, fy0, z1 - bar, x1, fy1, z1)
    faces |= add_box(bm, x0, fy0, z0, x0 + bar, fy1, z1)
    faces |= add_box(bm, x1 - bar, fy0, z0, x1, fy1, z1)
    faces |= add_box(bm, mid - bar / 2, fy0, z0, mid + bar / 2, fy1, z1)
    return faces


def build(variant, offset_x=0.0):
    ground = variant in GROUND_VARIANTS
    bm = bmesh.new()
    concrete = set()
    special = []  # (faces, region, rect, emissive)
    if variant in ("plain", "lit", "walled", "open"):
        concrete |= wall_with_hole(bm, WINDOW)
        x0, z0, x1, z1 = WINDOW
        concrete |= add_box(bm, x0 - 0.08, -0.08, z0 - 0.06, x1 + 0.08, 0.02, z0)  # Sill.
        if variant == "walled":
            special.append((add_box(bm, x0, 0.02, z0, x1, 0.1, z1), BLOCKS_REGION, WINDOW, False))
        elif variant == "open":
            special.append((window_frame(bm, WINDOW), FRAME_REGION, WINDOW, False))
        else:
            special.append((window_frame(bm, WINDOW), FRAME_REGION, WINDOW, False))
            glass = add_box(bm, x0, RECESS, z0, x1, RECESS + 0.02, z1)
            special.append((glass, LIT_REGION if variant == "lit" else GLASS_REGION, WINDOW, variant == "lit"))
    elif variant == "balcony":
        concrete |= wall_with_hole(bm, FRENCH_WINDOW)
        special.append((window_frame(bm, FRENCH_WINDOW), FRAME_REGION, FRENCH_WINDOW, False))
        x0, z0, x1, z1 = FRENCH_WINDOW
        special.append((add_box(bm, x0, RECESS, z0, x1, RECESS + 0.02, z1), GLASS_REGION, FRENCH_WINDOW, False))
        concrete |= add_box(bm, 0.3, -1.0, -0.12, 2.7, 0.0, 0.0)  # Slab.
        rust = set()
        rust |= add_box(bm, 0.3, -1.0, 0.95, 2.7, -0.96, 1.0)  # Hand rail, front.
        rust |= add_box(bm, 0.3, -1.0, 0.95, 0.34, 0.0, 1.0)  # Hand rails, sides.
        rust |= add_box(bm, 2.66, -1.0, 0.95, 2.7, 0.0, 1.0)
        for i in range(7):  # Railing posts.
            x = 0.3 + i * 0.4
            rust |= add_box(bm, x, -0.99, 0.0, x + 0.03, -0.96, 0.95)
        special.append((rust, RUST_REGION, None, False))
    elif variant == "door":
        concrete |= wall_with_hole(bm, DOOR)
        special.append((add_box(bm, DOOR[0], 0.1, DOOR[1], DOOR[2], 0.14, DOOR[3]), DOOR_REGION, DOOR, False))
        concrete |= add_box(bm, 0.6, -0.9, 2.3, 2.4, 0.0, 2.42)  # Canopy over the door.
    bm.normal_update()
    map_uv(bm, concrete)
    emissive = set()
    for faces, region, rect, lit in special:
        map_uv(bm, faces, region, rect)
        if lit:
            emissive |= faces
    for f in emissive:
        f.material_index = 1
    mesh = bpy.data.meshes.new("%s_%s" % (NAME, variant))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("%s_%s" % (NAME, variant), mesh)
    obj.location.x = offset_x
    bpy.context.collection.objects.link(obj)
    key = "ground" if ground else "upper"
    img = bpy.data.images.get("%s_%s_tex" % (NAME, key)) or make_texture(ground)
    mesh.materials.append(make_material("%s_%s_mat" % (NAME, key), img))
    if emissive:
        mesh.materials.append(make_material("%s_tv_mat" % NAME, img, emission=0.8))
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if __name__ == "__main__":
    objects = [build(v, offset_x=i * 3.5) for i, v in enumerate(VARIANTS)]
    for obj in objects:
        print("TRIANGLES", obj.name, triangle_count(obj))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        for obj in objects:
            for other in objects:
                other.select_set(other == obj)
            x = obj.location.x
            obj.location.x = 0.0
            path = os.path.join(args[1], obj.name + ".glb")
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True)
            obj.location.x = x
