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

enum Mode { SOLO, CLIENT, ROOM }

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var mode := Mode.SOLO
var link: RoomLink
## Client side: the commands of the avatar played here, sent to the room.
var local_commands: PlayerCommands:
	set = set_local_commands

var _send_left := 0.0


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


## Connects to a room; joined, refused or unreachable tells how it went.
func join(url: String) -> void:
	leave()
	link = _new_link()
	link.joined.connect(joined.emit)
	link.refused.connect(refused.emit)
	link.unreachable.connect(unreachable.emit)
	link.left.connect(left.emit)
	link.lobby_changed.connect(_on_lobby_changed)
	link.game_started.connect(_on_game_started)
	link.snapshot_received.connect(snapshot_received.emit)
	link.join(url)
	mode = Mode.CLIENT


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


## Client side, waiting room: sit in a free seat.
func take_seat(seat: int) -> void:
	if mode == Mode.CLIENT:
		link.ask_seat(seat)


## Client side, leader only: swap two seats.
func swap_seats(first: int, second: int) -> void:
	if mode == Mode.CLIENT:
		link.ask_swap(first, second)


func set_ready(is_ready: bool) -> void:
	if mode == Mode.CLIENT:
		link.ask_ready(is_ready)


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
			return "NET room %d players" % link.players.size()
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
