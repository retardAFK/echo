extends GutTest
## Lobby and rooms of the dedicated server (S-010, T-094). Everything runs in
## this process, on test ports, with rooms that are nodes instead of processes.

const LOBBY_PORT := 18910
const ROOM_PORT := 19001

var _settings: NetSettings


func before_each() -> void:
	_settings = NetSettings.new()
	_settings.room_connect_timeout = 3.0


func test_codes_are_four_clear_letters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 200:
		var code := RoomCode.generate(rng)
		assert_true(RoomCode.is_valid(code), code)
		for letter in "ILOS0123456789":
			assert_false(code.contains(letter), code)


func test_code_is_not_reused() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var first := RoomCode.generate(rng)
	rng.seed = 1
	assert_ne(RoomCode.generate(rng, [first]), first)


func test_typed_code_is_normalized() -> void:
	assert_eq(RoomCode.normalize(" kr bx "), "KRBX")
	assert_false(RoomCode.is_valid("KRB"))
	assert_false(RoomCode.is_valid("KRBO"))
	assert_true(RoomCode.is_valid("KRBX"))


func test_addresses_local_and_online() -> void:
	assert_eq(NetAddress.lobby_url(_settings), "ws://127.0.0.1:8910")
	assert_eq(NetAddress.room_url(_settings, 3, 9003), "ws://127.0.0.1:9003")
	_settings.server_address = "wss://echo.example.org"
	assert_eq(NetAddress.lobby_url(_settings), "wss://echo.example.org/lobby")
	assert_eq(NetAddress.room_url(_settings, 3, 9003), "wss://echo.example.org/s3")


func test_boot_arguments() -> void:
	assert_true(ServerBoot.parse(PackedStringArray([])))
	assert_eq(ServerBoot.scene(), "")
	assert_true(ServerBoot.parse(PackedStringArray(["--lobby"])))
	assert_eq(ServerBoot.scene(), ServerBoot.LOBBY_SCENE)
	assert_true(ServerBoot.parse(PackedStringArray(["--room", "3", "--code", "KRBX"])))
	assert_eq(ServerBoot.scene(), ServerBoot.ROOM_SCENE)
	assert_eq(ServerBoot.room_slot, 3)
	assert_eq(ServerBoot.room_code, "KRBX")
	assert_false(ServerBoot.parse(PackedStringArray(["--room", "x", "--code", "KRBX"])))
	assert_false(ServerBoot.parse(PackedStringArray(["--room", "2"])))
	assert_eq(ServerBoot.scene(), "")
	ServerBoot.parse(PackedStringArray([]))


func test_registry_fills_and_frees_slots() -> void:
	var registry := LobbyRegistry.new(2)
	var rng := RandomNumberGenerator.new()
	var first := registry.open(rng)
	var second := registry.open(rng)
	assert_eq([first[0], second[0]], [1, 2])
	assert_ne(first[1], second[1])
	assert_eq(registry.open(rng), [])
	assert_eq(registry.find(second[1]), 2)
	assert_eq(registry.find("ZZZZ"), 0)
	registry.close(1)
	assert_eq(registry.open_count(), 1)
	assert_eq(registry.open(rng)[0], 1)


func _lobby(max_rooms := 8) -> LobbyServer:
	var lobby := LobbyServer.new()
	lobby.auto_start = false
	_settings.max_rooms = max_rooms
	lobby.settings = _settings
	lobby.spawn_room = func(_slot: int, _code: String) -> int: return 0
	add_child_autofree(lobby)
	return lobby


func test_lobby_answers() -> void:
	var lobby := _lobby(1)
	var version := NetAddress.build_version()
	assert_eq(lobby.answer("nonsense")["reason"], "bad_request")
	assert_eq(lobby.answer({"op": "create", "version": "old"})["reason"], "version")
	var room := lobby.answer({"op": "create", "version": version})
	assert_eq(room["op"], "room")
	assert_eq(room["slot"], 1)
	assert_eq(room["port"], _settings.first_room_port)
	assert_eq(lobby.answer({"op": "create", "version": version})["reason"], "busy")
	var code: String = room["code"]
	var joined := lobby.answer({"op": "join", "code": code.to_lower(), "version": version})
	assert_eq(joined["slot"], 1)
	var wrong := lobby.answer({"op": "join", "code": "ZZZZ", "version": version})
	assert_eq(wrong["reason"], "unknown_code")
	lobby.close_room(1)
	assert_eq(
		lobby.answer({"op": "join", "code": code, "version": version})["reason"], "unknown_code"
	)


func test_lobby_over_websocket() -> void:
	var lobby := _lobby()
	assert_eq(lobby.listen(LOBBY_PORT), OK)
	var client := LobbyClient.new()
	client.settings = _settings
	add_child_autofree(client)
	watch_signals(client)
	client.create("ws://127.0.0.1:%d" % LOBBY_PORT)
	await wait_for_signal(client.answered, 3.0)
	var reply: Dictionary = get_signal_parameters(client.answered)[0]
	assert_eq(reply.get("op"), "room", str(reply))
	client.join("ws://127.0.0.1:%d" % LOBBY_PORT, reply.get("code", ""))
	await wait_for_signal(client.answered, 3.0)
	assert_eq(get_signal_parameters(client.answered)[0].get("slot"), 1)


func test_unreachable_lobby() -> void:
	var client := LobbyClient.new()
	_settings.lobby_timeout = 1.0
	client.settings = _settings
	add_child_autofree(client)
	watch_signals(client)
	client.create("ws://127.0.0.1:%d" % (LOBBY_PORT + 1))
	await wait_for_signal(client.answered, 3.0)
	assert_eq(get_signal_parameters(client.answered)[0].get("reason"), "unreachable")


func _side(link: RoomLink) -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	link.settings = _settings
	holder.add_child(link)
	return link


func test_four_players_join_and_ping_fifth_is_refused() -> void:
	var room := _side(RoomLink.new())
	assert_eq(room.listen(ROOM_PORT), OK)
	var clients: Array[RoomLink] = []
	for i in 4:
		var client := _side(RoomLink.new())
		client.join("ws://127.0.0.1:%d" % ROOM_PORT)
		clients.append(client)
	var waited := 0.0
	while waited < 5.0 and not clients.all(func(c: RoomLink) -> bool: return c.ping_ms >= 0):
		await wait_seconds(0.1)
		waited += 0.1
	var places := clients.map(func(c: RoomLink) -> int: return c.place)
	places.sort()
	assert_eq(places, [1, 2, 3, 4])
	assert_eq(room.players.size(), 4)
	for client in clients:
		assert_between(client.ping_ms, 0, 1000)
	var late := _side(RoomLink.new())
	watch_signals(late)
	late.join("ws://127.0.0.1:%d" % ROOM_PORT)
	await wait_for_signal(late.refused, 3.0)
	assert_signal_emitted_with_parameters(late, "refused", ["full"])
	assert_eq(room.players.size(), 4)
	clients[0].get_parent().free()
	await wait_seconds(0.5)
	assert_eq(room.players.size(), 3)


func test_room_not_started_yet_is_retried() -> void:
	var client := _side(RoomLink.new())
	client.join("ws://127.0.0.1:%d" % (ROOM_PORT + 1))
	await wait_seconds(0.6)
	var room := _side(RoomLink.new())
	assert_eq(room.listen(ROOM_PORT + 1), OK)
	await wait_for_signal(client.joined, 3.0)
	assert_eq(client.place, 1)


func test_unreachable_room() -> void:
	_settings.room_connect_timeout = 0.5
	var client := _side(RoomLink.new())
	watch_signals(client)
	client.join("ws://127.0.0.1:%d" % (ROOM_PORT + 2))
	await wait_for_signal(client.unreachable, 2.0)
	assert_signal_emitted(client, "unreachable")


func test_empty_room_expires() -> void:
	_settings.room_idle_timeout = 0.3
	var room := _side(RoomLink.new())
	watch_signals(room)
	assert_eq(room.listen(ROOM_PORT + 3), OK)
	await wait_for_signal(room.idle_expired, 2.0)
	assert_signal_emitted(room, "idle_expired")
