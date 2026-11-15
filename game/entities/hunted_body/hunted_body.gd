class_name HuntedBody
extends Node3D
## The body of a hunted (spec S-011, T-126): one of the three characters made
## by tools/blender/hunted.py, animated from what the game knows of the
## hunted (gait, horizontal speed, captured) and the gesture it makes (T-125:
## throwing, picking something up or putting it down, working at something).
## Online, the room sends the gesture with the rest of its state. Without a
## display (server, tests) no model is loaded.

## The three hunted, by role (Q1); online, the seat decides (Q5).
enum Role { AMBULANCIER, PARKA, MASQUE }
## What its hands do (BodyGesture): throw a bottle, pick something up or put
## an alarm clock down, work at something it holds "interact" on (a fuse box,
## a hiding spot, a teammate to free).
enum Gesture { NONE, THROW, PICK, WORK }

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
const THROW := &"throw"
const PICK := &"pick"
const WORK := &"work"
## Played once, not looped.
const ONE_SHOTS: Array[StringName] = [THROW, PICK]

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


## The animation for a state: captured kneels; a gesture comes next; then
## crouched creeps or crouches, otherwise idle, walk or run by gait and speed.
static func pick(
	gait: PlayerMotion.Gait,
	speed: float,
	down: bool,
	values: HuntedBodySettings,
	gesture := Gesture.NONE
) -> StringName:
	if down:
		return KNEEL
	match gesture:
		Gesture.THROW:
			return THROW
		Gesture.PICK:
			return PICK
		Gesture.WORK:
			return WORK
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


## Plays what fits the hunted's state. A gesture plays once from its start.
func show_state(gait: PlayerMotion.Gait, speed: float, down: bool, gesture := Gesture.NONE) -> void:
	var next := pick(gait, speed, down, settings, gesture)
	if _player != null:
		if next != animation:
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
		var once := anim_name in ONE_SHOTS
		_player.get_animation(anim_name).loop_mode = (
			Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
		)
	_player.play(animation)
