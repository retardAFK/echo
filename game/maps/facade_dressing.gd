class_name FacadeDressing
extends Node3D
## Dresses the blocks of flats with the facade modules of S-005 (spec S-006,
## T-045). The map generator lists every 3 x 3 m panel; they are drawn as one
## MultiMesh per wall and per module, so a whole facade costs a few draw calls.
## The panels have no collision: the greybox walls behind them stop the players.

## The modules, as validated in Blender (S-005, T-036).
@export var models: Array[PackedScene] = []
## Where each panel goes: its local +Z faces out of the wall.
@export var panels: Array[Transform3D] = []
## Index in models of each panel.
@export var variants := PackedInt32Array()
## Wall of each panel: the panels of one wall and one module share a MultiMesh.
@export var walls := PackedInt32Array()


func _ready() -> void:
	var meshes: Array[Mesh] = []
	for model in models:
		var instance := model.instantiate()
		var source := (
			instance.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		)
		meshes.append(source.mesh)
		instance.free()
	var batches := {}
	for i in panels.size():
		var key := Vector2i(walls[i], variants[i])
		if not batches.has(key):
			batches[key] = []
		batches[key].append(panels[i])
	for key: Vector2i in batches:
		var transforms: Array = batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[key.y]
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Wall%dModule%d" % [key.x, key.y]
		node.multimesh = multimesh
		add_child(node)


## Number of panels of a module, for the tests.
func count_of(variant: int) -> int:
	return variants.count(variant)
