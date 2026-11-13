class_name LobbyMenu
extends Control
## Online game menu (S-010, Q3 and Q6, T-096): create a game or join one
## with its code, then the waiting room: four seats (monster, hunted 1 to 3),
## who sits where, who is ready, and the leader's "Lancer". Empty seats are
## played by AIs. Built in code; texts go through strings.csv.

## The leader launched the game; seat is this player's (0 = monster).
signal launched(seat: int)

const START_MENU_SCENE := "res://game/ui/start_menu.tscn"
const ERROR_KEYS := {
	"unreachable": "LOBBY_ERROR_UNREACHABLE",
	"unknown_code": "LOBBY_ERROR_UNKNOWN_CODE",
	"busy": "LOBBY_ERROR_BUSY",
	"version": "LOBBY_ERROR_VERSION",
	"full": "LOBBY_ERROR_FULL",
	"started": "LOBBY_ERROR_STARTED",
	"closed": "LOBBY_ERROR_CLOSED",
	"bad_code": "LOBBY_ERROR_BAD_CODE",
}
const FONT_SIZE := 11
const SMALL_FONT_SIZE := 9

## Tests turn this off to stay on this screen.
@export var change_scene := true
@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var lobby_client: LobbyClient
var lobby: LobbyState

var _entry: VBoxContainer
var _code_edit: LineEdit
var _room: VBoxContainer
var _code_label: Label
var _rows: Array[Dictionary] = []
var _ready_button: Button
var _start_button: Button
var _hint: Label
var _status: Label


## What a seat shows: who sits there, seen from player me.
static func occupant_text(state: LobbyState, seat: int, me: int) -> String:
	var player := state.seats[seat]
	if player == 0:
		return TranslationServer.translate("LOBBY_AI")
	var text: String = (
		TranslationServer.translate("LOBBY_YOU")
		if player == me
		else TranslationServer.translate("LOBBY_PLAYER") % player
	)
	if player == state.leader:
		text += " " + TranslationServer.translate("LOBBY_LEADER")
	if state.is_ready(player):
		text += " · " + TranslationServer.translate("LOBBY_IS_READY")
	return text


static func seat_name(seat: int) -> String:
	if seat == LobbyState.MONSTER_SEAT:
		return TranslationServer.translate("LOBBY_SEAT_MONSTER")
	return TranslationServer.translate("LOBBY_SEAT_HUNTED") % seat


static func error_text(reason: String) -> String:
	return TranslationServer.translate(ERROR_KEYS.get(reason, "LOBBY_ERROR_OTHER"))


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby_client = LobbyClient.new()
	lobby_client.settings = settings
	add_child(lobby_client)
	lobby_client.answered.connect(_on_lobby_answered)
	_build()
	NetSession.joined.connect(_on_joined)
	NetSession.refused.connect(_show_error)
	NetSession.unreachable.connect(_on_unreachable)
	NetSession.left.connect(_on_left)
	NetSession.lobby_changed.connect(show_lobby)
	NetSession.game_started.connect(_on_game_started)
	show_entry()


func _exit_tree() -> void:
	for connection in [
		[NetSession.joined, _on_joined],
		[NetSession.refused, _show_error],
		[NetSession.unreachable, _on_unreachable],
		[NetSession.left, _on_left],
		[NetSession.lobby_changed, show_lobby],
		[NetSession.game_started, _on_game_started],
	]:
		if (connection[0] as Signal).is_connected(connection[1]):
			(connection[0] as Signal).disconnect(connection[1])


## Asks the lobby for a new game.
func create() -> void:
	_set_status(tr("LOBBY_CONNECTING"))
	lobby_client.create(NetAddress.lobby_url(settings))


## Asks the lobby for the room of the code typed.
func join_code(text: String) -> void:
	var code := RoomCode.normalize(text)
	if not RoomCode.is_valid(code):
		_show_error("bad_code")
		return
	_set_status(tr("LOBBY_CONNECTING"))
	lobby_client.join(NetAddress.lobby_url(settings), code)


func show_entry() -> void:
	_entry.visible = true
	_room.visible = false
	lobby = null


## Shows the waiting room as the room sent it.
func show_lobby(state: LobbyState) -> void:
	lobby = state
	_entry.visible = false
	_room.visible = true
	_set_status("")
	var me := NetSession.get_place()
	var my_seat := state.seat_of(me)
	_code_label.text = tr("LOBBY_CODE") % state.code
	for seat in LobbyState.SEATS:
		var row: Dictionary = _rows[seat]
		(row["who"] as Label).text = occupant_text(state, seat, me)
		var button: Button = row["button"]
		button.visible = seat != my_seat and (state.seats[seat] == 0 or me == state.leader)
		button.text = tr("LOBBY_TAKE") if state.seats[seat] == 0 else tr("LOBBY_SWAP")
	_ready_button.text = tr("LOBBY_NOT_READY") if state.is_ready(me) else tr("LOBBY_READY")
	_start_button.visible = me == state.leader
	_start_button.disabled = not state.can_start(me)
	_hint.text = tr("LOBBY_WAIT_READY") if me == state.leader else tr("LOBBY_WAIT_LEADER")


## Leaves the game and goes back to create or join.
func leave() -> void:
	NetSession.leave()
	show_entry()


func back() -> void:
	NetSession.leave()
	if change_scene:
		get_tree().change_scene_to_file(START_MENU_SCENE)


func get_status() -> String:
	return _status.text


func _on_seat_pressed(seat: int) -> void:
	if lobby == null:
		return
	if lobby.seats[seat] == 0:
		NetSession.take_seat(seat)
	else:
		NetSession.swap_seats(lobby.seat_of(NetSession.get_place()), seat)


func _on_ready_pressed() -> void:
	if lobby != null:
		NetSession.set_ready(not lobby.is_ready(NetSession.get_place()))


func _on_lobby_answered(reply: Dictionary) -> void:
	if reply.get("op") != "room":
		_show_error(str(reply.get("reason", "")))
		return
	NetSession.settings = settings
	NetSession.join(NetAddress.room_url(settings, int(reply["slot"]), int(reply["port"])))


func _on_joined(_place: int) -> void:
	_set_status(tr("LOBBY_CONNECTING"))


func _on_game_started(state: LobbyState) -> void:
	show_lobby(state)
	_set_status(tr("LOBBY_STARTING"))
	_ready_button.disabled = true
	_start_button.disabled = true
	launched.emit(state.seat_of(NetSession.get_place()))


func _on_unreachable() -> void:
	_show_error("unreachable")


func _on_left() -> void:
	_show_error("closed")


func _show_error(reason: String) -> void:
	NetSession.leave()
	show_entry()
	_set_status(error_text(reason))


func _set_status(text: String) -> void:
	_status.text = text


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(320, 0)
	column.position = Vector2(-160, -130)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_entry = VBoxContainer.new()
	_entry.add_theme_constant_override("separation", 6)
	column.add_child(_entry)
	_entry.add_child(_button("LOBBY_CREATE", create))
	var join_row := HBoxContainer.new()
	_entry.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "LOBBY_CODE_HINT"
	_code_edit.max_length = RoomCode.LENGTH + 2
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", FONT_SIZE)
	_code_edit.text_submitted.connect(join_code)
	join_row.add_child(_code_edit)
	join_row.add_child(_button("LOBBY_JOIN", func() -> void: join_code(_code_edit.text)))
	_entry.add_child(_button("MENU_BACK", back))
	_room = VBoxContainer.new()
	_room.add_theme_constant_override("separation", 6)
	column.add_child(_room)
	_code_label = _label(FONT_SIZE + 3)
	_room.add_child(_code_label)
	_room.add_child(_text_label("LOBBY_SHARE"))
	for seat in LobbyState.SEATS:
		var row := HBoxContainer.new()
		var name_label := _label(FONT_SIZE)
		name_label.text = seat_name(seat)
		name_label.custom_minimum_size = Vector2(80, 0)
		var who := _label(FONT_SIZE)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := _button("LOBBY_TAKE", _on_seat_pressed.bind(seat))
		row.add_child(name_label)
		row.add_child(who)
		row.add_child(button)
		_room.add_child(row)
		_rows.append({"who": who, "button": button})
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	_room.add_child(actions)
	actions.add_child(_button("LOBBY_LEAVE", leave))
	_ready_button = _button("LOBBY_READY", _on_ready_pressed)
	actions.add_child(_ready_button)
	_start_button = _button("LOBBY_START", NetSession.start_game)
	actions.add_child(_start_button)
	_hint = _label(SMALL_FONT_SIZE)
	_room.add_child(_hint)
	_status = _label(SMALL_FONT_SIZE)
	_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	column.add_child(_status)


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(action)
	return button


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _text_label(key: String) -> Label:
	var label := _label(SMALL_FONT_SIZE)
	label.text = key
	return label
