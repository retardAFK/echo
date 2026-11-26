class_name FallWatch
extends RefCounted
## Measures the falls of a body (spec S-024, Q34, T-376): call update() each
## physics frame with whether it stands on a floor and its height; it gives
## the height of the fall at the landing, else 0. Pure, for tests.

var _airborne := false
var _top := 0.0


## The height fallen if the body just landed, else 0.
func update(on_floor: bool, height: float) -> float:
	if not on_floor:
		if not _airborne:
			_airborne = true
			_top = height
		_top = maxf(_top, height)
		return 0.0
	if not _airborne:
		return 0.0
	_airborne = false
	return maxf(_top - height, 0.0)


## Forgets the fall under way (the body was moved by hand).
func reset() -> void:
	_airborne = false
