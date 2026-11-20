class_name SecondWindBar
extends CanvasLayer
## The hunted's second wind (S-020, T-338), above its breath bar: bright and
## emptying during the burst, grey while it recharges, full when ready.

const WIDTH := 100.0
const READY_COLOR := Color(0.78, 0.62, 0.3)
const ACTIVE_COLOR := Color(0.95, 0.8, 0.4)
const RECHARGE_COLOR := Color(0.3, 0.3, 0.3)

var second_wind: SecondWind

var _fill: ColorRect


func _init(p_second_wind: SecondWind = null) -> void:
	second_wind = p_second_wind
	layer = 10
	name = "SecondWindBar"


func _ready() -> void:
	var label := Label.new()
	label.theme = preload("res://game/ui/theme/echo_theme.tres")
	label.theme_type_variation = &"HudLabel"
	label.text = "HUD_SECOND_WIND"
	SprintBar.place(label, Rect2(8, -58, 44, 14))
	add_child(label)
	var bar := ColorRect.new()
	bar.color = Color(0.15, 0.15, 0.15, 0.8)
	SprintBar.place(bar, Rect2(56, -54, WIDTH, 6))
	add_child(bar)
	_fill = ColorRect.new()
	_fill.size = Vector2(WIDTH, 6)
	bar.add_child(_fill)


func _process(_delta: float) -> void:
	if second_wind == null:
		return
	if second_wind.is_active():
		_fill.color = ACTIVE_COLOR
	else:
		_fill.color = READY_COLOR if second_wind.is_ready() else RECHARGE_COLOR
	_fill.size.x = WIDTH * second_wind.get_ratio()


## Share of the bar filled, for the tests.
func get_fill() -> float:
	return _fill.size.x / WIDTH
