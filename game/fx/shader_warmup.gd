class_name ShaderWarmup
extends Node
## Compiles the shaders of a map before the game shows it (S-009, T-085).
## In the browser, a shader is compiled the first time something drawn with it
## comes into view, which makes the game stutter when the player first sees a
## place. So for a few frames, behind a black screen, a tiny copy of each
## different mesh and material of the map (and of what appears during a game:
## thrown bottles, alarm clocks) is drawn just in front of the camera, once
## unlit and once lit by a lamp, then removed.
## Skipped without a screen (tests, simulations).

## Scenes that appear during a game, warmed up with the map.
const SPAWNED_SCENES: Array[PackedScene] = [
	preload("res://game/entities/bottle/thrown_bottle.tscn"),
	preload("res://game/entities/decoy/decoy.tscn"),
]
## Frames drawn without the lamp, then with it.
const FRAMES_UNLIT := 2
const FRAMES_LIT := 2
## Grid of copies in front of the camera: distance, widest side and largest
## spacing, in meters. The grid stays well inside the view.
const DISTANCE := 0.5
const GRID_WIDTH := 0.25
const MAX_SPACING := 0.03

var _cover: CanvasLayer
var _group: Node3D
var _lamp: OmniLight3D


## One node per different look: a mesh with its materials, or a MultiMesh.
## Copies of the same mesh with the same materials count once.
static func collect(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	var keys := {}
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		var key := [node.mesh.get_instance_id(), _id(node.material_override)]
		for i in node.mesh.get_surface_count():
			key.append(_id(node.get_active_material(i)))
		if not keys.has(key):
			keys[key] = true
			found.append(node)
	for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh == null or node.multimesh.mesh == null:
			continue
		var key := ["multi", node.multimesh.mesh.get_instance_id(), _id(node.material_override)]
		if not keys.has(key):
			keys[key] = true
			found.append(node)
	return found


## A small copy of a node found by collect(), with the same mesh and materials.
static func make_copy(source: GeometryInstance3D, size: float) -> GeometryInstance3D:
	var mesh: Mesh
	var copy: GeometryInstance3D
	if source is MultiMeshInstance3D:
		var batch := source as MultiMeshInstance3D
		mesh = batch.multimesh.mesh
		var multimesh := MultiMesh.new()
		multimesh.transform_format = batch.multimesh.transform_format
		multimesh.use_colors = batch.multimesh.use_colors
		multimesh.use_custom_data = batch.multimesh.use_custom_data
		multimesh.mesh = mesh
		multimesh.instance_count = 1
		multimesh.visible_instance_count = 1
		if multimesh.transform_format == MultiMesh.TRANSFORM_3D:
			multimesh.set_instance_transform(0, Transform3D.IDENTITY)
		else:
			multimesh.set_instance_transform_2d(0, Transform2D.IDENTITY)
		var copy_batch := MultiMeshInstance3D.new()
		copy_batch.multimesh = multimesh
		copy = copy_batch
	else:
		var single := source as MeshInstance3D
		mesh = single.mesh
		var copy_single := MeshInstance3D.new()
		copy_single.mesh = mesh
		for i in mesh.get_surface_count():
			copy_single.set_surface_override_material(i, single.get_surface_override_material(i))
		copy = copy_single
	copy.material_override = source.material_override
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := mesh.get_aabb()
	var longest := maxf(box.get_longest_axis_size(), 0.001)
	copy.scale = Vector3.ONE * (size / longest)
	copy.position = -box.get_center() * copy.scale
	return copy


static func _id(object: Object) -> int:
	return object.get_instance_id() if object != null else 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_add_cover()
	# The camera of the map (player, monster or bench) is set during its _ready.
	await get_tree().process_frame
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		queue_free()
		return
	_build(camera)
	for i in FRAMES_UNLIT:
		await get_tree().process_frame
	_lamp.visible = true
	for i in FRAMES_LIT:
		await get_tree().process_frame
	_group.queue_free()
	queue_free()


func _build(camera: Camera3D) -> void:
	var sources := collect(get_parent())
	var spawned: Array[Node] = []
	for scene in SPAWNED_SCENES:
		var instance := scene.instantiate()
		RetroSurface.apply_to(instance, RetroSurface.DEFAULT_SETTINGS)
		spawned.append(instance)
		sources.append_array(collect(instance))
	_group = Node3D.new()
	_group.name = "ShaderWarmup"
	_group.position = Vector3(0, 0, -DISTANCE)
	camera.add_child(_group)
	var side := maxi(ceili(sqrt(sources.size())), 1)
	var spacing := minf(MAX_SPACING, GRID_WIDTH / side)
	for i in sources.size():
		var copy := make_copy(sources[i], spacing * 0.8)
		var cell := (
			Vector3(i % side, int(i / float(side)), 0) - Vector3(side - 1, side - 1, 0) * 0.5
		)
		copy.position += cell * spacing
		_group.add_child(copy)
	for instance in spawned:
		instance.free()
	_lamp = OmniLight3D.new()
	_lamp.omni_range = DISTANCE * 2.0
	_lamp.visible = false
	_group.add_child(_lamp)


func _add_cover() -> void:
	_cover = CanvasLayer.new()
	_cover.layer = 128
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(black)
	add_child(_cover)
