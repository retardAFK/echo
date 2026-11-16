extends Node
## Scripted online game with 4 clients (S-010, T-103), run by the CI against
## the exported server: 4 processes of this scene play a whole game, each
## with 75 ms added to every message, steering their avatar with the same
## commands as a player (keys and where it looks).
## - Index 0 creates the game and writes its code to <dir>/code; the others
##   join with the code. The roles are drawn at launch; each plays its seat.
## - Each hunted takes the fuse of one box (seat 1 the first fused box, and
##   so on). With fewer fuses, a hunted left without one types the code on
##   the transformer's keypad when the game has one (S-018, T-267: the CI's
##   lobby imposes ECHO_OBJECTIVES=fuse,fuse,code), reading it from the
##   post-it as its client shows it. The monster then catches the hunted of seat 2 at its box and
##   walks away; the caught one wakes up in a cage of the prison (S-018); a
##   free teammate frees it at the grille once the monster is far (any
##   hunted caught on the way is freed the same way); the freed one goes back
##   for the fuse it dropped where it was caught. All three place their
##   fuses, and run for the exit once it opens.
## The processes tell each other their phase and position through files in
## <dir> (seat<N>.json). Each prints ECHO_NET_MATCH and quits with 0 when
## the hunted won as planned, 1 otherwise.
## Run: godot --headless res://tools/godot/net_match.tscn -- --index N --dir D

const TIMEOUT := 420.0
const LATENCY_MS := 75
const PLAYERS := 4
const MAP := "res://game/maps/tilleuls/tilleuls.tscn"
## Close enough to a point of the path to aim at the next one, in meters.
const WAYPOINT_REACH := 0.6
## Seconds between two paths, and without progress before trying around.
const REPATH_TIME := 1.0
## A closed door this close ahead on the path: the player opens it (S-016).
const DOOR_REACH := 1.2
const STUCK_TIME := 1.5
## The monster walks at least that far from the hunted it caught.
const AWAY_DISTANCE := 30.0
## A teammate goes to free a captured hunted once the monster is that far.
const SAFE_DISTANCE := 20.0
## Seconds a freed hunted waits in its cage, so its rescuer goes out first.
const FREED_WAIT := 4.0
## A hunted waits while the monster it is not prey to is this close; the
## monster steps back only within half of it, so it can walk past (and
## from further when it stands away, so the waiting hunted can go on).
const CLEARANCE := 6.0
## Seconds between two lines on what each player is doing.
const STATUS_TIME := 10.0
## Seconds between two keys typed on the keypad.
const KEY_TIME := 0.4
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "sprint", "interact"
]

## Players the leader waits for before it launches.
var players_wanted := PLAYERS
var _settings := NetSettings.new()
var _lobby := LobbyClient.new()
var _index := 0
var _dir := "user://net_match"
var _code := ""
var _map: GameMap
var _net: NetGame
var _seat := -1
var _phase := "lobby"
var _elapsed := 0.0
## The actions held this frame.
var _wanted := {}
var _share_left := 0.0
var _path := PackedVector3Array()
var _path_target := Vector3.INF
## The path point walked to now: those before it are behind.
var _path_index := 0
var _repath_left := 0.0
var _stuck_left := STUCK_TIME
## Freed: seconds before it walks out of the prison.
var _freed_wait := 0.0
## Monster: where it caught the hunted of seat 2.
var _caught_at := Vector3.ZERO
var _last_position := Vector3.ZERO
var _sidestep_left := 0.0
var _box: FuseBox
var _seen := []
var _away_point := Vector3.ZERO
var _sidesteps := 0
var _status_left := STATUS_TIME
## Keypad: digits typed, and seconds before the next one.
var _typed := 0
var _key_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # The end screen pauses the game.
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--index":
				_index = int(args[i + 1])
			"--dir":
				_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_dir)
	_settings.debug_latency_ms = LATENCY_MS
	NetSession.settings = _settings
	_lobby.settings = _settings
	add_child(_lobby)
	_lobby.answered.connect(_on_answered)
	NetSession.lobby_changed.connect(_on_lobby_changed)
	NetSession.game_started.connect(_on_game_started)
	NetSession.event_received.connect(_on_event)
	NetSession.refused.connect(_fail)
	NetSession.unreachable.connect(_fail.bind("room unreachable"))
	if _index == 0:
		for name in ["code", "seat0.json", "seat1.json", "seat2.json", "seat3.json"]:
			DirAccess.remove_absolute(_dir.path_join(name))
		_lobby.create(NetAddress.lobby_url(_settings))


func _on_answered(reply: Dictionary) -> void:
	if reply.get("op") != "room":
		_fail("lobby: %s" % reply)
		return
	if _index == 0:
		_code = reply["code"]
		_write(_dir.path_join("code"), _code)
	NetSession.join(NetAddress.room_url(_settings, int(reply["slot"]), int(reply["port"])))


func _on_lobby_changed(lobby: LobbyState) -> void:
	var me := NetSession.get_place()
	if lobby.started or me == 0:
		return
	if not lobby.is_ready(me):
		NetSession.set_ready(true)
	elif lobby.players().size() == players_wanted and lobby.can_start(me):
		NetSession.start_game()


func _on_game_started(lobby: LobbyState) -> void:
	if _map != null:
		return
	_seat = lobby.seat_of(NetSession.get_place())
	GameSession.online_seat = _seat
	GameSession.role = (
		GameSession.Role.MONSTER if _seat == LobbyState.MONSTER_SEAT else GameSession.Role.HUNTED
	)
	_map = load(MAP).instantiate()
	add_child(_map)
	_net = _map.get_node("NetGame")
	if _map.pause_menu == null:
		_fail("no pause menu online (S-013, T-164)")
		return
	_phase = "start"


## What the room tells: captures and rescues, for the report.
func _on_event(event: Array) -> void:
	if event.size() == 3 and event[0] == NetGame.Event.CAUGHT:
		_seen.append("%d:%s" % [event[1], CaptureState.State.keys()[event[2]]])


func _physics_process(delta: float) -> void:
	_wanted.clear()
	_step(delta)
	for action in ACTIONS:
		if _wanted.has(action):
			Input.action_press(action)
		else:
			Input.action_release(action)


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
	_share_left -= delta
	if _share_left <= 0.0:
		_share_left = 0.25
		_write(_seat_file(_seat), JSON.stringify({"phase": _phase, "at": _vec(_own_position())}))
	_status_left -= delta
	if _status_left <= 0.0:
		_status_left = STATUS_TIME
		var speed := Vector2(_net.own.velocity.x, _net.own.velocity.z).length()
		print(
			(
				(
					"seat %d %s at %s, path %d/%d, %.1f m/s, gap %.2f m"
					% [
						_seat,
						_phase,
						_own_position().snapped(Vector3.ONE * 0.1),
						_path_index,
						_path.size(),
						speed,
						_net.worst_error,
					]
				)
				+ _aim_status()
			)
		)
	var loop := _map.game_loop
	if loop.is_over:
		_finish(loop.hunted_won)
		return
	if _seat == LobbyState.MONSTER_SEAT:
		_play_monster(delta)
	else:
		_play_hunted(delta)


## What a hunted aims at and holds, for the status lines: a hunted that
## stands still at a box or the transformer shows why.
func _aim_status() -> String:
	var player := _net.own as Player
	if player == null:
		return ""
	var target := player.get_interactable()
	var box := ""
	if _box != null:
		box = ", box %s fuse %s" % [_box.global_position.snapped(Vector3.ONE * 0.1), _box.has_fuse]
	return (
		", aims %s, hold %.2f%s"
		% [target.name if target != null else "nothing", player.get_hold_ratio(), box]
	)


func _join_when_created() -> void:
	if not FileAccess.file_exists(_dir.path_join("code")):
		return
	_code = FileAccess.get_file_as_string(_dir.path_join("code")).strip_edges()
	if _code != "":
		_lobby.join(NetAddress.lobby_url(_settings), _code)


func _play_hunted(delta: float) -> void:
	var loop := _map.game_loop
	var player := _net.own as Player
	if _monster_close():
		return
	if loop.is_exit_open():
		_phase = "exit"
		_go_to(loop_exit(), delta)
		return
	if player.held and _phase != "captured":
		_phase = "captured"
	match _phase:
		"start":
			var fused := _map.get_fuse_boxes().filter(
				func(box: FuseBox) -> bool: return box.has_fuse
			)
			if fused.size() == loop.rules.fuse_count and _seat - 1 < fused.size():
				_box = fused[_seat - 1]
				_phase = "to_box"
			elif fused.size() == loop.rules.fuse_count and _wants_code():
				_phase = "to_keypad"
		"to_keypad":
			var keypad := _keypad()
			if player.terminal == keypad:
				_phase = "typing"
				_typed = 0
			elif _go_to(keypad.seat_point(), delta, 0.4):
				_hold_on(keypad.global_position + Vector3.UP * 0.9)
		"typing":
			_type_code(player, delta)
		"helper":  # Nothing left to do but free the others.
			_rescue(delta)
		"to_box":
			if _go_to(_box.get_approach_point(), delta, 0.4):
				_hold_on(_box.global_position)
				if not _box.has_fuse:
					_phase = "wait_monster" if _seat == 2 else "fuse"
		"wait_monster":  # Seat 2 stays at its box to be caught.
			pass
		"captured":
			if not player.held:
				_phase = "freed"
				_freed_wait = FREED_WAIT
		"freed" when _freed_wait > 0.0:  # Lets its rescuer walk out first.
			_freed_wait -= delta
		"freed":  # Takes back the fuse it dropped where it was caught.
			var drop := _nearest_drop()
			if drop != null:
				if _go_to(drop.global_position, delta, 1.0):
					_hold_on(drop.global_position)
			else:
				_phase = "fuse" if loop.carried_by(player) > 0 else "to_box"
		"fuse":
			if _rescue(delta):
				return
			if _go_to(_transformer_spot(), delta, 0.5):
				_phase = "repair"
		"repair":
			if _rescue(delta):
				_phase = "fuse"  # Back to the transformer after.
				return
			_hold_on(_map.game_loop.transformer.global_position)


## The game has a code to type and this client shows it.
func _wants_code() -> bool:
	var quests := _map.game_loop.quests
	return quests != null and quests.wants_code() and quests.code.length() == 4


func _keypad() -> Terminal:
	for terminal: Terminal in CityNetwork.of(_map).terminals:
		if terminal.kind == Terminal.Kind.CODE:
			return terminal
	return null


## Seated at the keypad: types the code read on the post-it, a key at a
## time, then gets up. Typed again if the room did not take it.
func _type_code(player: Player, delta: float) -> void:
	var quests := _map.game_loop.quests
	if player.terminal == null:
		_phase = "helper" if not quests.wants_code() else "to_keypad"
		return
	_key_left -= delta
	if _key_left > 0.0:
		return
	_key_left = KEY_TIME
	if not quests.wants_code():
		# Done: gets up. A press, as a key gives: a held "interact" alone
		# pushes no action (LocalControls reads key events).
		player.commands.push(PlayerCommands.Action.INTERACT)
		_key_left = KEY_TIME * 5.0
		return
	if _typed >= quests.code.length():
		_typed = 0  # Not taken: once more after a pause.
		_key_left = KEY_TIME * 5.0
		return
	var digit := int(quests.code[_typed])
	player.commands.push_pick(9 if digit == 0 else digit - 1)
	_typed += 1


## The one teammate who frees a captured hunted: the first other one still
## free. Two of them would wedge in the narrow cellar doors (S-018).
func _rescuer_of(seat: int) -> int:
	for other in [1, 2, 3]:
		if other != seat and _read(other).get("phase") != "captured":
			return other
	return -1


## The nearest fuse lying on the ground.
func _nearest_drop() -> Node3D:
	var best: Node3D = null
	for drop: Node3D in _map.game_loop.drops:
		if best == null or _closer(drop.global_position, best.global_position):
			best = drop
	return best


func _closer(a: Vector3, b: Vector3) -> bool:
	return _own_position().distance_to(a) < _own_position().distance_to(b)


## Frees a captured teammate once the monster is far from it: at the grille
## of its cage (S-018), once it is in one. Returns true while busy with it.
func _rescue(delta: float) -> bool:
	var monster := _unvec(_read(LobbyState.MONSTER_SEAT).get("at", []))
	var prison := Prison.of(_map)
	for seat in [1, 2, 3]:
		var mate := _read(seat)
		if seat == _seat or mate.get("phase") != "captured" or _rescuer_of(seat) != _seat:
			continue
		var cage := prison.cage_of_seat(seat) if prison != null else null
		if prison != null and cage == null:
			continue  # Not in its cage yet.
		var at := cage.outside_point() if cage != null else _unvec(mate.get("at", []))
		if at.distance_to(monster) < SAFE_DISTANCE:
			continue
		var flat := Vector2(at.x - _own_position().x, at.z - _own_position().z)
		if flat.length() > 0.5:
			_go_to(at, delta, 0.4)
		else:
			_hold_on(cage.inside_point() if cage != null else at)
		return true
	return false


func _play_monster(delta: float) -> void:
	var prey := _read(2)
	if _keep_clear(delta):
		return
	match _phase:
		"start":
			if prey.get("phase") == "wait_monster":
				_phase = "hunt"
		"hunt":
			if prey.get("phase") == "captured" or "2:CAPTURED" in _seen:
				# Where it caught it: the caught one soon wakes up in a cage (S-018).
				_caught_at = _own_position()
				_away_point = _far_point(_caught_at)
				_phase = "leave"
			else:
				_go_to(_unvec(prey.get("at", [])), delta, 0.0)
		"leave":
			var there := _go_to(_away_point, delta, 1.0)
			var gone := _own_position().distance_to(_caught_at)
			if (there or gone >= AWAY_DISTANCE + 10.0) and _clear_of_cages():
				_phase = "away"
		"away":
			pass


## Far enough from the cages for the hunted to free the caught one there
## (S-018): stopping on its way past them, it kept them from coming.
func _clear_of_cages() -> bool:
	var prison := Prison.of(_map)
	if prison == null:
		return true
	for cage: Cage in prison.cages:
		if _own_position().distance_to(cage.outside_point()) < SAFE_DISTANCE + 5.0:
			return false
	return true


## The monster steps back from a hunted it is not after, so as not to catch
## it by running into it. Returns true while it does.
func _keep_clear(delta: float) -> bool:
	var here := _own_position()
	for seat in [1, 2, 3]:
		if seat == 2 and _phase == "hunt":
			continue
		var other := _read(seat)
		if other.get("phase") == "captured":
			continue  # A captured hunted cannot be caught again by touch.
		var at := _unvec(other.get("at", []))
		# Standing away, it makes room for the hunted waiting on it.
		var room := CLEARANCE + 1.0 if _phase == "away" else CLEARANCE * 0.5
		if other.has("at") and at.distance_to(here) < room:
			_face(here + (here - at))
			_wanted["move_forward"] = true
			_wanted["sprint"] = true
			_unstick(delta, here)
			_path = PackedVector3Array()
			return true
	return false


## A hunted waits while the monster is close, unless it is the one the
## monster comes for.
func _monster_close() -> bool:
	if _phase in ["wait_monster", "captured"]:
		return false
	var monster := _read(LobbyState.MONSTER_SEAT)
	var at := _unvec(monster.get("at", []))
	return monster.has("at") and at.distance_to(_own_position()) < CLEARANCE


## A patrol point far from the captured hunted, the transformer and the exit.
func _far_point(from: Vector3) -> Vector3:
	var best := from
	var best_score := -1.0
	var avoid: Array[Vector3] = [from, _map.game_loop.transformer.global_position, loop_exit()]
	var prison := Prison.of(_map)
	if prison != null:
		avoid.append(prison.bell_position())  # Its clock stops near it (S-018).
	for point in Prey.markers_of(_map.get_node("PatrolRoute")):
		var score := INF
		for other in avoid:
			score = minf(score, point.distance_to(other))
		if score > best_score:
			best = point
			best_score = score
	return best


func loop_exit() -> Vector3:
	return (_map.find_children("*", "ExitZone", true, false)[0] as Node3D).global_position


## Beside the transformer, a different place for each hunted.
func _transformer_spot() -> Vector3:
	var transformer := _map.game_loop.transformer
	var side := transformer.global_basis.z * (transformer.half_size.y + 0.8)
	return transformer.global_position + side + transformer.global_basis.x * (_seat - 2) * 1.2


## Walks (sprints) along the navigation path to a point. Returns true once
## within reach of it.
func _go_to(target: Vector3, delta: float, reach := 0.8) -> bool:
	var here := _own_position()
	if Vector2(target.x - here.x, target.z - here.z).length() <= maxf(reach, 0.3):
		return true
	_repath_left -= delta
	if _path.is_empty() or _repath_left <= 0.0 or target.distance_to(_path_target) > 0.5:
		var nav := _map.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(nav, here, target, true)
		_path_target = target
		_path_index = 0
		_repath_left = REPATH_TIME
	while (
		_path_index < _path.size()
		and (
			Vector2(_path[_path_index].x - here.x, _path[_path_index].z - here.z).length()
			<= WAYPOINT_REACH
		)
	):
		_path_index += 1
	var next := _path[_path_index] if _path_index < _path.size() else target
	_face(next)
	var door := Door.closed_ahead(get_tree(), here, next - here, DOOR_REACH)
	if door != null and door.can_use(_net.own):
		var leaf := door.closest_flat_point(here)
		_face(Vector3(leaf.x, here.y, leaf.y))
		_wanted["interact"] = true  # Standing: it opens at once.
	_wanted["move_forward"] = true
	_wanted["sprint"] = true
	_unstick(delta, here)
	return false


## Tries around an obstacle when it has not moved for a while: steps back
## and aside, one side then the other.
func _unstick(delta: float, here: Vector3) -> void:
	if _sidestep_left > 0.0:
		_sidestep_left -= delta
		_wanted.erase("move_forward")
		_wanted["move_back"] = true
		_wanted["move_right" if _sidesteps % 2 == 0 else "move_left"] = true
		return
	if here.distance_to(_last_position) > 0.3:
		_last_position = here
		_stuck_left = STUCK_TIME
		return
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		_stuck_left = STUCK_TIME
		_sidestep_left = 0.6
		_sidesteps += 1
		_path = PackedVector3Array()


## Looks at a point and holds "interact".
func _hold_on(at: Vector3) -> void:
	_face(at)
	_wanted["interact"] = true


func _face(at: Vector3) -> void:
	var gap := at - _own_position()
	if Vector2(gap.x, gap.z).length() > 0.05:
		_net.own.set_look(atan2(-gap.x, -gap.z), 0.0)


func _own_position() -> Vector3:
	return _net.own.global_position


func _finish(won: bool) -> void:
	var rules := _map.game_loop.rules
	var kinds := Array(rules.objectives).map(
		func(kind: int) -> String: return LoopRules.Objective.keys()[kind].to_lower()
	)
	var result := (
		"seat %d, phase %s, hunted won %s, objectives %s, seen %s, %.0f s"
		% [_seat, _phase, won, ",".join(kinds), _seen, _map.game_loop.get_duration()]
	)
	var planned := won and "2:CAPTURED" in _seen and "2:FREE" in _seen
	var wanted := OS.get_environment("ECHO_OBJECTIVES")
	if wanted != "" and ",".join(kinds) != wanted:
		planned = false  # The room's objectives did not reach this client.
	if not planned:
		_fail(result)
		return
	print("ECHO_NET_MATCH ok " + result)
	get_tree().quit(0)


func _seat_file(seat: int) -> String:
	return _dir.path_join("seat%d.json" % seat)


func _read(seat: int) -> Dictionary:
	var text := FileAccess.get_file_as_string(_seat_file(seat))
	var data: Variant = JSON.parse_string(text) if text != "" else null
	return data if data is Dictionary else {}


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)  # Whole, never half written.


static func _vec(at: Vector3) -> Array:
	return [at.x, at.y, at.z]


static func _unvec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2]) if values.size() == 3 else Vector3.ZERO


func _fail(reason: String) -> void:
	printerr("ECHO_NET_MATCH failed: seat %d, %s" % [_seat, reason])
	get_tree().quit(1)
