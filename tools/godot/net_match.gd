extends Node
## Scripted online game with 4 clients (S-010, T-103), run by the CI against
## the exported server: 4 processes of this scene play a whole game, each
## with 75 ms added to every message, steering their avatar with the same
## commands as a player (keys and where it looks).
## - Index 0 creates the game, writes its code to <dir>/code, and takes the
##   monster's seat; the others join with the code. Each plays its seat.
## - Each hunted takes the fuse of one box (seat 1 the first fused box, and
##   so on). The monster then catches the hunted of seat 2 at its box and
##   walks away; a free teammate frees it once the monster is far (any
##   hunted caught on the way is freed the same way); the freed one takes
##   back the fuse it dropped. All three place their fuses, and run for the
##   exit once it opens.
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
## A fuse dropped closer than this is the one a freed hunted lost.
const DROP_REACH := 4.0
## A hunted waits while the monster it is not prey to is this close; the
## monster steps back only within half of it, so it can walk past (and
## from further when it stands away, so the waiting hunted can go on).
const CLEARANCE := 6.0
## Seconds between two lines on what each player is doing.
const STATUS_TIME := 10.0
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "sprint", "interact"
]

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
var _last_position := Vector3.ZERO
var _sidestep_left := 0.0
var _box: FuseBox
var _seen := []
var _away_point := Vector3.ZERO
var _sidesteps := 0
var _status_left := STATUS_TIME


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
	if _index == 0 and lobby.seat_of(me) != LobbyState.MONSTER_SEAT:
		if lobby.seats[LobbyState.MONSTER_SEAT] == 0:
			NetSession.take_seat(LobbyState.MONSTER_SEAT)
		return
	if not lobby.is_ready(me):
		NetSession.set_ready(true)
	elif lobby.players().size() == PLAYERS and lobby.can_start(me):
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
			if fused.size() == loop.settings.fuse_count:
				_box = fused[_seat - 1]
				_phase = "to_box"
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
		"freed":  # Takes back the fuse it dropped at its feet.
			var drop := _drop_near()
			if drop != null:
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


## A fuse dropped within reach, or null.
func _drop_near() -> Node3D:
	for drop: Node3D in _map.game_loop.drops:
		if drop.global_position.distance_to(_own_position()) < DROP_REACH:
			return drop
	return null


## Frees a captured teammate once the monster is far from it. Returns true
## while busy with it.
func _rescue(delta: float) -> bool:
	var monster := _unvec(_read(LobbyState.MONSTER_SEAT).get("at", []))
	for seat in [1, 2, 3]:
		var mate := _read(seat)
		if seat == _seat or mate.get("phase") != "captured":
			continue
		var at := _unvec(mate.get("at", []))
		if at.distance_to(monster) < SAFE_DISTANCE:
			continue
		var flat := Vector2(at.x - _own_position().x, at.z - _own_position().z)
		if flat.length() > 1.1:
			_go_to(at, delta, 1.1)
		else:
			_hold_on(at)
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
				_away_point = _far_point(_unvec(prey.get("at", [])))
				_phase = "leave"
			else:
				_go_to(_unvec(prey.get("at", [])), delta, 0.0)
		"leave":
			var there := _go_to(_away_point, delta, 1.0)
			var gone := _own_position().distance_to(_unvec(prey.get("at", [])))
			if there or gone >= AWAY_DISTANCE + 10.0:
				_phase = "away"
		"away":
			pass


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
	var result := (
		"seat %d, phase %s, hunted won %s, seen %s, %.0f s"
		% [_seat, _phase, won, _seen, _map.game_loop.get_duration()]
	)
	var planned := won and "2:CAPTURED" in _seen and "2:FREE" in _seen
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
