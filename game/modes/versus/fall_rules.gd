class_name FallRules
extends RefCounted
## Falls in the Versus (spec S-024, Q34, T-376): what a fall from a roof
## costs a hunted or the boss. Pure, so tests need no physics. FallWatch
## measures the falls.


## Points a hunted loses for a fall of height meters (before a roll);
## a fall past fall_down_height takes them all (full_health).
static func hunted_damage(settings: VersusSettings, height: float, full_health: int) -> int:
	if height < settings.fall_safe_height:
		return 0
	if height > settings.fall_down_height:
		return full_health
	return 1 if height <= settings.fall_hurt_height else 2


## Points a dodge roll at the landing leaves (never below 0; a fall that
## puts down keeps putting down).
static func after_roll(settings: VersusSettings, damage: int, height: float) -> int:
	if height > settings.fall_down_height:
		return damage
	return maxi(damage - settings.fall_roll_saving, 0)


## Health the boss loses for a fall of height meters, out of max_health.
static func boss_damage(settings: VersusSettings, height: float, max_health: float) -> float:
	if height <= settings.fall_hurt_height:
		return 0.0
	return max_health * settings.boss_fall_ratio


## Whether a fall of height meters is heard (Q34).
static func is_loud(settings: VersusSettings, height: float) -> bool:
	return height >= settings.fall_safe_height
