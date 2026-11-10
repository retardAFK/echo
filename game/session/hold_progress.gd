class_name HoldProgress
extends RefCounted
## Progress of an action done by holding "interact" (spec S-007, Q2 and Q3):
## it fills while held and, when let go before the end, keeps a share of what
## was done (nothing for a fuse box, half for a transformer placement).

## Seconds of holding needed to finish.
var duration: float
## Share of the progress kept when let go, from 0 to 1.
var kept_on_release: float
## Seconds held so far.
var done := 0.0


func _init(p_duration: float, p_kept_on_release := 0.0) -> void:
	duration = p_duration
	kept_on_release = p_kept_on_release


## Holds for delta seconds. Returns true when the action just finished, and
## starts over for the next one.
func advance(delta: float) -> bool:
	done += delta
	if done < duration:
		return false
	done = 0.0
	return true


## Let go before the end.
func release() -> void:
	done *= kept_on_release


func get_ratio() -> float:
	return clampf(done / duration, 0.0, 1.0) if duration > 0.0 else 0.0
