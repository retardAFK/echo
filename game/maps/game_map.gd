class_name GameMap
extends Node3D
## A playable map (specs S-001 to S-004, S-006): the greybox test map and the
## cité des Tilleuls share it.
## With fuse boxes (the cité), it adds the game loop of S-007 (GameLoop): a
## catch then ends the game instead, and the end screen shows the result.
## Hunted role: wires the AI monster to the player and handles a catch (Q4 of
## S-003): "caught" screen, player back to the start, monster back on patrol.
## Monster role (S-004): the AI monster and the hunted player are replaced by
## the playable monster, standing where the AI monster starts, and an AI prey
## starting where the hunted does. Touching the prey catches it: "caught"
## screen, and the prey wanders again from the point farthest from the monster.
## Escape pauses the game (S-009, Q6): resume, read the controls, or go back
## to the start menu.
## If the map has a PlayerSpawns node, the hunted (or the AI prey) starts on one
## of its Marker3D children, drawn at random (S-006). Scannable buildings are the
## Building nodes of the map, wherever they are.

const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MARKERS_SCENE := preload("res://game/ui/noise_markers.tscn")
const SCAN_RETICLE_SCENE := preload("res://game/ui/scan_reticle.tscn")
const MONSTER_SCENE := preload("res://game/entities/monster/monster.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const MONSTER_SETTINGS := preload("res://game/data/monster_settings.tres")
const LOOP_HUD_SCENE := preload("res://game/ui/loop_hud.tscn")
const END_SCREEN_SCENE := preload("res://game/ui/end_screen.tscn")
const CARRY_HUD_SCENE := preload("res://game/ui/carry_hud.tscn")
const HIDE_MASK_SCENE := preload("res://game/ui/hide_mask.tscn")
const INTERACT_PROMPT_SCENE := preload("res://game/ui/interact_prompt.tscn")
const PAUSE_MENU_SCENE := preload("res://game/ui/pause_menu.tscn")
const HIGHLIGHTS_SCENE := preload("res://game/ui/interact_highlights.tscn")
const MAP_SCREEN_SCENE := preload("res://game/ui/map_screen.tscn")
## Size of the F4 markers for the prey's wander points and hiding spots, in meters.
const POINT_MARKER_SIZE := 0.3

var avatar: MonsterAvatar
var markers: NoiseMarkers
var prey: Prey
## Monster role, simulations (T-100): the AI preys besides prey.
var extra_preys: Array[Prey] = []
## The game loop (S-007), null on a map without fuse boxes.
var game_loop: GameLoop
## Shown when the game loop ends (S-007, Q6).
var end_screen: EndScreen
## Escape pauses the game (S-009, Q6).
var pause_menu: PauseMenu
## The hunted's map (S-017), null for the monster and on a map without a plan.
var map_screen: MapScreen

var _rng := RandomNumberGenerator.new()
## The online part of the game (S-010), null in solo.
var _net: NetGame
## Room side: every hunted, by seat: the humans' players and the AI preys
## in the empty seats (T-101).
var _online_hunted: Array[Node3D] = []
## Room side: the AI preys among them.
var _ai_preys: Array[Prey] = []
## Room side (T-102): places whose player left, with the seconds before an
## AI takes over; and the places an AI plays for now, with their seat.
var _gone := {}
var _replaced := {}
## Room side: the scene of a hunted's Player.
var _player_path := ""
## Client side, hunted: what its screen shows of its own player, hidden once
## it watches a teammate (T-107).
var _own_huds: Array[Node] = []

@onready var _player: Player = $Player
@onready var _monster: Monster = $Monster
@onready var _caught_screen: CaughtScreen = $CaughtScreen
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _gauge: NoiseGauge = $NoiseGauge
@onready var _spawn: Vector3 = _player.global_position
@onready var _spawn_yaw: float = _player.rotation.y


func _ready() -> void:
	if GameSession.game_seed != 0:
		_rng.seed = GameSession.game_seed
	else:
		_rng.randomize()
	if not get_spawn_points().is_empty():
		_pick_spawn()
		_player.global_position = _spawn
		_player.rotation.y = _spawn_yaw
	if NetSession.mode != NetSession.Mode.SOLO:
		_setup_online()  # S-010, T-097.
		return
	if GameSession.role == GameSession.Role.MONSTER:
		_setup_monster_role()
	else:
		_monster.player = _player
		_monster.buildings = get_buildings()
		_monster.player_caught.connect(_on_player_caught)
		var carry: CarryHud = CARRY_HUD_SCENE.instantiate()
		carry.player = _player
		add_child(carry)
		var mask: HideMask = HIDE_MASK_SCENE.instantiate()
		mask.player = _player
		add_child(mask)
		var highlights: InteractHighlights = HIGHLIGHTS_SCENE.instantiate()
		highlights.player = _player
		add_child(highlights)
		_add_map_screen()
	for spot in get_hiding_spots():
		spot.found.connect(_on_hidden_found)
	_setup_game_loop()
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)
	add_child(ShaderWarmup.new())  # No stutter on the first sight of a place (T-085).


func _setup_monster_role() -> void:
	avatar = AVATAR_SCENE.instantiate()
	add_child(avatar)
	avatar.global_transform = _monster.global_transform
	markers = MARKERS_SCENE.instantiate()
	markers.monster = avatar
	add_child(markers)
	var reticle: ScanReticle = SCAN_RETICLE_SCENE.instantiate()
	reticle.monster = avatar
	reticle.buildings = get_buildings()
	add_child(reticle)
	var scan_look := ScanLook.new()
	scan_look.monster = avatar
	scan_look.night = $WorldEnvironment
	add_child(scan_look)
	var prompt: InteractPrompt = INTERACT_PROMPT_SCENE.instantiate()
	prompt.player = avatar  # Opening hiding spots (S-008, Q7).
	add_child(prompt)
	prey = PREY_SCENE.instantiate()
	prey.wander_route = $PreyRoute
	prey.hiding_spots = $HidingSpots
	prey.monster = avatar
	prey.buildings = get_buildings()
	prey.position = _spawn  # Before entering the tree, so no first footstep jump.
	prey.rotation.y = _spawn_yaw
	add_child(prey)
	_overlay.player = null
	_overlay.monster = null
	_overlay.avatar = avatar
	_overlay.prey = prey
	_add_point_markers($PreyRoute)
	_add_point_markers($HidingSpots)
	_gauge.visible = false
	for node: Node in [_player, _monster]:
		remove_child(node)
		node.queue_free()
	_player = null
	_monster = null


## The hunted's map (S-017, T-252), if the map has a plan.
func _add_map_screen() -> void:
	var plan := MapPlan.for_scene(scene_file_path)
	if plan == null:
		return
	map_screen = MAP_SCREEN_SCENE.instantiate()
	map_screen.plan = plan
	map_screen.player = _player
	add_child(map_screen)


## Online game (S-010, T-097). The room plays everyone: a Player for each
## human hunted, the monster's avatar or the AI monster. A client plays only
## its own avatar and sees the others as puppets. Noises, scans and catches
## come from the room (T-098), and so do the map's changes and the game loop
## (T-099), which a client only mirrors. The AIs in empty seats come with T-101.
func _setup_online() -> void:
	var net := NetGame.new()
	net.name = "NetGame"
	net.settings = NetSession.settings
	net.is_room = NetSession.mode == NetSession.Mode.ROOM
	net.buildings = get_buildings()
	_net = net
	net.world = NetWorld.new(self)  # Before the loop draws or takes anything.
	if net.is_room:
		_setup_online_room(net)
	else:
		_setup_online_client(net)
	add_child(net)
	_setup_game_loop()
	net.world.game_loop = game_loop
	if not net.is_room:
		# Escape opens the pause, the game goes on (S-013, Q6, T-164).
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		add_child(pause_menu)
	if net.is_room:
		for spot in get_hiding_spots():
			spot.found.connect(_on_online_hidden_found)
		if game_loop != null:
			game_loop.ended.connect(_on_online_game_ended)
			for each in _ai_preys:
				each.start_loop(game_loop, get_fuse_boxes(), _rng.randi() | 1)


func _setup_online_room(net: NetGame) -> void:
	var lobby := GameSession.online_lobby
	_player_path = _player.scene_file_path
	var spawns: Array = []
	if has_node("PlayerSpawns"):
		spawns = far_apart(
			get_node("PlayerSpawns").get_children(),
			LobbyState.SEATS - 1,
			LOOP_SETTINGS.spawn_spacing,
			_rng
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
			one = _new_player(net, place, seat)
			if marker != null:
				one.global_position = marker.global_position
				one.rotation.y = marker.global_rotation.y
		_give_capture(one)
		hunted.append(one)
	_online_hunted = hunted
	var monster_place: int = lobby.seats[LobbyState.MONSTER_SEAT] if lobby != null else 0
	if monster_place != 0:
		avatar = AVATAR_SCENE.instantiate()
		avatar.local_controls = false
		add_child(avatar)
		avatar.global_transform = _monster.global_transform
		net.add_avatar(monster_place, LobbyState.MONSTER_SEAT, avatar)
		_free_node(_monster)
		_monster = null
		net.hunted_caught.connect(_online_catch)
	else:
		_monster.player = hunted[0] if not hunted.is_empty() else null
		for other in hunted.slice(1):
			_monster.others.append(other)
		_monster.buildings = get_buildings()
		_monster.hunted_caught.connect(_online_catch)
		net.ai_monster = _monster
	for each in _ai_preys:
		each.monster = avatar if avatar != null else _monster
	_free_node(_player)
	_player = null
	if NetSession.link != null:
		NetSession.link.player_left.connect(_on_player_left)
		NetSession.link.player_returned.connect(_on_player_returned)


## Room side: the Player of a human hunted in a place and a seat.
func _new_player(net: NetGame, place: int, seat: int) -> Player:
	var player: Player = load(_player_path).instantiate()
	player.local_controls = false
	player.name = "Hunted%d" % seat
	add_child(player)
	player.get_node("Head/Camera3D").current = false
	net.add_avatar(place, seat, player)
	return player


## Room side: the capture rule of a hunted (T-107).
func _give_capture(one: Node3D, like: CaptureState = null) -> CaptureState:
	var capture := CaptureState.new()
	if like != null:
		capture.copy_from(like)
	one.add_child(capture)
	one.set("capture", capture)
	capture.changed.connect(_on_capture_changed.bind(one))
	return capture


## Room side (T-102): a player left a game in progress. Its place waits for
## it seat_keep_time, then an AI takes it where it was.
func _on_player_left(place: int) -> void:
	if _net.avatars.has(place):
		_gone[place] = NetSession.settings.seat_keep_time


## Room side: a player came back with its token before the end: its avatar
## again, or the AI's place, as the AI left it.
func _on_player_returned(place: int) -> void:
	if _gone.erase(place) or not _replaced.has(place):
		return
	var seat: int = _replaced[place]
	_replaced.erase(place)
	if seat == LobbyState.MONSTER_SEAT:
		_monster_back(place)
	else:
		_hunted_back(place, seat)


func _process(delta: float) -> void:
	for place: int in _gone.keys():
		_gone[place] -= delta
		if _gone[place] <= 0.0:
			_gone.erase(place)
			replace_with_ai(place)


## Room side: an AI plays the place of a player who left, from where it was.
func replace_with_ai(place: int) -> void:
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
	for kind: Inventory.Kind in [Inventory.Kind.BOTTLE, Inventory.Kind.DECOY]:
		prey.inventory.set_count(kind, player.inventory.count(kind))
	prey.monster = avatar if avatar != null else _monster
	_net.ai_hunted[seat] = prey
	_swap_hunted(player, prey)
	if game_loop != null:
		prey.start_loop(game_loop, get_fuse_boxes(), _rng.randi() | 1)


func _hunted_back(place: int, seat: int) -> void:
	var prey: Prey = _net.ai_hunted.get(seat)
	if prey == null:
		return
	_net.ai_hunted.erase(seat)
	var player := _new_player(_net, place, seat)
	player.global_position = prey.global_position
	player.rotation.y = prey.rotation.y
	for kind: Inventory.Kind in [Inventory.Kind.BOTTLE, Inventory.Kind.DECOY]:
		player.inventory.set_count(kind, prey.inventory.count(kind))
	_ai_preys.erase(prey)
	_swap_hunted(prey, player)
	if NetGame.is_out(player):
		_net.spectate(player)


## One hunted takes the place of another: its capture rule, its fuses, its
## place among the monster's targets. The old one goes.
func _swap_hunted(old: Node3D, new: Node3D) -> void:
	var capture := _give_capture(new, old.get("capture"))
	new.set("held", old.get("held"))
	_online_hunted[_online_hunted.find(old)] = new
	if game_loop != null:
		game_loop.replace_hunted(old, new)
	if _monster != null:
		_monster.forget(old)
		if capture.is_free():
			_monster.add_target(new)
	_net.replace_watched(old, new)
	if capture.state == CaptureState.State.OUT:
		new.process_mode = Node.PROCESS_MODE_DISABLED
		new.global_position = Vector3(0, -60, 0)
	_free_node(old)


## The AI monster takes the place of a human monster who left, where it was.
func _monster_to_ai(old: MonsterAvatar) -> void:
	var monster: Monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster"
	monster.patrol_route = get_node_or_null("PatrolRoute")
	monster.buildings = get_buildings()
	monster.position = old.global_position
	monster.rotation.y = old.rotation.y
	monster.catch_count = old.catch_count
	_free_node(old)
	avatar = null
	add_child(monster)
	_set_ai_monster(monster)


## The human monster back in the AI monster's place.
func _monster_back(place: int) -> void:
	avatar = AVATAR_SCENE.instantiate()
	avatar.local_controls = false
	add_child(avatar)
	avatar.global_transform = _monster.global_transform
	avatar.catch_count = _monster.catch_count
	_net.add_avatar(place, LobbyState.MONSTER_SEAT, avatar)
	_net.ai_monster = null
	if not _net.hunted_caught.is_connected(_online_catch):
		_net.hunted_caught.connect(_online_catch)
	for each in _ai_preys:
		each.monster = avatar
	_free_node(_monster)
	_monster = null


## Room side: the AI monster hunts every hunted still free.
func _set_ai_monster(monster: Monster) -> void:
	_monster = monster
	_net.ai_monster = monster
	for one in _online_hunted:
		if CaptureState.is_free_hunted(one):
			monster.add_target(one)
	if not monster.hunted_caught.is_connected(_online_catch):
		monster.hunted_caught.connect(_online_catch)
	for each in _ai_preys:
		each.monster = monster
	if game_loop != null and game_loop.is_exit_open():
		_on_exit_opened()


## Room side: an AI prey for an empty hunted seat (T-101), where the seat's
## hunted would start (marker), or where a hunted who left was (T-102). It
## plays the loop with the others once it is set up.
func _new_ai_prey(seat: int, marker: Node3D) -> Prey:
	var each: Prey = PREY_SCENE.instantiate()
	each.name = "AiHunted%d" % seat
	(each.get_node("Body") as HuntedBody).role = HuntedBody.role_for_seat(seat)  # S-011 Q5.
	each.wander_route = get_node_or_null("PreyRoute")
	each.hiding_spots = get_node_or_null("HidingSpots")
	each.buildings = get_buildings()
	if marker != null:
		each.position = marker.global_position  # Before the tree: no first footstep jump.
		each.rotation.y = marker.global_rotation.y
	add_child(each)
	_ai_preys.append(each)
	return each


func _setup_online_client(net: NetGame) -> void:
	if GameSession.online_seat == LobbyState.MONSTER_SEAT:
		_setup_monster_role()  # Builds the local monster and its view...
		_free_node(prey)  # ...without the AI prey: the hunted are puppets.
		prey = null
		_overlay.prey = null
		net.own = avatar
	else:
		var carry: CarryHud = CARRY_HUD_SCENE.instantiate()
		carry.player = _player
		add_child(carry)
		var mask: HideMask = HIDE_MASK_SCENE.instantiate()
		mask.player = _player
		add_child(mask)
		var highlights: InteractHighlights = HIGHLIGHTS_SCENE.instantiate()
		highlights.player = _player
		add_child(highlights)
		_add_map_screen()
		_own_huds.assign([carry, mask, highlights, _gauge])
		if map_screen != null:
			_own_huds.append(map_screen)
		_own_huds.append_array(_player.find_children("*", "CanvasLayer", true, false))
		_overlay.monster = null
		_free_node(_monster)  # The room runs the monster; here it is a puppet.
		_monster = null
		net.own = _player
		net.spectating.connect(_on_spectating)
	net.caught_reported.connect(_on_caught_reported)
	# The next game launched while this one's end screen is up (T-099), or
	# this one again after a cut (T-102).
	NetSession.game_started.connect(_on_next_game)
	NetSession.left.connect(_on_connection_lost)
	NetSession.unreachable.connect(_on_rejoin_failed)
	NetSession.refused.connect(_on_rejoin_failed.unbind(1))
	add_child(ShaderWarmup.new())


## Room side: the monster (AI or human) caught a hunted, or opened its
## hiding spot (T-107): captured the first time, out the second.
func _online_catch(caught: Node3D) -> void:
	var capture: CaptureState = caught.get("capture")
	if capture != null and not (game_loop != null and game_loop.is_over):
		capture.catch()


## Room side: a hunted captured, freed or out. Everyone is told; the AI
## monster leaves a captured hunted and chases it again once freed; a hunted
## out of the game leaves the map and watches a teammate.
func _on_capture_changed(state: CaptureState.State, player: Node3D) -> void:
	player.set("held", state != CaptureState.State.FREE)
	_net.report_caught(_net.seat_of(player), state)
	match state:
		CaptureState.State.CAPTURED:
			if game_loop != null:
				game_loop.set_captured(player, true)
			if _monster != null:
				_monster.forget(player)
				_monster.hold_still(_monster.settings.catch_show_time)  # T-127.
				_monster.walk_away(player.global_position)
		CaptureState.State.FREE:
			if game_loop != null:
				game_loop.set_captured(player, false)
			if _monster != null:
				_monster.add_target(player)
		CaptureState.State.OUT:
			if game_loop != null:
				game_loop.drop_fuses(player)
				game_loop.hunted_out(player)
			if _monster != null:
				_monster.forget(player)
				_monster.hold_still(_monster.settings.catch_show_time)  # T-127.
				_monster.walk_away(player.global_position)
			_net.spectate(player)
			player.process_mode = Node.PROCESS_MODE_DISABLED
			player.global_position = Vector3(0, -60, 0)


## Client side (T-102): the connection to the room broke. It connects again
## with its token: the room gives its place back and the game starts again
## here, as it is in the room.
func _on_connection_lost() -> void:
	_caught_screen.show_for(NetSession.settings.room_connect_timeout, "HUD_RECONNECTING")
	NetSession.rejoin()


## Client side: the room cannot be reached again: back to the online menu.
func _on_rejoin_failed() -> void:
	NetSession.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file(EndScreen.LOBBY_SCENE)


func _on_next_game(state: LobbyState) -> void:
	LobbyMenu.enter_game(get_tree(), state)


## Room side: the monster opened a hiding spot with a hunted inside.
func _on_online_hidden_found(occupant: Node3D, _by: Node3D) -> void:
	_online_catch(occupant)


## Room side: the game is over. Everyone gets the last state at once, and the
## room goes back to its waiting room a little later (the end screens are up).
func _on_online_game_ended(_hunted_won: bool) -> void:
	_net.send_world()
	get_tree().create_timer(NetSession.settings.end_return_delay).timeout.connect(
		NetSession.end_game
	)


## Client side: the room says a hunted was caught or freed (T-107). Its
## player sees that it is captured, freed, or out; the monster sees that it
## caught someone.
func _on_caught_reported(seat: int, state: CaptureState.State) -> void:
	var settings: MonsterSettings = avatar.settings if avatar != null else MONSTER_SETTINGS
	if avatar != null:
		if state != CaptureState.State.FREE:
			_caught_screen.show_for(settings.caught_screen_time, "HUD_PREY_CAUGHT")
	elif seat == GameSession.online_seat:
		var keys := {
			CaptureState.State.CAPTURED: "HUD_CAPTURED",
			CaptureState.State.FREE: "HUD_RESCUED",
			CaptureState.State.OUT: "HUD_ELIMINATED",
		}
		var catcher: NetPuppet = _net.puppets.get(LobbyState.MONSTER_SEAT)
		if (
			state != CaptureState.State.FREE
			and catcher != null
			and catcher.visible
			and _player != null
		):
			# Seized (S-011, T-127): the head turns to the monster first.
			_player.watch_catcher(catcher.get_eye_position(), settings.catch_show_time)
			await get_tree().create_timer(settings.catch_show_time, false).timeout
		_caught_screen.show_for(settings.caught_screen_time, keys[state])


## Client side: out of the game, the hunted watches a teammate (T-107).
func _on_spectating() -> void:
	for hud in _own_huds:
		if is_instance_valid(hud):
			hud.set("visible", false)
			hud.process_mode = Node.PROCESS_MODE_DISABLED
	var view := SpectatorView.new()
	view.name = "SpectatorView"
	view.net = _net
	add_child(view)


func _free_node(node: Node) -> void:
	if node != null and node.get_parent() == self:
		remove_child(node)
		node.queue_free()


## The fuses, the transformer and the exit (S-007), when the map has fuse boxes.
func _setup_game_loop() -> void:
	var boxes := get_fuse_boxes()
	if boxes.is_empty():
		return
	var room := NetSession.mode == NetSession.Mode.ROOM
	game_loop = GameLoop.new()
	game_loop.name = "GameLoop"
	game_loop.settings = LOOP_SETTINGS
	game_loop.hunted = prey if avatar != null else _player
	if room:
		game_loop.hunted = _online_hunted[0] if not _online_hunted.is_empty() else null
		game_loop.team.assign(_online_hunted)
	elif NetSession.mode == NetSession.Mode.CLIENT:
		game_loop.mirror = true  # The room's loop decides (T-099).
		game_loop.hunted = null
	add_child(game_loop)
	game_loop.setup(self, GameSession.game_seed)
	game_loop.exit_opened.connect(_on_exit_opened)
	if room:
		return  # No screens on the server.
	end_screen = END_SCREEN_SCENE.instantiate()
	end_screen.online = NetSession.mode == NetSession.Mode.CLIENT
	add_child(end_screen)
	game_loop.ended.connect(_on_game_ended)
	if prey != null:
		prey.start_loop(game_loop, boxes, _rng.randi() | 1)
	if avatar == null:
		var hud: LoopHud = LOOP_HUD_SCENE.instantiate()
		hud.game_loop = game_loop
		add_child(hud)


## Every fuse box of the map (S-007).
func get_fuse_boxes() -> Array[FuseBox]:
	var found: Array[FuseBox] = []
	for node in find_children("*", "Node3D", true, false):
		if node is FuseBox:
			found.append(node)
	return found


func _physics_process(_delta: float) -> void:
	if (
		avatar == null
		or prey == null
		or _caught_screen.visible
		or (game_loop != null and game_loop.is_over)
	):
		return
	if HidingSpot.is_hidden(prey):
		return  # Only opening the hiding spot catches it (S-008, Q7).
	var gap := prey.global_position - avatar.global_position
	if (
		Vector2(gap.x, gap.z).length() <= avatar.settings.catch_distance
		and absf(gap.y) <= avatar.settings.catch_height
	):  # Not through a floor (T-079).
		_on_prey_caught()


## The AI monster goes to guard the tunnel (S-007, Q4).
func _on_exit_opened() -> void:
	if _monster != null:
		_monster.guard_exit(Prey.markers_of(get_node_or_null("GuardPoints")))


func _on_game_ended(_hunted_won: bool) -> void:
	end_screen.show_result(GameSession.role, game_loop)


func _on_prey_caught() -> void:
	avatar.catch_count += 1
	if game_loop != null:
		game_loop.finish(false)  # The monster wins (S-007, Q7).
		return
	_caught_screen.show_for(avatar.settings.caught_screen_time, "HUD_PREY_CAUGHT")
	var points := Prey.markers_of($PreyRoute)
	var index := MonsterBrain.farthest_index(points, avatar.global_position)
	prey.respawn(points[index], index)


## Small pale boxes on the prey's points, shown with F4 (noise debug).
func _add_point_markers(parent: Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * POINT_MARKER_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = avatar.settings.debug_cone_color
	mesh.material = material
	for point: Node3D in parent.get_children():
		var marker := MeshInstance3D.new()
		marker.mesh = mesh
		marker.position.y = POINT_MARKER_SIZE / 2.0
		marker.visible = false
		marker.add_to_group(NoiseDebug.DEBUG_GROUP)
		point.add_child(marker)


## Every hiding spot of the map (S-008).
func get_hiding_spots() -> Array[HidingSpot]:
	var found: Array[HidingSpot] = []
	for node in find_children("*", "Node3D", true, false):
		if node is HidingSpot:
			found.append(node)
	return found


## The monster opened a hiding spot with the hunted inside (S-008, Q7): a catch.
func _on_hidden_found(_occupant: Node3D, _by: Node3D) -> void:
	if avatar != null:
		_on_prey_caught()
	elif _monster != null:
		_monster.catch_count += 1
		_on_player_caught()


## Every scannable building of the map.
func get_buildings() -> Array[Building]:
	var found: Array[Building] = []
	for node in find_children("*", "Area3D", true, false):
		if node is Building:
			found.append(node)
	return found


## Where the hunted may start, empty if the map has no PlayerSpawns node.
func get_spawn_points() -> Array[Vector3]:
	var spawns := get_node_or_null("PlayerSpawns") as Node3D
	if spawns == null:
		return []
	return Prey.markers_of(spawns)


## Draws count markers (S-010, T-100), each at least spacing meters from the
## others when the map allows it, the rest anywhere.
static func far_apart(
	markers: Array, count: int, spacing: float, rng: RandomNumberGenerator
) -> Array:
	var shuffled := LoopRules.draw(markers, markers.size(), rng)
	var chosen := []
	for marker: Node3D in shuffled:
		var far := chosen.all(
			func(other: Node3D) -> bool:
				return other.global_position.distance_to(marker.global_position) >= spacing
		)
		if far and chosen.size() < count:
			chosen.append(marker)
	for marker: Node3D in shuffled:
		if chosen.size() >= count:
			break
		if marker not in chosen:
			chosen.append(marker)
	return chosen


## Draws a spawn marker: the hunted starts there, facing where the marker faces.
func _pick_spawn() -> void:
	var markers := get_node("PlayerSpawns").get_children()
	var marker: Node3D = markers[_rng.randi_range(0, markers.size() - 1)]
	_spawn = marker.global_position
	_spawn_yaw = marker.global_rotation.y


## Solo, hunted role: the monster caught the player. First the catch
## (S-011, T-127): the monster seizes it, the player's head turns to its red
## eyes, for catch_show_time (2 s at most, 2.3); then the end of the game, or
## the "caught" screen and a respawn outside the game loop.
func _on_player_caught() -> void:
	if _player.watching_catcher:
		return  # Already in its claws.
	var show := _monster.settings.catch_show_time
	_monster.gesture.play(MonsterBody.Action.CATCH, _monster.get_body_settings().catch_time)
	_monster.hold_still(show)
	_player.watch_catcher(_monster.get_eye_position(), show)
	await get_tree().create_timer(show, false).timeout
	_end_catch()


func _end_catch() -> void:
	if game_loop != null:
		game_loop.finish(false)  # No respawn in solo (S-007, Q5).
		return
	_caught_screen.show_for(_monster.settings.caught_screen_time)
	if not get_spawn_points().is_empty():
		_pick_spawn()
	_player.global_position = _spawn
	_player.rotation.y = _spawn_yaw
	_player.velocity = Vector3.ZERO
	_monster.reset_to_patrol(_spawn)


## Monster role only (S-010, T-100): count AI preys in all, each starting at
## least spawn_spacing from the others, all looking for the same fuses.
func add_ai_preys(count: int) -> void:
	var boxes := get_fuse_boxes()
	var markers := far_apart(
		get_node("PlayerSpawns").get_children(), count, LOOP_SETTINGS.spawn_spacing, _rng
	)
	for i in count:
		var each: Prey = prey
		if i > 0:
			each = PREY_SCENE.instantiate()
			each.name = "Prey%d" % (i + 1)
			each.wander_route = $PreyRoute
			each.hiding_spots = $HidingSpots
			each.monster = avatar
			each.buildings = get_buildings()
		var marker: Node3D = markers[i % markers.size()]
		(each.get_node("Body") as HuntedBody).role = (i % HuntedBody.Role.size()) as HuntedBody.Role
		each.position = marker.global_position
		each.rotation.y = marker.global_rotation.y
		if i > 0:
			add_child(each)
			game_loop.add_hunted(each)
			each.start_loop(game_loop, boxes, _rng.randi() | 1)
			extra_preys.append(each)
		else:
			each.start_loop(game_loop, boxes, _rng.randi() | 1)  # From its new place.


## An AI prey caught by the AI monster: out of the game, out of the way. The
## monster wins once none is free (one prey: at the first catch).
func _on_ai_prey_caught(caught: Node3D, monster: Monster) -> void:
	game_loop.hunted_out(caught)
	if game_loop.is_over:
		return
	monster.forget(caught)
	caught.process_mode = Node.PROCESS_MODE_DISABLED
	caught.global_position = Vector3(0, -60, 0)


## Monster role only: the playable monster is put away, out of sight and
## hearing, and an AI monster hunts the AI prey instead, as it would hunt the
## player. Used by the game simulation (S-007) and the bench mode (S-009).
func play_ai_against_ai() -> Monster:
	var spawn: Node3D = get_node("MonsterSpawn").get_child(0)
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	avatar.global_position = Vector3(0, -50, 0)
	var monster: Monster = MONSTER_SCENE.instantiate()
	monster.patrol_route = get_node("PatrolRoute")
	monster.buildings = get_buildings()
	monster.player = prey
	for other in extra_preys:
		monster.others.append(other)
	monster.position = spawn.global_position
	add_child(monster)
	for each: Prey in [prey] + extra_preys:
		each.monster = monster
	monster.hunted_caught.connect(_on_ai_prey_caught.bind(monster))
	game_loop.exit_opened.connect(monster.guard_exit.bind(Prey.markers_of(get_node("GuardPoints"))))
	return monster
