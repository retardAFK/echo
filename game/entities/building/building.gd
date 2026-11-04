class_name Building
extends Area3D
## A building the monster can scan (spec S-004, Q3): a box volume around it,
## on the "scan" physics layer so the monster can aim at it.
## T-024 makes its lights flicker while it is scanned.

signal scan_changed(is_scanned: bool)

const SCAN_LAYER := 1 << 4

var scanned := false:
	set(value):
		if value == scanned:
			return
		scanned = value
		scan_changed.emit(value)

@onready var _shape: CollisionShape3D = $CollisionShape3D


## True if a world position lies inside the building's volume.
func contains(point: Vector3) -> bool:
	var box: BoxShape3D = _shape.shape
	var local := _shape.global_transform.affine_inverse() * point
	var half := box.size / 2.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z
