extends Node
## Plays whole games of the loop between AI players, sped up, and prints how
## they went (spec S-007, T-058 and T-060). Headless:
##     godot --headless tools/godot/simulate_games.tscn -- [games] [speed] [--no-monster]
##         [--preys N]
## Without a monster, the AI prey plays alone (it must get out without being
## stuck). With one, the AI prey plays against the AI monster. With --preys 3,
## three AI preys play together (S-010, T-100): out as soon as one gets out,
## caught once none is free.

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
## Longest game, in game seconds, before it counts as stuck.
const TIME_LIMIT := 1800.0

var _games := 5
var _speed := 8.0
var _with_monster := true
var _preys := 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_games = int(args[0])
	if args.size() > 1 and args[1].is_valid_float():
		_speed = float(args[1])
	_with_monster = not args.has("--no-monster")
	var preys_at := args.find("--preys")
	if preys_at >= 0 and preys_at + 1 < args.size():
		_preys = maxi(int(args[preys_at + 1]), 1)
	Engine.physics_ticks_per_second = int(60 * _speed)
	Engine.max_physics_steps_per_frame = int(8 * _speed)
	Engine.time_scale = _speed
	var results := []
	for i in _games:
		results.append(await _play(i))
	var outcome := {}
	for r: Dictionary in results:
		outcome[r.result] = outcome.get(r.result, 0) + 1
	var durations := results.map(func(r: Dictionary) -> float: return r.duration)
	var wins := results.filter(func(r: Dictionary) -> bool: return r.result == "out").size()
	var stuck := results.filter(func(r: Dictionary) -> bool: return r.result == "stuck").size()
	var scans := 0
	var chases := 0
	var escapes := 0
	for r: Dictionary in results:
		scans += r.scans
		chases += r.chases
		escapes += r.escapes
	var mean := 0.0
	for d: float in durations:
		mean += d / durations.size()
	print(
		(
			(
				"SUMMARY games %d, prey out %d, caught %d, stuck %d, mean %.1f min, scans %d,"
				+ " chases %d, escapes %d"
			)
			% [_games, wins, _games - wins - stuck, stuck, mean / 60.0, scans, chases, escapes]
		)
	)
	get_tree().quit()


func _play(index: int) -> Dictionary:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = load(MAP_PATH).instantiate()
	add_child(map)
	map.end_screen.change_scene = false
	var avatar := map.avatar
	if _preys > 1:
		map.monster_role.add_ai_preys(_preys)
	if _with_monster:
		map.monster_role.play_ai_against_ai()
	else:
		avatar.process_mode = Node.PROCESS_MODE_DISABLED
		avatar.global_position = Vector3(0, -50, 0)  # Out of sight and hearing.
	var loop := map.game_loop
	var monsters := map.get_children().filter(func(n: Node) -> bool: return n is Monster)
	var monster: Monster = monsters[0] if not monsters.is_empty() else null
	var grid := TestGrid.new(monster)  # S-020, T-317.
	grid.chases = loop.chases  # Escapes as the end screen counts them (T-322).
	var started := Time.get_ticks_msec()
	var last_report := 0.0
	var result := "stuck"
	while loop.get_duration() < TIME_LIMIT:
		await get_tree().physics_frame
		grid.watch(monster, map.get_children().filter(func(n: Node) -> bool: return n is Prey))
		if loop.is_over:
			result = "out" if loop.hunted_won else "caught"
			break
		var game_time := loop.get_duration()
		if game_time - last_report >= 60.0:
			last_report = game_time
			print(
				(
					"  game %d  %3d s  %s goal %s  found %d placed %d  free %d  at %s"
					% [
						index,
						game_time,
						PreyBrain.State.keys()[map.prey.get_state()],
						PreyBrain.Goal.keys()[map.prey.brain.goal],
						loop.rules.found(),
						loop.rules.placed,
						loop.free_count(),
						map.prey.global_position
					]
				)
			)
			if OS.has_environment("SIM_DEBUG"):
				var m := map.get_children().filter(func(n: Node) -> bool: return n is Monster)
				var agent: NavigationAgent3D = map.prey.get_node("NavigationAgent3D")
				print(
					(
						"    dbg target %s fin %s next %s vel %s monster %s"
						% [
							map.prey.brain.target,
							agent.is_navigation_finished(),
							agent.get_next_path_position(),
							map.prey.velocity,
							m[0].global_position if not m.is_empty() else Vector3.ZERO
						]
					)
				)
	var duration := loop.get_duration()
	var ruses: Dictionary = map.prey.ruse_counts.duplicate()
	var scans := loop.scan_count
	if result == "caught":
		var hunter := map.get_children().filter(func(n: Node) -> bool: return n is Monster)
		print(
			(
				"    caught at %s, prey %s, monster %s"
				% [
					map.prey.global_position,
					PreyBrain.State.keys()[map.prey.get_state()],
					(
						MonsterBrain.State.keys()[hunter[0].brain.state]
						if not hunter.is_empty()
						else "-"
					)
				]
			)
		)
	print(
		(
			(
				"GAME %d: %s after %.1f min (fuses %d placed %d, noises %d, scans %d, ruses %s,"
				+ " chases %d, escapes %d, mean distance %.1f m, real %d s)"
			)
			% [
				index,
				result,
				duration / 60.0,
				loop.rules.found(),
				loop.rules.placed,
				loop.noise_count,
				scans,
				ruses,
				loop.chases.chase_count,
				loop.chases.escape_count,
				loop.chases.mean_distance(),
				(Time.get_ticks_msec() - started) / 1000
			]
		)
	)
	var winner: String = {"out": "chassés", "caught": "monstre"}.get(result, "bloquée")
	print("GRID " + grid.row("simulation", _preys, winner, duration / 60.0))
	# Read before the map goes: the loop goes with it.
	var played := {
		"result": result,
		"duration": duration,
		"ruses": ruses,
		"scans": scans,
		"chases": loop.chases.chase_count,
		"escapes": loop.chases.escape_count,
	}
	get_tree().paused = false
	map.queue_free()
	await get_tree().process_frame
	return played
