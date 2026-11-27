class_name VersusZone
extends RefCounted
## The zone of the Versus (spec S-025, Q6, T-406), pure: a circle around the
## arena's centre that shrinks in steps. Step i starts at zone_step_times[i]
## and takes zone_shrink_time to bring the radius down to
## zone_step_ratios[i] of the start radius. Outside it, a hunted loses a
## point every zone_hunted_tick seconds and the boss zone_boss_share of its
## health each second (VersusMode). Its radius only follows the clock, so
## the room and the clients draw the same zone.

var settings: VersusSettings
## Its centre, on the ground (x, z).
var centre := Vector2.ZERO
## Its radius at the start: the whole arena.
var start_radius := 100.0


func _init(p_settings: VersusSettings, bounds: Rect2) -> void:
	settings = p_settings
	centre = bounds.get_center()
	start_radius = bounds.size.length() * 0.5


## Its radius at clock seconds.
func radius(clock: float) -> float:
	var ratio := 1.0
	for i in settings.zone_step_times.size():
		var start := settings.zone_step_times[i]
		if clock <= start:
			break
		var target := (
			settings.zone_step_ratios[i] if i < settings.zone_step_ratios.size() else ratio
		)
		var t := clampf((clock - start) / maxf(settings.zone_shrink_time, 0.01), 0.0, 1.0)
		ratio = lerpf(ratio, target, t)
	return start_radius * ratio


## Whether point is outside the zone at clock.
func is_outside(point: Vector3, clock: float) -> bool:
	return distance_out(point, clock) > 0.0


## How far point is outside the zone at clock (0 or less: inside).
func distance_out(point: Vector3, clock: float) -> float:
	return Vector2(point.x, point.z).distance_to(centre) - radius(clock)


## Whether from is outside the zone, or will be in ahead seconds of play,
## with margin meters to spare: time for an AI to move in (S-025, T-408).
func must_move_in(from: Vector3, clock: float, ahead := 10.0, margin := 3.0) -> bool:
	return distance_out(from, clock + ahead) > -margin


## A point well inside the zone at clock, on from's side of the centre
## (share of the radius from it), at from's height: where an AI goes.
func inside_point(from: Vector3, clock: float, share := 0.5) -> Vector3:
	var flat := Vector2(from.x, from.z) - centre
	var direction := flat.normalized() if flat.length() > 0.01 else Vector2.RIGHT
	var point := centre + direction * radius(clock) * share
	return Vector3(point.x, from.y, point.y)


## The step under way or next at clock (0 to steps), and seconds until its
## shrinking starts (0 while it shrinks, -1 when no step is left).
func next_step(clock: float) -> Array:
	for i in settings.zone_step_times.size():
		var start := settings.zone_step_times[i]
		if clock < start:
			return [i, start - clock]
		if clock < start + settings.zone_shrink_time:
			return [i, 0.0]
	return [settings.zone_step_times.size(), -1.0]
