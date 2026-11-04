class_name CaughtScreen
extends CanvasLayer
## "Caught" screen (spec S-003, Q4): shown for a few seconds after a catch.
## The monster role shows "Caught" for the prey instead (S-004, Q6).

var _time_left := 0.0


func _ready() -> void:
	visible = false


func show_for(duration: float, text_key := "HUD_CAUGHT") -> void:
	$Label.text = text_key
	_time_left = duration
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
