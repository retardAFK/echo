"""The Versus arcade guns (spec S-025, T-409): light machine gun, precision
flare rifle, sonic shotgun, and the assault rifle (T-413). Chunky, bright, toy-like shapes (an arcade
shooter, not horror), low poly with small bevels. Each gun is exported as a
glTF to assets/models/versus/<id>.glb and rendered for review.

Conventions, read by game/modes/versus/gun_model.gd:
- Blender +Y is the muzzle's direction (glTF -Z, Godot forward), +Z up, and
  the origin is where the right hand holds the grip.
- One flat color per material. The material named "glow" takes the color of
  the gun's rarity in the game (VersusRarity); the others keep their color.
- An empty named "muzzle" marks the end of the barrel (where tracers start).

Run (bpy from pip, see tools/blender/README or the asset pipeline notes):
  python tools/blender/versus_guns.py <render_dir> [export_dir] [gun_id]
"""

import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/versus_guns"
EXPORT = sys.argv[2] if len(sys.argv) > 2 else None
X90 = (math.pi / 2, 0, 0)

## Glow colors of the four rarities (game/modes/versus/data/rarities/), for
## the renders only; the game tints "glow" itself.
RARITY = {
    "commune": (0.75, 0.78, 0.8),
    "rare": (0.2, 0.55, 1.0),
    "epique": (0.7, 0.25, 1.0),
    "legendaire": (1.0, 0.72, 0.15),
    "base": (0.4, 1.0, 0.95),
}

_mats = {}


def reset():
    _mats.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = 48
    s.cycles.device = "CPU"
    s.render.resolution_x, s.render.resolution_y = 960, 600
    w = bpy.data.worlds.new("w")
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.62, 0.9, 1)  # Day sky.
    bg.inputs[1].default_value = 0.7
    s.view_settings.view_transform = "Standard"  # Bright toy colors, unwashed.
    s.view_settings.exposure = -0.6


def mat(name, color, rough=0.5, metal=0.0, emit=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*color, 1)  # Exported as the glTF base color.
    _mats[name] = m
    return m


def glow(color):
    return mat("glow", color, 0.3, 0.0, 1.2)


def finish(o, m, bevel=0.0):
    o.data.materials.append(m)
    if bevel:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 1
        b.limit_method = "ANGLE"
    o.select_set(False)
    return o


def box(loc, size, m, rot=(0, 0, 0), bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def cyl(loc, r, depth, m, verts=12, r2=None, bevel=0.003):
    """A cylinder (or cone to r2) along +Y."""
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=verts, radius=r, depth=depth, location=loc, rotation=X90
        )
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=X90
        )
    # The cylinder points -Y after X90; turn its cone's wide end backwards.
    return finish(bpy.context.object, m, bevel)


def muzzle(y, z):
    bpy.ops.object.empty_add(location=(0, y, z))
    bpy.context.object.name = "muzzle"


def light_smg(color):
    """Compact, white shell, cyan strip, orange grip: friendly and quick."""
    shell = mat("shell", (0.88, 0.9, 0.92), 0.35)
    dark = mat("dark", (0.1, 0.11, 0.14), 0.6)
    accent = mat("accent", (1.0, 0.42, 0.08), 0.45)
    lit = glow(color)
    z = 0.075
    box((0, 0.1, z), (0.07, 0.3, 0.085), shell, bevel=0.018)  # Receiver.
    box((0, 0.05, z + 0.03), (0.074, 0.12, 0.04), shell, bevel=0.014)  # Upper hump.
    box((0, 0.13, z + 0.046), (0.03, 0.2, 0.012), lit, bevel=0.003)  # Top strip.
    for side in (-1, 1):
        box((side * 0.036, 0.12, z), (0.004, 0.16, 0.02), lit, bevel=0)  # Side strips.
    cyl((0, 0.29, z), 0.022, 0.1, dark)  # Barrel shroud.
    cyl((0, 0.345, z), 0.028, 0.02, lit)  # Muzzle ring.
    box((0, 0.0, -0.01), (0.044, 0.05, 0.11), accent, rot=(-0.25, 0, 0), bevel=0.012)  # Grip.
    box((0, 0.13, -0.02), (0.04, 0.045, 0.13), dark, rot=(0.15, 0, 0), bevel=0.008)  # Mag.
    box((0, 0.13, -0.08), (0.044, 0.05, 0.016), accent, rot=(0.15, 0, 0), bevel=0.004)
    box((0, -0.09, z - 0.005), (0.05, 0.08, 0.06), dark, bevel=0.012)  # Stub stock.
    box((0, 0.05, 0.016), (0.012, 0.05, 0.03), dark, bevel=0.003)  # Trigger guard.
    box((0, 0.03, z + 0.062), (0.02, 0.03, 0.02), dark, bevel=0.004)  # Sight.
    box((0, 0.03, z + 0.075), (0.008, 0.008, 0.008), lit, bevel=0)  # Sight dot.
    muzzle(0.36, z)


def precision_rifle(color):
    """Long, navy and orange, a big glowing scope: the sniper's toy."""
    body = mat("body", (0.1, 0.16, 0.34), 0.4)
    accent = mat("accent", (1.0, 0.45, 0.08), 0.45)
    dark = mat("dark", (0.08, 0.08, 0.1), 0.6)
    cream = mat("cream", (0.92, 0.88, 0.8), 0.5)
    lit = glow(color)
    z = 0.07
    box((0, 0.12, z), (0.06, 0.42, 0.08), body, bevel=0.016)  # Receiver.
    cyl((0, 0.5, z + 0.005), 0.018, 0.4, dark)  # Barrel.
    cyl((0, 0.39, z + 0.005), 0.032, 0.14, accent)  # Flare chamber.
    for y in (0.33, 0.45):
        cyl((0, y, z + 0.005), 0.035, 0.012, lit)
    cyl((0, 0.71, z + 0.005), 0.03, 0.05, accent)  # Muzzle brake.
    cyl((0, 0.738, z + 0.005), 0.022, 0.008, lit)
    cyl((0, 0.14, z + 0.085), 0.03, 0.24, dark, verts=14)  # Scope.
    cyl((0, 0.265, z + 0.085), 0.038, 0.03, dark, verts=14)
    cyl((0, 0.281, z + 0.085), 0.03, 0.004, lit, verts=14, bevel=0)  # Lens.
    cyl((0, 0.016, z + 0.085), 0.034, 0.02, cream, verts=14)
    for y in (0.08, 0.2):
        box((0, y, z + 0.05), (0.024, 0.03, 0.03), dark, bevel=0.004)  # Mounts.
    box((0, 0.12, z - 0.016), (0.064, 0.3, 0.012), lit, bevel=0)  # Belly strip.
    box((0, 0.0, -0.01), (0.042, 0.05, 0.11), dark, rot=(-0.3, 0, 0), bevel=0.01)  # Grip.
    box((0, -0.19, z - 0.01), (0.05, 0.22, 0.07), body, rot=(0.06, 0, 0), bevel=0.016)  # Stock.
    box((0, -0.3, z - 0.015), (0.056, 0.03, 0.1), accent, bevel=0.01)  # Butt pad.
    box((0, -0.12, z + 0.035), (0.04, 0.1, 0.02), cream, bevel=0.006)  # Cheek rest.
    box((0, 0.17, -0.01), (0.036, 0.04, 0.08), dark, rot=(0.2, 0, 0), bevel=0.006)  # Mag.
    box((0, 0.05, 0.02), (0.012, 0.05, 0.03), dark, bevel=0.003)
    muzzle(0.75, z + 0.005)


def sonic_shotgun(color):
    """Chunky, yellow, a speaker bell for a muzzle with rings that glow."""
    yellow = mat("yellow", (1.0, 0.78, 0.1), 0.4)
    dark = mat("dark", (0.09, 0.09, 0.11), 0.6)
    grey = mat("grey", (0.55, 0.57, 0.6), 0.35, 0.6)
    lit = glow(color)
    z = 0.075
    box((0, 0.1, z), (0.085, 0.32, 0.1), yellow, bevel=0.022)  # Body.
    box((0, 0.02, z + 0.055), (0.05, 0.12, 0.03), dark, bevel=0.01)  # Battery.
    for x in (-0.012, 0.012):
        box((x, 0.02, z + 0.072), (0.008, 0.09, 0.006), lit, bevel=0)
    cyl((0, 0.31, z), 0.034, 0.12, dark)  # Neck.
    cyl((0, 0.41, z), 0.09, 0.1, grey, verts=16, r2=0.04)  # Bell (wide end forward).
    for i, y in enumerate((0.27, 0.3, 0.33)):
        cyl((0, y, z), 0.045 + i * 0.004, 0.012, lit)  # Rings.
    cyl((0, 0.462, z), 0.088, 0.008, lit, verts=16, bevel=0)  # Bell rim.
    cyl((0, 0.455, z), 0.05, 0.01, dark, verts=16, bevel=0)  # Speaker cone.
    box((0, 0.22, z - 0.065), (0.06, 0.12, 0.05), dark, bevel=0.012)  # Pump.
    for y in (0.19, 0.22, 0.25):
        box((0, y, z - 0.065), (0.064, 0.008, 0.054), grey, bevel=0)
    box((0, 0.0, -0.015), (0.048, 0.055, 0.12), dark, rot=(-0.28, 0, 0), bevel=0.012)  # Grip.
    box((0, -0.1, z - 0.01), (0.07, 0.1, 0.085), yellow, bevel=0.02)  # Stock.
    box((0, -0.155, z - 0.01), (0.075, 0.02, 0.095), dark, bevel=0.006)
    box((0, 0.05, 0.018), (0.012, 0.05, 0.03), dark, bevel=0.003)
    muzzle(0.47, z)


def assault_rifle(color):
    """Mid-length, coral and graphite, a red dot sight to aim down (T-413)."""
    coral = mat("coral", (0.95, 0.3, 0.26), 0.4)
    dark = mat("dark", (0.12, 0.13, 0.16), 0.55)
    grey = mat("grey", (0.62, 0.64, 0.68), 0.35, 0.5)
    lens = mat("lens", (1.0, 0.15, 0.1), 0.2, 0.0, 2.0)
    lit = glow(color)
    z = 0.075
    box((0, 0.08, z), (0.064, 0.3, 0.08), coral, bevel=0.016)  # Receiver.
    box((0, 0.06, z + 0.046), (0.03, 0.22, 0.014), dark, bevel=0.003)  # Top rail.
    box((0, 0.33, z), (0.07, 0.22, 0.07), dark, bevel=0.014)  # Handguard.
    for y in (0.27, 0.32, 0.37):
        for side in (-1, 1):
            box((side * 0.036, y, z), (0.004, 0.03, 0.014), lit, bevel=0)  # Vents.
    box((0, 0.33, z + 0.036), (0.022, 0.2, 0.006), lit, bevel=0)  # Top glow strip.
    cyl((0, 0.5, z), 0.016, 0.14, grey)  # Barrel.
    cyl((0, 0.575, z), 0.026, 0.04, dark)  # Flash hider.
    cyl((0, 0.597, z), 0.02, 0.006, lit, bevel=0)
    # Red dot sight: a short tube on the rail, its lens glowing red.
    box((0, 0.06, z + 0.062), (0.04, 0.06, 0.018), dark, bevel=0.004)
    cyl((0, 0.06, z + 0.095), 0.024, 0.07, dark, verts=14)
    cyl((0, 0.097, z + 0.095), 0.018, 0.004, lens, verts=14, bevel=0)
    cyl((0, 0.024, z + 0.095), 0.026, 0.008, lit, verts=14, bevel=0)
    # A long curved magazine, in two tilted pieces.
    box((0, 0.15, 0.005), (0.038, 0.062, 0.1), dark, rot=(0.15, 0, 0), bevel=0.008)
    box((0, 0.165, -0.065), (0.038, 0.062, 0.07), dark, rot=(0.4, 0, 0), bevel=0.008)
    box((0, 0.18, -0.1), (0.042, 0.066, 0.016), coral, rot=(0.4, 0, 0), bevel=0.004)
    box((0, 0.0, -0.01), (0.042, 0.05, 0.11), dark, rot=(-0.28, 0, 0), bevel=0.01)  # Grip.
    box((0, 0.05, 0.018), (0.012, 0.05, 0.03), dark, bevel=0.003)  # Trigger guard.
    box((0, -0.13, z - 0.005), (0.05, 0.16, 0.06), dark, bevel=0.012)  # Stock.
    box((0, -0.22, z - 0.02), (0.056, 0.03, 0.1), coral, bevel=0.01)  # Butt pad.
    box((0, 0.36, z - 0.06), (0.03, 0.04, 0.07), dark, rot=(-0.15, 0, 0), bevel=0.006)  # Fore grip.
    muzzle(0.6, z)


GUNS = {
    "light_smg": (light_smg, 1.0, "base", 0.12),
    "precision_rifle": (precision_rifle, 1.8, "legendaire", 0.22),
    "sonic_shotgun": (sonic_shotgun, 1.3, "epique", 0.17),
    "assault_rifle": (assault_rifle, 1.5, "rare", 0.18),
}


def stage(dist, target=(0, 0.15, 0.04), yaw=25, height=0.3):
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -0.09))
    finish(bpy.context.object, mat("floor", (0.55, 0.5, 0.62), 0.8))
    d = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), height)).normalized()
    bpy.ops.object.camera_add(location=Vector(target) + d * dist)
    c = bpy.context.object
    c.rotation_euler = (Vector(target) - c.location).to_track_quat("-Z", "Y").to_euler()
    c.data.lens = 55
    bpy.context.scene.camera = c
    bpy.ops.object.light_add(type="SUN", rotation=(0.7, 0.2, -0.6))
    bpy.context.object.data.energy = 3.0
    bpy.context.object.data.color = (1.0, 0.95, 0.85)
    bpy.ops.object.light_add(type="AREA", location=(-0.8, 0.6, 0.8))
    area = bpy.context.object
    area.data.energy = 40
    area.data.size = 1.5
    area.rotation_euler = (Vector(target) - area.location).to_track_quat("-Z", "Y").to_euler()


def render(name):
    bpy.context.scene.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)


def tris():
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.name.startswith("Plane"):
            e = o.evaluated_get(dg)
            m = e.to_mesh()
            m.calc_loop_triangles()
            n += len(m.loop_triangles)
            e.to_mesh_clear()
    return n


def export(gun_id):
    for o in bpy.context.scene.objects:
        o.select_set(o.type == "MESH" and not o.name.startswith("Plane") or o.name == "muzzle")
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="b") if o.modifiers else None
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.ops.object.join()
    bpy.context.object.name = gun_id
    bpy.data.objects["muzzle"].select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=f"{EXPORT}/{gun_id}.glb",
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_lights=False,
        export_cameras=False,
    )


def main():
    only = sys.argv[3] if len(sys.argv) > 3 else None  # One gun id, or all.
    for gun_id, (build, dist, rarity, middle) in GUNS.items():
        if only and gun_id != only:
            continue
        reset()
        build(RARITY[rarity])
        print("TRIS", gun_id, tris())
        stage(dist, target=(0, middle, 0.04))
        render(gun_id)
        if EXPORT:
            reset()
            build(RARITY["base"])
            export(gun_id)
    if only:
        return
    # The light machine gun in each rarity, side by side.
    reset()
    for i, rarity in enumerate(("commune", "rare", "epique", "legendaire")):
        _mats.clear()
        light_smg(RARITY[rarity])
        for o in bpy.context.scene.objects:
            if o.type in ("MESH", "EMPTY") and "placed" not in o:
                o.location.x += (i - 1.5) * 0.2
                o.location.y += 0.0
                o["placed"] = True
    stage(1.5, target=(0, 0.12, 0.03), yaw=35, height=0.45)
    render("raretes")


main()
