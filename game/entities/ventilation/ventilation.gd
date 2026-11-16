class_name Ventilation
extends Node3D
## A ventilation zone of the hospital (spec S-014, Q5): the boiler room of the
## basement, the ducts of the operating theatres. Inside, a noise of
## NoiseSettings.ventilation_mask or less is lost in the roar: NoiseBus marks
## it masked, and the monster and its scan ignore it. Running, slamming a door
## or dropping something is still heard. A box of `size` around the node.

const GROUP := &"ventilation"

## Size of the zone, in meters.
@export var size := Vector3.ONE


func _ready() -> void:
	add_to_group(GROUP)


## True if a world position lies inside the zone.
func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	var half := size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## True if a world position lies in any ventilation zone of the tree.
static func covers(tree: SceneTree, point: Vector3) -> bool:
	for zone: Ventilation in tree.get_nodes_in_group(GROUP):
		if zone.contains(point):
			return true
	return false
