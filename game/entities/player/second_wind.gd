class_name SecondWind
extends RefCounted
## The hunted's second wind (S-020, T-338, piste E5): once per
## second_wind_recharge, a burst of second_wind_time seconds at
## second_wind_speed, very loud (each step and the gasp heard at
## second_wind_range). Pure, testable alone; the room and the client run the
## same one from the same commands, so the prediction keeps up.

var settings: PlayerSettings
## Seconds of burst left; above 0 while it runs.
var left := 0.0
## Seconds before the next one can start.
var recharge_left := 0.0


func _init(p_settings: PlayerSettings) -> void:
	settings = p_settings


func is_active() -> bool:
	return left > 0.0


func is_ready() -> bool:
	return recharge_left <= 0.0 and not is_active()


## Starts a burst if it is ready. Returns whether it started.
func start() -> bool:
	if not is_ready():
		return false
	left = settings.second_wind_time
	recharge_left = settings.second_wind_recharge
	return true


func update(delta: float) -> void:
	left = maxf(left - delta, 0.0)
	recharge_left = maxf(recharge_left - delta, 0.0)


## 0 to 1: the burst left while it runs, else how far the recharge got.
func get_ratio() -> float:
	if is_active():
		return left / settings.second_wind_time
	if settings.second_wind_recharge <= 0.0:
		return 1.0
	return 1.0 - recharge_left / settings.second_wind_recharge
