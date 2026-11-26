class_name PreyFighter
extends RefCounted
## Where an AI hunted goes in the Versus (spec S-024, Q17, T-383), pure: no
## nodes. Its Prey keeps its own legs (it walks, flees the boss and hides as
## in the Hunt); HunterKit asks this where to go now and sends it there, and
## shoots by itself when it sees the boss.
## - A downed teammate first, when the boss is far from it (ai_revive_safe).
## - Unarmed, the nearest chest worth opening; armed, one within
##   ai_chest_detour, when the boss is far from it (ai_chest_safe).
## - Else, with no teammate within ai_regroup_distance, the nearest
##   standing one: together, they cover each other and revive.
## - A goal it does not reach in ai_goal_time is left aside for good (a
##   chest it cannot reach, say).
## It also says when to roll away: the boss winding up a blow at it.

enum Goal { NONE, REVIVE, CHEST, REGROUP }

var settings: VersusSettings
## Where it goes, with goal.
var goal := Goal.NONE
var point := Vector3.ZERO
## Seconds left to reach point before it gives it up.
var goal_left := 0.0
## The points it gave up.
var given_up: Array[Vector3] = []


func _init(p_settings: VersusSettings) -> void:
	settings = p_settings


## Chooses its goal from where it is (own), the boss (boss_at), the downed
## and the standing teammates (mates) and the chests worth opening, armed or
## not. Returns the goal; point says where.
func choose(
	own: Vector3,
	boss_at: Vector3,
	downed: Array[Vector3],
	chests: Array[Vector3],
	armed: bool,
	mates: Array[Vector3] = []
) -> Goal:
	var best: Variant = _nearest(own, downed, boss_at, settings.ai_revive_safe, INF)
	if best != null:
		return _go(Goal.REVIVE, best)
	var reach := INF if not armed else settings.ai_chest_detour
	var safe := 0.0 if not armed else settings.ai_chest_safe
	best = _nearest(own, chests, boss_at, safe, reach)
	if best != null:
		return _go(Goal.CHEST, best)
	best = _nearest(own, mates, boss_at, 0.0, INF)
	if best != null and own.distance_to(best) > settings.ai_regroup_distance:
		return _go(Goal.REGROUP, best)
	goal = Goal.NONE
	return goal


## Time passes on the way; past ai_goal_time, the goal is given up.
func update(delta: float) -> void:
	if goal == Goal.NONE:
		return
	goal_left -= delta
	if goal_left <= 0.0:
		given_up.append(point)
		goal = Goal.NONE


## Whether to roll away now: the boss winds up a claw within reach (plus a
## step), or a charge it is in line for.
func should_dodge(claw_windup: bool, charge_windup: bool, distance: float) -> bool:
	if claw_windup:
		return distance <= settings.claw_reach + settings.ai_dodge_margin
	return charge_windup and distance <= settings.charge_distance


func _go(new_goal: Goal, at: Vector3) -> Goal:
	if new_goal != goal or at.distance_to(point) > 0.5:
		goal_left = settings.ai_goal_time
	goal = new_goal
	point = at
	return goal


## The nearest of points within reach of own, not given up, and with the
## boss at least safe metres from it; null when none.
func _nearest(
	own: Vector3, points: Array[Vector3], boss_at: Vector3, safe: float, reach: float
) -> Variant:
	var best: Variant = null
	var best_distance := reach
	for each in points:
		if _is_given_up(each) or each.distance_to(boss_at) < safe:
			continue
		var distance := own.distance_to(each)
		if distance <= best_distance:
			best = each
			best_distance = distance
	return best


func _is_given_up(at: Vector3) -> bool:
	for each in given_up:
		if each.distance_to(at) < 0.5:
			return true
	return false
