extends GutTest
## Departures and cuts of an online game (S-010, Q7, T-102): a resume token,
## the place kept seat_keep_time then played by an AI from where the player
## was, the player back in its place before the end, the leader's role passed
## on, the room stopped once nobody is in it.

const PORT := 19041
const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")

var _settings: NetSettings


func before_each() -> void:
	_settings = NetSettings.new()
	_settings.room_connect_timeout = 3.0


func after_each() -> void:
	NetSession.mode = NetSession.Mode.SOLO
	GameSession.online_lobby = null
	GameSession.game_seed = 0


func _room(port: int) -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	var room := RoomLink.new()
	room.settings = _settings
	holder.add_child(room)
	assert_eq(room.listen(port), OK)
	return room


func _client(port: int, token := "") -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	var client := RoomLink.new()
	client.settings = _settings
	holder.add_child(client)
	client.join("ws://127.0.0.1:%d" % port, token)
	return client


func _wait_until(condition: Callable, limit := 3.0) -> void:
	var waited := 0.0
	while waited < limit and not condition.call():
		await wait_seconds(0.05)
		waited += 0.05


func test_a_player_who_left_comes_back_with_its_token() -> void:
	var room := _room(PORT)
	var first := _client(PORT)
	await wait_for_signal(first.joined, 3.0)
	var second := _client(PORT)
	await wait_for_signal(second.joined, 3.0)
	assert_eq(first.resume_token.length(), 24)
	assert_ne(first.resume_token, second.resume_token)
	first.ask_ready(true)
	second.ask_ready(true)
	await _wait_until(func() -> bool: return room.lobby.can_start(first.place))
	first.ask_start()
	await wait_for_signal(second.game_started, 3.0)
	var token := first.resume_token
	var seat := room.lobby.seat_of(1)  # Drawn at launch.
	watch_signals(room)
	first.get_parent().free()
	await _wait_until(func() -> bool: return room.players.size() == 1)
	assert_signal_emitted_with_parameters(room, "player_left", [1])
	assert_eq(room.lobby.seat_of(1), seat, "its seat waits for it")
	assert_eq(room.lobby.leader, 2, "the leader's role goes on")
	var stranger := _client(PORT, "not-a-token")
	watch_signals(stranger)
	await wait_for_signal(stranger.refused, 3.0)
	assert_signal_emitted_with_parameters(stranger, "refused", ["started"])
	var back := _client(PORT, token)
	watch_signals(back)
	await wait_for_signal(back.game_started, 3.0)
	assert_eq(back.place, 1, "the same place")
	assert_signal_emitted(back, "game_started")
	assert_signal_emitted_with_parameters(room, "player_returned", [1])
	# It says its map is ready: the room hears it.
	back.say_ready()
	await wait_for_signal(room.place_ready, 3.0)
	assert_signal_emitted_with_parameters(room, "place_ready", [1])


func test_seats_of_those_gone_for_good_are_freed_after_the_game() -> void:
	var room := _room(PORT + 1)
	var first := _client(PORT + 1)
	await wait_for_signal(first.joined, 3.0)
	var second := _client(PORT + 1)
	await wait_for_signal(second.joined, 3.0)
	first.ask_ready(true)
	second.ask_ready(true)
	await _wait_until(func() -> bool: return room.lobby.can_start(first.place))
	first.ask_start()
	await wait_for_signal(second.game_started, 3.0)
	second.get_parent().free()
	await _wait_until(func() -> bool: return room.players.size() == 1)
	room.end_game()
	assert_eq(room.lobby.players(), [1] as Array[int])
	assert_false(room.tokens.has(2))
	assert_eq(room.free_place(), 2, "a newcomer may sit there")


func test_the_room_stops_once_nobody_is_in_it() -> void:
	_settings.room_idle_timeout = 0.5
	var room := _room(PORT + 2)
	var first := _client(PORT + 2)
	await wait_for_signal(first.joined, 3.0)
	room.lobby.set_ready(1, true)
	room.lobby.start(1)
	watch_signals(room)
	first.get_parent().free()
	await wait_for_signal(room.idle_expired, 3.0)
	assert_signal_emitted(room, "idle_expired", "even in a game: no human left")


func test_the_session_keeps_the_token_of_each_room() -> void:
	NetSession._last_url = "ws://127.0.0.1:1"
	NetSession._on_joined(3, "abc")
	assert_eq(NetSession.saved_token("ws://127.0.0.1:1"), "abc")
	assert_eq(NetSession.saved_token("ws://127.0.0.1:2"), "")
	NetSession._last_url = ""


## The cité played by the room, with these players in the seats (0: an AI).
func _map(seats: Array[int]) -> GameMap:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = seats
	GameSession.online_lobby = lobby
	GameSession.game_seed = 9
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	return map


func test_an_ai_plays_for_a_hunted_who_left_then_gives_its_place_back() -> void:
	var map := _map([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	var player: Player = net.avatars[11]
	player.global_position += Vector3(1, 0, 0)
	player.inventory.take(Inventory.Kind.BOTTLE)
	map.game_loop._on_fuse_taken(player)
	map.room.catch_hunted(player)
	map.room.catch_hunted(net.avatars[12])
	player.capture._set_state(CaptureState.State.FREE)  # Freed by a teammate.
	map.game_loop.set_captured(player, false)
	var was := player.global_position
	map.room._on_player_left(11)
	map.room._process(NetSession.settings.seat_keep_time - 0.5)
	assert_true(net.avatars.has(11), "kept a while")
	map.room._process(1.0)
	assert_false(net.avatars.has(11))
	var prey: Prey = net.ai_hunted[1]
	assert_almost_eq(prey.global_position.distance_to(was), 0.0, 0.01)
	assert_eq(prey.capture.catches, 1, "caught once already")
	assert_true(prey.capture.is_free())
	assert_eq(prey.inventory.count(Inventory.Kind.BOTTLE), 1)
	assert_eq(map.game_loop.carried_by(prey), 0, "its fuse fell when it was captured")
	assert_true(map.game_loop.is_hunted(prey))
	assert_false(map.game_loop.is_hunted(player))
	assert_has(monster.get_targets(), prey)
	assert_does_not_have(monster.get_targets(), player)
	assert_eq(net.seat_of(prey), 1, "the same seat: the others see no change")
	assert_eq(prey.monster, monster)
	assert_eq(prey.game_loop, map.game_loop)
	# Back before the end: its place again, where the AI got to.
	prey.global_position += Vector3(2, 0, 0)
	was = prey.global_position
	map.room._on_player_returned(11)
	var again: Player = net.avatars[11]
	assert_eq(net.seats[11], 1)
	assert_false(net.ai_hunted.has(1))
	assert_almost_eq(again.global_position.distance_to(was), 0.0, 0.01)
	assert_eq(again.capture.catches, 1)
	assert_true(map.game_loop.is_hunted(again))
	assert_has(monster.get_targets(), again)
	# Caught again: its second stay in prison, then out the third time (S-018).
	map.room.catch_hunted(again)
	assert_eq(again.capture.state, CaptureState.State.CAPTURED)
	again.capture.set_free()
	map.room.catch_hunted(again)
	assert_eq(again.capture.state, CaptureState.State.OUT)


func test_a_captured_hunted_who_left_stays_captured_under_the_ai() -> void:
	var map := _map([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var player: Player = net.avatars[11]
	map.room.catch_hunted(player)
	map.room.replace_with_ai(11)
	var prey: Prey = net.ai_hunted[1]
	assert_true(prey.held)
	assert_true(map.game_loop.is_captured(prey))
	assert_true(prey.capture.is_in_group(Interactable.GROUP), "a teammate can free it")
	assert_eq(map.game_loop.free_count(), 2)


func test_the_ai_monster_plays_for_a_monster_who_left() -> void:
	var map := _map([5, 11, 0, 0])
	var net: NetGame = map.get_node("NetGame")
	var human: MonsterAvatar = map.avatar
	human.catch_count = 2
	human.global_position += Vector3(3, 0, 0)
	var was := human.global_position
	map.room.replace_with_ai(5)
	var monster: Monster = net.ai_monster
	assert_not_null(monster)
	assert_null(map.avatar)
	assert_almost_eq(monster.global_position.distance_to(was), 0.0, 0.01)
	assert_eq(monster.catch_count, 2)
	assert_eq(monster.get_targets().size(), 3, "every hunted")
	for prey: Prey in net.ai_hunted.values():
		assert_eq(prey.monster, monster)
	map.room._on_player_returned(5)
	assert_not_null(map.avatar)
	assert_eq(net.avatars[5], map.avatar)
	assert_null(net.ai_monster)
	assert_eq(map.avatar.catch_count, 2)
	for prey: Prey in net.ai_hunted.values():
		assert_eq(prey.monster, map.avatar)
