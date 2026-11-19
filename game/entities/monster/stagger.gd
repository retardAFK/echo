class_name Stagger
extends RefCounted
## The monster stopped short for a moment (S-020): a door it smashed open on
## the run (T-307, piste E1), a gurney it knocked over on the run (T-308,
## piste E3), an empty hiding spot it opened (T-310, piste H1). The AI
## monster and the played one both hold one; online, the room sends its own.

## Seconds it still stands stopped.
var left := 0.0
## Stops so far: online, a client compares the room's with its own to know
## whether the room stopped it for something it could not predict.
var count := 0


## Stops it for duration seconds, never shortening a longer stop.
func hit(duration: float) -> void:
	if left <= 0.0:
		count += 1
	left = maxf(left, duration)


## Counts one frame down; true while it is stopped.
func update(delta: float) -> bool:
	if left <= 0.0:
		return false
	left = maxf(left - delta, 0.0)
	return true


## Stops user, an AI or played monster, if it has a Stagger.
static func hit_on(user: Node, duration: float) -> void:
	if user != null and "stagger" in user and user.stagger is Stagger:
		(user.stagger as Stagger).hit(duration)
