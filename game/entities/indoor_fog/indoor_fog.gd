class_name IndoorFog
extends Node3D
## A zone of indoor fog (spec S-014, T-190): the corridors of the hospital.
## While the camera is inside, NightEnvironment thickens the depth fog and
## turns it sea green, so the far neons fade into it. Compatibility has no
## FogVolume: this is its stand-in. A box of `size` around the node.

const GROUP := &"indoor_fog"

## Size of the zone, in meters.
@export var size := Vector3.ONE


func _ready() -> void:
	add_to_group(GROUP)


## True if a world position lies inside the zone.
func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	var half := size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## True if a world position lies in any indoor fog zone of the tree.
static func covers(tree: SceneTree, point: Vector3) -> bool:
	for zone: IndoorFog in tree.get_nodes_in_group(GROUP):
		if zone.contains(point):
			return true
	return false
