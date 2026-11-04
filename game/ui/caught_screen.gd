class_name CaughtScreen
extends CanvasLayer
## "Caught" screen (spec S-003, Q4): shown for a few seconds after a catch.

var _time_left := 0.0


func _ready() -> void:
	visible = false


func show_for(duration: float) -> void:
	_time_left = duration
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
