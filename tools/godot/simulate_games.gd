extends Node
## Plays whole games of the loop between AI players, sped up, and prints how
## they went (spec S-007, T-058 and T-060). Headless:
##     godot --headless tools/godot/simulate_games.tscn -- [games] [speed] [--no-monster]
## Without a monster, the AI prey plays alone (it must get out without being
## stuck). With one, the AI prey plays against the AI monster.

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
## Longest game, in game seconds, before it counts as stuck.
const TIME_LIMIT := 1800.0

var _games := 5
var _speed := 8.0
var _with_monster := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_games = int(args[0])
	if args.size() > 1 and args[1].is_valid_float():
		_speed = float(args[1])
	_with_monster = not args.has("--no-monster")
	Engine.physics_ticks_per_second = int(60 * _speed)
	Engine.max_physics_steps_per_frame = int(8 * _speed)
	Engine.time_scale = _speed
	var results := []
	for i in _games:
		results.append(await _play(i))
	var durations := results.map(func(r: Dictionary) -> float: return r.duration)
	var wins := results.filter(func(r: Dictionary) -> bool: return r.result == "out").size()
	var stuck := results.filter(func(r: Dictionary) -> bool: return r.result == "stuck").size()
	var mean := 0.0
	for d: float in durations:
		mean += d / durations.size()
	print("SUMMARY games %d, prey out %d, caught %d, stuck %d, mean %.1f min" % [
		_games, wins, _games - wins - stuck, stuck, mean / 60.0])
	get_tree().quit()


func _play(index: int) -> Dictionary:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = load(MAP_PATH).instantiate()
	add_child(map)
	map.end_screen.change_scene = false
	var avatar := map.avatar
	if _with_monster:
		_replace_avatar_with_ai(map)
	else:
		avatar.process_mode = Node.PROCESS_MODE_DISABLED
		avatar.global_position = Vector3(0, -50, 0)  # Out of sight and hearing.
	var loop := map.game_loop
	var started := Time.get_ticks_msec()
	var last_report := 0.0
	var result := "stuck"
	while loop.get_duration() * _speed < TIME_LIMIT:
		await get_tree().physics_frame
		if loop.is_over:
			result = "out" if loop.hunted_won else "caught"
			break
		var game_time := loop.get_duration() * _speed
		if game_time - last_report >= 60.0:
			last_report = game_time
			print("  game %d  %3d s  %s goal %s  found %d placed %d  at %s" % [
				index, game_time, PreyBrain.State.keys()[map.prey.get_state()],
				PreyBrain.Goal.keys()[map.prey.brain.goal], loop.rules.found(),
				loop.rules.placed, map.prey.global_position])
	var duration := loop.get_duration() * _speed
	print("GAME %d: %s after %.1f min (fuses %d placed %d, noises %d, real %d s)" % [
		index, result, duration / 60.0, loop.rules.found(), loop.rules.placed,
		loop.noise_count, (Time.get_ticks_msec() - started) / 1000])
	get_tree().paused = false
	map.queue_free()
	await get_tree().process_frame
	return {"result": result, "duration": duration}


## The playable monster stays still; an AI monster hunts the AI prey instead.
func _replace_avatar_with_ai(map: GameMap) -> void:
	map.avatar.process_mode = Node.PROCESS_MODE_DISABLED
	map.avatar.global_position = Vector3(0, -50, 0)
