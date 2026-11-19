class_name BreathHold
extends RefCounted
## Holding one's breath (S-020, T-311, piste H2): while the key is held, for
## hold_time seconds at most, the hunted's walking steps and its panting are
## silent (nothing for the scan either). Then it must breathe again: no new
## hold for recharge_time seconds, counted from when it let go.
## Hidden with the monster within reach, a hunted who does not hold it
## breathes audibly. Pure, testable alone; the room and the client run the
## same one from the same commands.

var settings: PlayerSettings
## Seconds of hold left in this breath.
var left := 0.0
## Seconds before it can hold its breath again.
var recharge_left := 0.0
var holding := false


func _init(p_settings: PlayerSettings) -> void:
	settings = p_settings
	left = settings.breath_hold_time


## Counts one frame with the key held or not.
func update(delta: float, wanted: bool) -> void:
	if recharge_left > 0.0:
		holding = false
		recharge_left = maxf(recharge_left - delta, 0.0)
		if recharge_left <= 0.0:
			left = settings.breath_hold_time
		return
	if wanted and left > 0.0:
		holding = true
		left = maxf(left - delta, 0.0)
		if left <= 0.0:
			_breathe_out()
	elif holding:
		_breathe_out()


func _breathe_out() -> void:
	holding = false
	left = 0.0
	recharge_left = settings.breath_recharge_time


## 0 to 1: the hold left, or how far the recharge got.
func get_ratio() -> float:
	if recharge_left > 0.0:
		return 1.0 - recharge_left / settings.breath_recharge_time
	return left / settings.breath_hold_time
