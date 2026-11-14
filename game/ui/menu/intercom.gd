class_name Intercom
extends PanelContainer
## The intercom of the waiting room (spec S-013, T-169): one line per seat,
## its role, a name tag and a lamp lit when that player is ready. A line is
## a button when this player can take or swap that seat. It only shows a
## LobbyState; LobbyMenu keeps the logic.

## This player pressed the line of a seat.
signal seat_pressed(seat: int)

const LAMP_SIZE := 12.0

var _rows: Array[Dictionary] = []


## The name on the tag of a seat, seen from player me.
static func tag_text(state: LobbyState, seat: int, me: int) -> String:
	var player := state.seats[seat]
	if player == 0:
		return TranslationServer.translate("LOBBY_AI")
	var text: String = (
		TranslationServer.translate("LOBBY_YOU")
		if player == me
		else TranslationServer.translate("LOBBY_PLAYER") % player
	)
	if player == state.leader:
		text += " · " + TranslationServer.translate("LOBBY_LEADER_TAG")
	return text


## Whether player me can press the line of a seat: take a free seat, or swap
## when leader. Never one's own seat.
static func can_press(state: LobbyState, seat: int, me: int) -> bool:
	if seat == state.seat_of(me):
		return false
	return state.seats[seat] == 0 or me == state.leader


func _ready() -> void:
	theme_type_variation = &"MetalPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	head.add_child(_caption("LOBBY_INTERCOM", true))
	head.add_child(_caption("LOBBY_INTERCOM_HINT", false))
	for seat in LobbyState.SEATS:
		column.add_child(_row(seat))


## Shows the room as the room sent it, seen from player me.
func show_state(state: LobbyState, me: int) -> void:
	for seat in LobbyState.SEATS:
		var row: Dictionary = _rows[seat]
		var player := state.seats[seat]
		(row["name"] as Label).text = tag_text(state, seat, me)
		(row["tag"] as PanelContainer).theme_type_variation = (
			&"NameTagAi" if player == 0 else &"NameTag"
		)
		var lamp: IntercomLamp = row["lamp"]
		lamp.lit = player != 0 and state.is_ready(player)
		var button: Button = row["button"]
		button.disabled = not can_press(state, seat, me)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		)


## The lamp of a seat, for tests.
func is_lamp_lit(seat: int) -> bool:
	return (_rows[seat]["lamp"] as IntercomLamp).lit


func is_seat_pressable(seat: int) -> bool:
	return not (_rows[seat]["button"] as Button).disabled


func _caption(key: String, left: bool) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"FootLabel"
	label.text = key
	label.uppercase = true
	if left:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _row(seat: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"IntercomRow"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 20)
	button.pressed.connect(func() -> void: seat_pressed.emit(seat))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	var role := Label.new()
	role.theme_type_variation = &"KeyLabel"
	role.text = LobbyMenu.seat_name(seat).to_upper()
	role.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	role.custom_minimum_size = Vector2(62, 0)
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(role)
	var tag := PanelContainer.new()
	tag.theme_type_variation = &"NameTag"
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(tag)
	var name_label := Label.new()
	name_label.theme_type_variation = &"TagLabel"
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tag.add_child(name_label)
	var lamp := IntercomLamp.new()
	lamp.custom_minimum_size = Vector2(LAMP_SIZE + 6, LAMP_SIZE)
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lamp)
	_rows.append({"button": button, "name": name_label, "tag": tag, "lamp": lamp})
	return button
