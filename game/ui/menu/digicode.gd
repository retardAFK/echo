class_name Digicode
extends PanelContainer
## The keypad of a building door (spec S-013, T-169): how a player types the
## four-letter code of a game. Click the keys or type on the keyboard;
## Backspace erases, Enter or the fourth letter sends the code.

## The code is complete and sent.
signal submitted(code: String)

## Letters typed so far.
var code := ""

var _display: Label


func _ready() -> void:
	theme_type_variation = &"MetalPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var caption := Label.new()
	caption.theme_type_variation = &"FootLabel"
	caption.text = "LOBBY_CODE_HINT"
	caption.uppercase = true
	column.add_child(caption)
	var screen := PanelContainer.new()
	screen.theme_type_variation = &"LcdPanel"
	column.add_child(screen)
	_display = Label.new()
	_display.theme_type_variation = &"LcdLabel"
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_display)
	var keys := GridContainer.new()
	keys.columns = 6
	keys.add_theme_constant_override("h_separation", 4)
	keys.add_theme_constant_override("v_separation", 4)
	column.add_child(keys)
	for letter in RoomCode.LETTERS:
		keys.add_child(_key(letter, type_letter.bind(letter)))
	keys.add_child(_key("←", erase))
	keys.add_child(_key("OK", submit))
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key.keycode == KEY_BACKSPACE:
		erase()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		submit()
	else:
		var letter := String.chr(key.unicode).to_upper()
		if key.unicode == 0 or not RoomCode.LETTERS.contains(letter):
			return
		type_letter(letter)
	get_viewport().set_input_as_handled()


func type_letter(letter: String) -> void:
	if code.length() >= RoomCode.LENGTH or not RoomCode.LETTERS.contains(letter):
		return
	code += letter
	_refresh()
	if code.length() == RoomCode.LENGTH:
		submit()


func erase() -> void:
	code = code.left(-1)
	_refresh()


func clear() -> void:
	code = ""
	_refresh()


## Sends the code as it is; the menu says if it is too short.
func submit() -> void:
	submitted.emit(code)


## What the display shows: the letters, then a mark per missing letter.
func display_text() -> String:
	return code + "_".repeat(RoomCode.LENGTH - code.length())


func _refresh() -> void:
	if _display != null:
		_display.text = display_text()


func _key(text: String, action: Callable) -> Button:
	var key := Button.new()
	key.theme_type_variation = &"DigicodeKey"
	key.text = text
	key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	key.focus_mode = Control.FOCUS_NONE
	key.custom_minimum_size = Vector2(26, 16)
	key.pressed.connect(action)
	return key
