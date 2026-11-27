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
## What it holds in both hands (hold(), a Versus gun, S-025 T-409): where
## the right hand grips it, from the feet, -Z ahead; lower when crouched.
const HOLD_AT := Vector3(0.2, 1.22, -0.2)
## Turned a little to the right while it holds it (radians), its left
## shoulder ahead, as a shooter stands: the gun shows beside its right side
## from a camera over its shoulder.
const HOLD_TURN := -0.45
const HOLD_CROUCH_DROP := 0.35
## The wrist sits a little behind the grip.
const WRIST_BEHIND := Vector3(0.0, 0.01, 0.07)
## The animations its hands keep it in; the others (kneeling, a gesture) put
## it out of sight.
const HOLDING: Array[StringName] = [IDLE, WALK, RUN, CROUCH, CROUCH_IDLE]

@export var role := Role.AMBULANCIER:
	set(value):
		role = value
		if is_inside_tree():
			_load_model()
@export var settings: HuntedBodySettings

## The animation chosen last (also without a model).
var animation := IDLE

## What it holds in both hands, or null.
var held: Node3D

var _model: Node3D
var _player: AnimationPlayer
var _hold_place: Node3D
var _wrists: Array[Node3D] = []
var _pose: HoldPose


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
	_update_hold()


## Holds item in both hands (a node of its own, whose -Z is ahead), the left
## hand at left_grip from the right one's grip; null holds nothing. The arms
## reach for it (HoldPose) while it walks, runs or crouches.
func hold(item: Node3D, left_grip := Vector3.FORWARD * 0.15) -> void:
	if held != null:
		held.queue_free()
		held = null
	if _hold_place == null:
		_hold_place = Node3D.new()
		_hold_place.name = "Hold"
		add_child(_hold_place)
	if item != null:
		held = item
		_hold_place.add_child(item)
		_wrists = [Node3D.new(), Node3D.new()]
		_wrists[0].position = WRIST_BEHIND
		_wrists[1].position = left_grip + WRIST_BEHIND * Vector3(1, 1, 0.5)
		for wrist in _wrists:
			item.add_child(wrist)
	_update_hold()


func _update_hold() -> void:
	var holding := held != null and animation in HOLDING
	if _hold_place != null:
		_hold_place.visible = holding
		var crouched := animation == CROUCH or animation == CROUCH_IDLE
		_hold_place.position = HOLD_AT + Vector3.DOWN * (HOLD_CROUCH_DROP if crouched else 0.0)
	if _model != null:
		_model.rotation.y = HOLD_TURN if holding else 0.0
	if _pose != null:
		_pose.active = holding
		_pose.right_target = _wrists[0] if holding else null
		_pose.left_target = _wrists[1] if holding else null


func _load_model() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _model != null:
		_model.queue_free()
		_model = null
		_player = null
		_pose = null
	var scene: PackedScene = load(MODELS[role])
	_model = scene.instantiate()
	add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_add_pose()
	_player = players[0]
	for anim_name in _player.get_animation_list():
		var once := anim_name in ONE_SHOTS
		_player.get_animation(anim_name).loop_mode = (
			Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
		)
	_player.play(animation)


func _add_pose() -> void:
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_pose = HoldPose.new()
	_pose.name = "HoldPose"
	skeletons[0].add_child(_pose)
	_update_hold()
