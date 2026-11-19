class_name BreathBar
extends CanvasLayer
## The hunted's held breath (S-020, T-311), above its noise gauge: pale while
## it holds its breath and the time runs out, grey while it recharges.

const WIDTH := 100.0
const READY_COLOR := Color(0.55, 0.62, 0.66)
const HOLDING_COLOR := Color(0.75, 0.85, 0.9)
const RECHARGE_COLOR := Color(0.3, 0.3, 0.3)

var breath: BreathHold

var _fill: ColorRect


func _init(p_breath: BreathHold = null) -> void:
	breath = p_breath
	layer = 10
	name = "BreathBar"


func _ready() -> void:
	var label := Label.new()
	label.theme = preload("res://game/ui/theme/echo_theme.tres")
	label.theme_type_variation = &"HudLabel"
	label.text = "HUD_BREATH"
	SprintBar.place(label, Rect2(8, -40, 44, 14))
	add_child(label)
	var bar := ColorRect.new()
	bar.color = Color(0.15, 0.15, 0.15, 0.8)
	SprintBar.place(bar, Rect2(56, -36, WIDTH, 6))
	add_child(bar)
	_fill = ColorRect.new()
	_fill.size = Vector2(WIDTH, 6)
	bar.add_child(_fill)


func _process(_delta: float) -> void:
	if breath == null:
		return
	if breath.recharge_left > 0.0:
		_fill.color = RECHARGE_COLOR
	else:
		_fill.color = HOLDING_COLOR if breath.holding else READY_COLOR
	_fill.size.x = WIDTH * breath.get_ratio()


## Share of the bar filled, for the tests.
func get_fill() -> float:
	return _fill.size.x / WIDTH
