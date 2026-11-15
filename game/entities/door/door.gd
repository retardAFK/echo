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
## monster running into a closed door smashes it open: 12 m.

signal toggled(is_open: bool, by: Node)

const GROUP := &"doors"
## Physics layer 2, "walls": a closed door is a wall (see the project settings).
const WALLS_LAYER := 1 << 1

@export var settings: DoorSettings
## Width and height of the doorway it closes, in meters.
@export var width := 1.2
@export var height := 2.4
## Whether it starts open.
@export var start_open := false

var is_open := false
## The last one who opened or closed it, or null.
var last_user: Node

var _progress := 0.0
var _holder: Node
var _wait_release := false
var _swing := 1.0  ## Which way it opens: 1 or -1 (away from the opener).
var _tween: Tween

@onready var _hinge: Node3D = $Hinge
@onready var _leaf: AnimatableBody3D = $Hinge/Leaf
@onready var _shape: CollisionShape3D = $Hinge/Leaf/CollisionShape3D
@onready var _mesh: MeshInstance3D = $Hinge/Leaf/Mesh
@onready var _creak: AudioStreamPlayer3D = $Creak


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	add_to_group(GROUP)
	_hinge.position = Vector3(-width / 2.0, 0.0, 0.0)
	_leaf.position = Vector3(width / 2.0, height / 2.0, 0.0)
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, settings.leaf_thickness)
	_shape.shape = box
	var mesh := BoxMesh.new()
	mesh.size = box.size
	_mesh.mesh = mesh
	_set_open(start_open, false)


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
		var gap := door.global_position - from
		var flat := Vector2(gap.x, gap.z)
		var distance := flat.length()
		if distance > best_distance:
			continue
		if distance > 0.01 and flat_direction.dot(flat / distance) < 0.3:
			continue  # Beside or behind.
		best = door
		best_distance = distance
	return best


func get_prompt() -> String:
	return "HUD_INTERACT_DOOR_CLOSE" if is_open else "HUD_INTERACT_DOOR_OPEN"


func get_prompt_for(_user: Node) -> String:
	return get_prompt()


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
	if _wait_release:
		return false
	if sneaks(user):
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
	_set_open(not is_open, true)
	last_user = user
	NoiseBus.emit_noise(NoiseEvent.Type.DOOR, global_position + Vector3.UP, noise_range, self)
	toggled.emit(is_open, user)


## Opens it on the way, standing (the AIs).
func open_by(user: Node) -> void:
	if not is_open:
		toggle(user, settings.open_range)


## The running monster bursts it open without stopping (Q2).
func smash(user: Node) -> void:
	if not is_open:
		toggle(user, settings.smash_range)


## Online client (S-010): shows the room's state, with the sound.
func mirror(open: bool) -> void:
	if open != is_open:
		_set_open(open, true)


func _swing_away_from(at: Vector3) -> void:
	var local := to_local(at)
	_swing = 1.0 if local.z > 0.0 else -1.0  # +angle swings the leaf to -Z.


func _set_open(open: bool, animate: bool) -> void:
	is_open = open
	_leaf.collision_layer = 0 if open else WALLS_LAYER
	var angle := deg_to_rad(settings.open_angle) * _swing if open else 0.0
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		_creak.play()
		_tween = create_tween()
		_tween.tween_property(_hinge, "rotation:y", angle, settings.swing_time)
	else:
		_hinge.rotation.y = angle
