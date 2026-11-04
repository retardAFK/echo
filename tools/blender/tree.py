"""Builds the bare winter tree (S-005, T-035) in the open Blender scene.

Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/tree.py -- <out.blend> <out.glb>
1 Blender unit = 1 meter. Target: about 400 triangles, no leaves (cheaper and
more unsettling). One 64 x 64 px bark texture, nearest filtering.
"""

import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

NAME = "tree_bare"
TEX_SIZE = 64
SEED = 5
TRUNK_HEIGHT = 2.6
TRUNK_RADIUS = 0.16
DEPTH = 3  # Branching levels after the trunk.
MAIN_BRANCHES = 4
SIDES = 4  # Sides of each branch prism (the trunk has 6).


def make_texture():
    rng = random.Random(SEED)
    img = bpy.data.images.new(NAME + "_tex", TEX_SIZE, TEX_SIZE, alpha=False)
    px = []
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            g = 0.2 + rng.uniform(-0.03, 0.03)
            if x % 5 == 0 or (x + y // 6) % 9 == 0:
                g -= 0.07  # Vertical bark furrows.
            if y < 8 and rng.random() < 0.4:  # Damp moss at the foot.
                px += [g * 0.8, g * 1.05, g * 0.6, 1.0]
                continue
            px += [g * 1.05, g * 0.95, g * 0.85, 1.0]
    img.pixels = px
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
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def add_limb(bm, uv, base, direction, length, r0, r1, sides):
    """A tapered open prism from base along direction, UVs wrapped around it."""
    direction = direction.normalized()
    side = direction.orthogonal().normalized()
    rings = []
    for center, radius in ((base, r0), (base + direction * length, r1)):
        ring = []
        for i in range(sides):
            rot = Matrix.Rotation(2 * math.pi * i / sides, 3, direction)
            ring.append(bm.verts.new(center + rot @ side * radius))
        rings.append(ring)
    v_top = length * 1.0  # About 64 px per meter vertically.
    for i in range(sides):
        j = (i + 1) % sides
        face = bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
        for loop, (u, v) in zip(face.loops, ((i, 0), (i + 1, 0), (i + 1, v_top), (i, v_top))):
            loop[uv].uv = (u / sides, v)
    return base + direction * length


def grow(bm, uv, rng, base, direction, length, radius, level):
    tip = add_limb(bm, uv, base, direction, length, radius, radius * 0.6, SIDES)
    if level == 0:
        return
    for _ in range(3 if level == 1 else 2):
        tilt = Matrix.Rotation(rng.uniform(0.45, 0.9), 3, direction.orthogonal())
        spin = Matrix.Rotation(rng.uniform(0, 2 * math.pi), 3, direction)
        child = spin @ tilt @ direction
        child.z = max(child.z, 0.15)  # Branches reach up, a little twisted.
        grow(bm, uv, rng, tip, child, length * rng.uniform(0.55, 0.75), radius * 0.6, level - 1)


def build():
    rng = random.Random(SEED)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    lean = Vector((0.08, 0.04, 1.0))
    top = add_limb(bm, uv, Vector((0, 0, 0)), lean, TRUNK_HEIGHT, TRUNK_RADIUS, TRUNK_RADIUS * 0.7, 6)
    for i in range(MAIN_BRANCHES):
        spin = Matrix.Rotation(2 * math.pi * i / MAIN_BRANCHES + rng.uniform(-0.3, 0.3), 3, Vector((0, 0, 1)))
        direction = spin @ Vector((0.7, 0, 1.0))
        grow(bm, uv, rng, top, direction, 1.5, TRUNK_RADIUS * 0.55, DEPTH - 1)
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
    tree = build()
    print("TRIANGLES", triangle_count(tree))
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", use_selection=False)
