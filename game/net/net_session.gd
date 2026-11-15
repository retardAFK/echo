extends Node
## The online session of this process (S-010, T-095), autoload "NetSession".
## SOLO: no network, the game runs here as before ("Jouer seul", Q9).
## CLIENT: connected to a room; the commands of the local avatar are sent to
## it, held keys commands_rate times per second and one-shot actions at once.
## ROOM: this process is a room; it receives the commands of every place.
## The connection itself is a RoomLink child named "Room".

signal joined(place: int)
signal refused(reason: String)
signal unreachable
## The room closed the connection after the player had joined.
signal left
## The waiting room changed (T-096): a LobbyState read from the room.
signal lobby_changed(lobby: LobbyState)
## The leader launched the game, with the final seats.
signal game_started(lobby: LobbyState)
## Client side: a snapshot of the game from the room (T-097).
signal snapshot_received(snapshot: Dictionary)
## Client side: an event of the game from the room (T-098).
signal event_received(event: Array)

enum Mode { SOLO, CLIENT, ROOM }

## Where the resume tokens are kept between visits (T-102): user:// is the
## browser's storage in the web build.
const RESUME_FILE := "user://resume.cfg"

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var mode := Mode.SOLO
var link: RoomLink
## Client side: the commands of the avatar played here, sent to the room.
var local_commands: PlayerCommands:
	set = set_local_commands

var _send_left := 0.0
## Client side: the room joined last, to come back to it (T-102).
var _last_url := ""


## Becomes a room listening on port.
func host(port: int) -> Error:
	leave()
	link = _new_link()
	var error := link.listen(port)
	if error != OK:
		leave()
		return error
	mode = Mode.ROOM
	return OK


## Connects to a room; joined, refused or unreachable tells how it went. The
## token the room gave last time, if any, asks for the same place back.
func join(url: String) -> void:
	leave()
	_last_url = url
	link = _new_link()
	link.joined.connect(_on_joined)
	link.refused.connect(refused.emit)
	link.unreachable.connect(unreachable.emit)
	link.left.connect(left.emit)
	link.lobby_changed.connect(_on_lobby_changed)
	link.game_started.connect(_on_game_started)
	link.snapshot_received.connect(snapshot_received.emit)
	link.event_received.connect(event_received.emit)
	link.join(url, saved_token(url))
	mode = Mode.CLIENT


## Client side: connects again to the room joined last, with its token, to
## get the place back after a cut (T-102).
func rejoin() -> void:
	if _last_url != "":
		join(_last_url)


## The resume token kept for a room, "" if none.
func saved_token(url: String) -> String:
	var file := ConfigFile.new()
	if file.load(RESUME_FILE) != OK:
		return ""
	return str(file.get_value("tokens", url, ""))


func _on_joined(place: int, token: String) -> void:
	var file := ConfigFile.new()
	file.load(RESUME_FILE)  # Missing the first time: a new file.
	file.set_value("tokens", _last_url, token)
	file.save(RESUME_FILE)
	joined.emit(place)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps the link alive behind a paused end screen.


## Room side: the game is over, back to the waiting room (T-099).
func end_game() -> void:
	if mode == Mode.ROOM:
		link.end_game()


## Closes the connection, if any, and goes back to playing alone.
func leave() -> void:
	if link != null:
		remove_child(link)
		link.queue_free()
		link = null
	mode = Mode.SOLO
	_send_left = 0.0


## Client side: own place in the room (1 to room_size), or 0.
func get_place() -> int:
	return link.place if mode == Mode.CLIENT else 0


## Client side: the last waiting room received, or null.
func get_lobby() -> LobbyState:
	if mode != Mode.CLIENT or link.lobby_state.is_empty():
		return null
	return LobbyState.from_dict(link.lobby_state)


## Client side: own seat in the waiting room (LobbyState.MONSTER_SEAT for the
## monster, 1 to 3 for the hunted), or -1.
func get_seat() -> int:
	var lobby := get_lobby()
	return lobby.seat_of(get_place()) if lobby != null else -1


func set_ready(is_ready: bool) -> void:
	if mode == Mode.CLIENT:
		link.ask_ready(is_ready)


## Client side, leader only: how many play, monster included (2 to 4).
func set_game_size(wanted: int) -> void:
	if mode == Mode.CLIENT:
		link.ask_game_size(wanted)


## Client side, leader only: launch the game once everyone is ready.
func start_game() -> void:
	if mode == Mode.CLIENT:
		link.ask_start()


## Client side: last round trip to the room in milliseconds, or -1.
func get_ping_ms() -> int:
	return link.ping_ms if mode == Mode.CLIENT else -1


func set_local_commands(commands: PlayerCommands) -> void:
	if local_commands != null and local_commands.action_pushed.is_connected(_on_action_pushed):
		local_commands.action_pushed.disconnect(_on_action_pushed)
	local_commands = commands
	if commands != null:
		commands.action_pushed.connect(_on_action_pushed)


## One line for the debug overlay (F3), or "" when playing alone.
func describe() -> String:
	match mode:
		Mode.CLIENT:
			if get_place() == 0:
				return "NET connecting"
			return "NET place %d ping %d ms" % [get_place(), get_ping_ms()]
		Mode.ROOM:
			return "NET room %d players" % (link.players.size() if link != null else 0)
	return ""


func _process(delta: float) -> void:
	if mode != Mode.CLIENT or local_commands == null or get_place() == 0:
		return
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left += 1.0 / settings.commands_rate
		_send_left = maxf(_send_left, 0.0)
		link.send_held(local_commands)


func _on_lobby_changed(state: Dictionary) -> void:
	lobby_changed.emit(LobbyState.from_dict(state))


func _on_game_started(state: Dictionary) -> void:
	game_started.emit(LobbyState.from_dict(state))


func _on_action_pushed(action: PlayerCommands.Action) -> void:
	if mode == Mode.CLIENT:
		link.send_action(action)


func _new_link() -> RoomLink:
	var new_link := RoomLink.new()
	new_link.settings = settings
	add_child(new_link)
	return new_link
