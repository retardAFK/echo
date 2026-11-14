class_name HuntedBody
extends Node3D
## How a hunted looks to the others (S-011): one of the three characters of
## "Le Réseau" (made by tools/blender/hunted/export.py), animated from how fast
## it moves and whether it is captured. Used by the AI prey and by the other
## players of an online game (NetPuppet). Feet at the origin, facing -Z.
## A dedicated server (no display) builds no model: nobody looks at it.

## The three characters, by look (seat 1 to 3 online, prey order offline).
const MODELS := [
	"res://assets/models/hunted/hunted_ambulancier.glb",
	"res://assets/models/hunted/hunted_parka.glb",
	"res://assets/models/hunted/hunted_masque.glb",
]
## Below this speed (m/s) it stands still.
const IDLE_SPEED := 0.3
## Above this speed (m/s) it runs.
const RUN_SPEED := 3.6
## Speeds (m/s) at which the walk and the run play at their own pace.
const WALK_PACE := 2.0
const RUN_PACE := 4.5
## Seconds to blend from one animation to the next.
const BLEND := 0.2

## Which of the three characters (wraps around).
@export var look := 0:
	set = set_look

## Horizontal speed in m/s, set by the owner every frame.
var speed := 0.0
## Captured: on its knees.
var down := false

var _model: Node3D
var _player: AnimationPlayer


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		build()


func set_look(value: int) -> void:
	look = value
	if _model != null:
		build()


## Makes (or remakes) the model of the current look.
func build() -> void:
	if _model != null:
		_model.queue_free()
	_model = (load(MODELS[posmod(look, MODELS.size())]) as PackedScene).instantiate()
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	for name in ["Idle", "Walk", "Run"]:
		if _player.has_animation(name):
			_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_player.play("Idle")


## The animation for the current speed and state, and its pace.
func get_wanted() -> Array:
	if down:
		return ["Kneel", 1.0]
	if speed < IDLE_SPEED:
		return ["Idle", 1.0]
	if speed < RUN_SPEED:
		return ["Walk", clampf(speed / WALK_PACE, 0.5, 2.0)]
	return ["Run", clampf(speed / RUN_PACE, 0.7, 1.6)]


func get_animation() -> StringName:
	return _player.current_animation if _player != null else &""


func _process(_delta: float) -> void:
	if _player == null:
		return
	var wanted := get_wanted()
	if _player.current_animation != wanted[0]:
		_player.play(wanted[0], BLEND)
	_player.speed_scale = wanted[1]
