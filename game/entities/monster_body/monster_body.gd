class_name MonsterBody
extends Node3D
## The hunter's body (spec S-011, T-122, T-123): the model made by
## tools/blender/hunter.py, animated from its speed and what it is doing
## (scanning a building, opening a hiding spot). Used by the AI monster and,
## online, by the hunted's view of the monster (NetPuppet), which only knows
## its speed. Without a display (server, tests) no model is loaded.

enum Action { NONE, SCAN, OPEN }

const MODEL := "res://assets/models/hunter/hunter.glb"
const IDLE := &"idle"
const PROWL := &"prowl"
const WALK := &"walk"
const RUN := &"run"
const SCAN := &"scan"
const REACH := &"reach"

@export var settings: MonsterBodySettings

## The animation chosen last (also without a model).
var animation := IDLE

var _player: AnimationPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_player = players[0]
	for anim_name in _player.get_animation_list():
		_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.play(animation)


## The animation for a state: an action first, else idle, prowl, walk or run
## by speed.
static func pick(speed: float, action: Action, values: MonsterBodySettings) -> StringName:
	match action:
		Action.SCAN:
			return SCAN
		Action.OPEN:
			return REACH
	if speed < values.still_speed:
		return IDLE
	if speed < values.walk_from:
		return PROWL
	if speed < values.run_from:
		return WALK
	return RUN


## The action shown for a state of the AI monster's brain.
static func action_for(state: MonsterBrain.State) -> Action:
	match state:
		MonsterBrain.State.SCAN:
			return Action.SCAN
		MonsterBrain.State.OPEN:
			return Action.OPEN
	return Action.NONE


## Playback speed of an animation at a speed, so the feet roughly keep pace.
static func playback_scale(anim: StringName, speed: float, values: MonsterBodySettings) -> float:
	var made_for := 0.0
	match anim:
		PROWL:
			made_for = values.prowl_speed
		WALK:
			made_for = values.walk_speed
		RUN:
			made_for = values.run_speed
	if made_for <= 0.0:
		return 1.0
	return clampf(speed / made_for, values.min_scale, values.max_scale)


## Plays what fits the hunter's state.
func show_state(speed: float, action := Action.NONE) -> void:
	var next := pick(speed, action, settings)
	if _player != null:
		if next != animation or not _player.is_playing():
			_player.play(next, settings.blend_time)
		_player.speed_scale = playback_scale(next, speed, settings)
	animation = next
