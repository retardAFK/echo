"""Builds the concrete and wood benches (S-005, T-034) in the open Blender scene.

Two variants, as asked by Maxime: "dirty" (dirty but intact) and "broken"
(filthy, a missing slat, a snapped backrest slat and a chipped leg).

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
VARIANTS = ("dirty", "broken")
TEX_SIZE = 64
LENGTH = 1.8
SEAT_HEIGHT = 0.45

# Texture atlas regions (u0, v0, u1, v1): concrete, wood.
CONCRETE = (0.0, 0.0, 1.0, 0.5)
WOOD = (0.0, 0.5, 1.0, 1.0)


def make_texture(variant):
    rng = random.Random(9)
    grime = 0.7 if variant == "dirty" else 1.0
    img = bpy.data.images.new("%s_%s_tex" % (NAME, variant), TEX_SIZE, TEX_SIZE, alpha=False)
    # Dark blotches shared by concrete and wood.
    blotches = [(rng.randrange(TEX_SIZE), rng.randrange(TEX_SIZE), rng.uniform(3, 9)) for _ in range(int(26 * grime))]
    px = []
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            if y < TEX_SIZE // 2:  # Stained concrete.
                g = 0.42 + rng.uniform(-0.05, 0.05)
                if rng.random() < 0.05:
                    g -= 0.12
                c = [g, g, g * 0.96]
                if y < 6 + 6 * grime and rng.random() < 0.5 * grime:  # Moss at the foot.
                    c = [c[0] * 0.75, c[1] * 0.95, c[2] * 0.6]
            else:  # Weathered wood, grain along x, worn planks.
                stripe = 0.04 if (y // 2) % 3 == 0 else 0.0
                g = 0.30 + stripe + rng.uniform(-0.03, 0.03)
                if y % 8 == 0:
                    g -= 0.1  # Gap between planks.
                c = [g * 1.15, g * 0.9, g * 0.62]
            for bx, by, r in blotches:
                d = ((x - bx) ** 2 + (y - by) ** 2) ** 0.5
                if d < r:
                    k = 1.0 - 0.6 * grime * (1.0 - d / r)
                    c = [c[0] * k, c[1] * k, c[2] * k * 0.95]
            px += [c[0], c[1], c[2], 1.0]
    img.pixels = px
    img.pack()
    return img


def make_material(img, variant):
    mat = bpy.data.materials.new("%s_%s_mat" % (NAME, variant))
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def add_box(bm, center, size, tilt=0.0, axis="X"):
    before = set(bm.faces)
    box = bmesh.ops.create_cube(bm, size=1.0)
    for v in box["verts"]:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if tilt:
        import mathutils

        bmesh.ops.rotate(
            bm, verts=box["verts"], cent=(0, 0, 0), matrix=mathutils.Matrix.Rotation(tilt, 3, axis)
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


def build(variant, offset_x=0.0):
    broken = variant == "broken"
    bm = bmesh.new()
    concrete = set()
    wood = set()
    for side, x in enumerate((-LENGTH / 2 + 0.2, LENGTH / 2 - 0.2)):
        if broken and side == 1:  # Chipped leg: shorter block and a fallen chunk.
            concrete |= add_box(bm, (x, 0.05, 0.19), (0.14, 0.4, 0.38))
            concrete |= add_box(bm, (x + 0.25, 0.32, 0.05), (0.12, 0.1, 0.1), tilt=0.6)
        else:
            concrete |= add_box(bm, (x, 0.0, SEAT_HEIGHT / 2 - 0.02), (0.14, 0.5, SEAT_HEIGHT - 0.04))
        concrete |= add_box(bm, (x, -0.24, 0.62), (0.12, 0.1, 0.36))  # Backrest post.
    for y in (-0.16, 0.0, 0.16):
        if broken and y == 0.0:
            continue  # Missing slat.
        if broken and y == 0.16:  # Front slat snapped, sagging on the chipped leg.
            wood |= add_box(bm, (-0.45, y, SEAT_HEIGHT + 0.02), (0.9, 0.13, 0.04))
            wood |= add_box(bm, (0.42, y, SEAT_HEIGHT - 0.03), (0.86, 0.13, 0.04))
            continue
        wood |= add_box(bm, (0.0, y, SEAT_HEIGHT + 0.02), (LENGTH, 0.13, 0.04))
    for z in (0.62, 0.76):
        if broken and z == 0.76:  # Top backrest slat hangs from one post.
            wood |= add_box(bm, (-0.42, -0.31, 0.55), (0.8, 0.04, 0.11), tilt=0.45, axis="Y")
            continue
        wood |= add_box(bm, (0.0, -0.3, z), (LENGTH, 0.04, 0.11), tilt=-0.15)
    bm.normal_update()
    fit_uv(bm, concrete, CONCRETE)
    fit_uv(bm, wood, WOOD)
    mesh = bpy.data.meshes.new("%s_%s" % (NAME, variant))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("%s_%s" % (NAME, variant), mesh)
    obj.location.x = offset_x
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(make_material(make_texture(variant), variant))
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if __name__ == "__main__":
    for i, variant in enumerate(VARIANTS):
        bench = build(variant, offset_x=i * 2.5)
        print("TRIANGLES", variant, triangle_count(bench))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", use_selection=False)
