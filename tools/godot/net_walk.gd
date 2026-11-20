extends Node
## Online walk test (S-010, Q8, T-097), run by the CI after net_smoke against
## the exported server: creates a game, launches it as the only player (a
## hunted, the AI monster on the room), sprints forward for 4 s with
## walk_latency_ms (150 ms) added to every message, and checks that the
## predicted position never drifted from the room's beyond walk_max_gap. It
## also checks that the map mirrors the room's (T-099): its fuse boxes hold
## the fuses the room drew.
## With --bad-link (S-020, T-330, piste T7), the client also gets bursts of
## up to bad_jitter_ms, and the gap must stay under bad_max_gap. The values
## are in game/data/net_test_settings.tres. --jitter N sets the bursts by hand.
## Prints ECHO_NET_WALK and quits with 0 on success, 1 otherwise.
## Run: godot --headless res://tools/godot/net_walk.tscn [-- --bad-link]

const TIMEOUT := 40.0
const WALK_TIME := 4.0
const MIN_DISTANCE := 3.0
const TEST_SETTINGS := preload("res://game/data/net_test_settings.tres")

var _settings := NetSettings.new()
var _lobby := LobbyClient.new()
var _map: GameMap
var _elapsed := 0.0
var _walked := -1.0
var _start := Vector3.ZERO
## Gap between prediction and room that fails the test.
var _max_gap: float = TEST_SETTINGS.walk_max_gap


func _ready() -> void:
	_settings.debug_latency_ms = TEST_SETTINGS.walk_latency_ms
	var args := OS.get_cmdline_user_args()
	if args.has("--bad-link"):  # S-020, T-330.
		_settings.debug_jitter_ms = TEST_SETTINGS.bad_jitter_ms
		_max_gap = TEST_SETTINGS.bad_max_gap
	var at := args.find("--jitter")  # S-020, T-319: bursts, as on a real WebSocket.
	if at >= 0 and at + 1 < args.size():
		_settings.debug_jitter_ms = int(args[at + 1])
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
	if not lobby.is_ready(me):
		NetSession.set_ready(true)
	elif lobby.can_start(me):
		NetSession.start_game()


func _on_game_started(lobby: LobbyState) -> void:
	GameSession.online_seat = lobby.seat_of(NetSession.get_place())
	_map = load("res://game/maps/tilleuls/tilleuls.scn").instantiate()
	add_child(_map)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		_fail("timeout")
		return
	if _map == null:
		return
	var net: NetGame = _map.get_node("NetGame")
	if not net.prediction.started:
		return
	if _walked < 0.0:
		_walked = 0.0
		_start = net.own.global_position
		Input.action_press("move_forward")
		Input.action_press("sprint")
		return
	_walked += delta
	if _walked < WALK_TIME:
		return
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var distance := net.own.global_position.distance_to(_start)
	var fuses := _map.get_fuse_boxes().filter(func(box: FuseBox) -> bool: return box.has_fuse)
	var result := (
		(
			"moved %.1f m, worst gap %.2f m (max %.2f), link %d+0..%d ms, ping %d ms,"
			+ " %d fuses mirrored, %d map messages of %d B (S-020, T-303)"
		)
		% [
			distance,
			net.worst_error,
			_max_gap,
			_settings.debug_latency_ms,
			_settings.debug_jitter_ms,
			NetSession.get_ping_ms(),
			fuses.size(),
			net.world_total,
			net.world_bytes,
		]
	)
	if (
		distance < MIN_DISTANCE
		or net.worst_error >= _max_gap
		or fuses.size() != _map.game_loop.rules.fuse_count
	):
		_fail(result)
		return
	print("ECHO_NET_WALK ok " + result)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	printerr("ECHO_NET_WALK failed: %s" % reason)
	get_tree().quit(1)
