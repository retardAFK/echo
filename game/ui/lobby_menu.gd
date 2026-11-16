class_name LobbyMenu
extends Control
## Online game menu (S-010, Q3 and Q6, T-096; style A of S-013, T-169):
## create a game or type its code on the digicode, then the waiting room: the
## code to send, the intercom with the four seats (monster, hunted 1 to 3),
## who is in and who is ready, how many play (the leader chooses, 2 to 4) and
## the leader's "Lancer". The roles are drawn at random at launch; hunted
## seats nobody takes are played by AIs. Texts go through strings.csv.

## The leader launched the game; seat is this player's (0 = monster).
signal launched(seat: int)

const START_MENU_SCENE := "res://game/ui/start_menu.tscn"
const MAP_SCENE := "res://game/maps/tilleuls/tilleuls.tscn"
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

## Tests turn this off to stay on this screen.
@export var change_scene := true
@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var lobby_client: LobbyClient
var lobby: LobbyState

@onready var _entry: Control = %Entry
@onready var _entry_list: MenuList = %EntryList
@onready var _digicode: Digicode = %Digicode
@onready var _room: Control = %Room
@onready var _code_label: Label = %Code
@onready var _intercom: Intercom = %Intercom
@onready var _room_list: MenuList = %RoomList
@onready var _hint: Label = %Hint
@onready var _status: Label = %Status


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
	_entry_list.chosen.connect(_on_entry_chosen)
	_room_list.chosen.connect(_on_room_chosen)
	_digicode.submitted.connect(join_code)
	NetSession.joined.connect(_on_joined)
	NetSession.refused.connect(_show_error)
	NetSession.unreachable.connect(_on_unreachable)
	NetSession.left.connect(_on_left)
	NetSession.lobby_changed.connect(show_lobby)
	NetSession.game_started.connect(_on_game_started)
	show_entry()
	var current := NetSession.get_lobby()
	if current != null:  # Back from a game (T-099): still in the room.
		show_lobby(current)


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _room.visible:
			leave()
		else:
			back()
		get_viewport().set_input_as_handled()


func show_entry() -> void:
	_entry.visible = true
	_room.visible = false
	lobby = null
	_digicode.clear()
	_entry_list.focus_first()


## Shows the waiting room as the room sent it.
func show_lobby(state: LobbyState) -> void:
	var arriving := not _room.visible
	lobby = state
	_entry.visible = false
	_room.visible = true
	_set_status("")
	var me := NetSession.get_place()
	_code_label.text = state.code
	_intercom.show_state(state, me)
	_room_list.item("LOBBY_READY").key = (
		"LOBBY_NOT_READY" if state.is_ready(me) else "LOBBY_READY"
	)
	var size_item := _room_list.item("LOBBY_GAME_SIZE")
	size_item.text = (tr("LOBBY_GAME_SIZE") % state.game_size).to_upper()
	_room_list.set_item_visible("LOBBY_GAME_SIZE", me == state.leader)
	_room_list.set_item_visible("LOBBY_START", me == state.leader)
	_room_list.item("LOBBY_START").disabled = not state.can_start(me)
	_hint.text = tr("LOBBY_WAIT_READY") if me == state.leader else tr("LOBBY_WAIT_LEADER")
	if arriving:
		_room_list.focus_first()


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


## The game size the leader gets by choosing the entry again: one more,
## back to the smallest after 4, skipping sizes too small for those in.
static func next_game_size(state: LobbyState) -> int:
	var wanted := state.game_size
	for i in LobbyState.SEATS:
		wanted = wanted + 1 if wanted < LobbyState.SEATS else LobbyState.MIN_GAME_SIZE
		if wanted >= state.players().size():
			return wanted
	return state.game_size


func _on_entry_chosen(key: String) -> void:
	match key:
		"LOBBY_CREATE":
			create()
		"LOBBY_JOIN":
			join_code(_digicode.code)
		_:
			back()


func _on_room_chosen(key: String) -> void:
	match key:
		"LOBBY_READY":
			_on_ready_pressed()
		"LOBBY_GAME_SIZE":
			if lobby != null:
				NetSession.set_game_size(next_game_size(lobby))
		"LOBBY_START":
			NetSession.start_game()
		_:
			leave()


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
	_room_list.item("LOBBY_READY").disabled = true
	_room_list.item("LOBBY_START").disabled = true
	var seat := state.seat_of(NetSession.get_place())
	launched.emit(seat)
	if change_scene:
		enter_game(get_tree(), state)


## Plays the seat the room gave this player in the game it launched.
static func enter_game(tree: SceneTree, state: LobbyState) -> void:
	var seat := state.seat_of(NetSession.get_place())
	GameSession.online_seat = seat
	GameSession.role = (
		GameSession.Role.MONSTER if seat == LobbyState.MONSTER_SEAT else GameSession.Role.HUNTED
	)
	tree.paused = false
	LoadingScreen.open(tree, MAP_SCENE)  # T-166.


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
