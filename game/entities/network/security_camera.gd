class_name SecurityCamera
extends Node3D
## A security camera of the cité's network (spec S-018, Q11): a small box on
## a wall or a ceiling, looking along -Z. A hunted at a terminal (or in a
## cage) watches through it: its view moves to the lens (Player.watching),
## shown green and coarse (SecurityFeed). While someone watches, a red LED is
## lit under the lens, which the monster can see.
## The monster holds "interact" under it for monster_hold to smash it: a
## CAMERA noise, and it is dead for the rest of the game.
## The CityNetwork says who watches it; the camera only shows it.

const GROUP := &"security_cameras"
const LED_ON := Color(1.0, 0.08, 0.05)
const LED_OFF := Color(0.12, 0.03, 0.03)
const SOUND_SMASH := preload("res://assets/audio/network/camera_break.wav")
## What blocks its view: the walls (layer 2), like a player's eyes.
const SIGHT_MASK := 2

@export var settings: NetworkSettings
## Its name in the terminals' menus, a translation key.
@export var label_key := ""

## How many watch through it (on a client: 1 when the room says it is lit).
var watchers := 0
var broken := false

var _smash: HoldProgress
var _led_material: StandardMaterial3D

@onready var _lens: Node3D = $Lens
@onready var _led: MeshInstance3D = $Led
@onready var _body: Node3D = $Body
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)
	add_to_group(Terminal.MONSTER_GROUP)
	_smash = HoldProgress.new(settings.monster_hold)
	_led_material = _led.get_surface_override_material(0).duplicate()
	_led.set_surface_override_material(0, _led_material)
	DrawRange.limit(self, DrawRange.INDOOR)  # Small: unseen further.
	_show()


## Where a watcher's eyes go: the lens, looking where the camera looks.
func eye_transform() -> Transform3D:
	return _lens.global_transform


func eye_position() -> Vector3:
	return _lens.global_position


func is_watched() -> bool:
	return watchers > 0 and not broken


## Whether it sees a point (a body's eyes): in range, in its field of view,
## no wall between. exclude: bodies the ray ignores.
func sees(point: Vector3, exclude: Array[RID] = []) -> bool:
	if broken:
		return false
	var eye := eye_position()
	var gap := point - eye
	if gap.length() > settings.camera_sight or gap.length() < 0.01:
		return gap.length() < 0.01
	var forward := -_lens.global_basis.z
	if forward.angle_to(gap) > deg_to_rad(settings.camera_fov) / 2.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The monster under it, close enough to reach up.
func can_interact(from: Vector3) -> bool:
	if broken:
		return false
	var gap := global_position - from
	return Vector2(gap.x, gap.z).length() <= settings.camera_reach and gap.y > -1.0 and gap.y < 4.5


## Only the monster uses it, and only once.
func wanted_by(who: Node) -> bool:
	return not broken and Door.is_monster(who)


func get_prompt() -> String:
	return ""


func get_prompt_for(who: Node) -> String:
	return "HUD_MONSTER_SMASH_CAMERA" if wanted_by(who) else ""


func interact(_who: Node) -> void:
	pass


func hold(who: Node, delta: float) -> void:
	if wanted_by(who) and _smash.advance(delta):
		smash(who)


func release(_who: Node) -> void:
	_smash.release()


func get_hold_ratio() -> float:
	return _smash.get_ratio()


## Smashed by the monster: a CAMERA noise, dead for the game. The network
## sends its watchers back to their eyes.
func smash(who: Node = null) -> void:
	if broken:
		return
	broken = true
	_play_smash()
	NoiseBus.emit_noise(NoiseEvent.Type.CAMERA, global_position, settings.smash_range, who)
	_show()


## Online client: what the room says of it.
func mirror_state(watched: bool, is_broken: bool) -> void:
	watchers = 1 if watched else 0
	if is_broken and not broken:
		broken = true
		_play_smash()
	_show()


## Online client: the sound of a smash heard from the room.
func voice() -> void:
	_play_smash()


func set_watchers(count: int) -> void:
	watchers = count
	_show()


func is_led_lit() -> bool:
	return _led_material.emission_enabled


func _play_smash() -> void:
	if is_inside_tree() and not _sound.playing:
		_sound.stream = SOUND_SMASH
		SoundSpace.play(_sound)


## The LED lit while watched; smashed, the body hangs askew and dark.
func _show() -> void:
	if _led_material == null:
		return
	var lit := is_watched()
	_led_material.emission_enabled = lit
	_led_material.albedo_color = LED_ON if lit else LED_OFF
	_led.visible = lit  # Off, no draw call for it.
	if broken:
		_body.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(20.0), 0.0)
