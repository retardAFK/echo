class_name NetPuppet
extends Node3D
## Another player of an online game as this client sees it (S-010, T-097): a
## plain silhouette (characters come with S-011), moved between the snapshots
## the room sends. Hidden while the room does not send it (out of sight).
## A captured hunted (T-107) is down on its knees: a free hunted next to it
## sees the prompt to free it, and the room does the freeing.

enum Kind { HUNTED, MONSTER }

const HUNTED_HEIGHT := 1.75
const MONSTER_HEIGHT := 2.2
const RADIUS := 0.3
const HUNTED_COLOR := Color(0.55, 0.55, 0.5)
const MONSTER_COLOR := Color(0.12, 0.1, 0.1)
## Share of its height a captured hunted keeps on its knees.
const KNEEL_SCALE := 0.55
## Eyes below the top of the silhouette, in meters (the spectator's view).
const EYE_OFFSET := 0.15
const PLAYER_SETTINGS := preload("res://game/data/player_settings.tres")

var kind := Kind.HUNTED
var buffer := SnapshotBuffer.new()
## Captured, on its knees (T-107).
var down := false

var _body: MeshInstance3D


func _ready() -> void:
	var height := _height()
	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = RADIUS
	var material := StandardMaterial3D.new()
	material.albedo_color = MONSTER_COLOR if kind == Kind.MONSTER else HUNTED_COLOR
	material.roughness = 1.0
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = material
	_body.position.y = height / 2.0
	add_child(_body)


## Moves to where the buffer has it at time (seconds).
func show_at(time: float, max_extrapolation: float) -> void:
	if buffer.is_empty():
		return
	var pose := buffer.sample(time, max_extrapolation)
	global_position = pose[0]
	rotation.y = pose[1]


## Down on its knees (captured) or standing again (freed).
func set_down(value: bool) -> void:
	if value == down or kind != Kind.HUNTED:
		return
	down = value
	var scale_y := KNEEL_SCALE if down else 1.0
	_body.scale.y = scale_y
	_body.position.y = _height() * scale_y / 2.0
	if down:
		add_to_group(Interactable.GROUP)
	else:
		remove_from_group(Interactable.GROUP)


## Height of its eyes above its feet.
func get_eye_height() -> float:
	return _height() * (KNEEL_SCALE if down else 1.0) - EYE_OFFSET


func _height() -> float:
	return MONSTER_HEIGHT if kind == Kind.MONSTER else HUNTED_HEIGHT


## A free hunted next to a captured one sees how to free it (the room frees).
func get_prompt() -> String:
	return "HUD_INTERACT_RESCUE" if down else ""


func can_interact(from: Vector3) -> bool:
	if not down or not visible:
		return false
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= PLAYER_SETTINGS.rescue_reach and absf(gap.y) < 2.0


func wanted_by(user: Node) -> bool:
	return user is Player and not (user as Player).held


func interact(_user: Node) -> void:
	pass
