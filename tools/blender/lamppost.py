"""Builds the sodium lamppost (S-005, T-033) in the open Blender scene.

Run inside Blender (Text editor or the MCP connector), or headless:
    blender --background --python tools/blender/lamppost.py -- <out.blend> <out.glb>
1 Blender unit = 1 meter (constitution 2.3). Target: about 150 triangles,
one 64 x 64 px texture with nearest filtering.
"""

import math
import random
import sys

import bmesh
import bpy

NAME = "lamppost_sodium"
POLE_HEIGHT = 5.0
POLE_SIDES = 6
TEX_SIZE = 64

# Texture atlas regions (u0, v0, u1, v1): paint, housing, glass.
PAINT = (0.0, 0.5, 1.0, 1.0)
HOUSING = (0.0, 0.0, 0.5, 0.5)
GLASS = (0.5, 0.0, 1.0, 0.5)


def make_texture():
    rng = random.Random(4)
    img = bpy.data.images.new(NAME + "_tex", TEX_SIZE, TEX_SIZE, alpha=False)
    px = []
    for y in range(TEX_SIZE):
        for x in range(TEX_SIZE):
            u, v = x / TEX_SIZE, y / TEX_SIZE
            if v >= 0.5:  # Faded green-grey paint with rust spots.
                g = 0.30 + rng.uniform(-0.03, 0.03)
                c = (g * 0.85, g, g * 0.9)
                if rng.random() < 0.06:
                    c = (0.32, 0.17, 0.08)
            elif u < 0.5:  # Dark housing.
                g = 0.16 + rng.uniform(-0.02, 0.02)
                c = (g, g, g * 1.05)
            else:  # Sodium glass, brighter in the middle.
                d = abs(u - 0.75) * 4 + abs(v - 0.25) * 4
                k = max(0.0, 1.0 - d * 0.5)
                c = (1.0, 0.55 + 0.15 * k, 0.18 + 0.1 * k)
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
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def fit_uv(bm, faces, region):
    """Box-projects faces and squeezes their UVs into an atlas region."""
    uv = bm.loops.layers.uv.verify()
    coords = []
    for f in faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
            coords.append((loop, co[a], co[b]))
    if not coords:
        return
    min_a = min(c[1] for c in coords)
    max_a = max(c[1] for c in coords)
    min_b = min(c[2] for c in coords)
    max_b = max(c[2] for c in coords)
    u0, v0, u1, v1 = region
    for loop, a, b in coords:
        ua = (a - min_a) / max(max_a - min_a, 1e-4)
        vb = (b - min_b) / max(max_b - min_b, 1e-4)
        loop[uv].uv = (u0 + ua * (u1 - u0), v0 + vb * (v1 - v0))


def build():
    bm = bmesh.new()
    # Concrete-capped plinth, then a tapered hexagonal pole.
    base = bmesh.ops.create_cone(
        bm, cap_ends=True, segments=POLE_SIDES, radius1=0.16, radius2=0.14, depth=0.5
    )
    bmesh.ops.translate(bm, verts=base["verts"], vec=(0, 0, 0.25))
    pole = bmesh.ops.create_cone(
        bm, cap_ends=True, segments=POLE_SIDES, radius1=0.08, radius2=0.05,
        depth=POLE_HEIGHT - 0.5,
    )
    bmesh.ops.translate(bm, verts=pole["verts"], vec=(0, 0, 0.5 + (POLE_HEIGHT - 0.5) / 2))
    paint = set(bm.faces)
    # Arm: three short segments bending forward (+Y) from the top.
    arm_faces = set()
    pts = [(0, 0, POLE_HEIGHT - 0.1), (0, 0.35, POLE_HEIGHT + 0.12), (0, 0.85, POLE_HEIGHT + 0.2),
           (0, 1.25, POLE_HEIGHT + 0.12)]
    for p, q in zip(pts, pts[1:]):
        before = set(bm.faces)
        seg = bmesh.ops.create_cube(bm, size=1.0)
        dx, dy, dz = q[0] - p[0], q[1] - p[1], q[2] - p[2]
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        for v in seg["verts"]:
            v.co.x *= 0.06
            v.co.z *= 0.06
            v.co.y *= length
        angle = math.atan2(dz, dy)
        bmesh.ops.rotate(bm, verts=seg["verts"], cent=(0, 0, 0),
                         matrix=__import__("mathutils").Matrix.Rotation(angle, 3, "X"))
        bmesh.ops.translate(bm, verts=seg["verts"],
                            vec=((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2))
        arm_faces |= set(bm.faces) - before
    paint |= arm_faces
    # Cobra head housing, tilted slightly down, with the glass underneath.
    before = set(bm.faces)
    head = bmesh.ops.create_cube(bm, size=1.0)
    for v in head["verts"]:
        v.co.x *= 0.32
        v.co.y *= 0.62
        v.co.z *= 0.16
        if v.co.z > 0:
            v.co.x *= 0.7
            v.co.y *= 0.85
    bmesh.ops.translate(bm, verts=head["verts"], vec=(0, 1.45, POLE_HEIGHT + 0.06))
    head_faces = set(bm.faces) - before
    bm.normal_update()
    glass = {f for f in head_faces if f.normal.z < -0.9}
    housing = head_faces - glass
    fit_uv(bm, paint, PAINT)
    fit_uv(bm, housing, HOUSING)
    fit_uv(bm, glass, GLASS)
    mesh = bpy.data.meshes.new(NAME)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new(NAME, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(make_material(make_texture()))
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if __name__ == "__main__":
    lamppost = build()
    print("TRIANGLES", triangle_count(lamppost))
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args:
        bpy.ops.wm.save_as_mainfile(filepath=args[0])
    if len(args) > 1:
        bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", use_selection=False)
