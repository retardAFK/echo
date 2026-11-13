class_name LobbyServer
extends Node
## The lobby process (S-010, T-094), started with `-- --lobby`. A client
## sends one JSON message and gets one answer:
##   {"op": "create", "version": v}          -> {"op": "room", "code", "slot", "port"}
##   {"op": "join", "code": c, "version": v} -> {"op": "room", ...}
##   otherwise                               -> {"op": "error", "reason": r}
## with r in "version", "busy" (every room taken), "unknown_code", "bad_request".
## Each new game gets its own room process; its slot is freed when it stops.

## Tests turn this off and call listen() themselves.
@export var auto_start := true
@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

## Starts the room of a slot and returns its process id, or -1. Tests replace
## it to stay in one process.
var spawn_room := _spawn_process
var registry: LobbyRegistry

var _server := TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _pids := {}
## Seconds since each client connected.
var _ages := {}
var _rng := RandomNumberGenerator.new()
var _check_left := 0.0


func _ready() -> void:
	registry = LobbyRegistry.new(settings.max_rooms)
	if not auto_start:
		return
	var error := listen(settings.lobby_port)
	if error != OK:
		printerr("ECHO_LOBBY cannot listen on %d: %s" % [settings.lobby_port, error])
		get_tree().quit(1)
		return
	print(
		"ECHO_LOBBY listening on %d, version %s" % [settings.lobby_port, NetAddress.build_version()]
	)


func _exit_tree() -> void:
	_server.stop()
	for pid in _pids.values():
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)


func listen(port: int) -> Error:
	return _server.listen(port, settings.bind_address)


func _process(delta: float) -> void:
	while _server.is_connection_available():
		var socket := WebSocketPeer.new()
		if socket.accept_stream(_server.take_connection()) == OK:
			_clients.append(socket)
	for socket: WebSocketPeer in _clients.duplicate():
		socket.poll()
		_ages[socket] = _ages.get(socket, 0.0) + delta
		if _ages[socket] > settings.lobby_timeout:
			socket.close()  # A client that never asks or never leaves.
		match socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while socket.get_available_packet_count() > 0:
					var text := socket.get_packet().get_string_from_utf8()
					# The client closes once it has the answer: closing here could drop it.
					socket.send_text(JSON.stringify(answer(JSON.parse_string(text))))
			WebSocketPeer.STATE_CLOSED:
				_clients.erase(socket)
				_ages.erase(socket)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 1.0
		_free_stopped_rooms()


## The answer to one message (a parsed JSON value).
func answer(message: Variant) -> Dictionary:
	if not message is Dictionary or not (message as Dictionary).get("version") is String:
		return _error("bad_request")
	var request := message as Dictionary
	if request["version"] != NetAddress.build_version():
		return _error("version")
	match request.get("op"):
		"create":
			return _create()
		"join":
			return _join(request.get("code"))
	return _error("bad_request")


func _create() -> Dictionary:
	var opened := registry.open(_rng)
	if opened.is_empty():
		return _error("busy")
	var pid: int = spawn_room.call(opened[0], opened[1])
	if pid < 0:
		registry.close(opened[0])
		return _error("busy")
	_pids[opened[0]] = pid
	print("ECHO_LOBBY room %s in slot %d" % [opened[1], opened[0]])
	return _room(opened[0])


func _join(code: Variant) -> Dictionary:
	if not code is String:
		return _error("bad_request")
	var slot := registry.find(RoomCode.normalize(code))
	if slot == 0:
		return _error("unknown_code")
	return _room(slot)


func _room(slot: int) -> Dictionary:
	return {
		"op": "room",
		"code": registry.code_of(slot),
		"slot": slot,
		"port": settings.first_room_port + slot - 1,
	}


func _error(reason: String) -> Dictionary:
	return {"op": "error", "reason": reason}


func _free_stopped_rooms() -> void:
	for slot in _pids.keys():
		var pid: int = _pids[slot]
		if pid == 0 or OS.is_process_running(pid):
			continue  # 0: a room run by a test in this process.
		print("ECHO_LOBBY room %s stopped" % registry.code_of(slot))
		_pids.erase(slot)
		registry.close(slot)


## Frees a slot whose room stopped, for rooms not run as processes.
func close_room(slot: int) -> void:
	_pids.erase(slot)
	registry.close(slot)


func _spawn_process(slot: int, code: String) -> int:
	var args := PackedStringArray(["--headless"])
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--room", str(slot), "--code", code])
	return OS.create_process(OS.get_executable_path(), args)
