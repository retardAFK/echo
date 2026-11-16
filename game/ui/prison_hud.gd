class_name PrisonHud
extends CanvasLayer
## What a hunted in prison sees of its stay (spec S-018, Q5): the time left
## before it is out, in small at the top of the screen, under the goal. The
## clock stops while the monster is near (Q6); the room says how long is left.

## Its seat online (GameSession.online_seat when left at -1).
@export var seat := -1

var prison: Prison

var _label: Label


func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -100.0
	_label.offset_right = 100.0
	_label.offset_top = 22.0
	_label.offset_bottom = 36.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.theme = load(MenuStyle.THEME_PATH)
	_label.theme_type_variation = &"HudValue"
	add_child(_label)
	_label.visible = false


func _process(_delta: float) -> void:
	var cage := prison.cage_of_seat(seat if seat >= 0 else GameSession.online_seat)
	_label.visible = cage != null
	if cage != null:
		_label.text = text_for(cage.time_left)


## "Prison : 1:42" for 102 seconds left.
static func text_for(seconds: float) -> String:
	var whole := maxi(ceili(seconds), 0)
	return TranslationServer.translate("HUD_PRISON_TIME") % [whole / 60, whole % 60]


func get_text() -> String:
	return _label.text if _label.visible else ""
