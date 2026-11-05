class_name ScanLook
extends Node
## What the monster sees while it scans a building (spec S-005, Q5, T-032):
## everything outside the building darkens and loses its colors, the building's
## edges light up in pale white and a pale wave leaves it every second.
## The revealed noises stay orange: they are drawn by the HUD, above all this.

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")
@export var monster: MonsterAvatar
@export var night: NightEnvironment

## 0 without scan, 1 while scanning, faded in between.
var amount := 0.0
## Phase of the current wave, from 0 to 1.
var wave := 0.0

## Last scanned building, kept while the look fades out.
var _building: Building
var _wave_time := 0.0


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if monster.scan_target != null:
		_building = monster.scan_target
	var target := 1.0 if monster.scan_target != null else 0.0
	var step := delta / settings.scan_fade_time if settings.scan_fade_time > 0.0 else 1.0
	var previous := amount
	amount = move_toward(amount, target, step)
	if amount == 0.0:
		_wave_time = 0.0
		if previous > 0.0:
			_send()
		return
	_wave_time = fmod(_wave_time + delta, settings.scan_wave_interval)
	wave = _wave_time / settings.scan_wave_interval
	_send()


func _send() -> void:
	RetroSurface.set_scan(_building, amount, wave, settings)
	if night != null:
		night.set_scan_amount(amount)


func _exit_tree() -> void:
	# Leaves the shared materials clean for the next map.
	RetroSurface.set_scan(null, 0.0, 0.0, settings)
