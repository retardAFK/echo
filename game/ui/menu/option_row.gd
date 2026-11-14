class_name OptionRow
extends Button
## One line of the options (spec S-013, T-163): its name, then a bar of ten
## segments for a number, or the value for an on/off setting, a choice or a
## key. Left and right change the value; a click on the bar sets it there.
## A key line waits for the next key once pressed (Escape cancels).

enum Kind { NUMBER, FLAG, CHOICE, KEY }

const SEGMENTS := 10
const NAME_WIDTH := 150.0
const VALUE_WIDTH := 44.0

## The setting (or the action, for a key line).
var setting := ""
var kind := Kind.NUMBER
## Translation key of the name.
var label_key := ""
## True while a key line waits for a key.
var waiting := false

var _lit := false


func _init() -> void:
	theme_type_variation = &"OptionRow"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 15)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_entered.connect(func() -> void: grab_focus())
	focus_entered.connect(_set_lit.bind(true))
	focus_exited.connect(_set_lit.bind(false))


func _ready() -> void:
	Settings.changed.connect(func(_key: String) -> void: queue_redraw())


static func make(row_setting: String, row_kind: Kind, row_label: String) -> OptionRow:
	var row := OptionRow.new()
	row.setting = row_setting
	row.kind = row_kind
	row.label_key = row_label
	row.name = row_setting
	return row


func _gui_input(event: InputEvent) -> void:
	if waiting:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var key := event as InputEventKey
			if key.keycode != KEY_ESCAPE:
				Settings.set_key(setting, key.physical_keycode)
			waiting = false
			queue_redraw()
			accept_event()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if kind != Kind.KEY:
			Settings.step(setting, -1 if event.is_action_pressed("ui_left") else 1)
			accept_event()
	elif event is InputEventMouseButton and event.pressed and kind == Kind.NUMBER:
		var bar := _bar_rect()
		if event.button_index == MOUSE_BUTTON_LEFT and bar.has_point(event.position):
			var spec: Array = UserSettings.NUMBERS[setting]
			var at := clampf((event.position.x - bar.position.x) / bar.size.x, 0.0, 1.0)
			Settings.set_value(setting, lerpf(spec[1], spec[2], at))
			accept_event()


func _pressed() -> void:
	match kind:
		Kind.FLAG, Kind.CHOICE:
			Settings.step(setting, 1)
		Kind.KEY:
			waiting = true
			queue_redraw()


## The value as the line shows it.
func value_text() -> String:
	match kind:
		Kind.NUMBER:
			var value := float(Settings.get_value(setting))
			if setting == "fov":
				return "%d°" % roundi(value)
			if setting == "sensitivity":
				return ("× %.2f" % value).replace(".", ",")
			return "%d %%" % roundi(value * 100.0)
		Kind.FLAG:
			return tr("OPTIONS_ON") if Settings.get_value(setting) else tr("OPTIONS_OFF")
		Kind.CHOICE:
			return "◂ %s ▸" % tr("OPTIONS_CHOICE_" + str(Settings.get_value(setting)).to_upper())
		_:
			return tr("OPTIONS_PRESS_KEY") if waiting else Settings.key_label(setting)


func is_lit() -> bool:
	return _lit


func _draw() -> void:
	var font := get_theme_font("font", &"KeyLabel")
	var font_size := get_theme_font_size("font_size", &"KeyLabel")
	var small := get_theme_font("font", &"BodyLabel")
	var small_size := get_theme_font_size("font_size", &"BodyLabel")
	if _lit:
		draw_rect(Rect2(Vector2.ZERO, size), Color(MenuStyle.SODIUM, 0.14))
		draw_rect(Rect2(Vector2.ZERO, size), Color(MenuStyle.SODIUM, 0.5), false, 1.0)
	var baseline := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var color := MenuStyle.CREAM if _lit else MenuStyle.TEXT
	draw_string(font, Vector2(8, baseline), tr(label_key).to_upper(), 0, -1, font_size, color)
	if kind == Kind.NUMBER:
		var bar := _bar_rect()
		var lit_segments := roundi(Settings.ratio(setting) * SEGMENTS)
		var width := (bar.size.x - (SEGMENTS - 1) * 2.0) / SEGMENTS
		for index in SEGMENTS:
			var segment := Rect2(
				bar.position + Vector2(index * (width + 2.0), 0), Vector2(width, bar.size.y)
			)
			draw_rect(segment, MenuStyle.SODIUM if index < lit_segments else MenuStyle.METAL)
		var text := value_text()
		var text_width := small.get_string_size(text, 0, -1, small_size).x
		draw_string(
			small,
			Vector2(size.x - 8 - text_width, baseline),
			text,
			0,
			-1,
			small_size,
			MenuStyle.MUTED
		)
	else:
		var value_color := MenuStyle.SODIUM if waiting else color
		draw_string(
			small, Vector2(NAME_WIDTH, baseline), value_text(), 0, -1, small_size + 1, value_color
		)


func _bar_rect() -> Rect2:
	var left := NAME_WIDTH
	var right := size.x - VALUE_WIDTH - 8.0
	return Rect2(Vector2(left, size.y / 2.0 - 3.5), Vector2(right - left, 7.0))


func _set_lit(lit: bool) -> void:
	_lit = lit
	if not lit:
		waiting = false
	queue_redraw()
