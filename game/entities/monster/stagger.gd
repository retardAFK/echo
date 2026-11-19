class_name Stagger
extends RefCounted
## The monster stopped short for a moment (S-020): a door it smashed open on
## the run (T-307, piste E1). The AI monster and the played one both hold one.

## Seconds it still stands stopped.
var left := 0.0


## Stops it for duration seconds, never shortening a longer stop.
func hit(duration: float) -> void:
	left = maxf(left, duration)


## Counts one frame down; true while it is stopped.
func update(delta: float) -> bool:
	if left <= 0.0:
		return false
	left -= delta
	return true


## Stops user, an AI or played monster, if it has a Stagger.
static func hit_on(user: Node, duration: float) -> void:
	if user != null and "stagger" in user and user.stagger is Stagger:
		(user.stagger as Stagger).hit(duration)
