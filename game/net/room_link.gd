class_name RoomLink
extends Node
## The connection between a room and its players (S-010, T-094), on both
## sides: the room server listens, each client connects. It owns a
## SceneMultiplayer set on its parent, so a room and several clients can
## live in one process (tests, CI) without mixing their messages. Its
## remote procedures need the same node name on both sides: always "Room".
## A client says hello with its build version; the room welcomes it with a
## place (1 to room_size) and a resume token, or refuses it (other version,
## room full, game started).
## Departures (T-102): a player who leaves a game in progress keeps its seat;
## coming back with its token before the end, it gets its place back. The
## leader's role goes to another player still there.

signal joined(place: int, token: String)
signal refused(reason: String)
## A client could not reach the room before room_connect_timeout.
signal unreachable
## Round trip of the last ping, client side.
signal pinged(milliseconds: int)
## Room side: a player arrived or left.
signal players_changed(count: int)
## Room side, game in progress (T-102): the player of a place left, or came
## back with its token.
signal player_left(place: int)
signal player_returned(place: int)
## Room side: the game map of a place is ready to receive the game (T-102).
signal place_ready(place: int)
## Room side: nobody has been in the room for room_idle_timeout.
signal idle_expired
## Client side: the room closed the connection after the player had joined.
signal left
## Client side: the waiting room changed (T-096); state is LobbyState.to_dict().
signal lobby_changed(state: Dictionary)
## Both sides: the leader launched the game.
signal game_started(state: Dictionary)
## Room side: the game is over and the room is back to its waiting room (T-099).
signal game_ended
## Client side: what the room sends about the game, snapshot_rate times a second (T-097).
signal snapshot_received(snapshot: Dictionary)
## Client side: an event of the game from the room, as it happens (T-098).
signal event_received(event: Array)

const NODE_NAME := "Room"
## Seconds between refusing a player and closing its connection.
const REFUSED_CLOSE_DELAY := 0.5

@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var is_room := false
## Build version a client announces and a room expects (tests change it).
var version := NetAddress.build_version()
## Room side: place of each connected player, by peer id.
var players := {}
## Room side: newest commands received from each place, by place (T-095).
var commands := {}
## Room side: the CommandQueue of each place, by place (S-020, T-321).
var queues := {}
## Room side: the waiting room (T-096).
var lobby := LobbyState.new()
## Client side: the last waiting room received.
var lobby_state := {}
## Room side: the resume token of each place (T-102).
var tokens := {}
## Client side: own place once welcomed, else 0.
var place := 0
## Client side: the token sent with hello, to get a place back.
var resume_token := ""
## Client side: last round trip in milliseconds, -1 before the first pong.
var ping_ms := -1

var _api := SceneMultiplayer.new()
var _peer: WebSocketMultiplayerPeer
var _url := ""
var _idle := 0.0
var _ping_left := 0.0
var _connect_left := 0.0
var _retry_left := 0.0
## When the last delayed message goes out, and comes in (debug jitter, T-319).
var _out_due_msec := 0
var _in_due_msec := 0


func _init() -> void:
	name = NODE_NAME


func _exit_tree() -> void:
	if _peer != null:
		_peer.close()
	if get_parent() != null:
		get_tree().set_multiplayer(null, get_parent().get_path())


## Room side: listens for players on port.
func listen(port: int) -> Error:
	is_room = true
	_peer = WebSocketMultiplayerPeer.new()
	var error := _peer.create_server(port, settings.bind_address)
	if error != OK:
		return error
	_attach()
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	return OK


## Client side: connects to a room, trying again while it starts. A token
## from an earlier welcome asks for that place back (T-102).
func join(url: String, token := "") -> void:
	is_room = false
	_url = url
	resume_token = token
	_connect_left = settings.room_connect_timeout
	_api.connected_to_server.connect(_on_connected)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)
	_try_connect()


func _attach() -> void:
	_api.multiplayer_peer = _peer
	get_tree().set_multiplayer(_api, get_parent().get_path())


func _try_connect() -> void:
	_peer = WebSocketMultiplayerPeer.new()
	if _peer.create_client(_url) != OK:
		_retry_left = settings.room_connect_retry
		return
	_attach()


func _process(delta: float) -> void:
	if is_room:
		_idle = _idle + delta if players.is_empty() else 0.0
		if _idle >= settings.room_idle_timeout:
			_idle = 0.0
			idle_expired.emit()
		return
	if _url == "":
		return
	if place == 0 and _connect_left > 0.0:
		_connect_left -= delta
		if _connect_left <= 0.0:
			_url = ""
			unreachable.emit()
			return
	if _retry_left > 0.0:
		_retry_left -= delta
		if _retry_left <= 0.0:
			_try_connect()
	if place > 0:
		_ping_left -= delta
		if _ping_left <= 0.0:
			_ping_left = settings.ping_interval
			var sent := Time.get_ticks_msec()
			_later(func() -> void: ping.rpc_id(1, sent))


func _on_connected() -> void:
	hello.rpc_id(1, version, resume_token)


func _on_connection_failed() -> void:
	# The room may still be starting: try again until room_connect_timeout.
	_retry_left = settings.room_connect_retry


func _on_server_disconnected() -> void:
	if place > 0:
		place = 0
		left.emit()


func _on_peer_connected(_id: int) -> void:
	pass  # A player counts once its hello is accepted.


func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	var gone: int = players[id]
	commands.erase(gone)
	queues.erase(gone)
	players.erase(id)
	if lobby.started:
		# Its seat waits for it (T-102); the leader's role goes on.
		if lobby.leader == gone:
			lobby.leader = _lowest_place()
		player_left.emit(gone)
	else:
		lobby.remove_player(gone)
		tokens.erase(gone)
	players_changed.emit(players.size())
	_broadcast_lobby()


func _lowest_place() -> int:
	var connected: Array = players.values()
	connected.sort()
	return connected[0] if not connected.is_empty() else 0


## Room side: the commands of a place, created empty for a place nobody has
## sent anything from yet.
func commands_for(given_place: int) -> PlayerCommands:
	if not commands.has(given_place):
		commands[given_place] = PlayerCommands.new()
	return commands[given_place]


## Room side: the CommandQueue of a place, created empty (T-321).
func queue_for(given_place: int) -> CommandQueue:
	if not queues.has(given_place):
		queues[given_place] = CommandQueue.new(settings)
	return queues[given_place]


## Client side: sends the last frames of what is held and where the player
## looks, oldest first (S-020, T-321). Packets may be lost or late: each one
## repeats the frames of the ones before.
func send_held(recent: Array[PlayerCommands]) -> void:
	if place > 0 and not recent.is_empty():
		var bytes := PlayerCommands.frames_to_bytes(recent)
		_later(func() -> void: _receive_held.rpc_id(1, bytes))


## Client side: sends a one-shot action of the frame seq, which must not be
## lost (T-321: the room plays it with that frame).
func send_action(seq: int, action: PlayerCommands.Action) -> void:
	if place > 0:
		_later(func() -> void: _receive_action.rpc_id(1, seq, action))


func _drop(peer_id: int) -> void:
	if _peer != null and _api.get_peers().has(peer_id):
		_peer.disconnect_peer(peer_id)


## The free place with the lowest number, or 0 if the room is full. A place
## kept for a player who left (it has a token) is not free.
func free_place() -> int:
	for candidate in range(1, settings.room_size + 1):
		if not players.values().has(candidate) and not tokens.has(candidate):
			return candidate
	return 0


## The place a token was given for, if its player is not connected; else 0.
func returning_place(token: String) -> int:
	if token == "":
		return 0
	for kept: int in tokens:
		if tokens[kept] == token and _peer_of(kept) == 0:
			return kept
	return 0


@rpc("any_peer", "call_remote", "reliable")
func hello(client_version: String, token := "") -> void:
	if not is_room:
		return
	var sender := _api.get_remote_sender_id()
	var back := returning_place(token) if client_version == version else 0
	if back != 0:
		_welcome_back(sender, back)
		return
	var reason := ""
	if client_version != version:
		reason = "version"
	elif lobby.started:
		reason = "started"
	elif free_place() == 0 or lobby.players().size() >= lobby.game_size:
		reason = "full"
	if reason != "":
		refuse.rpc_id(sender, reason)
		# Leave time for the refusal to leave before closing the connection.
		get_tree().create_timer(REFUSED_CLOSE_DELAY).timeout.connect(_drop.bind(sender))
		return
	players[sender] = free_place()
	tokens[players[sender]] = _new_token()
	lobby.add_player(players[sender])
	welcome.rpc_id(sender, players[sender], tokens[players[sender]])
	players_changed.emit(players.size())
	_broadcast_lobby()


## A player back with its token (T-102): its place again, and the game in
## progress if there is one.
func _welcome_back(sender: int, back: int) -> void:
	players[sender] = back
	welcome.rpc_id(sender, back, tokens[back])
	if lobby.leader == 0:
		lobby.leader = back
	players_changed.emit(players.size())
	if lobby.started:
		_start_game.rpc_id(sender, lobby.to_dict())
		player_returned.emit(back)
	_broadcast_lobby()


static func _new_token() -> String:
	var bytes := Crypto.new().generate_random_bytes(12)
	return bytes.hex_encode()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_held(bytes: PackedByteArray) -> void:
	var sender_place: int = players.get(_api.get_remote_sender_id(), 0) if is_room else 0
	if sender_place == 0:
		return
	var frames := PlayerCommands.frames_from_bytes(bytes)
	var held := commands_for(sender_place)
	for received in frames:
		if received.seq > held.seq:
			held.copy_held(received)
	queue_for(sender_place).receive(frames)


@rpc("any_peer", "call_remote", "reliable")
func _receive_action(seq: int, action: int) -> void:
	var sender_place: int = players.get(_api.get_remote_sender_id(), 0) if is_room else 0
	if sender_place == 0 or action < 0:
		return
	# An action, or the pick of a line of a terminal's menu (S-018).
	if action < PlayerCommands.Action.size() or PlayerCommands.picked(action) >= 0:
		queue_for(sender_place).add_action(seq, action)


@rpc("authority", "call_remote", "reliable")
func welcome(given_place: int, token: String) -> void:
	place = given_place
	resume_token = token
	_ping_left = 0.0
	joined.emit(place, token)


## Client side: its game map is ready; the room then sends it the game.
func say_ready() -> void:
	if place > 0:
		_client_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	if _sender_place() != 0:
		place_ready.emit(_sender_place())


@rpc("authority", "call_remote", "reliable")
func refuse(reason: String) -> void:
	_url = ""
	refused.emit(reason)


@rpc("any_peer", "call_remote", "unreliable")
func ping(sent_msec: int) -> void:
	if is_room and players.has(_api.get_remote_sender_id()):
		var sender := _api.get_remote_sender_id()
		_later(func() -> void: pong.rpc_id(sender, sent_msec))


@rpc("authority", "call_remote", "unreliable")
func pong(sent_msec: int) -> void:
	ping_ms = Time.get_ticks_msec() - sent_msec
	pinged.emit(ping_ms)


## With it go the gadgets it picked (S-023, T-352), which it may change
## until the game starts.
func ask_ready(is_ready: bool, loadout: Array[StringName] = []) -> void:
	if place > 0:
		_request_ready.rpc_id(1, is_ready, Loadout.to_indexes(loadout))


## Client side, the leader's choices before the launch: how many play
## (game_size, 2 to 4) or the game mode (mode, S-024, Q26), by name.
func ask_choice(choice: StringName, wanted: Variant) -> void:
	if place > 0:
		match choice:
			&"game_size":
				_request_game_size.rpc_id(1, int(wanted))
			&"mode":
				_request_mode.rpc_id(1, str(wanted))


## Client side: the leader asks to launch.
func ask_start() -> void:
	if place > 0:
		_request_start.rpc_id(1)


func _sender_place() -> int:
	return players.get(_api.get_remote_sender_id(), 0) if is_room else 0


func _broadcast_lobby() -> void:
	var state := lobby.to_dict()
	for id in players:
		_show_lobby.rpc_id(id, state)


@rpc("any_peer", "call_remote", "reliable")
func _request_game_size(wanted: int) -> void:
	if _sender_place() != 0 and lobby.set_game_size(_sender_place(), wanted):
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _request_mode(wanted: String) -> void:
	if _sender_place() != 0 and lobby.set_mode(_sender_place(), StringName(wanted)):
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(is_ready: bool, loadout: Array = []) -> void:
	if _sender_place() != 0:
		lobby.set_ready(_sender_place(), is_ready)
		if not loadout.is_empty():
			lobby.set_loadout(_sender_place(), Loadout.from_indexes(loadout))
		_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _request_start() -> void:
	if _sender_place() == 0 or not lobby.start(_sender_place()):
		return
	var state := lobby.to_dict()
	for id in players:
		_start_game.rpc_id(id, state)
	game_started.emit(lobby.to_dict(true))  # The room's map equips the picks (S-023).


## Room side: the game is over; back to the waiting room, sent to everyone.
func end_game() -> void:
	if not lobby.started:
		return
	lobby.finish()
	# Those who left and never came back lose their seat now.
	var connected: Array = players.values()
	for kept: int in tokens.keys():
		if kept not in connected:
			lobby.remove_player(kept)
			tokens.erase(kept)
	_broadcast_lobby()
	game_ended.emit()


@rpc("authority", "call_remote", "reliable")
func _show_lobby(state: Dictionary) -> void:
	lobby_state = state
	lobby_changed.emit(state)


@rpc("authority", "call_remote", "reliable")
func _start_game(state: Dictionary) -> void:
	lobby_state = state
	game_started.emit(state)


## Room side: sends a snapshot to the player in a place. Lost or late ones
## are replaced by the next.
func send_snapshot(to_place: int, snapshot: Dictionary) -> void:
	var peer_id := _peer_of(to_place)
	if peer_id != 0:
		_later(func() -> void: _snapshot.rpc_id(peer_id, snapshot))


## Room side: sends an event to the player in a place, reliably and in order.
func send_event(to_place: int, event: Array) -> void:
	var peer_id := _peer_of(to_place)
	if peer_id != 0:
		_later(func() -> void: _event.rpc_id(peer_id, event))


## The peer playing a place, 0 if nobody.
func _peer_of(place: int) -> int:
	for id: int in players:
		if players[id] == place:
			return id
	return 0


## Calls send now, or after debug_latency_ms to test a bad connection.
func _later(send: Callable) -> void:
	var jitter := 0 if is_room else settings.debug_jitter_ms
	if settings.debug_latency_ms <= 0 and jitter <= 0:
		send.call()
		return
	var due := Time.get_ticks_msec() + settings.debug_latency_ms + randi_range(0, jitter)
	_out_due_msec = maxi(due, _out_due_msec)  # In order, as on a WebSocket.
	_after(_out_due_msec, send)


## Client side: hands a received message on now, or after a random delay up
## to debug_jitter_ms, in order (S-020, T-319): a late one holds back those
## behind it, which then come in a burst, as TCP does.
func _received(hand_on: Callable) -> void:
	if is_room or settings.debug_jitter_ms <= 0:
		hand_on.call()
		return
	var due := Time.get_ticks_msec() + randi_range(0, settings.debug_jitter_ms)
	_in_due_msec = maxi(due, _in_due_msec)
	_after(_in_due_msec, hand_on)


func _after(due_msec: int, call: Callable) -> void:
	var wait := maxf((due_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	get_tree().create_timer(wait).timeout.connect(
		func() -> void:
			if _peer != null and _api.multiplayer_peer != null:
				call.call()
	)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(snapshot: Dictionary) -> void:
	_received(func() -> void: snapshot_received.emit(snapshot))


@rpc("authority", "call_remote", "reliable")
func _event(event: Array) -> void:
	_received(func() -> void: event_received.emit(event))
