class_name MetalFloor
extends Node3D
## A stretch of metal floor (spec S-016, Q9): fire escape stairs, steel steps.
## A box around its origin; the hunted's footsteps on it carry farther
## (NoiseSettings.metal_walk_range and metal_sprint_range). It has no body:
## the map's floors and ramps carry the weight.

const GROUP := &"metal_floors"

## Size of the box, centred on the origin, in meters (not rotated).
@export var size := Vector3(2, 3, 2)


func _ready() -> void:
	add_to_group(GROUP)


## Whether this position stands on a metal floor.
static func under(tree: SceneTree, position: Vector3) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		var floor_box := node as MetalFloor
		if floor_box.contains(position):
			return true
	return false


func contains(position: Vector3) -> bool:
	var local := position - global_position
	var half := size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z
