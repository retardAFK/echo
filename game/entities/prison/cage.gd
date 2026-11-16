class_name Cage
extends Node3D
## One cage of the prison (spec S-018, Q1 to Q5): a cellar cage whose grille
## has a gate. It stands on the line of the grille, in the middle of the
## gate, the inside toward -Z. The gate, hinged at its west side, swings out
## to +Z.
## Closed, it stops bodies like the rest of the grille. A lamp over the gate
## is lit while someone waits inside, and blinks in its last seconds.
## The Prison decides who goes in and when it opens; the cage shows it.
## Occupied, it is something to use (Interactable): a free teammate holds
## "interact" at the grille to free the one inside. On the room it hands the
## hold to the occupant's CaptureState; on a client it only shows the prompt.

## The gate: width, height, where its hinge stands, in meters.
const GATE_SIZE := Vector3(1.4, 2.8, 0.05)
const GATE_HINGE_X := -0.7
## Where the one inside waits, and where a teammate stands to free it (local).
const INSIDE := Vector3(0.0, 0.0, -0.6)
const OUTSIDE := Vector3(0.0, 0.0, 0.6)
const LAMP_AT := Vector3(0.0, 2.55, -0.15)
const OPEN_TIME := 0.4
const LAMP_LIGHT := Color(1.0, 0.92, 0.65)
const SOUND_GATE := preload("res://assets/audio/network/cage_gate.wav")

@export var settings: PrisonSettings

## Who waits inside, or null; its seat online, -1 if none.
var occupant: Node3D
var occupant_seat := -1
## Seconds before the one inside is out.
var time_left := 0.0
var is_open := false

var _lamp_material: StandardMaterial3D
var _tween: Tween
var _clock := 0.0

@onready var _hinge: Node3D = $Hinge
@onready var _shape: CollisionShape3D = $Hinge/Gate/CollisionShape3D
@onready var _gate_mesh: Node3D = $Hinge/Gate/Mesh
@onready var _lamp: Node3D = $Lamp
@onready var _creak: AudioStreamPlayer3D = $Creak


func _ready() -> void:
	_hinge.position = Vector3(GATE_HINGE_X, 0.0, 0.0)
	var box := BoxShape3D.new()
	box.size = GATE_SIZE
	_shape.shape = box
	_shape.position = Vector3(GATE_SIZE.x / 2.0, GATE_SIZE.y / 2.0, 0.0)
	_gate_mesh.position = _shape.position
	_lamp.position = LAMP_AT
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.emission = LAMP_LIGHT
	_lamp_material.emission_energy_multiplier = 2.0
	for mesh: MeshInstance3D in _lamp.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _lamp_material
	_show_lamp(false)
	DrawRange.limit(self, DrawRange.INDOOR)
	add_to_group(Interactable.GROUP)


func is_free() -> bool:
	return occupant == null


## Where the one inside waits, in world space.
func inside_point() -> Vector3:
	return global_transform * INSIDE


## Where a teammate stands to open it, in world space.
func outside_point() -> Vector3:
	return global_transform * OUTSIDE


## The yaw of someone inside facing the corridor.
func inside_yaw() -> float:
	return global_rotation.y


## Someone goes in for this many seconds; the gate shuts.
func lock(hunted: Node3D, seat: int, seconds: float) -> void:
	occupant = hunted
	occupant_seat = seat
	time_left = seconds
	set_open(false)


## Nobody inside any more: freed (the gate opens) or out (it stays shut).
func empty(open: bool) -> void:
	occupant = null
	occupant_seat = -1
	time_left = 0.0
	if open:
		set_open(true)


## Swings the gate, with its creak when it moves.
func set_open(open: bool, sound := true) -> void:
	if open == is_open:
		return
	is_open = open
	if sound and is_inside_tree():
		_creak.stream = SOUND_GATE
		_creak.play()
	if _tween != null:
		_tween.kill()
	var yaw := -PI / 2.0 if open else 0.0
	# Open, nothing snags on it; shut, it stops bodies.
	_shape.set_deferred(&"disabled", open)
	if not is_inside_tree():
		_hinge.rotation.y = yaw
		return
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation:y", yaw, OPEN_TIME)


func _process(delta: float) -> void:
	_clock += delta
	_show_lamp(occupant_seat >= 0 or occupant != null)


func _show_lamp(occupied: bool) -> void:
	var lit := occupied and PrisonRules.lamp_lit(time_left, _clock, settings)
	_lamp_material.emission_enabled = lit
	_lamp_material.albedo_color = Color(0.9, 0.85, 0.6) if lit else Color(0.15, 0.15, 0.14)


## Online client: what the room says of this cage.
func mirror(seat: int, open: bool, seconds: float) -> void:
	occupant_seat = seat
	time_left = seconds
	set_open(open)


func is_occupied() -> bool:
	return occupant != null or occupant_seat >= 0


func _capture() -> CaptureState:
	return occupant.get("capture") if occupant != null else null


func get_prompt() -> String:
	return "HUD_INTERACT_FREE_CAGE" if is_occupied() and not is_open else ""


func can_interact(from: Vector3) -> bool:
	if not is_occupied() or is_open:
		return false
	var gap := from - outside_point()
	return Vector2(gap.x, gap.z).length() <= settings.free_reach and absf(gap.y) < 2.0


## Only a free hunted outside frees the one inside.
func wanted_by(user: Node) -> bool:
	if user == occupant or not CaptureState.is_free_hunted(user):
		return false
	return not (user is Player and (user as Player).held)


func interact(_user: Node) -> void:
	pass


func hold(user: Node, delta: float) -> void:
	var capture := _capture()
	if capture != null:
		capture.hold(user, delta)


func release(user: Node) -> void:
	var capture := _capture()
	if capture != null:
		capture.release(user)


func get_hold_ratio() -> float:
	var capture := _capture()
	return capture.get_hold_ratio() if capture != null else 0.0


func is_lamp_lit() -> bool:
	return _lamp_material.emission_enabled
