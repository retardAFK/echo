class_name BossLeap
extends RefCounted
## The Versus boss's leap (spec S-024, Q9, T-379), from phase 2: it jumps in
## an arc onto a noise it heard (an orange mark), its shadow shows on the
## ground where it lands for the whole jump, and the landing sends out a
## shock wave. Pure but for the noises it is told of; BossKit drives it.

var settings: VersusSettings
## Noises of the hunted it heard lately: {"at": Vector3, "age": float}.
var heard: Array[Dictionary] = []
## Seconds before it may leap again.
var wait := 0.0
## While leaping: where from, where to, seconds in the air.
var from := Vector3.ZERO
var to := Vector3.ZERO
var flown := 0.0
var leaping := false


func _init(versus: VersusSettings) -> void:
	settings = versus


## A hunted made a noise at point.
func hear(point: Vector3) -> void:
	heard.append({"at": point, "age": 0.0})


## Counts delta seconds: old noises fade, the wait runs down.
func update(delta: float) -> void:
	wait = maxf(wait - delta, 0.0)
	for each in heard:
		each["age"] += delta
	heard = heard.filter(
		func(each: Dictionary) -> bool: return each["age"] <= settings.leap_noise_memory
	)


## The heard noise it may leap onto from origin, the one nearest the line of
## aim (a unit vector; zero: the one nearest to near). Null if none.
func pick(origin: Vector3, aim := Vector3.ZERO, near := Vector3.INF) -> Variant:
	var best: Variant = null
	var best_score := -INF
	for each in heard:
		var point: Vector3 = each["at"]
		var offset := point - origin
		var distance := Vector2(offset.x, offset.z).length()
		if distance < settings.leap_min_distance or distance > settings.leap_range:
			continue
		var score := -point.distance_to(near) if aim == Vector3.ZERO else aim.dot(offset / distance)
		if aim != Vector3.ZERO and score < settings.leap_aim_cos:
			continue
		if score > best_score:
			best = point
			best_score = score
	return best


## Starts the leap from start onto target.
func start(start_at: Vector3, target: Vector3) -> void:
	from = start_at
	to = target
	flown = 0.0
	leaping = true
	wait = settings.leap_cooldown


## One frame of the leap: where the body is now. Ends the leap at the end.
func fly(delta: float) -> Vector3:
	flown = minf(flown + delta, settings.leap_time)
	var t := flown / settings.leap_time
	var point := from.lerp(to, t)
	point.y += 4.0 * settings.leap_height * t * (1.0 - t)  # The arc.
	if t >= 1.0:
		leaping = false
	return point
