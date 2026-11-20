class_name OptionsMenu
extends Control
## Options (spec S-013, Q4, T-163): four tabs, Son, Contrôles, Image and
## Touches, opened from the home screen and from the pause. Every change is
## applied and saved at once by Settings. Up reaches the tabs, left and right
## switch them; Escape or "Retour" closes.

## The player left the options.
signal closed

## Tabs: translation key, then the lines (setting, kind, name key).
const TABS := [
	[
		"OPTIONS_TAB_SOUND",
		[
			["volume_master", OptionRow.Kind.NUMBER, "OPTIONS_VOLUME_MASTER"],
			["volume_effects", OptionRow.Kind.NUMBER, "OPTIONS_VOLUME_EFFECTS"],
			["volume_ambience", OptionRow.Kind.NUMBER, "OPTIONS_VOLUME_AMBIENCE"],
			["volume_music", OptionRow.Kind.NUMBER, "OPTIONS_VOLUME_MUSIC"],
		],
	],
	[
		"OPTIONS_TAB_CONTROLS",
		[
			["sensitivity", OptionRow.Kind.NUMBER, "OPTIONS_SENSITIVITY"],
			["invert_y", OptionRow.Kind.FLAG, "OPTIONS_INVERT_Y"],
		],
	],
	[
		"OPTIONS_TAB_IMAGE",
		[
			["fullscreen", OptionRow.Kind.FLAG, "OPTIONS_FULLSCREEN"],
			["brightness", OptionRow.Kind.NUMBER, "OPTIONS_BRIGHTNESS"],
			["fov", OptionRow.Kind.NUMBER, "OPTIONS_FOV"],
		],
	],
	[
		"OPTIONS_TAB_KEYS",
		[
			["keyboard", OptionRow.Kind.CHOICE, "OPTIONS_KEYBOARD"],
			["move_forward", OptionRow.Kind.KEY, "OPTIONS_KEY_FORWARD"],
			["move_back", OptionRow.Kind.KEY, "OPTIONS_KEY_BACK"],
			["move_left", OptionRow.Kind.KEY, "OPTIONS_KEY_LEFT"],
			["move_right", OptionRow.Kind.KEY, "OPTIONS_KEY_RIGHT"],
			["sprint", OptionRow.Kind.KEY, "OPTIONS_KEY_SPRINT"],
			["crouch", OptionRow.Kind.KEY, "OPTIONS_KEY_CROUCH"],
			["hold_breath", OptionRow.Kind.KEY, "OPTIONS_KEY_HOLD_BREATH"],
			["place_firecracker", OptionRow.Kind.KEY, "OPTIONS_KEY_FIRECRACKER"],
			["place_can_wire", OptionRow.Kind.KEY, "OPTIONS_KEY_CAN_WIRE"],
			["place_walkman", OptionRow.Kind.KEY, "OPTIONS_KEY_WALKMAN"],
			["smoke_bomb", OptionRow.Kind.KEY, "OPTIONS_KEY_SMOKE"],
			["interact", OptionRow.Kind.KEY, "OPTIONS_KEY_INTERACT"],
			["map", OptionRow.Kind.KEY, "OPTIONS_KEY_MAP"],
			["ping", OptionRow.Kind.KEY, "OPTIONS_KEY_PING"],
		],
	],
]

var tab := 0

var _tab_buttons: Array[MenuItem] = []
var _rows: Array[OptionRow] = []

@onready var _tabs: HBoxContainer = %Tabs
@onready var _lines: VBoxContainer = %Lines
@onready var _actions: MenuList = %Actions


func _ready() -> void:
	for index in TABS.size():
		var button := MenuItem.new()
		button.theme_type_variation = &"SmallMenuItem"
		button.key = TABS[index][0]
		button.focus_entered.connect(show_tab.bind(index))
		button.pressed.connect(show_tab.bind(index))
		_tabs.add_child(button)
		_tab_buttons.append(button)
	_actions.chosen.connect(_on_action)
	show_tab(0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	show_tab(tab)
	if not _rows.is_empty():
		_rows[0].grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func show_tab(index: int) -> void:
	tab = index
	for button_index in _tab_buttons.size():
		_tab_buttons[button_index].set_text_color(
			MenuStyle.SODIUM if button_index == index else null
		)
	for row in _rows:
		_lines.remove_child(row)
		row.queue_free()
	_rows.clear()
	for line: Array in TABS[index][1]:
		var row := OptionRow.make(line[0], line[1], line[2])
		_lines.add_child(row)
		_rows.append(row)
	_link_focus()


## The lines of the tab shown, for tests.
func get_rows() -> Array[OptionRow]:
	return _rows


func _link_focus() -> void:
	var first_action := _actions.item("OPTIONS_RESET")
	for index in _rows.size():
		var row := _rows[index]
		var above: Control = _tab_buttons[tab] if index == 0 else _rows[index - 1]
		var below: Control = first_action if index == _rows.size() - 1 else _rows[index + 1]
		row.focus_neighbor_top = row.get_path_to(above)
		row.focus_neighbor_bottom = row.get_path_to(below)
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()
	for button in _tab_buttons:
		button.focus_neighbor_bottom = button.get_path_to(_rows[0])
		button.focus_neighbor_top = button.get_path()
	first_action.focus_neighbor_top = first_action.get_path_to(_rows[-1])


func _on_action(key: String) -> void:
	if key == "OPTIONS_RESET":
		Settings.reset()
	else:
		close()
