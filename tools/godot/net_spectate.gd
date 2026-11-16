extends "res://tools/godot/net_match.gd"
## Scripted online game with 3 clients for the spectator (S-010, T-107):
## index 0 is the monster, the two others the hunted of seats 1 and 2; seat 3
## is an AI. The hunted of seat 2 stands still; the monster catches it, walks
## away, its teammate frees it from its cage (S-018), it walks back to where
## it started, and so on until the third catch: it is out. Its
## client must then watch a teammate: the spectator camera is the one in use,
## at that teammate's eyes, and a click moves it to the other teammate.
## Prints ECHO_NET_SPECTATE and quits with 0 when all of this held.
## Run: godot --headless res://tools/godot/net_spectate.tscn -- --index N --dir D

## Seconds out before looking at the view, and after asking for the next one.
const SETTLE_TIME := 3.0
## How far the spectator camera may be from the watched teammate's eyes.
const EYE_REACH := 0.5

var _out_left := SETTLE_TIME
var _first_watched := -1
## Seat 2: where it waits for the monster, away from the prison.
var _home := Vector3.ZERO


func _ready() -> void:
	players_wanted = 3
	super()


func _play_hunted(delta: float) -> void:
	var player := _net.own as Player
	if _seat == 1:
		_phase = "help"
		if _read(2).get("phase") == "done":
			_succeed("helped the hunted of seat 2")
			return
		_rescue(delta)
		return
	if _net.is_spectator:
		_phase = "out"
		_check_view(delta)
		return
	if player.held:
		_phase = "captured"
	elif _phase == "start":
		_home = _own_position()
		_phase = "wait_monster"
	elif _phase in ["captured", "back"]:
		_phase = "back"  # Out of its cage: back where it waits.
		if _go_to(_home, delta, 1.0):
			_phase = "wait_monster"


func _play_monster(delta: float) -> void:
	var prey := _read(2)
	if prey.get("phase") == "done":
		_succeed("caught the hunted of seat 2 three times")
		return
	if _keep_clear(delta):
		return
	match _phase:
		"start", "away":
			var caught_once := "2:CAPTURED" in _seen
			if prey.get("phase") == "wait_monster" and (not caught_once or "2:FREE" in _seen):
				_phase = "hunt"
		"hunt":
			if "2:OUT" in _seen:
				_phase = "done"
			elif prey.get("phase") == "captured":
				_caught_at = _own_position()  # The caught one soon wakes up in a cage.
				_away_point = _far_point(_caught_at)
				_phase = "leave"
			else:
				_go_to(_unvec(prey.get("at", [])), delta, 0.0)
		"leave":
			var there := _go_to(_away_point, delta, 1.0)
			var gone := _own_position().distance_to(_caught_at)
			if there or gone >= AWAY_DISTANCE + 10.0:
				_phase = "away"


## Out of the game: the view is a teammate's, then the next one's.
func _check_view(delta: float) -> void:
	_out_left -= delta
	if _out_left > 0.0:
		return
	var problem := _view_problem()
	if problem != "":
		_fail_spectate(problem)
		return
	if _first_watched < 0:
		_first_watched = _net.watched_seat
		_net.own.commands.push(PlayerCommands.Action.INTERACT)  # What a click does.
		_out_left = SETTLE_TIME
		return
	if _net.watched_seat == _first_watched:
		_fail_spectate("a click did not move to the other teammate (seat %d)" % _first_watched)
		return
	_phase = "done"
	_write(_seat_file(_seat), JSON.stringify({"phase": _phase, "at": _vec(_own_position())}))
	_succeed("watched seat %d, then seat %d" % [_first_watched, _net.watched_seat])


## What is wrong with the spectator's view, or "".
func _view_problem() -> String:
	var view := _map.get_node_or_null("SpectatorView")
	if view == null:
		return "no SpectatorView"
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.get_parent() != view:
		return "the camera in use is %s, not the spectator's" % camera
	if _net.watched_seat not in [1, 3]:
		return "watches seat %d" % _net.watched_seat
	var puppet: NetPuppet = _net.puppets.get(_net.watched_seat)
	if puppet == null or not puppet.visible:
		return "the watched teammate (seat %d) is not shown" % _net.watched_seat
	var gap := camera.global_position.distance_to(puppet.get_eye_position())
	if gap > EYE_REACH:
		return "camera %.1f m from the teammate's eyes" % gap
	return ""


func _finish(won: bool) -> void:
	_fail_spectate("the game ended (hunted won %s) before the check, seen %s" % [won, _seen])


func _succeed(what: String) -> void:
	print("ECHO_NET_SPECTATE ok seat %d, %s, seen %s" % [_seat, what, _seen])
	get_tree().quit(0)


func _fail_spectate(reason: String) -> void:
	printerr("ECHO_NET_SPECTATE failed: seat %d, %s" % [_seat, reason])
	get_tree().quit(1)
