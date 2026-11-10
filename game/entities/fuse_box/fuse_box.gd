class_name FuseBox
extends Node3D
## An electrical box on a wall of a visitable building (spec S-007, Q1 and Q2).
## At the start of a game, GameLoop puts a fuse in some of them: those get a
## small red LED, seen up close in the dark, and the hunted takes the fuse by
## holding "interact" while aiming at the box. The metal clanks at the start and
## at the end; letting go before the end starts over from zero.

## Emitted when a hunted (the player or the AI prey) took the fuse.
signal fuse_taken(user: Node)

@export var settings: LoopSettings

## Name of the building the box is in.
@export var building_name := ""

var has_fuse := false
var progress: HoldProgress

@onready var _led: MeshInstance3D = $Led


func _ready() -> void:
	add_to_group(CarAlarm.INTERACTABLE_GROUP)
	progress = HoldProgress.new(settings.pickup_time)
	_led.visible = has_fuse


## Puts a fuse in the box, or takes it out (start of a game).
func set_fuse(value: bool) -> void:
	has_fuse = value
	progress.done = 0.0
	if is_node_ready():
		_led.visible = value


## Where to stand to use the box: in front of it.
func get_approach_point() -> Vector3:
	return global_position + global_basis.z * (settings.fuse_reach * 0.6)


func get_prompt() -> String:
	return "HUD_INTERACT_FUSE_BOX" if has_fuse else ""


func can_interact(from: Vector3) -> bool:
	if not has_fuse:
		return false
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= settings.fuse_reach and absf(gap.y) < 2.0


## A single press does nothing: the fuse is taken by holding.
func interact(_user: Node) -> void:
	pass


func hold(user: Node, delta: float) -> void:
	if not has_fuse:
		return
	if progress.done == 0.0:
		_clank(user)
	if progress.advance(delta):
		_clank(user)
		set_fuse(false)
		fuse_taken.emit(user)


func release(_user: Node) -> void:
	progress.release()


func get_hold_ratio() -> float:
	return progress.get_ratio()


## The metal of the box, heard as made by the hunted holding it.
func _clank(user: Node) -> void:
	NoiseBus.emit_noise(NoiseEvent.Type.FUSE, global_position, settings.fuse_noise_range, user)
