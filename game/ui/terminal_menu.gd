class_name TerminalMenu
extends CanvasLayer
## The menu of a terminal (spec S-018, Q10), while the hunted sits at one: on
## the right of the screen, the lines the network offers there
## (CityNetwork.entries_for), numbered. Keys 1 to 9 pick a line, 0 the tenth
## (the transformer's keypad, T-266); the mouse wheel moves the highlight and
## a click picks it. A pick goes out as a PICK
## action of the player's commands, so online the room carries it out. The
## line of the camera watched is marked. "interact" or moving gets up.

const GREEN := MenuStyle.SCREEN
const DIM := MenuStyle.SCREEN_DIM
const WIDTH := 250.0

var player: Player

var _panel: PanelContainer
var _title: Label
var _lines: VBoxContainer
var _help: Label
var _selected := 0
var _entries: Array = []


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -WIDTH - 12.0
	_panel.offset_right = -12.0
	_panel.offset_top = 24.0
	_panel.offset_bottom = -40.0
	_panel.theme = load(MenuStyle.THEME_PATH)
	_panel.theme_type_variation = &"ScreenPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_panel.add_child(column)
	_title = _label(GREEN)
	column.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 0)
	column.add_child(_lines)
	_help = _label(DIM)
	column.add_child(_help)
	_panel.visible = false


func _process(_delta: float) -> void:
	var terminal := player.terminal if is_instance_valid(player) else null
	_panel.visible = terminal != null
	if terminal == null:
		_selected = 0
		return
	var network := CityNetwork.of(player)
	_entries = network.entries_for(terminal) if network != null else []
	_selected = clampi(_selected, 0, maxi(_entries.size() - 1, 0))
	_show_lines(network)
	_help.text = Settings.fill(tr("HUD_TERMINAL_HELP"))
	_title.text = tr("HUD_TERMINAL_TITLE")
	if terminal.kind == Terminal.Kind.CODE:
		_title.text = tr("HUD_KEYPAD_TITLE")
		var quests := Quests.of(player)
		if quests == null or not quests.wants_code():
			_help.text = tr("HUD_KEYPAD_IDLE")
		else:
			_help.text = tr("HUD_KEYPAD_TYPED") % quests.typed_on(terminal).rpad(4, "_")


func _input(event: InputEvent) -> void:
	if not _panel.visible or LocalControls.frozen or _entries.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var digit: int = event.physical_keycode - KEY_1
		if event.physical_keycode == KEY_0:
			digit = 9  # The keypad's 0 comes after its 9.
		if digit >= 0 and digit < mini(10, _entries.size()):
			pick(digit)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_selected = posmod(_selected - 1, _entries.size())
			MOUSE_BUTTON_WHEEL_DOWN:
				_selected = posmod(_selected + 1, _entries.size())
			MOUSE_BUTTON_LEFT:
				pick(_selected)
			_:
				return
		get_viewport().set_input_as_handled()


## Picks line n (from 0): the room does what it says.
func pick(n: int) -> void:
	_selected = n
	player.commands.push_pick(n)


## The lines as they read now, for the tests.
func get_lines() -> PackedStringArray:
	var texts := PackedStringArray()
	for line: Label in _lines.get_children():
		texts.append(line.text)
	return texts


func _show_lines(network: CityNetwork) -> void:
	while _lines.get_child_count() < _entries.size():
		_lines.add_child(_label(GREEN))
	while _lines.get_child_count() > _entries.size():
		var extra := _lines.get_child(_lines.get_child_count() - 1)
		_lines.remove_child(extra)
		extra.queue_free()
	for i in _entries.size():
		var line: Label = _lines.get_child(i)
		line.text = _line_text(network, i)
		line.add_theme_color_override(&"font_color", GREEN if i == _selected else DIM)


func _line_text(network: CityNetwork, i: int) -> String:
	var entry: Array = _entries[i]
	var text := "%d  %s" % [i + 1, tr("HUD_TERMINAL_CAMERA") % tr(entry[2])]
	match entry[0]:
		CityNetwork.Entry.SPEAKER:
			text = "%d  %s" % [i + 1, tr("HUD_TERMINAL_SPEAKER") % tr(entry[2])]
			if network.speakers[entry[1]].used:
				text += "  " + tr("HUD_TERMINAL_USED")
		CityNetwork.Entry.SHUTTER:
			text = "%d  %s" % [i + 1, tr("HUD_TERMINAL_SHUTTER") % tr(entry[2])]
			var shutter := network.shutters[entry[1]]
			if shutter.is_down():
				text += "  " + tr("HUD_TERMINAL_DOWN")
			elif not shutter.is_ready():
				text += "  " + tr("HUD_TERMINAL_RECHARGE") % ceili(shutter.recharge_left)
		CityNetwork.Entry.OPEN_CAGES:
			text = "%d  %s" % [i + 1, tr(entry[2])]
			var progress := player.terminal.progress
			if progress > 0.0:
				text += "  %d %%" % roundi(progress * 100.0)
			elif not network.has_prisoners():
				text += "  " + tr("HUD_TERMINAL_NOBODY")
		CityNetwork.Entry.CAMERA:
			var camera := network.cameras[entry[1]]
			if camera.broken:
				text += "  " + tr("HUD_TERMINAL_BROKEN")
			elif player.watching == camera:
				text = "> " + text
	return text


func _label(color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"ScreenLabel"
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 18.0
	return label
