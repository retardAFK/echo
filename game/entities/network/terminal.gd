class_name Terminal
extends Node3D
## An old terminal of the cité's network (spec S-018, Q9 to Q12): a beige PC
## on a desk, its green screen toward +Z. A hunted aims at it and holds
## "interact" for sit_time to sit at it: it stands still at the keyboard, the
## keys clack (a KEYBOARD noise now and then) and the screen lights its face.
## A menu then shows what the network offers (CityNetwork.entries_for); the
## hunted leaves with "interact" or by moving.
## The monster holds "interact" on it to switch it off for off_time: whoever
## sits there is thrown off, and nobody uses it until it comes back on.
## A GUARD terminal also opens the cages (T-264); a CODE one, the transformer's
## keypad, only takes a code (T-266).

## Someone sat down at it, or left it.
signal sat(user: Node3D)
signal left(user: Node3D)
## The monster switched it off.
signal switched_off

enum Kind { NORMAL, GUARD, CODE }

const GROUP := &"terminals"
## What the monster may use with "interact" besides doors and hiding spots.
const MONSTER_GROUP := &"monster_usable"
## Where the one at the keyboard stands, in front of the desk (local).
const SEAT := Vector3(0.0, 0.0, 0.75)
const SCREEN_IDLE := Color(0.1, 0.45, 0.2)
const SCREEN_LIT := Color(0.35, 1.0, 0.5)
const SCREEN_OFF := Color(0.02, 0.03, 0.02)
const WOOD := Color(0.32, 0.27, 0.2)
const BEIGE := Color(0.62, 0.58, 0.47)
## Its boxes, merged in one mesh (one draw call): [size, center, color].
const BOXES := [
	[Vector3(1.2, 0.75, 0.6), Vector3(0.0, 0.375, -0.3), WOOD],
	[Vector3(0.46, 0.4, 0.42), Vector3(0.0, 0.95, -0.38), BEIGE],
	[Vector3(0.44, 0.04, 0.16), Vector3(0.0, 0.77, -0.1), BEIGE],
]

@export var settings: NetworkSettings
@export var kind := Kind.NORMAL
## Its name in the network's menus, a translation key.
@export var label_key := ""

## The hunted at its keyboard, or null.
var user: Node3D
## Seconds before it comes back on, 0 when on.
var off_left := 0.0
## Online client: someone sits at it in the room.
var remote_in_use := false
## What it is doing for the one at it, from 0 to 1 (the guard's terminal
## opening the cages, T-264), 0 when nothing.
var progress := 0.0
## Online client: the room's loop and objects decide.
var mirror := false

var _sit: HoldProgress
var _switch: HoldProgress
var _keyboard_left := 0.0
var _screen_material: StandardMaterial3D

@onready var _body: MeshInstance3D = $Body
@onready var _screen: MeshInstance3D = $Screen
@onready var _light: OmniLight3D = $ScreenLight
@onready var _keys: AudioStreamPlayer3D = $Keys


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	add_to_group(GROUP)
	add_to_group(MONSTER_GROUP)
	_body.mesh = _build_body()
	_sit = HoldProgress.new(settings.sit_time)
	_switch = HoldProgress.new(settings.monster_hold)
	_screen_material = _screen.get_surface_override_material(0).duplicate()
	_screen.set_surface_override_material(0, _screen_material)
	_light.omni_range = settings.screen_light_range
	_keys.stream = PlaceholderSounds.keys()
	DrawRange.limit(self, DrawRange.INDOOR)
	_show()


func is_on() -> bool:
	return off_left <= 0.0


func is_in_use() -> bool:
	return user != null or remote_in_use


## Where the one at the keyboard stands, in world space.
func seat_point() -> Vector3:
	return global_transform * SEAT


func can_interact(from: Vector3) -> bool:
	var gap := from - seat_point()
	return Vector2(gap.x, gap.z).length() <= settings.reach and absf(gap.y) < 1.5


## The monster switches it off while on; a free hunted sits at a free one.
func wanted_by(who: Node) -> bool:
	if not is_on():
		return false
	if Door.is_monster(who):
		return true
	return not is_in_use() and CaptureState.is_free_hunted(who)


func get_prompt() -> String:
	return "HUD_INTERACT_TERMINAL" if is_on() and not is_in_use() else ""


func get_prompt_for(who: Node) -> String:
	if Door.is_monster(who):
		return "HUD_MONSTER_SWITCH_OFF" if is_on() else ""
	return get_prompt()


func interact(_who: Node) -> void:
	pass


func hold(who: Node, delta: float) -> void:
	if not wanted_by(who):
		return
	if Door.is_monster(who):
		if _switch.advance(delta):
			switch_off()
	elif _sit.advance(delta):
		sit(who as Node3D)


func release(_who: Node) -> void:
	_sit.release()
	_switch.release()


func get_hold_ratio() -> float:
	return maxf(_sit.get_ratio(), _switch.get_ratio())


## A hunted sits at the keyboard, facing the screen.
func sit(who: Node3D) -> void:
	if user != null or who == null:
		return
	user = who
	_keyboard_left = 0.0  # The first keys at once.
	if "terminal" in who:
		who.terminal = self
	_show()
	sat.emit(who)


## The one at the keyboard leaves (it moved, pressed "interact", was caught,
## or the monster switched the terminal off).
func leave() -> void:
	if user == null:
		return
	var who := user
	user = null
	if "terminal" in who:
		who.terminal = null
	_show()
	left.emit(who)


## The monster switched it off (Q12): off for off_time, nobody at it.
func switch_off() -> void:
	off_left = settings.off_time
	leave()
	_show()
	switched_off.emit()


func _physics_process(delta: float) -> void:
	if mirror:
		return
	if off_left > 0.0:
		off_left = maxf(off_left - delta, 0.0)
		if off_left <= 0.0:
			_show()
	if user == null:
		return
	if not is_instance_valid(user) or not CaptureState.is_free_hunted(user):
		leave()
		return
	_keyboard_left -= delta
	if _keyboard_left <= 0.0:
		_keyboard_left = settings.keyboard_interval
		_keys.play()
		NoiseBus.emit_noise(
			NoiseEvent.Type.KEYBOARD, global_position + Vector3.UP, settings.keyboard_range, user
		)


## Online client: what the room says of it.
func mirror_state(off: bool, in_use: bool) -> void:
	off_left = settings.off_time if off else 0.0
	remote_in_use = in_use
	_show()


## Online client: the keys heard from the room.
func voice() -> void:
	_keys.play()


## The screen: dark when off, bright (and lighting the face before it) when
## used, dim green otherwise.
func _show() -> void:
	if _screen_material == null:
		return
	var color := SCREEN_IDLE
	if not is_on():
		color = SCREEN_OFF
	elif is_in_use():
		color = SCREEN_LIT
	_screen_material.albedo_color = color
	_screen_material.emission = color
	_light.visible = is_on() and is_in_use()


## The desk, the case and the keyboard as one mesh, colored per vertex.
static func _build_body() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box: Array in BOXES:
		var cube := BoxMesh.new()
		cube.size = box[0]
		var arrays := cube.get_mesh_arrays()
		var colors := PackedColorArray()
		colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(box[2])
		arrays[Mesh.ARRAY_COLOR] = colors
		var part := ArrayMesh.new()
		part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		tool.append_from(part, 0, Transform3D(Basis.IDENTITY, box[1]))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	tool.set_material(material)
	return tool.commit()
