extends GutTest
## The online session (S-010, T-095): commands sent from a client to its room,
## version check, ping on F3, leaving. The room is a RoomLink in this process.

const PORT := 19021

var _settings: NetSettings


func before_each() -> void:
	_settings = NetSettings.new()
	_settings.room_connect_timeout = 3.0
	_settings.ping_interval = 0.1
	NetSession.settings = _settings


func after_each() -> void:
	NetSession.leave()
	NetSession.local_commands = null
	NetSession.settings = preload("res://game/data/net_settings.tres")


func _room(port: int) -> RoomLink:
	var holder := Node.new()
	add_child_autofree(holder)
	var room := RoomLink.new()
	room.settings = _settings
	holder.add_child(room)
	assert_eq(room.listen(port), OK)
	return room


func _join(port: int) -> void:
	watch_signals(NetSession)
	NetSession.join("ws://127.0.0.1:%d" % port)
	await wait_for_signal(NetSession.joined, 3.0)


func test_solo_by_default() -> void:
	assert_eq(NetSession.mode, NetSession.Mode.SOLO)
	assert_eq(NetSession.get_place(), 0)
	assert_eq(NetSession.describe(), "")


func test_held_commands_reach_the_room() -> void:
	var room := _room(PORT)
	await _join(PORT)
	assert_eq(NetSession.mode, NetSession.Mode.CLIENT)
	assert_eq(NetSession.get_place(), 1)
	var local := PlayerCommands.new()
	NetSession.local_commands = local
	local.seq = 5
	local.move = Vector2(0.0, -1.0)
	local.yaw = 0.75
	local.sprint = true
	await wait_seconds(0.3)
	var received := room.commands_for(1)
	assert_eq(received.seq, 5)
	assert_almost_eq(received.move.y, -1.0, 0.0001)
	assert_almost_eq(received.yaw, 0.75, 0.0001)
	assert_true(received.sprint)
	local.seq = 4  # An old frame arriving late is ignored.
	local.sprint = false
	await wait_seconds(0.2)
	assert_true(room.commands_for(1).sprint)


func test_actions_reach_the_room_once() -> void:
	var room := _room(PORT + 1)
	await _join(PORT + 1)
	var local := PlayerCommands.new()
	NetSession.local_commands = local
	local.push(PlayerCommands.Action.THROW)
	local.push(PlayerCommands.Action.CROUCH)
	await wait_seconds(0.3)
	assert_eq(
		room.commands_for(1).take_actions(),
		[PlayerCommands.Action.THROW, PlayerCommands.Action.CROUCH] as Array
	)


func test_ping_shown_on_debug_text() -> void:
	_room(PORT + 2)
	await _join(PORT + 2)
	await wait_seconds(0.5)
	assert_between(NetSession.get_ping_ms(), 0, 1000)
	assert_string_contains(NetSession.describe(), "NET place 1 ping")


func test_other_version_is_refused() -> void:
	var room := _room(PORT + 3)
	room.version = "other"
	watch_signals(NetSession)
	NetSession.join("ws://127.0.0.1:%d" % (PORT + 3))
	await wait_for_signal(NetSession.refused, 3.0)
	assert_signal_emitted_with_parameters(NetSession, "refused", ["version"])
	assert_eq(room.players.size(), 0)


func test_leaving_frees_the_place() -> void:
	var room := _room(PORT + 4)
	await _join(PORT + 4)
	assert_eq(room.players.size(), 1)
	NetSession.leave()
	assert_eq(NetSession.mode, NetSession.Mode.SOLO)
	await wait_seconds(0.5)
	assert_eq(room.players.size(), 0)
	assert_false(room.commands.has(1))


func test_room_closing_is_reported() -> void:
	var room := _room(PORT + 5)
	await _join(PORT + 5)
	room.get_parent().free()
	await wait_for_signal(NetSession.left, 3.0)
	assert_signal_emitted(NetSession, "left")
	assert_eq(NetSession.get_place(), 0)


func test_session_as_room_receives_players() -> void:
	assert_eq(NetSession.host(PORT + 6), OK)
	assert_eq(NetSession.mode, NetSession.Mode.ROOM)
	var holder := Node.new()
	add_child_autofree(holder)
	var client := RoomLink.new()
	client.settings = _settings
	holder.add_child(client)
	client.join("ws://127.0.0.1:%d" % (PORT + 6))
	await wait_for_signal(client.joined, 3.0)
	assert_eq(NetSession.link.players.size(), 1)
	assert_eq(NetSession.describe(), "NET room 1 players")


func test_local_player_commands_are_sent_when_online() -> void:
	_room(PORT + 7)
	await _join(PORT + 7)
	var player: Player = preload("res://game/entities/player/player.tscn").instantiate()
	add_child_autofree(player)
	assert_eq(NetSession.local_commands, player.commands)
