class_name HidingSpot
extends Node3D
## A closet or a dumpster the hunted hides in (spec S-008, Q5 to Q7).
## Hold "interact" for 1 s in front of it to get in, and again to get out:
## each time the door or the lid makes a noise of 3 m. Inside, the hunted is
## invisible and makes no footstep, but their breath still reaches the scan.
## The monster opens it the same way: whoever is inside is caught.
## Its front faces +Z: the hunted gets out there, and looks out that way.

## Someone was inside when the monster opened it.
signal found(occupant: Node3D, by: Node3D)
signal opened(by: Node3D)

const GROUP := &"hiding_spots"

@export var settings: RuseSettings
## Whether the hidden one crouches (a dumpster) or stands (a closet).
@export var crouched := false

## The hunted inside, or null.
var occupant: Node3D

var _progress := 0.0
var _holder: Node
var _wait_release := false

@onready var _creak: AudioStreamPlayer3D = $Creak


## Whether this body is hidden in a hiding spot (the player or the AI prey).
static func is_hidden(body: Node) -> bool:
	return body != null and body.has_method("is_hidden") and body.is_hidden()


static func is_monster(user: Node) -> bool:
	return user is Monster or user is MonsterAvatar


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	add_to_group(GROUP)
	_creak.stream = PlaceholderSounds.creak()


## Where the one who gets out stands, in front of it.
func get_exit_point() -> Vector3:
	return global_position + global_basis.z * (settings.hide_reach * 0.6)


## Which way the hidden one looks: straight out of the front, as a yaw.
func get_out_yaw() -> float:
	return global_rotation.y + PI


func is_free() -> bool:
	return occupant == null


func get_prompt() -> String:
	return "HUD_INTERACT_HIDE"


## The hint depends on who looks at it (Q11).
func get_prompt_for(user: Node) -> String:
	if is_monster(user):
		return "HUD_INTERACT_OPEN"
	if occupant == user:
		return "HUD_INTERACT_LEAVE"
	return "HUD_INTERACT_HIDE" if is_free() else ""


## Whether a body standing at this position is in reach of the front.
func can_interact(from: Vector3) -> bool:
	var gap := from - get_exit_point()
	return Vector2(gap.x, gap.z).length() <= settings.hide_reach and absf(gap.y) <= 1.0


## A hunted wants it if it is free or they are the one inside; a monster
## always may open it.
func wanted_by(user: Node) -> bool:
	return is_monster(user) or is_free() or occupant == user


## A plain press does nothing: getting in or out is held (Q5).
func interact(_user: Node) -> void:
	pass


func hold(user: Node, delta: float) -> void:
	if user != _holder:
		_holder = user
		_progress = 0.0
		_wait_release = false
	if _wait_release or not wanted_by(user):
		return
	_progress += delta
	if _progress >= settings.hide_time:
		_progress = 0.0
		_wait_release = true  # Holding on does not get straight back out.
		_finish(user)


func release(user: Node) -> void:
	if user == _holder:
		_progress = 0.0
		_wait_release = false


func get_hold_ratio() -> float:
	return 0.0 if _wait_release else clampf(_progress / settings.hide_time, 0.0, 1.0)


func _finish(user: Node) -> void:
	NoiseBus.emit_noise(
		NoiseEvent.Type.HIDE, global_position + Vector3.UP, settings.hide_noise_range, self
	)
	_creak.play()
	if is_monster(user):
		open(user)
	elif occupant == user:
		occupant = null
		user.leave_hiding()
	elif is_free():
		occupant = user
		user.hide_in(self)


## The monster opens it (Q7): whoever is inside comes out, caught.
func open(by: Node3D) -> void:
	opened.emit(by)
	if occupant == null:
		return
	var caught := occupant
	occupant = null
	caught.leave_hiding()
	found.emit(caught, by)
