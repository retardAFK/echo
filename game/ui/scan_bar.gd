class_name ScanBar
extends CanvasLayer
## The monster's scan gauge on screen (spec S-004, Q3): a pale bar at the
## bottom, dimmed while it is too low to start a scan. Never orange.

## Dimming of the bar while the gauge is below the minimum to start a scan.
const LOW_ALPHA := 0.35

@export var monster: MonsterAvatar

@onready var _bar: ColorRect = $Bar
@onready var _fill: ColorRect = $Bar/Fill


func _ready() -> void:
	_fill.color = monster.settings.scan_bar_color
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var gauge := monster.scan
	_fill.size.x = _bar.size.x * gauge.get_ratio()
	_fill.modulate.a = 1.0 if gauge.active or gauge.can_start() else LOW_ALPHA
