class_name UserSettings
extends Node
## The player's settings (spec S-013, Q4 and Q5, T-163), autoload "Settings":
## volumes per bus, mouse, image and keys. Saved in user://settings.cfg, kept
## by the browser between visits. A missing, broken or out-of-range value
## goes back to its default.

signal changed(key: String)

const PATH := "user://settings.cfg"
const SECTION := "settings"
const KEYS_SECTION := "keys"
## Number settings: default, lowest, highest, step.
const NUMBERS := {
	"volume_master": [0.8, 0.0, 1.0, 0.1],
	"volume_effects": [1.0, 0.0, 1.0, 0.1],
	"volume_ambience": [1.0, 0.0, 1.0, 0.1],
	"volume_music": [0.7, 0.0, 1.0, 0.1],
	"sensitivity": [1.0, 0.25, 3.0, 0.25],
	"brightness": [1.0, 0.6, 1.6, 0.1],
	"fov": [75.0, 60.0, 100.0, 5.0],
}
## On or off settings and their default. "fullscreen" is the state of the
## window, never saved: a browser only allows it right after a key or a click.
## "first_steps_*": the first steps of a role were read (S-013, T-166).
## "tip_*": the first-time tip of a thing was shown (S-020, T-329, FirstTips).
const FLAGS := {
	"invert_y": false,
	"fullscreen": false,
	"first_steps_hunted": false,
	"first_steps_monster": false,
	"tip_hiding_spot": false,
	"tip_terminal": false,
	"tip_fuse_box": false,
}
const FULLSCREEN := "fullscreen"
## Settings picked in a list; the first one is the default.
const CHOICES := {"keyboard": ["azerty", "qwerty"]}
## Audio bus of each volume. The buses come from default_bus_layout.tres: in a
## browser, a bus added while the game runs stays silent.
const BUSES := {
	"volume_master": "Master",
	"volume_effects": "Effets",
	"volume_ambience": "Ambiance",
	"volume_music": "Musique",
}
## Keyboard actions the player can move to another key, in menu order.
const REMAPPABLE: Array[String] = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"sprint",
	"crouch",
	"hold_breath",
	"place_firecracker",
	"interact",
	"map",
	"ping",
]
## Tokens of the texts that name a key, and the actions they name.
const TOKENS := {
	"{move}": ["move_forward", "move_left", "move_back", "move_right"],
	"{sprint}": ["sprint"],
	"{crouch}": ["crouch"],
	"{hold_breath}": ["hold_breath"],
	"{place_firecracker}": ["place_firecracker"],
	"{interact}": ["interact"],
	"{map}": ["map"],
	"{ping}": ["ping"],
}
## What an AZERTY keyboard prints on the keys that differ from QWERTY.
const AZERTY := {
	KEY_W: "Z",
	KEY_A: "Q",
	KEY_Q: "A",
	KEY_Z: "W",
	KEY_SEMICOLON: "M",
	KEY_M: ",",
	KEY_COMMA: ";",
	KEY_PERIOD: ":",
}
## Text keys (game/i18n/strings.csv) of the names of the keys that are not
## a letter.
const KEY_NAMES := {
	KEY_SHIFT: "KEY_SHIFT",
	KEY_CTRL: "KEY_CTRL",
	KEY_ALT: "KEY_ALT",
	KEY_SPACE: "KEY_SPACE",
	KEY_TAB: "KEY_TAB",
	KEY_ENTER: "KEY_ENTER",
	KEY_BACKSPACE: "KEY_BACKSPACE",
	KEY_CAPSLOCK: "KEY_CAPSLOCK",
	KEY_UP: "KEY_UP",
	KEY_DOWN: "KEY_DOWN",
	KEY_LEFT: "KEY_LEFT",
	KEY_RIGHT: "KEY_RIGHT",
}

## Tests use another file so the player's own settings stay untouched.
var path := PATH

var _values := {}
## Default key of each remappable action, read from the project.
var _default_keys := {}
var _keys := {}


func _ready() -> void:
	for action in REMAPPABLE:
		_default_keys[action] = _first_key(action)
	_make_buses()
	load_file()
	get_tree().node_added.connect(route_audio)
	# The browser leaves fullscreen on its own (Escape): the options follow.
	get_tree().root.size_changed.connect(changed.emit.bind(FULLSCREEN))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		step(FULLSCREEN, 1)
		get_viewport().set_input_as_handled()


func get_value(key: String) -> Variant:
	if key == FULLSCREEN:
		return is_fullscreen()
	if not _values.has(key):
		return default_of(key)
	return _values[key]


static func default_of(key: String) -> Variant:
	if NUMBERS.has(key):
		return float(NUMBERS[key][0])
	if FLAGS.has(key):
		return FLAGS[key]
	if CHOICES.has(key):
		return CHOICES[key][0]
	return null


## A value made valid: numbers clamped and snapped to their step, unknown
## choices and wrong types back to the default.
static func sanitize(key: String, value: Variant) -> Variant:
	if NUMBERS.has(key):
		if not (value is float or value is int):
			return default_of(key)
		var spec: Array = NUMBERS[key]
		var low: float = spec[1]
		var snapped_value := snappedf(float(value) - low, spec[3]) + low
		return clampf(snapped_value, low, spec[2])
	if FLAGS.has(key):
		return value if value is bool else default_of(key)
	if CHOICES.has(key):
		return value if value is String and (CHOICES[key] as Array).has(value) else default_of(key)
	return null


func set_value(key: String, value: Variant) -> void:
	if key == FULLSCREEN:
		set_fullscreen(sanitize(key, value))
		return
	_values[key] = sanitize(key, value)
	_apply(key)
	save_file()
	changed.emit(key)


## Moves a number one step, flips a flag, or picks the next choice.
func step(key: String, direction: int) -> void:
	if NUMBERS.has(key):
		set_value(key, float(get_value(key)) + direction * float(NUMBERS[key][3]))
	elif FLAGS.has(key):
		set_value(key, not get_value(key))
	elif CHOICES.has(key):
		var choices: Array = CHOICES[key]
		var index := choices.find(get_value(key))
		set_value(key, choices[posmod(index + direction, choices.size())])


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


## Fills the screen, or goes back to a window (in a browser, the page).
func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)
	changed.emit(FULLSCREEN)


## Where a number sits between its lowest and highest value, 0 to 1.
func ratio(key: String) -> float:
	var spec: Array = NUMBERS[key]
	return inverse_lerp(spec[1], spec[2], float(get_value(key)))


func reset() -> void:
	_values.clear()
	_keys.clear()
	_apply_all()
	save_file()
	changed.emit("")


func load_file() -> void:
	_values.clear()
	_keys.clear()
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in NUMBERS.keys() + FLAGS.keys() + CHOICES.keys():
			if key != FULLSCREEN and file.has_section_key(SECTION, key):
				_values[key] = sanitize(key, file.get_value(SECTION, key))
		for action in REMAPPABLE:
			var code: Variant = file.get_value(KEYS_SECTION, action, 0)
			if code is int and code > 0 and OS.get_keycode_string(code) != "":
				_keys[action] = code
	_apply_all()


func save_file() -> void:
	var file := ConfigFile.new()
	for key: String in _values:
		file.set_value(SECTION, key, _values[key])
	for action: String in _keys:
		file.set_value(KEYS_SECTION, action, _keys[action])
	file.save(path)


## The physical key of an action.
func key_of(action: String) -> Key:
	return _keys.get(action, _default_keys.get(action, KEY_NONE))


## Moves an action to a physical key. An action that had this key gets the
## old key of the moved one, so no key does two things.
func set_key(action: String, physical: Key) -> void:
	if not REMAPPABLE.has(action) or physical == KEY_NONE or physical == KEY_ESCAPE:
		return
	var old := key_of(action)
	for other in REMAPPABLE:
		if other != action and key_of(other) == physical:
			_keys[other] = old
	_keys[action] = physical
	_apply_keys()
	save_file()
	changed.emit("keys")


## The name printed on the key of an action, for the keyboard chosen.
func key_label(action: String) -> String:
	return label_for(key_of(action), str(get_value("keyboard")))


static func label_for(physical: Key, keyboard: String) -> String:
	if KEY_NAMES.has(physical):
		return Text.t(KEY_NAMES[physical])
	if keyboard == "azerty" and AZERTY.has(physical):
		return AZERTY[physical]
	return OS.get_keycode_string(physical)


## A text with its key tokens ({move}, {interact}...) replaced by key names.
func fill(text: String) -> String:
	for token: String in TOKENS:
		if text.contains(token):
			var names := ""
			for action: String in TOKENS[token]:
				names += key_label(action)
			text = text.replace(token, names)
	return text


## A mouse movement with the sensitivity and the vertical inversion applied.
func adjust_look(relative: Vector2) -> Vector2:
	var adjusted := relative * float(get_value("sensitivity"))
	if get_value("invert_y"):
		adjusted.y = -adjusted.y
	return adjusted


## Sends a new sound player to its bus: the ambience of a map to Ambiance,
## every other sound to Effets (until the buses of S-012).
func route_audio(node: Node) -> void:
	if not (
		node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
	):
		return
	if node.bus != &"Master":
		return
	var parent := node.get_parent()
	var ambience := node is AmbientTrain or (parent != null and parent.name == "Ambience")
	node.bus = BUSES["volume_ambience"] if ambience else BUSES["volume_effects"]


func _make_buses() -> void:
	for key: String in BUSES:
		var bus: String = BUSES[key]
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _apply_all() -> void:
	for key in NUMBERS.keys() + FLAGS.keys() + CHOICES.keys():
		_apply(key)
	_apply_keys()


func _apply(key: String) -> void:
	if BUSES.has(key):
		var index := AudioServer.get_bus_index(BUSES[key])
		if index >= 0:
			var volume := float(get_value(key))
			AudioServer.set_bus_mute(index, volume <= 0.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


func _apply_keys() -> void:
	for action in REMAPPABLE:
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		for event in events:
			if event is InputEventKey:
				(event as InputEventKey).physical_keycode = key_of(action)
				break


func _first_key(action: String) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return KEY_NONE
