class_name GunModel
extends RefCounted
## The 3D models of the Versus guns (spec S-025, T-409), made by
## tools/blender/versus_guns.py: assets/models/versus/<item id>.glb. Their
## origin is where the right hand holds the grip, their muzzle points to -Z,
## and the parts of the material "glow" take the color of the gun's rarity.
## Two uses: in the hands of a character (instance(), held by a HuntedBody),
## and merged into the first-person arms (append(), ViewModel).
## Adding a gun: build it in versus_guns.py, export it, and give its left
## hand's place in FORE_GRIPS. A gun without a model keeps the boxes of
## ViewModel and shows nothing in the character's hands.

const PATH := "res://assets/models/versus/%s.glb"
## The name of the material that takes the rarity's color.
const GLOW_MATERIAL := "glow"
## Where the left hand holds each gun, from its grip (meters, -Z forward).
const FORE_GRIPS := {
	&"light_smg": Vector3(0.0, -0.01, -0.14),
	&"precision_rifle": Vector3(0.0, 0.0, -0.3),
	&"sonic_shotgun": Vector3(0.0, -0.06, -0.22),
	&"assault_rifle": Vector3(0.0, -0.03, -0.34),
	&"pulse_pistol": Vector3(0.0, -0.08, -0.03),
	&"burst_rifle": Vector3(0.0, -0.01, -0.26),
	&"neon_minigun": Vector3(0.0, -0.04, -0.24),
}
## How high above the grip the eye looks while aiming (meters, T-412,
## ViewModel): just over each gun's sight, which then sits under the HUD's
## red dot.
const SIGHTS := {
	&"light_smg": 0.165,
	&"precision_rifle": 0.205,
	&"sonic_shotgun": 0.17,
	&"assault_rifle": 0.205,
	&"pulse_pistol": 0.22,
	&"burst_rifle": 0.165,
	&"neon_minigun": 0.185,
}

static var _meshes := {}
## Copies of the meshes with their glow in a color: "id:color" -> Mesh.
static var _lit_meshes := {}


## Whether the gun of this item id has a model.
static func has_model(id: StringName) -> bool:
	return FORE_GRIPS.has(id) and ResourceLoader.exists(PATH % id)


## Where its left hand goes, from the grip.
static func fore_grip(id: StringName) -> Vector3:
	return FORE_GRIPS.get(id, Vector3.FORWARD * 0.15)


## The gun's mesh, loaded once; null without a model.
static func mesh_of(id: StringName) -> Mesh:
	if not has_model(id):
		return null
	if not _meshes.has(id):
		var scene: Node = (load(PATH % id) as PackedScene).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		_meshes[id] = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
		scene.free()
	return _meshes[id]


## A node showing the gun, its glowing parts in glow; null without a model.
static func instance(id: StringName, glow: Color) -> Node3D:
	var mesh := lit_mesh(id, glow)
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = "Gun"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The gun's mesh with its glowing parts in glow (one copy per color, kept).
static func lit_mesh(id: StringName, glow: Color) -> Mesh:
	var mesh := mesh_of(id)
	if mesh == null:
		return null
	var key := "%s:%s" % [id, glow.to_html()]
	if not _lit_meshes.has(key):
		var copy := mesh.duplicate() as Mesh
		for surface in copy.get_surface_count():
			if _is_glow(copy, surface):
				var lit := StandardMaterial3D.new()
				lit.resource_name = GLOW_MATERIAL
				lit.albedo_color = glow
				lit.emission_enabled = true
				lit.emission = glow
				lit.emission_energy_multiplier = 1.5
				(copy as ArrayMesh).surface_set_material(surface, lit)
		_lit_meshes[key] = copy
	return _lit_meshes[key]


## Adds the gun's triangles to tool, moved by place, each in the color of its
## material (glow for the glowing ones). False without a model, or without
## its triangles (no display: the dummy renderer keeps none).
static func append(tool: SurfaceTool, id: StringName, glow: Color, place: Transform3D) -> bool:
	var mesh := mesh_of(id)
	if mesh == null:
		return false
	var added := false
	for surface in mesh.get_surface_count():
		var color := glow if _is_glow(mesh, surface) else _color_of(mesh, surface)
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty() or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		added = true
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		for index in indices:
			tool.set_color(color)
			tool.set_normal((place.basis * normals[index]).normalized())
			tool.add_vertex(place * vertices[index])
	return added


static func _is_glow(mesh: Mesh, surface: int) -> bool:
	var material := mesh.surface_get_material(surface)
	return material != null and material.resource_name == GLOW_MATERIAL


static func _color_of(mesh: Mesh, surface: int) -> Color:
	var material := mesh.surface_get_material(surface) as BaseMaterial3D
	return material.albedo_color if material != null else Color.GRAY
