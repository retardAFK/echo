"""Builds the HLM facade module (S-005, T-036) in the open Blender scene.

A 3 x 3 m prefab concrete panel with one window, made to be repeated side by
side and stacked to make a block of flats. Origin at the bottom-left corner of
the outer face, the outside faces -Y.

Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/facade.py -- <out.blend> <out.glb>
1 Blender unit = 1 meter, 64 px per meter: one 256 x 256 px texture (the
building size of constitution 2.3) covers 4 m.
"""

import math
import random
import sys

import bmesh
import bpy

NAME = "facade_hlm"
TEX_SIZE = 256
METERS_PER_TEXTURE = 4.0
SIZE = 3.0
THICKNESS = 0.2
WINDOW = (0.9, 1.0, 2.1, 2.4)  # x0, z0, x1, z1 of the opening.
RECESS = 0.12
# Atlas: concrete everywhere, except a dark glass square and a pale frame strip
# kept in the top right corner of the texture.
GLASS_REGION = (0.8, 0.8, 1.0, 1.0)
FRAME_REGION = (0.8, 0.7, 1.0, 0.78)


def make_texture():
    rng = random.Random(3)
    px = []
    for y in range(TEX_SIZE):
        row = []
        for x in range(TEX_SIZE):
            g = 0.47 + rng.uniform(-0.04, 0.04)
            if rng.random() < 0.03:
                g -= 0.1
            row.append([g, g * 0.99, g * 0.95])
        px.append(row)
    ppm = TEX_SIZE / METERS_PER_TEXTURE
    # Panel joints every 3 m (dark sealant lines), so repeated panels tile.
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            if int(x % (SIZE * ppm)) < 2 or int(y % (SIZE * ppm)) < 2:
                px[y][x] = [0.2, 0.2, 0.21]
    # Black run-off streaks under the window corners and random rain marks.
    sill_y = int(WINDOW[1] * ppm)
    for wx in (WINDOW[0], WINDOW[2], (WINDOW[0] + WINDOW[2]) / 2):
        x0 = int(wx * ppm)
        for dx in range(-3, 4):
            length = rng.randint(20, 55)
            for dy in range(length):
                y = sill_y - dy
                if 0 <= y < TEX_SIZE:
                    k = 1.0 - 0.35 * (1 - dy / length) * (1 - abs(dx) / 4)
                    c = px[y][(x0 + dx) % TEX_SIZE]
                    px[y][(x0 + dx) % TEX_SIZE] = [c[0] * k, c[1] * k, c[2] * k]
    for _ in range(25):
        x0, y0 = rng.randrange(TEX_SIZE), rng.randrange(TEX_SIZE)
        for dy in range(rng.randint(8, 30)):
            c = px[(y0 - dy) % TEX_SIZE][x0]
            px[(y0 - dy) % TEX_SIZE][x0] = [c[0] * 0.85, c[1] * 0.85, c[2] * 0.85]
    # Dark glass with a faint cold reflection, and a peeling pale frame paint.
    for y in range(int(GLASS_REGION[1] * TEX_SIZE), TEX_SIZE):
        for x in range(int(GLASS_REGION[0] * TEX_SIZE), TEX_SIZE):
            r = 0.05 + (0.05 if (x + y) % 23 < 3 else 0.0)
            px[y][x] = [r * 0.8, r * 0.9, r * 1.3]
    for y in range(int(FRAME_REGION[1] * TEX_SIZE), int(FRAME_REGION[3] * TEX_SIZE)):
        for x in range(int(FRAME_REGION[0] * TEX_SIZE), TEX_SIZE):
            g = 0.62 if rng.random() > 0.2 else 0.4
            px[y][x] = [g, g, g * 0.97]
    img = bpy.data.images.new(NAME + "_tex", TEX_SIZE, TEX_SIZE, alpha=False)
    img.pixels = [v for row in px for c in row for v in (c[0], c[1], c[2], 1.0)]
    img.pack()
    return img


def make_material(img):
    mat = bpy.data.materials.new(NAME + "_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def add_box(bm, x0, y0, z0, x1, y1, z1):
    before = set(bm.faces)
    box = bmesh.ops.create_cube(bm, size=1.0)
    for v in box["verts"]:
        v.co.x = x0 if v.co.x < 0 else x1
        v.co.y = y0 if v.co.y < 0 else y1
        v.co.z = z0 if v.co.z < 0 else z1
    return set(bm.faces) - before


def map_uv(bm, faces, region=None):
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            co = loop.vert.co
            if region:
                u = (co[a] - WINDOW[0]) / (WINDOW[2] - WINDOW[0]) if a == 0 else 0.5
                v = (co[b] - WINDOW[1]) / (WINDOW[3] - WINDOW[1]) if b == 2 else 0.5
                u = region[0] + min(max(u, 0), 1) * (region[2] - region[0])
                v = region[1] + min(max(v, 0), 1) * (region[3] - region[1])
                loop[uv].uv = (u, v)
            else:
                loop[uv].uv = (co[a] / METERS_PER_TEXTURE, co[b] / METERS_PER_TEXTURE)


def build():
    bm = bmesh.new()
    x0, z0, x1, z1 = WINDOW
    t = THICKNESS
    concrete = set()
    concrete |= add_box(bm, 0, 0, 0, SIZE, t, z0)  # Below the window.
    concrete |= add_box(bm, 0, 0, z1, SIZE, t, SIZE)  # Above.
    concrete |= add_box(bm, 0, 0, z0, x0, t, z1)  # Left.
    concrete |= add_box(bm, x1, 0, z0, SIZE, t, z1)  # Right.
    bar = 0.06  # Window frame bars, with a middle mullion.
    fy0, fy1 = RECESS - 0.03, RECESS
    mid = (x0 + x1) / 2
    frame = set()
    frame |= add_box(bm, x0, fy0, z0, x1, fy1, z0 + bar)
    frame |= add_box(bm, x0, fy0, z1 - bar, x1, fy1, z1)
    frame |= add_box(bm, x0, fy0, z0, x0 + bar, fy1, z1)
    frame |= add_box(bm, x1 - bar, fy0, z0, x1, fy1, z1)
    frame |= add_box(bm, mid - bar / 2, fy0, z0, mid + bar / 2, fy1, z1)
    sill = add_box(bm, x0 - 0.08, -0.08, z0 - 0.06, x1 + 0.08, 0.02, z0)
    glass = add_box(bm, x0, RECESS, z0, x1, RECESS + 0.02, z1)
    bm.normal_update()
    map_uv(bm, concrete | sill)
    map_uv(bm, frame, FRAME_REGION)
    map_uv(bm, glass, GLASS_REGION)
    mesh = bpy.data.meshes.new(NAME)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(NAME, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(make_material(make_texture()))
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if __name__ == "__main__":
    facade = build()
    print("TRIANGLES", triangle_count(facade))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", use_selection=False)
