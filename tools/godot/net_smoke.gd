extends Node
## Connection test of the dedicated server (S-010, T-094), run by the CI
## against the exported server started with `-- --lobby`:
## creates a game at the lobby, connects 4 players to its room, waits for a
## ping from each, joins the same code again, and checks a fifth player is
## refused. Prints ECHO_NET_SMOKE and quits with 0 on success, 1 otherwise.
## Run: godot --headless res://tools/godot/net_smoke.tscn

const TIMEOUT := 20.0
const PLAYERS := 4

var _settings: NetSettings = preload("res://game/data/net_settings.tres")
var _lobby: LobbyClient
var _clients: Array[RoomLink] = []
var _late: RoomLink
var _late_reason := ""
var _code := ""
var _url := ""
var _rejoined := false
var _elapsed := 0.0


func _ready() -> void:
	_lobby = LobbyClient.new()
	add_child(_lobby)
	_lobby.answered.connect(_on_created, CONNECT_ONE_SHOT)
	_lobby.create(NetAddress.lobby_url(_settings))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		_fail("timeout (code %s, %s)" % [_code, _state()])
		return
	if _clients.size() < PLAYERS or not _rejoined or _late_reason == "":
		return
	if not _clients.all(func(c: RoomLink) -> bool: return c.ping_ms >= 0):
		return
	if _late_reason != "full":
		_fail("fifth player: %s instead of full" % _late_reason)
		return
	var pings := _clients.map(func(c: RoomLink) -> int: return c.ping_ms)
	print("ECHO_NET_SMOKE ok code %s, 4 players, pings %s ms, fifth refused" % [_code, pings])
	get_tree().quit(0)


func _on_created(reply: Dictionary) -> void:
	if reply.get("op") != "room":
		_fail("create: %s" % reply)
		return
	_code = reply["code"]
	_url = NetAddress.room_url(_settings, int(reply["slot"]), int(reply["port"]))
	for i in PLAYERS:
		var client := _link()
		client.joined.connect(_on_joined, CONNECT_ONE_SHOT)
		client.unreachable.connect(_fail.bind("room unreachable"))
		client.join(_url)
		_clients.append(client)
	_lobby.answered.connect(_on_rejoined, CONNECT_ONE_SHOT)
	_lobby.join(NetAddress.lobby_url(_settings), _code.to_lower())


func _on_rejoined(reply: Dictionary) -> void:
	if reply.get("code") != _code:
		_fail("join: %s" % reply)
		return
	_rejoined = true


func _on_joined(_place: int) -> void:
	var joined := _clients.filter(func(c: RoomLink) -> bool: return c.place > 0)
	if joined.size() == PLAYERS and _late == null:
		_late = _link()
		_late.refused.connect(func(reason: String) -> void: _late_reason = reason)
		_late.join(_url)


## A room link under its own node, so each player has its own connection.
func _link() -> RoomLink:
	var holder := Node.new()
	add_child(holder)
	var link := RoomLink.new()
	holder.add_child(link)
	return link


func _state() -> String:
	return (
		"places %s, rejoined %s, fifth %s"
		% [
			_clients.map(func(c: RoomLink) -> int: return c.place),
			_rejoined,
			_late_reason,
		]
	)


func _fail(reason: String) -> void:
	printerr("ECHO_NET_SMOKE failed: %s" % reason)
	get_tree().quit(1)
