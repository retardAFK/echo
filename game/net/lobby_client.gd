class_name LobbyClient
extends Node
## Asks the lobby for a room (S-010, T-094): one message, one answer, then
## the connection closes. The answer is a Dictionary as described in
## LobbyServer, or {"op": "error", "reason": "unreachable"}.

signal answered(reply: Dictionary)

@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var _socket: WebSocketPeer
var _message := {}
var _sent := false
var _left := 0.0


## Asks for a new game.
func create(url: String) -> void:
	_ask(url, {"op": "create", "version": NetAddress.build_version()})


## Asks for the room of a code typed by the player.
func join(url: String, code: String) -> void:
	_ask(
		url, {"op": "join", "code": RoomCode.normalize(code), "version": NetAddress.build_version()}
	)


func _ask(url: String, message: Dictionary) -> void:
	_message = message
	_sent = false
	_left = settings.lobby_timeout
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url(url) != OK:
		_finish({"op": "error", "reason": "unreachable"})


func _process(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	_left -= delta
	if _socket.get_available_packet_count() > 0:
		# The lobby closes right after answering: read before looking at the state.
		var reply: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		_finish(reply if reply is Dictionary else {"op": "error", "reason": "bad_reply"})
		return
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _sent:
				_socket.send_text(JSON.stringify(_message))
				_sent = true
		WebSocketPeer.STATE_CLOSED:
			_finish({"op": "error", "reason": "unreachable"})
			return
	if _left <= 0.0:
		_finish({"op": "error", "reason": "unreachable"})


func _finish(reply: Dictionary) -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	answered.emit(reply)
