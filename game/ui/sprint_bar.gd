class_name SprintBar
extends CanvasLayer
## The played monster's run gauge (S-020, T-309), bottom left where the
## hunted has its noise gauge: full, it runs flat out; empty, it is out of
## breath and the bar turns grey until it is full again.

const WIDTH := 100.0
const FULL_COLOR := Color(0.55, 0.12, 0.12)
const WINDED_COLOR := Color(0.35, 0.35, 0.35)

var sprint: MonsterSprint

var _fill: ColorRect


func _init(p_sprint: MonsterSprint = null) -> void:
	sprint = p_sprint
	layer = 10
	name = "SprintBar"


func _ready() -> void:
	var label := Label.new()
	label.theme = preload("res://game/ui/theme/echo_theme.tres")
	label.theme_type_variation = &"HudLabel"
	label.text = "HUD_SPRINT"
	_place(label, Rect2(8, -22, 44, 14))
	add_child(label)
	var bar := ColorRect.new()
	bar.color = Color(0.15, 0.15, 0.15, 0.8)
	_place(bar, Rect2(56, -18, WIDTH, 6))
	add_child(bar)
	_fill = ColorRect.new()
	_fill.size = Vector2(WIDTH, 6)
	bar.add_child(_fill)


func _process(_delta: float) -> void:
	if sprint == null:
		return
	var winded := sprint.is_winded()
	_fill.color = WINDED_COLOR if winded else FULL_COLOR
	var left := sprint.winded_left / sprint.settings.winded_time if winded else sprint.get_ratio()
	_fill.size.x = WIDTH * (1.0 - left if winded else left)


## Anchored to the bottom left corner, offsets as in noise_gauge.tscn.
func _place(control: Control, rect: Rect2) -> void:
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


## Share of the bar filled, for the tests.
func get_fill() -> float:
	return _fill.size.x / WIDTH
