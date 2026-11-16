class_name PrisonRules
extends RefCounted
## The rules of the prison (spec S-018, Q5 and Q6), testable without a scene:
## how long a hunted stays in a cage, when it is out, when the clock runs and
## how the lamp over the cage looks.


## Seconds of stay for a hunted caught this many times.
static func stay_for(catches: int, settings: PrisonSettings) -> float:
	return settings.first_stay if catches <= 1 else settings.second_stay


## Whether a hunted caught this many times is out at once, without a cage.
static func is_out(catches: int, settings: PrisonSettings) -> bool:
	return catches >= settings.catches_out


## Seconds left after delta: the clock stops while the monster is nearer
## than guard_distance (a negative distance: no monster).
static func tick(
	left: float, delta: float, monster_distance: float, settings: PrisonSettings
) -> float:
	if monster_distance >= 0.0 and monster_distance < settings.guard_distance:
		return left
	return maxf(left - delta, 0.0)


## Whether the lamp of an occupied cage is lit: steady, then blinking in the
## last blink_time seconds. time is any running clock, in seconds.
static func lamp_lit(left: float, time: float, settings: PrisonSettings) -> bool:
	if left > settings.blink_time:
		return true
	return fmod(time, settings.blink_period) < settings.blink_period / 2.0
