"""Builds the concrete benches (S-005, T-034) in the open Blender scene.

Maxime's choice (04/11/2026): all concrete, stained and tagged, in two
variants: "dirty" (dirty but intact) and "broken" (filthy and broken, with
rusty rebar showing). Tags use dull colors only: orange is the noise color
(constitution 2.3).

Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/bench.py -- <out.blend> <out.glb>
1 Blender unit = 1 meter. About 64 texture pixels per meter: one 128 x 128 px
texture covers 2 m. The seat faces +Y.
"""

import math
import random
import sys

import bmesh
import bpy
import mathutils

NAME = "bench_concrete"
VARIANTS = ("dirty", "broken")
TEX_SIZE = 128
METERS_PER_TEXTURE = 2.0
LENGTH = 1.8
SEAT_HEIGHT = 0.45
# Tag colors: dull black, blue, dark red, dirty white. Never orange.
TAG_COLORS = ((0.06, 0.06, 0.07), (0.12, 0.17, 0.36), (0.38, 0.08, 0.09), (0.7, 0.7, 0.66))
RUST = (0.3, 0.14, 0.06)
# Rust lives in a small corner of the texture, used by the rebar only.
RUST_REGION = (0.0, 0.0, 4 / TEX_SIZE, 4 / TEX_SIZE)


def _draw_tag(px, rng, color, x0, y0):
    """A scribbled tag: a few thick random strokes, like a signature."""
    x, y = x0, y0
    heading = rng.uniform(-0.4, 0.4)
    for _ in range(rng.randint(50, 90)):
        heading += rng.uniform(-1.2, 1.2)
        x += math.cos(heading) * 1.2
        y += math.sin(heading) * 0.9
        for dx in (0, 1):
            ix, iy = int(x + dx) % TEX_SIZE, int(y) % TEX_SIZE
            if ix < 6 and iy < 6:
                continue  # Keep the rust corner clean.
            px[iy][ix] = color


def make_texture(variant):
    rng = random.Random(21 if variant == "dirty" else 37)
    grime = 0.6 if variant == "dirty" else 1.0
    px = []
    for y in range(TEX_SIZE):
        row = []
        for x in range(TEX_SIZE):
            g = 0.44 + rng.uniform(-0.05, 0.05)
            if rng.random() < 0.04:
                g -= 0.14  # Pores and gravel.
            row.append([g, g, g * 0.96])
        px.append(row)
    # Run-off stains and dark blotches.
    for _ in range(int(30 * grime)):
        bx, by, r = rng.randrange(TEX_SIZE), rng.randrange(TEX_SIZE), rng.uniform(4, 14)
        for y in range(int(by - r), int(by + r)):
            for x in range(int(bx - r), int(bx + r)):
                d = math.hypot(x - bx, (y - by) * 0.6)
                if d < r:
                    k = 1.0 - 0.5 * grime * (1.0 - d / r)
                    c = px[y % TEX_SIZE][x % TEX_SIZE]
                    px[y % TEX_SIZE][x % TEX_SIZE] = [c[0] * k, c[1] * k, c[2] * k * 0.97]
    # Moss along the bottom rows (the bottom of every face maps there).
    for y in range(int(10 * grime)):
        for x in range(TEX_SIZE):
            if rng.random() < 0.6 * grime * (1 - y / 12):
                c = px[y][x]
                px[y][x] = [c[0] * 0.7, c[1] * 0.92, c[2] * 0.55]
    # Tags.
    for _ in range(5 if variant == "dirty" else 8):
        color = list(TAG_COLORS[rng.randrange(len(TAG_COLORS))])
        _draw_tag(px, rng, color, rng.uniform(10, 100), rng.uniform(14, 58))
    # Cracks on the broken bench.
    if variant == "broken":
        for _ in range(5):
            x, y = rng.uniform(0, TEX_SIZE), rng.uniform(0, TEX_SIZE)
            for _ in range(40):
                x += rng.uniform(-1, 1)
                y += 1
                c = px[int(y) % TEX_SIZE][int(x) % TEX_SIZE]
                px[int(y) % TEX_SIZE][int(x) % TEX_SIZE] = [c[0] * 0.45, c[1] * 0.45, c[2] * 0.45]
    for y in range(4):
        for x in range(4):
            px[y][x] = list(RUST)
    img = bpy.data.images.new("%s_%s_tex" % (NAME, variant), TEX_SIZE, TEX_SIZE, alpha=False)
    img.pixels = [v for row in px for c in row for v in (c[0], c[1], c[2], 1.0)]
    img.pack()
    return img


def make_material(img, variant):
    mat = bpy.data.materials.new("%s_%s_mat" % (NAME, variant))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return mat


def add_box(bm, center, size, tilt=0.0, axis="X"):
    before = set(bm.faces)
    box = bmesh.ops.create_cube(bm, size=1.0)
    for v in box["verts"]:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if tilt:
        rot = mathutils.Matrix.Rotation(tilt, 3, axis)
        bmesh.ops.rotate(bm, verts=box["verts"], cent=(0, 0, 0), matrix=rot)
    bmesh.ops.translate(bm, verts=box["verts"], vec=center)
    return set(bm.faces) - before


def map_uv(bm, faces, region=None):
    """World-scale box projection (64 px per meter), or a fixed atlas corner."""
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        axis = max(range(3), key=lambda i: abs(f.normal[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            if region:
                loop[uv].uv = ((region[0] + region[2]) / 2, (region[1] + region[3]) / 2)
                continue
            co = loop.vert.co
            loop[uv].uv = (co[a] / METERS_PER_TEXTURE + 0.5, co[b] / METERS_PER_TEXTURE + 0.05)


def build(variant, offset_x=0.0):
    broken = variant == "broken"
    bm = bmesh.new()
    concrete = set()
    rebar = set()
    legs = (-LENGTH / 2 + 0.22, LENGTH / 2 - 0.22)
    for side, x in enumerate(legs):
        if broken and side == 1:  # Leg cracked off: a stump and a fallen block.
            concrete |= add_box(bm, (x, 0.0, 0.1), (0.2, 0.5, 0.2))
            concrete |= add_box(bm, (x + 0.35, 0.35, 0.1), (0.2, 0.22, 0.2), tilt=0.5, axis="Z")
            rebar |= add_box(bm, (x - 0.05, 0.1, 0.27), (0.02, 0.02, 0.16), tilt=0.3, axis="Y")
        else:
            concrete |= add_box(bm, (x, 0.0, SEAT_HEIGHT / 2 - 0.04), (0.2, 0.5, SEAT_HEIGHT - 0.08))
        concrete |= add_box(bm, (x, -0.22, 0.66), (0.18, 0.1, 0.4))  # Backrest post.
    if broken:  # Seat slab snapped in two, one half dropped onto the stump.
        concrete |= add_box(bm, (-0.42, 0.0, SEAT_HEIGHT - 0.04), (0.96, 0.52, 0.08))
        concrete |= add_box(bm, (0.46, 0.02, 0.3), (0.86, 0.52, 0.08), tilt=-0.32, axis="Y")
        rebar |= add_box(bm, (0.06, 0.1, SEAT_HEIGHT - 0.05), (0.18, 0.02, 0.02))
        rebar |= add_box(bm, (0.06, -0.1, SEAT_HEIGHT - 0.06), (0.14, 0.02, 0.02))
        # Backrest slab with a chunk missing at one end.
        concrete |= add_box(bm, (-0.2, -0.26, 0.76), (1.4, 0.09, 0.42), tilt=-0.12)
        rebar |= add_box(bm, (0.56, -0.26, 0.84), (0.14, 0.02, 0.02))
    else:
        concrete |= add_box(bm, (0.0, 0.0, SEAT_HEIGHT - 0.04), (LENGTH, 0.52, 0.08))
        concrete |= add_box(bm, (0.0, -0.26, 0.76), (LENGTH, 0.09, 0.42), tilt=-0.12)
    bm.normal_update()
    map_uv(bm, concrete)
    map_uv(bm, rebar, RUST_REGION)
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
