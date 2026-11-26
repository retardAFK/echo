extends Node
## Plays whole Versus games between the AI boss and AI hunted, sped up, and
## prints how they went (spec S-024, T-384): who won, how long, the boss's
## health left, the damage each hunted dealt, the chests opened. Headless:
##     godot --headless res://tools/godot/simulate_versus.tscn -- [games] [speed] [--hunted N]
## The spec's aim (S-024, criteria): the boss wins 40 to 60 % of the games,
## which last 5 to 9 min on average, and none gets stuck.

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
## Game seconds past the clock's end after which a game counts as stuck.
const STUCK_MARGIN := 60.0

var _games := 5
var _speed := 8.0
var _hunted := 3


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_games = int(args[0])
	if args.size() > 1 and args[1].is_valid_float():
		_speed = float(args[1])
	var hunted_at := args.find("--hunted")
	if hunted_at >= 0 and hunted_at + 1 < args.size():
		_hunted = clampi(int(args[hunted_at + 1]), 1, 4)
	var results: Array[Dictionary] = []
	for i in _games:
		results.append(await _play(i))
	var boss_wins := 0
	var stuck := 0
	var mean := 0.0
	for r in results:
		boss_wins += 1 if r.winner == "boss" else 0
		stuck += 1 if r.winner == "stuck" else 0
		mean += r.duration / results.size()
	print(
		(
			"SUMMARY hunted %d, games %d, boss wins %d (%.0f %%), hunted wins %d, stuck %d, mean %.1f min"
			% [
				_hunted,
				_games,
				boss_wins,
				100.0 * boss_wins / maxi(_games, 1),
				_games - boss_wins - stuck,
				stuck,
				mean / 60.0
			]
		)
	)
	get_tree().quit()


func _play(index: int) -> Dictionary:
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.MONSTER
	_set_speed(_speed)
	var map: GameMap = load(MAP_PATH).instantiate()
	add_child(map)
	map.monster_role.add_ai_preys(_hunted)
	map.avatar.remove_from_group(Prison.MONSTERS_GROUP)  # The AI boss instead.
	map.monster_role.play_ai_against_ai()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var versus: VersusMode = map.get_node("VersusMode")
	versus.end_screen.change_scene = false
	var started := Time.get_ticks_msec()
	var last_report := 0.0
	var winner := "stuck"
	while versus.rules.clock < versus.settings.match_time + STUCK_MARGIN:
		await get_tree().physics_frame
		if versus.is_over():
			winner = "boss" if versus.rules.winner == VersusRules.Winner.BOSS else "hunted"
			break
		if versus.rules.clock - last_report >= 60.0:
			last_report = versus.rules.clock
			print("  game %d  %3d s  %s" % [index, versus.rules.clock, _state(versus)])
	var duration := versus.rules.clock
	print(
		(
			"GAME %d: %s after %.1f min, %s, real %d s"
			% [
				index,
				winner,
				duration / 60.0,
				_state(versus),
				(Time.get_ticks_msec() - started) / 1000
			]
		)
	)
	var played := {"winner": winner, "duration": duration}
	map.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	return played


## The boss's health and phase, each hunted's state and damage, chests opened.
func _state(versus: VersusMode) -> String:
	var health := versus.boss.health
	var hunted := []
	for kit in versus.hunters:
		var weapon := String(kit.loadout.weapon.id) if kit.loadout.weapon != null else "-"
		hunted.append(
			(
				"%s %d hp %s %.0f dmg"
				% [
					HuntedVitals.State.keys()[kit.vitals.state],
					kit.vitals.health,
					weapon,
					versus.stats.damage_of(kit)
				]
			)
		)
	var opened := 0
	for node in get_tree().get_nodes_in_group(VersusChest.GROUP):
		opened += 1 if (node as VersusChest).is_open else 0
	return (
		"boss %.0f/%.0f phase %d, hunted [%s], chests opened %d"
		% [health.health, health.max_health, health.phase, ", ".join(hunted), opened]
	)


func _set_speed(speed: float) -> void:
	Engine.physics_ticks_per_second = int(60 * speed)
	Engine.max_physics_steps_per_frame = int(8 * speed)
	Engine.time_scale = speed
