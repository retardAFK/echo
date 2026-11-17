class_name ScanGauge
extends RefCounted
## The monster's concentration gauge for the building scan (spec S-004, Q3,
## D-009): a few seconds of scan in total, recharged slowly, which cannot start
## below a minimum. A scan begins with a short concentration before the
## building can be heard. Pure logic, testable without a scene.

## Remaining scan time, in seconds (0 to settings.scan_capacity).
var level: float
var active := false

var _settings: MonsterSettings
var _focus_left := 0.0


func _init(settings: MonsterSettings) -> void:
	_settings = settings
	level = settings.scan_capacity


## Gauge level from 0 (empty) to 1 (full).
func get_ratio() -> float:
	return level / _settings.scan_capacity


func can_start() -> bool:
	return not active and get_ratio() >= _settings.scan_min_start


## Starts a scan if the gauge allows it. Returns whether it started.
func start() -> bool:
	if not can_start():
		return false
	active = true
	_focus_left = _settings.scan_focus_time
	return true


func stop() -> void:
	active = false


## How far the concentration has gone, from 0 (not scanning) to 1 (listening).
func get_focus_ratio() -> float:
	if not active:
		return 0.0
	if _settings.scan_focus_time <= 0.0:
		return 1.0
	return clampf(1.0 - _focus_left / _settings.scan_focus_time, 0.0, 1.0)


## True once the concentration is over: the building can be heard.
func is_listening() -> bool:
	return active and _focus_left <= 0.0


## Drains while scanning (concentration included), recharges otherwise.
## Stops the scan when the gauge is empty.
func update(delta: float) -> void:
	if not active:
		level = minf(
			level + delta * _settings.scan_capacity / _settings.scan_recharge_time,
			_settings.scan_capacity
		)
		return
	_focus_left -= delta
	level = maxf(level - delta, 0.0)
	if level <= 0.0:
		stop()
