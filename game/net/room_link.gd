class_name RoomLink
extends Node
## The connection between a room and its players (S-010, T-094), on both
## sides: the room server listens, each client connects. It owns a
## SceneMultiplayer set on its parent, so a room and several clients can
## live in one process (tests, CI) without mixing their messages. Its
## remote procedures need the same node name on both sides: always "Room".
## A client says hello with its build version; the room welcomes it with a
## place (1 to room_size) or refuses it (other version, room full).

signal joined(place: int)
signal refused(reason: String)
## A client could not reach the room before room_connect_timeout.
signal unreachable
## Round trip of the last ping, client side.
signal pinged(milliseconds: int)
## Room side: a player arrived or left.
signal players_changed(count: int)
## Room side: nobody has been in the room for room_idle_timeout.
signal idle_expired

const NODE_NAME := "Room"
## Seconds between refusing a player and closing its connection.
const REFUSED_CLOSE_DELAY := 0.5

@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var is_room := false
## Room side: place of each connected player, by peer id.
var players := {}
## Client side: own place once welcomed, else 0.
var place := 0
## Client side: last round trip in milliseconds, -1 before the first pong.
var ping_ms := -1

var _api := SceneMultiplayer.new()
var _peer: WebSocketMultiplayerPeer
var _url := ""
var _idle := 0.0
var _ping_left := 0.0
var _connect_left := 0.0
var _retry_left := 0.0


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


## Client side: connects to a room, trying again while it starts.
func join(url: String) -> void:
	is_room = false
	_url = url
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
			ping.rpc_id(1, Time.get_ticks_msec())


func _on_connected() -> void:
	hello.rpc_id(1, NetAddress.build_version())


func _on_connection_failed() -> void:
	# The room may still be starting: try again until room_connect_timeout.
	_retry_left = settings.room_connect_retry


func _on_server_disconnected() -> void:
	if place > 0:
		place = 0
		refused.emit("closed")


func _on_peer_connected(_id: int) -> void:
	pass  # A player counts once its hello is accepted.


func _on_peer_disconnected(id: int) -> void:
	if players.erase(id):
		players_changed.emit(players.size())


func _drop(peer_id: int) -> void:
	if _peer != null and _api.get_peers().has(peer_id):
		_peer.disconnect_peer(peer_id)


## The free place with the lowest number, or 0 if the room is full.
func free_place() -> int:
	for candidate in range(1, settings.room_size + 1):
		if not players.values().has(candidate):
			return candidate
	return 0


@rpc("any_peer", "call_remote", "reliable")
func hello(version: String) -> void:
	if not is_room:
		return
	var sender := _api.get_remote_sender_id()
	var reason := ""
	if version != NetAddress.build_version():
		reason = "version"
	elif free_place() == 0:
		reason = "full"
	if reason != "":
		refuse.rpc_id(sender, reason)
		# Leave time for the refusal to leave before closing the connection.
		get_tree().create_timer(REFUSED_CLOSE_DELAY).timeout.connect(_drop.bind(sender))
		return
	players[sender] = free_place()
	welcome.rpc_id(sender, players[sender])
	players_changed.emit(players.size())


@rpc("authority", "call_remote", "reliable")
func welcome(given_place: int) -> void:
	place = given_place
	_ping_left = 0.0
	joined.emit(place)


@rpc("authority", "call_remote", "reliable")
func refuse(reason: String) -> void:
	_url = ""
	refused.emit(reason)


@rpc("any_peer", "call_remote", "unreliable")
func ping(sent_msec: int) -> void:
	if is_room and players.has(_api.get_remote_sender_id()):
		pong.rpc_id(_api.get_remote_sender_id(), sent_msec)


@rpc("authority", "call_remote", "unreliable")
func pong(sent_msec: int) -> void:
	ping_ms = Time.get_ticks_msec() - sent_msec
	pinged.emit(ping_ms)
