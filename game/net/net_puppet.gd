class_name NetPuppet
extends Node3D
## Another player of an online game as this client sees it (S-010, T-097),
## moved between the snapshots the room sends. A hunted has its character
## (S-011, T-126: the seat decides which), animated from its gait and the
## speed seen between snapshots; the monster is still a plain silhouette.
## Hidden while the room does not send it (out of sight).
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
const BODY_SCENE := preload("res://game/entities/hunted_body/hunted_body.tscn")
## How fast the shown speed follows the speed seen between frames (per second).
const SPEED_SMOOTHING := 10.0

var kind := Kind.HUNTED
## Its seat in the lobby (S-011 Q5: a hunted's character).
var seat := 1
## Its gait, from the snapshots (PlayerMotion.Gait).
var gait := PlayerMotion.Gait.WALK
var buffer := SnapshotBuffer.new()
## Captured, on its knees (T-107).
var down := false

var _body: MeshInstance3D
var _character: HuntedBody
var _speed := 0.0
var _last_position := Vector3.ZERO
var _last_time := -1.0


func _ready() -> void:
	if kind == Kind.HUNTED:
		_character = BODY_SCENE.instantiate()
		_character.role = HuntedBody.role_for_seat(seat)
		add_child(_character)
		return
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
	var position_now: Vector3 = pose[0]
	if _last_time >= 0.0 and time > _last_time:
		var gap := position_now - _last_position
		var seen := Vector2(gap.x, gap.z).length() / (time - _last_time)
		_speed = lerpf(_speed, seen, minf(1.0, SPEED_SMOOTHING * (time - _last_time)))
	_last_time = time
	_last_position = position_now
	global_position = position_now
	rotation.y = pose[1]
	if _character != null:
		_character.show_state(gait, _speed, down)


## Back in sight: no speed from where it was lost.
func restart_motion() -> void:
	_last_time = -1.0
	_speed = 0.0


## Down on its knees (captured) or standing again (freed).
func set_down(value: bool) -> void:
	if value == down or kind != Kind.HUNTED:
		return
	down = value  # The character kneels (show_state).
	if down:
		add_to_group(Interactable.GROUP)
	else:
		remove_from_group(Interactable.GROUP)


## Hides its character while the spectator camera sits in its head.
func set_seen_from_inside(inside: bool) -> void:
	if _character != null:
		_character.visible = not inside


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
