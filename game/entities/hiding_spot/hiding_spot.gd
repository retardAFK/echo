class_name HidingSpot
extends Node3D
## A closet or a dumpster the hunted hides in (spec S-008, Q5 to Q7).
## Hold "interact" for 1 s in front of it to get in, and again to get out:
## each time the door or the lid makes a noise of 3 m. Inside, the hunted is
## invisible and makes no footstep, but their breath still reaches the scan.
## The monster opens it the same way: whoever is inside is caught.
## Its front faces +Z: the hunted gets out there, and looks out that way.
## Four families (S-016, Q6) change the times and noises: CLOSET (closets and
## dumpsters, above), LOW (2 s, 1 m), MAKESHIFT (0.5 s, silent, but seen by a
## monster within 2 m looking at it) and METAL (6 m, the monster takes 2 s).

## Someone was inside when the monster opened it.
signal found(occupant: Node3D, by: Node3D)
signal opened(by: Node3D)

## The family of the spot (S-016, Q6).
enum Family { CLOSET, LOW, MAKESHIFT, METAL }

const GROUP := &"hiding_spots"

@export var settings: RuseSettings
## Whether the hidden one crouches (a dumpster) or stands (a closet).
@export var crouched := false
@export var family := Family.CLOSET

## The hunted inside, or null.
var occupant: Node3D
## A firecracker a hunted set in it, empty, as a trap (S-020, T-331, piste
## R6): it goes off when a monster opens the spot. Null when none.
var trap: Firecracker

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
	DrawRange.limit(self, DrawRange.OUTDOOR)


## Whether a monster's eye looking along `forward` misses a body: anyone not
## hidden is not concealed (the usual sight rules apply); a hidden one is
## concealed, except in a makeshift spot from a monster this close that faces
## it (S-016, Q6).
static func conceals(body: Node, eye: Vector3, forward: Vector3) -> bool:
	if not is_hidden(body):
		return false
	var spot: HidingSpot = body.get("hiding_in")
	if spot == null or spot.family != Family.MAKESHIFT:
		return true
	var gap := spot.global_position - eye
	var flat := Vector2(gap.x, gap.z)
	if flat.length() > spot.settings.makeshift_reveal_distance:
		return true
	var look := Vector2(forward.x, forward.z)
	if flat.length() < 0.01 or look.length_squared() < 0.0001:
		return false
	return look.normalized().dot(flat.normalized()) < 0.0  # Looking away.


## Whether a hidden body is in a makeshift spot and seen there.
static func is_revealed(body: Node, eye: Vector3, forward: Vector3) -> bool:
	return is_hidden(body) and not conceals(body, eye, forward)


## The hiding spot nearest to a position within a flat distance, or null.
static func nearest(tree: SceneTree, at: Vector3, radius: float) -> HidingSpot:
	var best: HidingSpot = null
	var best_distance := radius
	for node in tree.get_nodes_in_group(GROUP):
		var spot := node as HidingSpot
		var gap := spot.global_position - at
		var distance := Vector2(gap.x, gap.z).length()
		if distance <= best_distance:
			best = spot
			best_distance = distance
	return best


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


## One frame of holding "interact". Returns whether the hold just finished.
func hold(user: Node, delta: float) -> bool:
	if user != _holder:
		_holder = user
		_progress = 0.0
		_wait_release = false
	if _wait_release or not wanted_by(user):
		return false
	_progress += delta
	if _progress < time_for(user):
		return false
	_progress = 0.0
	_wait_release = true  # Holding on does not get straight back out.
	_finish(user)
	return true


func release(user: Node) -> void:
	if user == _holder:
		_progress = 0.0
		_wait_release = false


func get_hold_ratio() -> float:
	if _wait_release or _holder == null:
		return 0.0
	return clampf(_progress / time_for(_holder), 0.0, 1.0)


## How long this one holds "interact" to get in or out, or to open it.
func time_for(user: Node) -> float:
	if is_monster(user):
		return settings.metal_open_time if family == Family.METAL else settings.hide_time
	match family:
		Family.LOW:
			return settings.low_hide_time
		Family.MAKESHIFT:
			return settings.makeshift_hide_time
	return settings.hide_time


## Range of the noise of getting in or out, or of opening it.
func noise_range() -> float:
	match family:
		Family.LOW:
			return settings.low_noise_range
		Family.MAKESHIFT:
			return settings.makeshift_noise_range
		Family.METAL:
			return settings.metal_noise_range
	return settings.hide_noise_range


## Whether a hunted can set a trap in it now: empty and not trapped yet (T-331).
func can_trap() -> bool:
	return is_free() and trap == null


## Online client (S-010, T-099): the door of the spot, opened in the room.
func voice() -> void:
	SoundSpace.play(_creak)


func _finish(user: Node) -> void:
	var loud := noise_range()
	if is_monster(user) and is_free():
		loud = maxf(loud, settings.empty_search_range)  # Searched for nothing (T-310).
	if loud > 0.0:
		NoiseBus.emit_noise(NoiseEvent.Type.HIDE, global_position + Vector3.UP, loud, self)
		SoundSpace.play(_creak)
	if is_monster(user):
		open(user)
	elif occupant == user:
		occupant = null
		user.leave_hiding()
	elif is_free():
		occupant = user
		user.hide_in(self)


## The monster opens it (Q7): whoever is inside comes out, caught.
## Empty, the monster stands there empty_search_stagger (S-020, T-310).
func open(by: Node3D) -> void:
	opened.emit(by)
	if trap != null:  # T-331: the trap goes off in the monster's face.
		var sprung := trap
		trap = null
		sprung.go_off(by)
	if occupant == null:
		Stagger.hit_on(by, settings.empty_search_stagger)
		return
	var caught := occupant
	occupant = null
	caught.leave_hiding()
	found.emit(caught, by)
