class_name MenuItem
extends Button
## One entry of a menu (spec S-013, T-162): its translated text in capitals
## behind a small square. The chosen entry is a sodium band with dark text;
## the mouse choosing an entry gives it the focus, so the keyboard and the
## mouse never show two chosen entries.

## Translation key of the text.
@export var key := "":
	set(value):
		key = value
		_refresh_text()

var _lit := false
## A text color set from outside (the current tab), kept while lit.
var _kept_color: Variant = null


func _init() -> void:
	theme_type_variation = &"MenuItem"
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_set_lit.bind(true))
	focus_exited.connect(_set_lit.bind(false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


## Whether the entry shows as chosen.
func is_lit() -> bool:
	return _lit


func _draw() -> void:
	var color := MenuStyle.INK if _lit else MenuStyle.FAINT
	var side := float(MenuStyle.BULLET_SIZE)
	draw_rect(Rect2(Vector2(7, (size.y - side) / 2.0), Vector2(side, side)), color)


func _on_mouse_entered() -> void:
	if not disabled and is_visible_in_tree():
		grab_focus()


func _set_lit(lit: bool) -> void:
	_lit = lit
	if lit:
		add_theme_stylebox_override("normal", get_theme_stylebox("hover"))
		add_theme_color_override("font_color", get_theme_color("font_focus_color"))
	else:
		remove_theme_stylebox_override("normal")
		if _kept_color != null:
			add_theme_color_override("font_color", _kept_color)
		else:
			remove_theme_color_override("font_color")
	queue_redraw()


## A text color of its own when not chosen (the current tab), or null.
func set_text_color(color: Variant) -> void:
	_kept_color = color
	if not _lit:
		if color != null:
			add_theme_color_override("font_color", color)
		else:
			remove_theme_color_override("font_color")


func _refresh_text() -> void:
	text = tr(key).to_upper()
