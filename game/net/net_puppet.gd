class_name NetPuppet
extends Node3D
## Another player of an online game as this client sees it (S-010, T-097): a
## plain silhouette (characters come with S-011), moved between the snapshots
## the room sends. Hidden while the room does not send it (out of sight).

enum Kind { HUNTED, MONSTER }

const HUNTED_HEIGHT := 1.75
const MONSTER_HEIGHT := 2.2
const RADIUS := 0.3
const HUNTED_COLOR := Color(0.55, 0.55, 0.5)
const MONSTER_COLOR := Color(0.12, 0.1, 0.1)

var kind := Kind.HUNTED
var buffer := SnapshotBuffer.new()


func _ready() -> void:
	var height := MONSTER_HEIGHT if kind == Kind.MONSTER else HUNTED_HEIGHT
	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = RADIUS
	var material := StandardMaterial3D.new()
	material.albedo_color = MONSTER_COLOR if kind == Kind.MONSTER else HUNTED_COLOR
	material.roughness = 1.0
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.material_override = material
	body.position.y = height / 2.0
	add_child(body)


## Moves to where the buffer has it at time (seconds).
func show_at(time: float, max_extrapolation: float) -> void:
	if buffer.is_empty():
		return
	var pose := buffer.sample(time, max_extrapolation)
	global_position = pose[0]
	rotation.y = pose[1]
