class_name MapOnlineRoom
extends Node
## Online game, room side (S-010, T-097; S-022, T-433): the room (the
## server) plays everyone. A Player for each human hunted and an AI prey in
## each empty seat (T-101, T-314), the monster's avatar or the AI monster.
## It applies the capture rule (T-107): a catch captures, the prison holds
## the captured (S-018), a second catch or the end of a stay puts the hunted
## out. A player who leaves is played by an AI after seat_keep_time, and
## takes its place back if it returns (T-102).
## GameMap adds it on the room before the game loop; NetGame relays the state.

const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MONSTER_SCENE := preload("res://game/entities/monster/monster.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")

var map: GameMap
## Every hunted, by seat: the humans' players and the AI preys in the empty
## seats (T-101).
var online_hunted: Array[Node3D] = []
## The AI preys among them.
var ai_preys: Array[Prey] = []

var _net: NetGame
## Places whose player left, with the seconds before an AI takes over (T-102).
var _gone := {}
## The places an AI plays for now, with their seat.
var _replaced := {}
## The scene of a hunted's Player.
var _player_path := ""


## Called once added, before the game loop: the hunted, the monster, and the
## departures.
func setup(net: NetGame) -> void:
	_net = net
	if map.prison != null:
		map.prison.timed_out.connect(_on_prison_timed_out)
	var lobby := GameSession.online_lobby
	_player_path = map.player.scene_file_path
	# Always 3 hunted: the seats nobody took, the game size included, are
	# played by AI preys (S-020, T-314, Maxime's rule of 19/11/2026).
	var spawns: Array = []
	if map.has_node("PlayerSpawns"):
		spawns = GameMap.far_apart(
			map.get_node("PlayerSpawns").get_children(),
			LobbyState.SEATS - 1,
			LOOP_SETTINGS.spawn_spacing,
			map.rng
		)
	var hunted: Array[Node3D] = []
	for seat in range(1, LobbyState.SEATS):
		var place: int = lobby.seats[seat] if lobby != null else 0
		var marker: Node3D = (
			spawns[hunted.size() % spawns.size()] if not spawns.is_empty() else null
		)
		var one: Node3D
		if place == 0:
			one = _new_ai_prey(seat, marker)  # An empty seat (T-101).
			net.ai_hunted[seat] = one
		else:
			one = _new_player(place, seat)
			if marker != null:
				one.global_position = marker.global_position
				one.rotation.y = marker.global_rotation.y
		_give_capture(one)
		hunted.append(one)
	online_hunted = hunted
	var monster_place: int = lobby.seats[LobbyState.MONSTER_SEAT] if lobby != null else 0
	if monster_place != 0:
		_monster_back(monster_place)
	else:
		var monster := map.monster
		monster.player = hunted[0] if not hunted.is_empty() else null
		for other in hunted.slice(1):
			monster.others.append(other)
		monster.buildings = map.get_buildings()
		monster.hunted_caught.connect(catch_hunted)
		net.ai_monster = monster
		for each in ai_preys:
			each.monster = monster
	map.free_child(map.player)
	map.player = null
	if NetSession.link != null:
		NetSession.link.player_left.connect(_on_player_left)
		NetSession.link.player_returned.connect(_on_player_returned)


## Called once the game loop is set up: the hiding spots catch, the AI preys
## play the loop, and the end of the game takes everyone back to the lobby.
func start() -> void:
	for spot in map.get_hiding_spots():
		spot.found.connect(_on_hidden_found)
	if map.game_loop != null:
		map.game_loop.ended.connect(_on_game_ended)
		for each in ai_preys:
			each.start_loop(map.game_loop, map.get_fuse_boxes(), map.rng.randi() | 1)


## The monster (AI or human) caught a hunted, or opened its hiding spot
## (T-107): captured the first time, out the second.
func catch_hunted(caught: Node3D) -> void:
	var capture: CaptureState = caught.get("capture")
	if capture != null and not (map.game_loop != null and map.game_loop.is_over):
		capture.catch()


## S-018, Q2: a captured hunted goes to a free cage, if it is still captured
## and not in one yet.
func jail(player: Node3D) -> void:
	var prison := map.prison
	if not is_instance_valid(player) or prison == null:
		return
	var capture: CaptureState = player.get("capture")
	if capture == null or capture.state != CaptureState.State.CAPTURED:
		return
	if prison.cage_of(player) == null:
		prison.jail(player, _net.seat_of(player), capture.catches)


## An AI plays the place of a player who left, from where it was (T-102).
func replace_with_ai(place: int) -> void:
	var game_loop := map.game_loop
	if not _net.avatars.has(place) or (game_loop != null and game_loop.is_over):
		return
	var seat: int = _net.seats[place]
	var old: Node3D = _net.avatars[place]
	_net.remove_avatar(place)
	_replaced[place] = seat
	if seat == LobbyState.MONSTER_SEAT:
		_monster_to_ai(old as MonsterAvatar)
		return
	var player := old as Player
	if player.hiding_in != null:
		player.hiding_in.occupant = null
		player.leave_hiding()
	var prey := _new_ai_prey(seat, player)  # Where the player was.
	for kind: Inventory.Kind in Inventory.Kind.values():
		prey.inventory.set_count(kind, player.inventory.count(kind))
	prey.monster = map.avatar if map.avatar != null else map.monster
	_net.ai_hunted[seat] = prey
	_swap_hunted(player, prey)
	if game_loop != null:
		prey.start_loop(game_loop, map.get_fuse_boxes(), map.rng.randi() | 1)


func _process(delta: float) -> void:
	for place: int in _gone.keys():
		_gone[place] -= delta
		if _gone[place] <= 0.0:
			_gone.erase(place)
			replace_with_ai(place)


## The Player of a human hunted in a place and a seat.
func _new_player(place: int, seat: int) -> Player:
	var player: Player = load(_player_path).instantiate()
	player.local_controls = false
	player.name = "Hunted%d" % seat
	map.add_child(player)
	player.get_node("Head/Camera3D").current = false
	_net.add_avatar(place, seat, player)
	var lobby := GameSession.online_lobby
	if lobby != null:
		player.loadout = lobby.loadout_of(place)  # Picked in the lobby (S-023, T-352).
	return player


## An AI prey for an empty hunted seat (T-101), where the seat's hunted would
## start (marker), or where a hunted who left was (T-102). It plays the loop
## with the others once it is set up.
func _new_ai_prey(seat: int, marker: Node3D) -> Prey:
	var each: Prey = PREY_SCENE.instantiate()
	each.name = "AiHunted%d" % seat
	(each.get_node("Body") as HuntedBody).role = HuntedBody.role_for_seat(seat)  # S-011 Q5.
	each.wander_route = map.get_node_or_null("PreyRoute")
	each.hiding_spots = map.get_node_or_null("HidingSpots")
	each.buildings = map.get_buildings()
	if marker != null:
		each.position = marker.global_position  # Before the tree: no first footstep jump.
		each.rotation.y = marker.global_rotation.y
	map.add_child(each)
	ai_preys.append(each)
	return each


## The capture rule of a hunted (T-107).
func _give_capture(one: Node3D, like: CaptureState = null) -> CaptureState:
	var capture := CaptureState.new()
	capture.prison = map.prison
	if like != null:
		capture.copy_from(like)
	one.add_child(capture)
	one.set("capture", capture)
	capture.changed.connect(_on_capture_changed.bind(one))
	return capture


## A player left a game in progress (T-102). Its place waits for it
## seat_keep_time, then an AI takes it where it was.
func _on_player_left(place: int) -> void:
	if _net.avatars.has(place):
		_gone[place] = NetSession.settings.seat_keep_time


## A player came back with its token before the end: its avatar again, or the
## AI's place, as the AI left it.
func _on_player_returned(place: int) -> void:
	if _gone.erase(place) or not _replaced.has(place):
		return
	var seat: int = _replaced[place]
	_replaced.erase(place)
	if seat == LobbyState.MONSTER_SEAT:
		_monster_back(place)
	else:
		_hunted_back(place, seat)


func _hunted_back(place: int, seat: int) -> void:
	var prey: Prey = _net.ai_hunted.get(seat)
	if prey == null:
		return
	_net.ai_hunted.erase(seat)
	var player := _new_player(place, seat)
	player.global_position = prey.global_position
	player.rotation.y = prey.rotation.y
	for kind: Inventory.Kind in Inventory.Kind.values():
		player.inventory.set_count(kind, prey.inventory.count(kind))
	ai_preys.erase(prey)
	_swap_hunted(prey, player)
	if NetGame.is_out(player):
		_net.spectate(player)


## One hunted takes the place of another: its capture rule, its fuses, its
## place among the monster's targets. The old one goes.
func _swap_hunted(old: Node3D, new: Node3D) -> void:
	var capture := _give_capture(new, old.get("capture"))
	new.set("held", old.get("held"))
	online_hunted[online_hunted.find(old)] = new
	if map.game_loop != null:
		map.game_loop.replace_hunted(old, new)
	if map.monster != null:
		map.monster.forget(old)
		if capture.is_free():
			map.monster.add_target(new)
	_net.replace_watched(old, new)
	if map.prison != null and map.prison.cage_of(old) != null:
		map.prison.cage_of(old).occupant = new  # Waits in the same cage.
	if capture.state == CaptureState.State.OUT:
		new.process_mode = Node.PROCESS_MODE_DISABLED
		new.global_position = Vector3(0, -60, 0)
	map.free_child(old)


## The AI monster takes the place of a human monster who left, where it was.
func _monster_to_ai(old: MonsterAvatar) -> void:
	var monster: Monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster"
	monster.patrol_route = map.get_node_or_null("PatrolRoute")
	monster.buildings = map.get_buildings()
	monster.position = old.global_position
	monster.rotation.y = old.rotation.y
	monster.catch_count = old.catch_count
	map.free_child(old)
	map.avatar = null
	map.add_child(monster)
	_set_ai_monster(monster)


## The human monster in the AI monster's place: at the start of the game, or
## back after a cut (T-102).
func _monster_back(place: int) -> void:
	var monster := map.monster
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	map.avatar = avatar
	avatar.local_controls = false
	map.add_child(avatar)
	avatar.global_transform = monster.global_transform
	avatar.catch_count = monster.catch_count
	_net.add_avatar(place, LobbyState.MONSTER_SEAT, avatar)
	_net.ai_monster = null
	if not _net.hunted_caught.is_connected(catch_hunted):
		_net.hunted_caught.connect(catch_hunted)
	for each in ai_preys:
		each.monster = avatar
	map.free_child(monster)
	map.monster = null


## The AI monster hunts every hunted still free.
func _set_ai_monster(monster: Monster) -> void:
	map.monster = monster
	_net.ai_monster = monster
	for one in online_hunted:
		if CaptureState.is_free_hunted(one):
			monster.add_target(one)
	if not monster.hunted_caught.is_connected(catch_hunted):
		monster.hunted_caught.connect(catch_hunted)
	for each in ai_preys:
		each.monster = monster
	if map.game_loop != null and map.game_loop.is_exit_open():
		map.on_exit_opened()


## A hunted captured, freed or out. Everyone is told; the AI monster leaves a
## captured hunted and chases it again once freed; a hunted out of the game
## leaves the map and watches a teammate.
func _on_capture_changed(state: CaptureState.State, player: Node3D) -> void:
	var game_loop := map.game_loop
	var monster := map.monster
	var prison := map.prison
	player.set("held", state != CaptureState.State.FREE)
	_net.report_caught(_net.seat_of(player), state)
	match state:
		CaptureState.State.CAPTURED:
			if game_loop != null:
				game_loop.set_captured(player, true)
			if monster != null:
				_monster_leaves(monster, player)
			if prison != null:
				# To a cage once the black screen is up (S-018, Q2).
				get_tree().create_timer(prison.settings.jail_delay, false).timeout.connect(
					jail.bind(player)
				)
		CaptureState.State.FREE:
			if game_loop != null:
				game_loop.set_captured(player, false)
			if monster != null:
				monster.add_target(player)
			if prison != null:
				prison.release(player, true)
		CaptureState.State.OUT:
			if prison != null:
				prison.release(player, false)
			if game_loop != null:
				game_loop.drop_fuses(player)
				game_loop.hunted_out(player)
			if monster != null:
				_monster_leaves(monster, player)
			_net.spectate(player)
			player.process_mode = Node.PROCESS_MODE_DISABLED
			player.global_position = Vector3(0, -60, 0)


## The AI monster shows its catch (T-127), then walks away from the hunted.
func _monster_leaves(monster: Monster, player: Node3D) -> void:
	monster.forget(player)
	monster.hold_still(monster.settings.catch_show_time)
	monster.walk_away(player.global_position)


## S-018, Q5: a stay in prison is over: out of the game.
func _on_prison_timed_out(hunted: Node3D) -> void:
	var capture: CaptureState = hunted.get("capture")
	if capture != null:
		capture.time_out()


## The monster opened a hiding spot with a hunted inside.
func _on_hidden_found(occupant: Node3D, by: Node3D) -> void:
	if by != null:
		MonsterNoise.scream(by)
	catch_hunted(occupant)


## The game is over. Everyone gets the last state at once, and the room goes
## back to its waiting room a little later (the end screens are up).
func _on_game_ended(_hunted_won: bool) -> void:
	_net.send_clock()  # The final counts first, for the end screen (S-020, T-301).
	_net.send_world()
	get_tree().create_timer(NetSession.settings.end_return_delay).timeout.connect(
		NetSession.end_game
	)
