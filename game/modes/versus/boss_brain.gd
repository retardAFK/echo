class_name BossBrain
extends RefCounted
## The AI boss's fighting choices (spec S-024, Q12, T-382), pure: no nodes,
## so that tests and simulations can ask it directly. BossKit gives it what
## its Monster sees and does what it chooses, with the same rules and numbers
## as the played boss.
## - Its target: the nearest standing hunted, unless one that hurt it more
##   is barely farther (brain_grudge_margin): it goes for that one.
## - Claws a target in reach; leaps onto a lone shooter (no teammate within
##   brain_lone_distance) whose noise it heard (phase 2+); charges a target
##   6 to 14 m away in a clear line; else throws a fireball at a target in
##   sight between fireball_min_distance and fireball_range (S-025, T-413).
## - Backs off (brain_retreat_time) when its poise is nearly full
##   (brain_retreat_poise), before it would kneel.
## - The Fury: BossKit starts it as soon as it can.

## What it chooses this frame.
enum Act { WAIT, CLAW, CHARGE, LEAP, RETREAT, FIREBALL }

var settings: VersusSettings
## Seconds left of backing off, while it does not attack.
var retreat_left := 0.0


func _init(p_settings: VersusSettings) -> void:
	settings = p_settings


func update(delta: float) -> void:
	retreat_left = maxf(retreat_left - delta, 0.0)


func is_retreating() -> bool:
	return retreat_left > 0.0


## Its choice against its target at distance (flat), in sight or not;
## lone_leap says a leap onto a lone shooter is ready; poise_ratio is its
## poise over its maximum; fire_ready says a fireball is ready.
func choose(
	distance: float, sees: bool, lone_leap: bool, poise_ratio: float, fire_ready := false
) -> Act:
	if is_retreating():
		return Act.WAIT
	if poise_ratio >= settings.brain_retreat_poise and distance <= settings.charge_distance:
		retreat_left = settings.brain_retreat_time
		return Act.RETREAT
	if distance <= settings.claw_reach * 0.9:
		return Act.CLAW
	if lone_leap:
		return Act.LEAP
	if sees and distance >= settings.charge_min_distance and distance <= settings.charge_distance:
		return Act.CHARGE
	var in_range := (
		distance >= settings.fireball_min_distance and distance <= settings.fireball_range
	)
	return Act.FIREBALL if sees and fire_ready and in_range else Act.WAIT


## Its target among the standing hunted (each with its place and the damage
## it dealt): the nearest, or one that hurt it more within the grudge margin.
## Returns the index in places, or -1 when none.
func pick_target(origin: Vector3, places: Array[Vector3], damage: Array[float]) -> int:
	var nearest := -1
	for i in places.size():
		if nearest < 0 or _flat(origin, places[i]) < _flat(origin, places[nearest]):
			nearest = i
	if nearest < 0:
		return -1
	var best := nearest
	var reach := _flat(origin, places[nearest]) + settings.brain_grudge_margin
	for i in places.size():
		if _flat(origin, places[i]) <= reach and damage[i] > damage[best]:
			best = i
	return best


## Whether the hunted at index stands alone: no other within lone distance.
func is_lone(index: int, places: Array[Vector3]) -> bool:
	for i in places.size():
		if i != index and _flat(places[i], places[index]) < settings.brain_lone_distance:
			return false
	return true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
