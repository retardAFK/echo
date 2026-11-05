class_name Building
extends Area3D
## A building the monster can scan (spec S-004, Q3): a box volume around it,
## on the "scan" physics layer so the monster can aim at it.
## While it is scanned, its lights (Light3D children) flicker: the hunted's only
## warning, with no message on screen (D-009, T-024).

signal scan_changed(is_scanned: bool)

const SCAN_LAYER := 1 << 4

@export var settings: MonsterSettings
## Size of the box volume, in meters. Set on each building of a map: the shape
## is built from it at load, because an override of an instanced child's shape
## is lost in the exported game (T-028).
@export var size := Vector3.ONE

var scanned := false:
	set(value):
		if value == scanned:
			return
		scanned = value
		if not value:
			_restore_lights()
		scan_changed.emit(value)

var _lights: Array[Light3D] = []
var _energies: Array[float] = []
var _flicker_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	for child in get_children():
		if child is Light3D:
			_lights.append(child)
			_energies.append(child.light_energy)


func _process(delta: float) -> void:
	if not scanned:
		return
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	_flicker_timer = 1.0 / settings.light_flicker_rate
	for i in _lights.size():
		_lights[i].light_energy = _energies[i] * _rng.randf_range(settings.light_flicker_min, 1.0)


func get_lights() -> Array[Light3D]:
	return _lights


## Normal energy of a light, as set in the map.
func get_base_energy(index: int) -> float:
	return _energies[index]


## World transform of the box volume (its center and orientation).
func get_box_transform() -> Transform3D:
	return _shape.global_transform


## True if a world position lies inside the building's volume.
func contains(point: Vector3) -> bool:
	var box: BoxShape3D = _shape.shape
	var local := _shape.global_transform.affine_inverse() * point
	var half := box.size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


func _restore_lights() -> void:
	_flicker_timer = 0.0
	for i in _lights.size():
		_lights[i].light_energy = _energies[i]
