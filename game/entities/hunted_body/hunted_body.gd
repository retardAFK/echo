class_name HuntedBody
extends Node3D
## The body of a hunted (spec S-011, T-126): one of the three characters made
## by tools/blender/hunted.py, animated from what the game already knows of
## the hunted (gait, horizontal speed, captured). Nothing new goes over the
## network (Q6). Without a display (server, tests) no model is loaded.

## The three hunted, by role (Q1); online, the seat decides (Q5).
enum Role { AMBULANCIER, PARKA, MASQUE }

const MODELS := {
	Role.AMBULANCIER: "res://assets/models/hunted/hunted_ambulancier.glb",
	Role.PARKA: "res://assets/models/hunted/hunted_parka.glb",
	Role.MASQUE: "res://assets/models/hunted/hunted_masque.glb",
}
const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const CROUCH := &"crouch"
const CROUCH_IDLE := &"crouch_idle"
const KNEEL := &"kneel"

@export var role := Role.AMBULANCIER:
	set(value):
		role = value
		if is_inside_tree():
			_load_model()
@export var settings: HuntedBodySettings

## The animation chosen last (also without a model).
var animation := IDLE

var _model: Node3D
var _player: AnimationPlayer


func _ready() -> void:
	_load_model()


## The character of an online seat (1 to 3); seat 0 is the monster's.
static func role_for_seat(seat: int) -> Role:
	return clampi(seat - 1, 0, Role.size() - 1) as Role


## The animation for a state: captured kneels, crouched creeps or crouches,
## otherwise idle, walk or run by gait and speed.
static func pick(
	gait: PlayerMotion.Gait, speed: float, down: bool, values: HuntedBodySettings
) -> StringName:
	if down:
		return KNEEL
	var still := speed < values.still_speed
	match gait:
		PlayerMotion.Gait.CROUCH:
			return CROUCH_IDLE if still else CROUCH
		PlayerMotion.Gait.SPRINT:
			return IDLE if still else RUN
	return IDLE if still else WALK


## Playback speed of an animation at a speed, so the feet roughly keep pace.
static func playback_scale(anim: StringName, speed: float, values: HuntedBodySettings) -> float:
	var made_for := 0.0
	match anim:
		WALK:
			made_for = values.walk_speed
		RUN:
			made_for = values.run_speed
		CROUCH:
			made_for = values.crouch_speed
	if made_for <= 0.0:
		return 1.0
	return clampf(speed / made_for, values.min_scale, values.max_scale)


## Plays what fits the hunted's state.
func show_state(gait: PlayerMotion.Gait, speed: float, down: bool) -> void:
	var next := pick(gait, speed, down, settings)
	if _player != null:
		if next != animation or not _player.is_playing():
			_player.play(next, settings.blend_time)
		_player.speed_scale = playback_scale(next, speed, settings)
	animation = next


func _load_model() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _model != null:
		_model.queue_free()
		_model = null
		_player = null
	var scene: PackedScene = load(MODELS[role])
	_model = scene.instantiate()
	add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_player = players[0]
	for anim_name in _player.get_animation_list():
		_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.play(animation)
