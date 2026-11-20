extends GutTest
## Routes replayed on the end screen's map (spec S-020, T-339, piste U2):
## the log records everyone's positions and the catches, stays small, breaks
## the line where a player was moved, goes from the room to the clients, and
## the end screen draws it.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SETTINGS := preload("res://game/data/route_settings.tres")


func after_each() -> void:
	get_tree().paused = false
	GameSession.role = GameSession.Role.HUNTED
	NetSession.mode = NetSession.Mode.SOLO
	GameSession.online_lobby = null
	GameSession.game_seed = 0


func _points(values: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	points.assign(values)
	return points


func test_the_log_records_every_player_and_interpolates() -> void:
	var log := RouteLog.new(SETTINGS)
	log.record(_points([Vector2(0, 0)]), 0.0)
	log.record(_points([Vector2(2, 0), Vector2(10, 10)]), 2.0)
	assert_eq(log.tracks.size(), 2, "a new track for a newcomer")
	assert_eq(log.size(), 2)
	assert_eq(log.tracks[1][0], RouteLog.MISSING, "padded before it came")
	assert_false(log.joined(1, 1), "no line from where it was not")
	assert_true(log.joined(0, 1))
	assert_eq(log.position_at(0, 1.0), Vector2(1, 0), "halfway between two positions")
	assert_eq(log.end_time, 2.0)


func test_a_jump_breaks_the_line() -> void:
	var log := RouteLog.new(SETTINGS)
	var far := SETTINGS.break_speed * SETTINGS.sample_time + 1.0
	log.record(_points([Vector2.ZERO]), 0.0)
	log.record(_points([Vector2(far, 0)]), SETTINGS.sample_time)
	assert_false(log.joined(0, 1), "moved to the prison: no line across the map")
	assert_eq(log.position_at(0, SETTINGS.sample_time * 0.5), Vector2.ZERO)


func test_a_long_game_stays_small() -> void:
	var log := RouteLog.new(SETTINGS)
	for i in SETTINGS.max_points:
		log.record(_points([Vector2(i, 0)]), i * SETTINGS.sample_time)
	assert_lt(log.size(), SETTINGS.max_points)
	assert_eq(log.sample_time, SETTINGS.sample_time * 2.0, "twice the time between two")
	assert_eq(log.tracks[0][1], Vector2(2, 0), "every other position kept")
	assert_almost_eq(log.time_of(1), 2.0 * SETTINGS.sample_time, 0.001)


func test_values_go_and_come_back() -> void:
	var log := RouteLog.new(SETTINGS)
	log.record(_points([Vector2(1, 2), Vector2(3, 4)]), 0.0)
	log.capture(1, 0.5, Vector2(3, 4))
	log.end_time = 7.0
	var copy := RouteLog.from_values(bytes_to_var(var_to_bytes(log.values())), SETTINGS)
	assert_eq(copy.tracks, log.tracks)
	assert_eq(copy.captures, log.captures)
	assert_eq(copy.end_time, 7.0)
	assert_eq(copy.sample_time, log.sample_time)


func test_a_solo_game_records_the_routes_and_the_catch() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	await wait_physics_frames(3)
	var loop := map.game_loop
	assert_false(loop.routes.is_empty(), "the first positions at the start")
	assert_eq(loop.routes.tracks.size(), 1 + loop.team.size(), "the monster and each hunted")
	var player: Player = map.get_node("Player")
	assert_eq(loop.routes.tracks[1][0], Vector2(player.global_position.x, player.global_position.z))
	loop.finish(false)
	assert_eq(loop.routes.captures.size(), 1, "solo: the catch that ends the game")
	assert_eq(loop.routes.captures[0][0], 1)
	assert_true(map.end_screen.get_node("%ReplayBox").visible, "the replay on the plan")
	var replay: RouteReplay = map.end_screen.get_node("%Replay")
	assert_true(replay.has_routes())
	replay.replay_clock = SETTINGS.replay_time
	assert_almost_eq(replay.shown_time(), loop.routes.end_time, 0.001, "the end of the game")


func test_an_escape_has_no_catch() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	await wait_physics_frames(2)
	map.game_loop.finish(true)
	assert_true(map.game_loop.routes.captures.is_empty())


func test_the_room_sends_the_routes_before_the_end() -> void:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = [0, 11, 12, 0]
	GameSession.online_lobby = lobby
	GameSession.game_seed = 5
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(3)
	var net: NetGame = map.get_node("NetGame")
	var kinds := func() -> Array:
		return net.sent_events.map(func(sent: Array) -> int: return sent[1][0])
	net.send_world()
	assert_false(NetGame.Event.ROUTES in kinds.call(), "not before the end")
	var hunted: Node3D = map.game_loop.team[0]
	map.game_loop.set_captured(hunted, true)
	assert_eq(map.game_loop.routes.captures.size(), 1, "the catch on the room's routes")
	net.sent_events.clear()
	map.game_loop.finish(false)  # The room sends the clock and the map at once.
	var sent: Array = kinds.call()
	assert_true(NetGame.Event.ROUTES in sent)
	assert_lt(sent.find(NetGame.Event.ROUTES), sent.find(NetGame.Event.WORLD), "before the end")
	net.sent_events.clear()
	map.get_node("Network").cameras[0].smash()
	net.send_world()
	assert_false(NetGame.Event.ROUTES in kinds.call(), "only once")


func test_a_client_takes_the_room_s_routes() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	var net := NetGame.new()
	net.world = NetWorld.new(map)
	net.world.game_loop = map.game_loop
	autofree(net)
	var log := RouteLog.new(SETTINGS)
	log.record(_points([Vector2(1, 1), Vector2(5, 5)]), 0.0)
	log.end_time = 30.0
	net.apply_event([NetGame.Event.ROUTES, log.values()])
	assert_eq(map.game_loop.routes.tracks, log.tracks)
	assert_eq(map.game_loop.routes.end_time, 30.0)
