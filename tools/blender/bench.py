"""Builds the concrete and wood bench (S-005, T-034) in the open Blender scene.

Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/bench.py -- <out.blend> <out.glb>
1 Blender unit = 1 meter (constitution 2.3). Target: about 120 triangles,
one 64 x 64 px texture with nearest filtering. The seat faces +Y.
"""

import random
import sys

import bmesh
import bpy

NAME = "bench_concrete"
TEX_SIZE = 64
LENGTH = 1.8
SEAT_HEIGHT = 0.45

# Texture atlas regions (u0, v0, u1, v1): concrete, wood.
CONCRETE = (0.0, 0.0, 1.0, 0.5)
WOOD = (0.0, 0.5, 1.0, 1.0)


def make_texture():
    rng = random.Random(9)
    img = bpy.data.images.new(NAME + "_tex", TEX_SIZE, TEX_SIZE, alpha=False)
    px = []
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            if y < TEX_SIZE // 2:  # Stained concrete.
                g = 0.42 + rng.uniform(-0.05, 0.05)
                if rng.random() < 0.05:
                    g -= 0.12
                c = (g, g, g * 0.96)
            else:  # Weathered wood, grain along x, worn planks.
                stripe = 0.04 if (y // 2) % 3 == 0 else 0.0
                g = 0.30 + stripe + rng.uniform(-0.03, 0.03)
                if y % 8 == 0:
                    g -= 0.1  # Gap between planks.
                c = (g * 1.15, g * 0.9, g * 0.62)
            px += [c[0], c[1], c[2], 1.0]
    img.pixels = px
    img.pack()
    return img


def make_material(img):
    mat = bpy.data.materials.new(NAME + "_mat")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def add_box(bm, center, size, tilt=0.0):
    before = set(bm.faces)
    box = bmesh.ops.create_cube(bm, size=1.0)
    for v in box["verts"]:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if tilt:
        import mathutils

        bmesh.ops.rotate(
            bm, verts=box["verts"], cent=(0, 0, 0), matrix=mathutils.Matrix.Rotation(tilt, 3, "X")
        )
    bmesh.ops.translate(bm, verts=box["verts"], vec=center)
    return set(bm.faces) - before


def fit_uv(bm, faces, region):
    """Box-projects each face and squeezes it into an atlas region (1 m = full width)."""
    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = region
    for f in faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            co = loop.vert.co
            ua = (co[a] / LENGTH) % 1.0 if a == 0 else (co[a] * 2.0) % 1.0
            vb = (co[b] * 2.0) % 1.0
            loop[uv].uv = (u0 + ua * (u1 - u0), v0 + vb * (v1 - v0))


def build():
    bm = bmesh.new()
    concrete = set()
    wood = set()
    for x in (-LENGTH / 2 + 0.2, LENGTH / 2 - 0.2):
        concrete |= add_box(bm, (x, 0.0, SEAT_HEIGHT / 2 - 0.02), (0.14, 0.5, SEAT_HEIGHT - 0.04))
        concrete |= add_box(bm, (x, -0.24, 0.62), (0.12, 0.1, 0.36))  # Backrest post.
    for i, y in enumerate((-0.16, 0.0, 0.16)):
        wood |= add_box(bm, (0.0, y, SEAT_HEIGHT + 0.02), (LENGTH, 0.13, 0.04))
    for z in (0.62, 0.76):
        wood |= add_box(bm, (0.0, -0.3, z), (LENGTH, 0.04, 0.11), tilt=-0.15)
    bm.normal_update()
    fit_uv(bm, concrete, CONCRETE)
    fit_uv(bm, wood, WOOD)
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
    bench = build()
    print("TRIANGLES", triangle_count(bench))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", use_selection=False)
