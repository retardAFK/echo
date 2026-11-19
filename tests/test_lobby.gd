extends GutTest
## The waiting room (S-010, Q6, T-096): seats, ready, leader, launch; over the
## network with a room in this process; and the menu that shows it.

const PORT := 19031
const START_MENU := preload("res://game/ui/start_menu.tscn")

var _settings: NetSettings


func before_each() -> void:
	_settings = NetSettings.new()
	_settings.room_connect_timeout = 3.0


func after_each() -> void:
	NetSession.leave()
	NetSession.settings = preload("res://game/data/net_settings.tres")


func test_players_sit_hunted_first_then_monster() -> void:
	var lobby := LobbyState.new()
	for player in [1, 2, 3, 4]:
		assert_true(lobby.add_player(player))
	assert_eq(lobby.seats, [4, 1, 2, 3] as Array[int])
	assert_eq(lobby.leader, 1)
	assert_false(lobby.add_player(5), "four seats")


func test_start_needs_leader_and_everyone_ready() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(1)
	lobby.add_player(2)
	lobby.set_ready(1, true)
	assert_false(lobby.can_start(1))
	lobby.set_ready(2, true)
	assert_false(lobby.can_start(2), "not the leader")
	assert_true(lobby.start(1))
	assert_true(lobby.started)
	assert_false(lobby.add_player(3), "no newcomer once started")


func test_leader_sets_the_game_size() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(1)
	lobby.add_player(2)
	lobby.add_player(3)
	lobby.set_ready(2, true)
	assert_false(lobby.set_game_size(2, 3), "only the leader")
	assert_false(lobby.set_game_size(1, 2), "fewer than the players in")
	assert_false(lobby.set_game_size(1, 1), "2 at least")
	assert_false(lobby.set_game_size(1, 5), "4 at most")
	assert_true(lobby.set_game_size(1, 3))
	assert_eq(lobby.game_size, 3)
	assert_eq(lobby.seats[3], 0, "the closed seat is empty")
	assert_eq(lobby.players().size(), 3)
	assert_false(lobby.is_ready(2), "everyone says again they are ready")
	assert_false(lobby.add_player(4), "full at 3")


func test_two_players_play_one_against_one() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(1)
	assert_true(lobby.set_game_size(1, 2))
	assert_true(lobby.add_player(2))
	assert_false(lobby.add_player(3))
	lobby.set_ready(1, true)
	lobby.set_ready(2, true)
	assert_true(lobby.start(1))
	assert_true(lobby.seat_of(1) < 2 and lobby.seat_of(2) < 2, "monster and hunted 1")
	assert_eq(lobby.seats[2], 0)
	assert_eq(lobby.seats[3], 0)


func test_roles_are_drawn_at_random_with_a_player_as_monster() -> void:
	var monsters := {}
	for draw in 40:
		var lobby := LobbyState.new()
		lobby.rng.seed = draw
		for player in [1, 2, 3]:
			lobby.add_player(player)
			lobby.set_ready(player, true)
		assert_true(lobby.start(1))
		assert_ne(lobby.seats[LobbyState.MONSTER_SEAT], 0, "a player is the monster")
		assert_eq(lobby.seats[3], 0, "the hunted seat left: an AI")
		var sorted := lobby.players()
		sorted.sort()
		assert_eq(sorted, [1, 2, 3] as Array[int])
		monsters[lobby.seats[LobbyState.MONSTER_SEAT]] = true
	assert_eq(monsters.size(), 3, "each player can be drawn the monster")


func test_leader_passes_on_when_leaving() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(2)
	lobby.add_player(3)
	lobby.remove_player(2)
	assert_eq(lobby.leader, 3)
	assert_eq(lobby.seats, [0, 0, 3, 0] as Array[int])
	lobby.remove_player(3)
	assert_eq(lobby.leader, 0)


func test_state_round_trip() -> void:
	var lobby := LobbyState.new()
	lobby.code = "KRBX"
	lobby.add_player(1)
	lobby.add_player(2)
	lobby.set_ready(2, true)
	var read := LobbyState.from_dict(JSON.parse_string(JSON.stringify(lobby.to_dict())))
	assert_eq(read.seats, lobby.seats)
	assert_eq(read.leader, 1)
	assert_eq(read.code, "KRBX")
	assert_true(read.is_ready(2))
	assert_false(read.is_ready(1))
	lobby.set_game_size(1, 3)
	read = LobbyState.from_dict(JSON.parse_string(JSON.stringify(lobby.to_dict())))
	assert_eq(read.game_size, 3)


func _room(port: int) -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	var room := RoomLink.new()
	room.settings = _settings
	holder.add_child(room)
	assert_eq(room.listen(port), OK)
	room.lobby.code = "KRBX"
	return room


func _client(port: int) -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	var client := RoomLink.new()
	client.settings = _settings
	holder.add_child(client)
	client.join("ws://127.0.0.1:%d" % port)
	return client


func _wait_until(condition: Callable, limit := 3.0) -> void:
	var waited := 0.0
	while waited < limit and not condition.call():
		await wait_seconds(0.05)
		waited += 0.05


func test_waiting_room_over_the_network() -> void:
	var room := _room(PORT)
	var first := _client(PORT)
	await wait_for_signal(first.joined, 3.0)
	var second := _client(PORT)
	await wait_for_signal(second.joined, 3.0)
	await _wait_until(func() -> bool: return first.lobby_state.get("seats", []).count(0) == 2)
	var seen := LobbyState.from_dict(first.lobby_state)
	assert_eq(seen.code, "KRBX")
	assert_eq(seen.leader, first.place)
	second.ask_game_size(2)  # Not the leader: ignored.
	first.ask_game_size(2)
	await _wait_until(func() -> bool: return room.lobby.game_size == 2)
	assert_eq(room.lobby.game_size, 2)
	second.ask_start()  # Not the leader: ignored.
	first.ask_ready(true)
	second.ask_ready(true)
	await _wait_until(func() -> bool: return room.lobby.can_start(first.place))
	watch_signals(second)
	first.ask_start()
	await wait_for_signal(second.game_started, 3.0)
	assert_signal_emitted(second, "game_started")
	assert_true(room.lobby.started)
	var drawn := room.lobby.seats.duplicate()
	assert_true(
		drawn.slice(0, 2).has(first.place) and drawn.slice(0, 2).has(second.place),
		"one monster, one hunted: %s" % [drawn]
	)
	var late := _client(PORT)
	watch_signals(late)
	await wait_for_signal(late.refused, 3.0)
	assert_signal_emitted_with_parameters(late, "refused", ["started"])
	# The game is over (T-099): everyone back in the waiting room, not ready.
	watch_signals(room)
	room.end_game()
	assert_signal_emitted(room, "game_ended")
	await _wait_until(func() -> bool: return not first.lobby_state.get("started", true))
	var after := LobbyState.from_dict(first.lobby_state)
	assert_false(after.started)
	assert_false(after.is_ready(first.place))
	assert_eq(after.seats, drawn, "seats kept")


func test_leaving_frees_the_seat_for_everyone() -> void:
	var room := _room(PORT + 1)
	var first := _client(PORT + 1)
	await wait_for_signal(first.joined, 3.0)
	var second := _client(PORT + 1)
	await wait_for_signal(second.joined, 3.0)
	first.get_parent().free()
	await _wait_until(func() -> bool: return LobbyState.from_dict(second.lobby_state).leader == 2)
	assert_eq(room.lobby.players(), [2] as Array[int])
	assert_eq(LobbyState.from_dict(second.lobby_state).leader, second.place)


func _menu() -> LobbyMenu:
	var menu: LobbyMenu = preload("res://game/ui/lobby_menu.tscn").instantiate()
	menu.change_scene = false
	menu.settings = _settings
	add_child_autofree(menu)
	return menu


func test_menu_joins_and_shows_the_room() -> void:
	var room := _room(PORT + 2)
	room.settings.server_address = "ws://127.0.0.1"
	var lobby := LobbyServer.new()
	lobby.auto_start = false
	_settings.lobby_port = PORT + 3
	_settings.first_room_port = PORT + 2
	lobby.settings = _settings
	lobby.spawn_room = func(_slot: int, _code: String) -> int: return 0
	add_child_autofree(lobby)
	assert_eq(lobby.listen(PORT + 3), OK)
	var menu := _menu()
	menu.create()
	await _wait_until(func() -> bool: return menu.lobby != null)
	assert_not_null(menu.lobby, menu.get_status())
	assert_eq(menu.lobby.seat_of(NetSession.get_place()), 1)
	assert_eq(LobbyMenu.player_name(menu.lobby, 1, NetSession.get_place()), "Toi")
	assert_eq(LobbyMenu.player_name(menu.lobby, 0, NetSession.get_place()), "IA")
	menu.leave()
	assert_null(menu.lobby)
	assert_eq(NetSession.mode, NetSession.Mode.SOLO)


func test_menu_refuses_a_bad_code() -> void:
	var menu := _menu()
	menu.join_code("ab")
	assert_eq(menu.get_status(), LobbyMenu.error_text("bad_code"))
	assert_eq(LobbyMenu.seat_name(0), "Monstre")
	assert_eq(LobbyMenu.seat_name(2), "Chassé 2")


func test_online_button_hidden_until_enabled() -> void:
	var menu: StartMenu = START_MENU.instantiate()
	menu.change_scene = false
	add_child_autofree(menu)
	assert_false(menu.get_node("%MainList").item("MENU_ONLINE").visible)
	var shown: StartMenu = START_MENU.instantiate()
	shown.change_scene = false
	shown.net_settings = _settings
	_settings.show_online = true
	add_child_autofree(shown)
	assert_true(shown.get_node("%MainList").item("MENU_ONLINE").visible)
