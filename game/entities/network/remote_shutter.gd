class_name RemoteShutter
extends Node3D
## A metal shutter of the cité's network (spec S-018, Q11), lowered from a
## terminal: for shutter_time it closes its opening to everyone, sight and
## noise included (a body on the walls' layer), with a SHUTTER noise of
## shutter_range going down and up. It can be lowered again shutter_recharge
## after it went down.
## It stands at the bottom middle of its opening, the opening across its X
## axis, width wide and height high. The navigation mesh does not change: an
## AI finds it on its way with down_ahead(), like a closed door.

const GROUP := &"remote_shutters"
const SOUND := preload("res://assets/audio/interiors/shutter_roll.wav")
const WALLS_LAYER := 2
## The rolled-up shutter in its box, at the top, in meters.
const ROLL_HEIGHT := 0.3
const ROLL_DEPTH := 0.3
const DROP_TIME := 1.2

@export var settings: NetworkSettings
## Its name in the terminals' menus, a translation key.
@export var label_key := ""
@export var width := 2.0
@export var height := 2.8

## Seconds it stays down, 0 when up.
var down_left := 0.0
## Seconds before it can go down again.
var recharge_left := 0.0
## Online client: the room decides.
var mirror := false

var _tween: Tween

@onready var _body: StaticBody3D = $Body
@onready var _shape: CollisionShape3D = $Body/CollisionShape3D
@onready var _curtain: MeshInstance3D = $Curtain
@onready var _roll: MeshInstance3D = $Roll
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	add_to_group(GROUP)
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.1)
	_shape.shape = box
	_shape.position = Vector3(0.0, height / 2.0, 0.0)
	var curtain := BoxMesh.new()
	curtain.size = Vector3(width, height, 0.06)
	_curtain.mesh = curtain
	var roll := BoxMesh.new()
	roll.size = Vector3(width + 0.1, ROLL_HEIGHT, ROLL_DEPTH)
	_roll.mesh = roll
	_roll.position = Vector3(0.0, height + ROLL_HEIGHT / 2.0, 0.0)
	_sound.stream = SOUND
	DrawRange.limit(self, DrawRange.OUTDOOR)
	_show(false, false)


func is_down() -> bool:
	return down_left > 0.0


func is_ready() -> bool:
	return not is_down() and recharge_left <= 0.0


## Lowered from a terminal: true if it was ready.
func lower() -> bool:
	if not is_ready():
		return false
	down_left = settings.shutter_time
	recharge_left = settings.shutter_recharge
	_show(true, true)
	_make_noise()
	return true


func _physics_process(delta: float) -> void:
	if mirror:
		return
	recharge_left = maxf(recharge_left - delta, 0.0)
	if down_left > 0.0:
		down_left = maxf(down_left - delta, 0.0)
		if down_left <= 0.0:
			_show(false, true)
			_make_noise()


func _make_noise() -> void:
	NoiseBus.emit_noise(
		NoiseEvent.Type.SHUTTER, global_position + Vector3.UP, settings.shutter_range, self
	)


## Online client: what the room says of it.
func mirror_state(down: bool, recharge: float) -> void:
	recharge_left = recharge
	if down != is_down():
		down_left = settings.shutter_time if down else 0.0
		_show(down, true)


## Online client: its rattle heard from the room.
func voice() -> void:
	SoundSpace.play(_sound)


## Down, it blocks and hides; up, only its box shows.
func _show(down: bool, animate: bool) -> void:
	_body.collision_layer = WALLS_LAYER if down else 0
	_shape.disabled = not down
	if animate and is_inside_tree():
		SoundSpace.play(_sound)
	if _tween != null:
		_tween.kill()
	var scale_y := 1.0 if down else 0.02
	_curtain.visible = true
	if not animate or not is_inside_tree():
		_set_drop(scale_y)
		_curtain.visible = down
		return
	_tween = create_tween()
	_tween.tween_method(_set_drop, _curtain.scale.y, scale_y, DROP_TIME)
	if not down:
		_tween.tween_callback(func() -> void: _curtain.visible = false)


## The curtain hangs from the roll, this share of the way down.
func _set_drop(share: float) -> void:
	_curtain.scale.y = share
	_curtain.position = Vector3(0.0, height * (1.0 - share / 2.0), 0.0)


## The shutter down across the way of a body walking from `from` along
## `direction` within `reach` meters, or null.
static func down_ahead(
	tree: SceneTree, from: Vector3, direction: Vector3, reach: float
) -> RemoteShutter:
	var flat := Vector2(direction.x, direction.z)
	if flat.length() < 0.01:
		return null
	flat = flat.normalized()
	for node in tree.get_nodes_in_group(GROUP):
		var shutter := node as RemoteShutter
		if not shutter.is_down():
			continue
		var local := shutter.global_transform.affine_inverse() * from
		var ahead := shutter.global_basis.inverse() * Vector3(flat.x, 0.0, flat.y)
		if absf(ahead.z) < 0.01 or signf(ahead.z) == signf(local.z):
			continue  # Walking along it, or away from it.
		var steps := -local.z / ahead.z
		var cross := local.x + ahead.x * steps
		if steps <= reach and absf(cross) <= shutter.width / 2.0 + 0.4:
			if absf(local.y) < shutter.height:
				return shutter
	return null
