class_name Door
extends Node3D
## A door that opens and closes (spec S-016, Q1 and Q2). It stands in the
## middle of its doorway, the leaf across its local X axis, hinged at -X.
## Closed, the leaf is on the walls layer: it stops bodies, blocks sight and
## muffles noise like a wall (NoiseBus.walls_between). Open, it has no
## collision at all, so nothing snags on it and the navigation mesh, baked
## through the doorway, stays true.
## Hold "interact" in reach: standing, it opens or closes at once with a noise
## of 6 m; crouched (or prowling, for the monster) it takes 1 s for 2 m. The
## monster running into a closed door smashes it open: 12 m, and it stops
## short for 0.8 s (S-020, T-307).
## Two special kinds (Q3): a FIRE door closes on its own fire_close_delay after
## it was opened, with a slam; an EMERGENCY exit opens only from inside (its
## -Z side) with a loud crash bar, and stays open. A closed emergency exit is
## a wall for the navigation mesh (the map adds it to navigation_source): the
## AIs never plan through a door they could not open.
## A SHUTTER (a shop's metal shutter) rolls up instead of swinging, always
## loudly; a door with a bell rings it when it is opened, even slowly.

signal toggled(is_open: bool, by: Node)

## NORMAL: opened and closed by hand. FIRE: closes itself. EMERGENCY: opens
## from inside only, and stays open.
enum Kind { NORMAL, FIRE, EMERGENCY, SHUTTER }

const GROUP := &"doors"
## Physics layer 2, "walls": a closed door is a wall (see the project settings).
const WALLS_LAYER := 1 << 1
## What it sounds like (T-242), by what happens to it.
const SOUND_OPEN := preload("res://assets/audio/interiors/door_open.wav")
const SOUND_QUIET := preload("res://assets/audio/interiors/door_quiet.wav")
const SOUND_CLOSE := preload("res://assets/audio/interiors/door_close.wav")
const SOUND_SMASH := preload("res://assets/audio/interiors/door_smash.wav")
const SOUND_FIRE_SLAM := preload("res://assets/audio/interiors/fire_door_slam.wav")
const SOUND_CRASH_BAR := preload("res://assets/audio/interiors/crash_bar.wav")
const SOUND_SHUTTER := preload("res://assets/audio/interiors/shutter_roll.wav")
const SOUND_BELL := preload("res://assets/audio/interiors/shop_bell.wav")
## The leaf of each kind (T-240): 1 x 2.4 m models, scaled to the doorway.
const LEAF_MODELS := {
	Kind.NORMAL: preload("res://assets/models/door_leaf.glb"),
	Kind.FIRE: preload("res://assets/models/fire_door_leaf.glb"),
	Kind.EMERGENCY: preload("res://assets/models/emergency_leaf.glb"),
	Kind.SHUTTER: preload("res://assets/models/shutter_leaf.glb"),
}
const LEAF_MODEL_SIZE := Vector3(1.0, 2.4, 0.06)
## Physics layers 3 and 4, the hunted and the monster: a fire door waits for
## the doorway to be clear before it closes.
const BODIES_LAYERS := (1 << 2) | (1 << 3)

@export var settings: DoorSettings
@export var kind := Kind.NORMAL
## Width and height of the doorway it closes, in meters.
@export var width := 1.2
@export var height := 2.4
## Whether it starts open.
@export var start_open := false
## A bell over the door rings when it opens (bell_range).
@export var bell := false
## Between two rooms of a building, not on an outer wall: drawn only near
## the camera, since no one sees it from the street (T-244).
@export var indoor := false

var is_open := false
## The last one who opened or closed it, or null.
var last_user: Node

var _progress := 0.0
var _holder: Node
var _wait_release := false
var _swing := 1.0  ## Which way it opens: 1 or -1 (away from the opener).
var _open_for := 0.0  ## Seconds since it was opened (fire doors).
var _tween: Tween

@onready var _hinge: Node3D = $Hinge
@onready var _leaf: AnimatableBody3D = $Hinge/Leaf
@onready var _shape: CollisionShape3D = $Hinge/Leaf/CollisionShape3D
@onready var _creak: AudioStreamPlayer3D = $Creak
@onready var _bell: AudioStreamPlayer3D = $Bell


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	add_to_group(GROUP)
	_hinge.position = Vector3(-width / 2.0, 0.0, 0.0)
	_leaf.position = Vector3(width / 2.0, height / 2.0, 0.0)
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, settings.leaf_thickness)
	_shape.shape = box
	var leaf: Node3D = LEAF_MODELS[kind].instantiate()
	leaf.name = "Model"
	leaf.scale = box.size / LEAF_MODEL_SIZE
	_leaf.add_child(leaf)
	DrawRange.limit(self, DrawRange.INDOOR if indoor else DrawRange.OUTDOOR)
	_set_open(start_open, false)


func _physics_process(delta: float) -> void:
	if kind != Kind.FIRE or not is_open or NoiseBus.mirror:
		return  # On an online client, the room closes it (S-010).
	_open_for += delta
	if _open_for >= settings.fire_close_delay and not _doorway_busy():
		last_user = null
		_set_open(false, true, SOUND_FIRE_SLAM)
		NoiseBus.emit_noise(
			NoiseEvent.Type.DOOR, global_position + Vector3.UP, settings.slam_range, self
		)
		toggled.emit(false, null)


## Whether the one using it does it the slow, quiet way: crouched, or the
## monster prowling (anything with is_sneaking()).
static func sneaks(user: Node) -> bool:
	return user != null and user.has_method("is_sneaking") and user.is_sneaking()


static func is_monster(user: Node) -> bool:
	return user is Monster or user is MonsterAvatar


## The closed door a body walking from `from` along `direction` meets within
## `reach` meters, or null (the AIs open it, the running monster smashes it).
static func closed_ahead(tree: SceneTree, from: Vector3, direction: Vector3, reach: float) -> Door:
	var flat_direction := Vector2(direction.x, direction.z)
	if flat_direction.length_squared() < 0.0001:
		return null
	flat_direction = flat_direction.normalized()
	var best: Door = null
	var best_distance := reach
	for node in tree.get_nodes_in_group(GROUP):
		var door := node as Door
		if door.is_open or absf(door.global_position.y - from.y) > door.settings.reach_height:
			continue
		var flat := door.closest_flat_point(from) - Vector2(from.x, from.z)
		var distance := flat.length()
		if distance > best_distance:
			continue
		if distance > 0.01 and flat_direction.dot(flat / distance) < 0.3:
			continue  # Beside or behind.
		best = door
		best_distance = distance
	return best


## The point of the leaf, closed, nearest to a position, on the ground plan
## (x, z): a wide door or one leaf of a double door is met at its edge, not
## only at its middle.
func closest_flat_point(at: Vector3) -> Vector2:
	var center := Vector2(global_position.x, global_position.z)
	var axis := Vector2(global_basis.x.x, global_basis.x.z).normalized()
	var along := clampf(axis.dot(Vector2(at.x, at.z) - center), -width / 2.0, width / 2.0)
	return center + axis * along


func get_prompt() -> String:
	if kind == Kind.SHUTTER:
		return "HUD_INTERACT_SHUTTER_CLOSE" if is_open else "HUD_INTERACT_SHUTTER_OPEN"
	return "HUD_INTERACT_DOOR_CLOSE" if is_open else "HUD_INTERACT_DOOR_OPEN"


func get_prompt_for(user: Node) -> String:
	return get_prompt() if can_use(user) else ""


## Whether this one may open or close it now: an emergency exit opens from
## inside only (the monster may smash it from outside) and is never closed.
func can_use(user: Node) -> bool:
	if kind != Kind.EMERGENCY:
		return true
	if is_open:
		return false
	return user is Node3D and to_local((user as Node3D).global_position).z < 0.0


## Whether a body standing at this position is in reach of the doorway.
func can_interact(from: Vector3) -> bool:
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= settings.reach and absf(gap.y) <= settings.reach_height


## A plain press does nothing: the hold decides (standing: at once).
func interact(_user: Node) -> void:
	pass


## One frame of holding "interact". Standing, the door moves on the first
## frame; sneaking, after quiet_time. Returns whether it just moved.
func hold(user: Node, delta: float) -> bool:
	if user != _holder:
		_holder = user
		_progress = 0.0
		_wait_release = false
	if _wait_release or not can_use(user):
		return false
	if kind == Kind.EMERGENCY:
		toggle(user, settings.emergency_range)  # The crash bar: no quiet way.
	elif kind == Kind.SHUTTER:
		toggle(user, settings.shutter_range)  # No quiet way either.
	elif sneaks(user):
		_progress += delta
		if _progress < settings.quiet_time:
			return false
		toggle(user, settings.quiet_range)
	else:
		toggle(user, settings.open_range)
	_progress = 0.0
	_wait_release = true  # Holding on does not swing it back.
	return true


func release(user: Node) -> void:
	if user == _holder:
		_progress = 0.0
		_wait_release = false


func get_hold_ratio() -> float:
	if _wait_release or _holder == null or not sneaks(_holder):
		return 0.0
	return clampf(_progress / settings.quiet_time, 0.0, 1.0)


## Opens it if closed, closes it if open, with a noise of this range.
func toggle(user: Node, noise_range: float) -> void:
	if not is_open and user is Node3D:
		_swing_away_from((user as Node3D).global_position)
	_set_open(not is_open, true, sound_for(not is_open, noise_range))
	_open_for = 0.0
	last_user = user
	if bell and is_open:
		noise_range = maxf(noise_range, settings.bell_range)
	NoiseBus.emit_noise(NoiseEvent.Type.DOOR, global_position + Vector3.UP, noise_range, self)
	toggled.emit(is_open, user)


## Opens it on the way, standing (the AIs).
func open_by(user: Node) -> void:
	if is_open or not can_use(user):
		return
	toggle(user, _loud_range())


## The range of opening it standing: the crash bar, the shutter or the plain way.
func _loud_range() -> float:
	match kind:
		Kind.EMERGENCY:
			return settings.emergency_range
		Kind.SHUTTER:
			return settings.shutter_range
	return settings.open_range


## The running monster bursts it open (Q2), and stops short for
## smash_stagger (S-020, T-307, piste E1): fleeing through doors pays off.
func smash(user: Node) -> void:
	if is_open:
		return
	toggle(user, settings.smash_range)
	Stagger.hit_on(user, settings.smash_stagger)


## Online client (S-010): shows the room's state, with the sound.
func mirror(open: bool) -> void:
	if open != is_open:
		_set_open(open, true, sound_for(open, settings.open_range))


## Whether someone stands in the doorway, where the leaf would close on them.
func _doorway_busy() -> bool:
	if not is_inside_tree():
		return false
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 1.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform.translated_local(Vector3(0, height / 2.0, 0))
	query.collision_mask = BODIES_LAYERS
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _swing_away_from(at: Vector3) -> void:
	var local := to_local(at)
	_swing = 1.0 if local.z > 0.0 else -1.0  # +angle swings the leaf to -Z.


## The sound of opening or closing it with a noise of this range: the crash
## bar, the shutter, a smash, the quiet way or the plain one. A fire door
## slamming on its own has its own sound.
func sound_for(open: bool, noise_range: float) -> AudioStream:
	if kind == Kind.EMERGENCY:
		return SOUND_CRASH_BAR
	if kind == Kind.SHUTTER:
		return SOUND_SHUTTER
	if open and noise_range >= settings.smash_range:
		return SOUND_SMASH
	if noise_range <= settings.quiet_range:
		return SOUND_QUIET
	return SOUND_OPEN if open else SOUND_CLOSE


func _set_open(open: bool, animate: bool, sound: AudioStream = null) -> void:
	is_open = open
	_leaf.collision_layer = 0 if open else WALLS_LAYER
	# On an online client, a leaf the room swings shut must not sweep the
	# client's own player, a little ahead of the room's, out of the doorway and
	# through a wall (net_match fall in the cellar corridor, S-020, T-330): it
	# only becomes solid once it is shut.
	var solid_when_shut := animate and not open and NoiseBus.mirror and is_inside_tree()
	if solid_when_shut:
		_leaf.collision_layer = 0
	var property := "rotation:y"
	var value := deg_to_rad(settings.open_angle) * _swing if open else 0.0
	if kind == Kind.SHUTTER:
		property = "position:y"  # Rolled up under the lintel.
		value = height - settings.shutter_hang if open else 0.0
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		if sound != null:
			_creak.stream = sound
			SoundSpace.play(_creak)
		if bell and open:
			SoundSpace.play(_bell)
		_tween = create_tween()
		_tween.tween_property(_hinge, property, value, settings.swing_time)
		if solid_when_shut:
			_tween.tween_callback(_make_solid)
	else:
		_hinge.set_indexed(property, value)


## The leaf of a client's door, swung shut, stops bodies again.
func _make_solid() -> void:
	if not is_open:
		_leaf.collision_layer = WALLS_LAYER
