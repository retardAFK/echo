extends Node
## Online cut test (S-010, Q7, T-102), run by the CI after net_walk against
## the exported server: creates a game, launches it as the only player (a
## hunted), then cuts the connection and connects again with the resume
## token. The room must give the same place back with the game in progress,
## and send the map as it is now (the fuses the room drew).
## Prints ECHO_NET_REJOIN and quits with 0 on success, 1 otherwise.
## Run: godot --headless res://tools/godot/net_rejoin.tscn

const TIMEOUT := 40.0
## Seconds of the first game before the cut.
const PLAY_TIME := 1.5

var _settings := NetSettings.new()
var _lobby := LobbyClient.new()
var _map: GameMap
var _elapsed := 0.0
var _played := 0.0
var _place := 0
var _cut := false


func _ready() -> void:
	NetSession.settings = _settings
	_lobby.settings = _settings
	add_child(_lobby)
	_lobby.answered.connect(_on_answered)
	NetSession.lobby_changed.connect(_on_lobby_changed)
	NetSession.game_started.connect(_on_game_started)
	NetSession.refused.connect(_fail)
	NetSession.unreachable.connect(_fail.bind("room unreachable"))
	_lobby.create(NetAddress.lobby_url(_settings))


func _on_answered(reply: Dictionary) -> void:
	if reply.get("op") != "room":
		_fail("lobby: %s" % reply)
		return
	NetSession.join(NetAddress.room_url(_settings, int(reply["slot"]), int(reply["port"])))


func _on_lobby_changed(lobby: LobbyState) -> void:
	var me := NetSession.get_place()
	if lobby.started:
		return
	if not lobby.is_ready(me):
		NetSession.set_ready(true)
	elif lobby.can_start(me):
		NetSession.start_game()


func _on_game_started(lobby: LobbyState) -> void:
	if _map != null:
		remove_child(_map)
		_map.free()  # Back after the cut: a new map, as a scene change would make.
		_map = null
	GameSession.online_seat = lobby.seat_of(NetSession.get_place())
	_map = load("res://game/maps/tilleuls/tilleuls.tscn").instantiate()
	add_child(_map)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		_fail("timeout")
		return
	if _map == null or not _map.is_inside_tree():
		return
	var net: NetGame = _map.get_node("NetGame")
	if not net.prediction.started:
		return
	_played += delta
	if _played < PLAY_TIME:
		return
	if not _cut:
		_cut = true
		_played = 0.0
		_place = NetSession.get_place()
		NetSession.leave()  # The cut: the room keeps the place.
		var old := _map
		_map = null
		remove_child(old)
		old.free()
		NetSession.rejoin()
		return
	var fuses := _map.get_fuse_boxes().filter(func(box: FuseBox) -> bool: return box.has_fuse)
	var result := (
		"place %d back as %d, %d fuses mirrored" % [_place, NetSession.get_place(), fuses.size()]
	)
	if NetSession.get_place() != _place or fuses.size() != _map.game_loop.settings.fuse_count:
		_fail(result)
		return
	print("ECHO_NET_REJOIN ok " + result)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	printerr("ECHO_NET_REJOIN failed: %s" % reason)
	get_tree().quit(1)
