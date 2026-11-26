extends "res://tools/godot/net_match.gd"
## Scripted online Versus game with 2 clients (S-024, T-381), run by the CI
## against the exported server, whose lobby has ECHO_VERSUS_TIME set (a
## short clock). Index 0 creates the game and picks the Versus mode; the
## roles are drawn: one is the boss, the other a hunted (the 2 other hunted
## are AI preys).
## - The hunted opens its first chest and takes the flare launcher (its
##   client shows it in its hands), then fires at the boss whenever it is
##   within range, and stays where it is.
## - The boss walks up to the hunted and claws it.
## Each checks what its client shows: the hunted, its launcher, a hit on the
## boss, its own health down; the boss, its health down. Then dawn comes:
## both see the end screen. Each prints ECHO_NET_VERSUS and quits with 0
## when all of this held, 1 otherwise.
## Run: godot --headless res://tools/godot/net_versus.tscn -- --index N --dir D

## Seconds between two shots.
const SHOT_TIME := 0.6
## Distance to the chest it opens, and to the hunted for the boss's claw.
const CHEST_STAND := 1.2
const CLAW_STAND := 1.6

var _versus: VersusMode
var _armed := false
var _hurt := false
var _hit_boss := false
var _shot_left := 0.0
var _fire := false


func _ready() -> void:
	players_wanted = 2
	super()


func _on_lobby_changed(lobby: LobbyState) -> void:
	var me := NetSession.get_place()
	if lobby.started or me == 0:
		return
	if lobby.leader == me and lobby.mode != GameModes.VERSUS:
		NetSession.set_game_mode(GameModes.VERSUS)
		return
	if lobby.mode != GameModes.VERSUS:
		return
	super(lobby)


func _on_game_started(lobby: LobbyState) -> void:
	GameSession.mode = lobby.mode  # As LobbyMenu.enter_game does.
	super(lobby)


func _physics_process(delta: float) -> void:
	_fire = false
	super(delta)
	if _fire:
		Input.action_press("throw")
	else:
		Input.action_release("throw")


func _step(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		_fail("timeout in phase %s" % _phase)
		return
	if _index != 0 and _code == "" and NetSession.mode == NetSession.Mode.SOLO:
		_join_when_created()
		return
	if _map == null or _net.own == null or not _net.prediction.started:
		return
	if _versus == null:
		_versus = _map.get_node_or_null("VersusMode")
		if _versus == null or _versus.rules == null:
			_versus = null
			return
	_share_left -= delta
	if _share_left <= 0.0:
		_share_left = 0.25
		_write(_seat_file(_seat), JSON.stringify({"phase": _phase, "at": _vec(_own_position())}))
	_status_left -= delta
	if _status_left <= 0.0:
		_status_left = STATUS_TIME
		print(
			(
				"seat %d %s at %s, %s"
				% [_seat, _phase, _own_position().snapped(Vector3.ONE * 0.1), _report()]
			)
		)
	if _versus.boss_health().health < _versus.boss_health().max_health:
		_hit_boss = true
	if _versus.end_screen.visible:
		_finish_versus()
		return
	if _seat == LobbyState.MONSTER_SEAT:
		_play_boss(delta)
	else:
		_play_fighter(delta)


func _play_fighter(delta: float) -> void:
	var kit := _versus.hunters[0]
	if kit.vitals.health < _versus.settings.hunted_health:
		_hurt = true
	if not kit.vitals.is_standing():
		_phase = "down"
		return
	if kit.loadout.has_weapon(&"flare_launcher"):
		_armed = true
	if not _armed:
		_phase = "chest"
		var chest := _nearest_chest()
		if chest == null:
			return
		if _go_to(chest.global_position, delta, CHEST_STAND):
			_hold_on(chest.global_position)
		return
	_phase = "fight"
	var boss := _unvec(_read(LobbyState.MONSTER_SEAT).get("at", []))
	if boss == Vector3.ZERO or boss.distance_to(_own_position()) > _versus.settings.ai_fire_range:
		return
	_face(boss)
	_shot_left -= delta
	if _shot_left <= 0.0:
		_shot_left = SHOT_TIME
		_fire = true  # A press: one flare (released the next frame).


func _play_boss(delta: float) -> void:
	_phase = "hunt"
	if _versus.boss_health().health < _versus.boss_health().max_health:
		_hurt = true
	var prey := _read(_other_seat())
	if prey.get("phase") != "fight":
		return  # It waits for the hunted to be armed.
	var at := _unvec(prey.get("at", []))
	if _go_to(at, delta, CLAW_STAND):
		_face(at)
		_shot_left -= delta
		if _shot_left <= 0.0:
			_shot_left = SHOT_TIME * 2.0
			_fire = true


func _other_seat() -> int:
	for seat in range(1, LobbyState.SEATS):
		if FileAccess.file_exists(_seat_file(seat)):
			return seat
	return 1


func _nearest_chest() -> VersusChest:
	var best: VersusChest
	for node in get_tree().get_nodes_in_group(VersusChest.GROUP):
		var chest := node as VersusChest
		if (
			best == null
			or (
				chest.global_position.distance_to(_own_position())
				< best.global_position.distance_to(_own_position())
			)
		):
			best = chest
	return best


func _report() -> String:
	return (
		"armed %s, hurt %s, boss hit %s, boss %.0f, clock %.0f s"
		% [
			_armed,
			_hurt,
			_hit_boss,
			_versus.boss_health().health,
			_versus.rules.clock,
		]
	)


func _finish_versus() -> void:
	var title := _versus.end_screen.title.text
	var result := 'seat %d, %s, end "%s", %.0f s' % [_seat, _report(), title, _elapsed]
	var planned := _hurt and _hit_boss and title != ""
	if _seat != LobbyState.MONSTER_SEAT:
		planned = planned and _armed
	if not planned:
		_fail(result)
		return
	print("ECHO_NET_VERSUS ok " + result)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	printerr("ECHO_NET_VERSUS failed: seat %d, %s" % [_seat, reason])
	get_tree().quit(1)
