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
## Size of the F4 markers for the prey's wander points and hiding spots, in meters.
const POINT_MARKER_SIZE := 0.3

var avatar: MonsterAvatar
var markers: NoiseMarkers
var prey: Prey
## The game loop (S-007), null on a map without fuse boxes.
var game_loop: GameLoop
## Shown when the game loop ends (S-007, Q6).
var end_screen: EndScreen
## Escape pauses the game (S-009, Q6).
var pause_menu: PauseMenu

var _rng := RandomNumberGenerator.new()
## The online part of the game (S-010), null in solo.
var _net: NetGame

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


## Online game (S-010, T-097). The room plays everyone: a Player for each
## human hunted, the monster's avatar or the AI monster. A client plays only
## its own avatar and sees the others as puppets. Noises, scans and catches
## come from the room (T-098); the game loop and the AIs in empty seats come
## with T-099 to T-101.
func _setup_online() -> void:
	var net := NetGame.new()
	net.name = "NetGame"
	net.settings = NetSession.settings
	net.is_room = NetSession.mode == NetSession.Mode.ROOM
	net.buildings = get_buildings()
	_net = net
	if net.is_room:
		_setup_online_room(net)
	else:
		_setup_online_client(net)
	add_child(net)


func _setup_online_room(net: NetGame) -> void:
	var lobby := GameSession.online_lobby
	var spawns: Array = []
	if has_node("PlayerSpawns"):
		spawns = get_node("PlayerSpawns").get_children()
	spawns.shuffle()
	var hunted: Array[Player] = []
	for seat in range(1, LobbyState.SEATS):
		var place: int = lobby.seats[seat] if lobby != null else 0
		if place == 0:
			continue
		var player: Player = load(_player.scene_file_path).instantiate()
		player.local_controls = false
		player.name = "Hunted%d" % seat
		var marker: Node3D = (
			spawns[hunted.size() % spawns.size()] if not spawns.is_empty() else null
		)
		add_child(player)
		player.get_node("Head/Camera3D").current = false
		if marker != null:
			player.global_position = marker.global_position
			player.rotation.y = marker.global_rotation.y
		net.add_avatar(place, seat, player)
		hunted.append(player)
	var monster_place: int = lobby.seats[LobbyState.MONSTER_SEAT] if lobby != null else 0
	if monster_place != 0:
		avatar = AVATAR_SCENE.instantiate()
		avatar.local_controls = false
		add_child(avatar)
		avatar.global_transform = _monster.global_transform
		net.add_avatar(monster_place, LobbyState.MONSTER_SEAT, avatar)
		_free_node(_monster)
		_monster = null
		net.hunted_caught.connect(_put_back)
	else:
		_monster.player = hunted[0] if not hunted.is_empty() else null
		_monster.buildings = get_buildings()
		_monster.player_caught.connect(_on_online_caught)
		net.ai_monster = _monster
	_free_node(_player)
	_player = null


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
		_overlay.monster = null
		_free_node(_monster)  # The room runs the monster; here it is a puppet.
		_monster = null
		net.own = _player
	net.caught_reported.connect(_on_caught_reported)
	add_child(ShaderWarmup.new())


## Room side: the AI monster caught a hunted; back to a spawn point until the
## capture rule of S-010 (T-107).
func _on_online_caught() -> void:
	var caught: Node3D = _monster.player
	if caught == null:
		return
	_net.report_caught(_net.seat_of(caught))
	_put_back(caught)
	_monster.reset_to_patrol(_spawn)


## Room side: a caught hunted goes back to a spawn point (until T-107).
func _put_back(caught: Node3D) -> void:
	_pick_spawn()
	caught.global_position = _spawn
	caught.velocity = Vector3.ZERO


## Client side: the room says a hunted was caught. Its player sees the "caught"
## screen; the monster sees that it caught someone.
func _on_caught_reported(seat: int) -> void:
	var settings: MonsterSettings = avatar.settings if avatar != null else MONSTER_SETTINGS
	if avatar != null:
		_caught_screen.show_for(settings.caught_screen_time, "HUD_PREY_CAUGHT")
	elif seat == GameSession.online_seat:
		_caught_screen.show_for(settings.caught_screen_time)


func _free_node(node: Node) -> void:
	if node != null and node.get_parent() == self:
		remove_child(node)
		node.queue_free()


## The fuses, the transformer and the exit (S-007), when the map has fuse boxes.
func _setup_game_loop() -> void:
	var boxes := get_fuse_boxes()
	if boxes.is_empty():
		return
	game_loop = GameLoop.new()
	game_loop.name = "GameLoop"
	game_loop.settings = LOOP_SETTINGS
	game_loop.hunted = prey if avatar != null else _player
	add_child(game_loop)
	game_loop.setup(self, GameSession.game_seed)
	end_screen = END_SCREEN_SCENE.instantiate()
	add_child(end_screen)
	game_loop.ended.connect(_on_game_ended)
	game_loop.exit_opened.connect(_on_exit_opened)
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


## Draws a spawn marker: the hunted starts there, facing where the marker faces.
func _pick_spawn() -> void:
	var markers := get_node("PlayerSpawns").get_children()
	var marker: Node3D = markers[_rng.randi_range(0, markers.size() - 1)]
	_spawn = marker.global_position
	_spawn_yaw = marker.global_rotation.y


func _on_player_caught() -> void:
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
	monster.position = spawn.global_position
	add_child(monster)
	prey.monster = monster
	monster.player_caught.connect(game_loop.finish.bind(false))
	game_loop.exit_opened.connect(monster.guard_exit.bind(Prey.markers_of(get_node("GuardPoints"))))
	return monster
