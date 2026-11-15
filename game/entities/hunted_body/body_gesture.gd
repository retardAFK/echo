class_name BodyGesture
extends RefCounted
## A short gesture shown by a body (spec S-011, T-125, T-127): one at a time,
## for its duration. What the hunted or the monster does sets it; its body
## plays it, and online the room sends it with the others' state (NetGame).
## kind is a HuntedBody.Gesture for a hunted, a MonsterBody.Action for the
## monster; 0 is none for both.

var kind := 0

var _left := 0.0


## Shows a gesture for a duration (seconds), in place of the one going on.
func play(value: int, duration: float) -> void:
	kind = value
	_left = duration


## Time goes by; at the end of its duration the gesture stops.
func update(delta: float) -> void:
	if kind == 0:
		return
	_left -= delta
	if _left <= 0.0:
		kind = 0
		_left = 0.0
