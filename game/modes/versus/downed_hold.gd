class_name DownedHold
extends RefCounted
## Holding interact by a downed hunted (spec S-024, Q5, T-378): a teammate
## revives it (HunterKit), the boss finishes it (BossKit). It keeps the
## hunted held on and for how long; the kit calls update() each frame and
## acts on the hunted it returns.

## The hold started on target (a revive makes a noise).
signal started(target: HunterKit)

## The downed hunted held on, or null.
var target: HunterKit
## Seconds held on it.
var held := 0.0


## The downed hunted nearest to point within reach, other than except, or null.
static func nearest(
	hunters: Array[HunterKit], point: Vector3, reach: float, except: HunterKit = null
) -> HunterKit:
	var best: HunterKit
	var best_distance := reach
	for kit in hunters:
		if kit == except or not kit.vitals.is_down():
			continue
		var distance := kit.body.global_position.distance_to(point)
		if distance <= best_distance:
			best = kit
			best_distance = distance
	return best


## One frame of interact held (pressed) or not, from point. Returns the
## hunted once held on for duration (and starts over), else null.
func update(
	hunters: Array[HunterKit],
	point: Vector3,
	pressed: bool,
	delta: float,
	duration: float,
	reach: float,
	except: HunterKit = null
) -> HunterKit:
	var found := nearest(hunters, point, reach, except) if pressed else null
	if found != target:
		target = found
		held = 0.0
		if found != null:
			started.emit(found)
	if target == null:
		return null
	held += delta
	if held < duration:
		return null
	var done := target
	reset()
	return done


## How far along the hold is, from 0 to 1.
func ratio(duration: float) -> float:
	return clampf(held / duration, 0.0, 1.0) if target != null else 0.0


## Starts over (a blow broke it).
func reset() -> void:
	target = null
	held = 0.0
