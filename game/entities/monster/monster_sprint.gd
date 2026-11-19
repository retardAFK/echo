class_name MonsterSprint
extends RefCounted
## The monster's run as a gauge (S-020, T-309, piste E2): run_speed for
## sprint_time seconds of running, then out of breath for winded_time seconds
## where it runs at winded_speed only, slower than a sprinting hunted, so a
## long chase is no longer lost in advance. Walking refills the gauge.
## The AI monster and the played one both hold one; pure, testable alone.

var settings: MonsterSettings
## Seconds of full-speed run left.
var charge := 0.0
## Seconds it stays out of breath.
var winded_left := 0.0


func _init(p_settings: MonsterSettings) -> void:
	settings = p_settings
	charge = settings.sprint_time


## Counts one frame: running drains the gauge, else it refills.
func update(delta: float, running: bool) -> void:
	if winded_left > 0.0:
		winded_left -= delta
		if winded_left <= 0.0:
			winded_left = 0.0
			charge = settings.sprint_time
		return
	if running:
		charge -= delta
		if charge <= 0.0:
			charge = 0.0
			winded_left = settings.winded_time
	else:
		charge = minf(charge + delta * settings.sprint_refill, settings.sprint_time)


func is_winded() -> bool:
	return winded_left > 0.0


## Speed of a run now.
func run_speed() -> float:
	return settings.winded_speed if is_winded() else settings.run_speed


## Share of the gauge left, 0 to 1 (0 while out of breath).
func get_ratio() -> float:
	return 0.0 if is_winded() else charge / settings.sprint_time
