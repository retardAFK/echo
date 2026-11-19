class_name GameMap
extends Node3D
## A playable map (specs S-001 to S-004, S-006): the greybox test map and the
## cité des Tilleuls share it. GameMap holds what every way of playing shares:
## the spawns, the buildings, the hiding spots, the game loop of S-007 when
## the map has fuse boxes (a catch then ends the game, and the end screen
## shows the result), and the pause menu (S-009, Q6). The rest lives in one
## part per way of playing, a child node added in _ready (S-022, T-433):
## - MapHuntedRole: solo, the player is the hunted, the AI monster hunts it.
## - MapMonsterRole: solo, the player is the monster, an AI prey is hunted.
## - MapOnlineRoom: online, the room (server) plays everyone (S-010).
## - MapOnlineClient: online, one player's screen (S-010).
## HuntedHuds adds what the hunted's screen shows of its own player.
## The parts read and write the shared state below (player, monster, avatar,
## prey, net, prison...); a part never calls another part.
## If the map has a PlayerSpawns node, the hunted (or the AI prey) starts on one
## of its Marker3D children, drawn at random (S-006). Scannable buildings are the
## Building nodes of the map, wherever they are.

const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const LOOP_HUD_SCENE := preload("res://game/ui/loop_hud.tscn")
const END_SCREEN_SCENE := preload("res://game/ui/end_screen.tscn")
const PAUSE_MENU_SCENE := preload("res://game/ui/pause_menu.tscn")

## The monster played by a person (solo monster role, or online), else null.
var avatar: MonsterAvatar
## The monster's noise markers (S-002), with the avatar.
var markers: NoiseMarkers
## Solo monster role: the AI prey it hunts.
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
## The part for the way the map is played (S-022, T-433): one of them is set
## (MapMonsterRole also on the client of the monster's player).
var hunted_role: MapHuntedRole
var monster_role: MapMonsterRole
var room: MapOnlineRoom
var client: MapOnlineClient
## The online part of the game (S-010), null in solo.
var net: NetGame
## Online (S-018): where the captured hunted wait, null on a map without one.
var prison: Prison
var rng := RandomNumberGenerator.new()

## The hunted player of the scene, null once a part removed it.
@onready var player: Player = $Player
## The AI monster of the scene, null once a part removed it.
@onready var monster: Monster = $Monster
@onready var caught_screen: CaughtScreen = $CaughtScreen
@onready var overlay: DebugOverlay = $DebugOverlay
@onready var gauge: NoiseGauge = $NoiseGauge
## Where the hunted starts (S-006), drawn again by pick_spawn().
@onready var spawn: Vector3 = player.global_position
@onready var spawn_yaw: float = player.rotation.y


func _ready() -> void:
	add_child(LevelVisibility.new())  # Draw calls: interiors near the camera only (T-195).
	if GameSession.game_seed != 0:
		rng.seed = GameSession.game_seed
	else:
		rng.randomize()
	if not get_spawn_points().is_empty():
		pick_spawn()
		player.global_position = spawn
		player.rotation.y = spawn_yaw
	if NetSession.mode != NetSession.Mode.SOLO:
		_setup_online()  # S-010, T-097.
		return
	if GameSession.role == GameSession.Role.MONSTER:
		monster_role = MapMonsterRole.new()
		_add_part(monster_role, "MonsterRole")
		monster_role.setup()
	else:
		hunted_role = MapHuntedRole.new()
		_add_part(hunted_role, "HuntedRole")
		hunted_role.setup()
	for spot in get_hiding_spots():
		spot.found.connect(_on_hidden_found)
	_setup_game_loop()
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)
	add_child(ShaderWarmup.new())  # No stutter on the first sight of a place (T-085).


func _add_part(part: Node, part_name: String) -> void:
	part.name = part_name
	part.set("map", self)
	add_child(part)


## Online game (S-010, T-097): NetGame, the mirrored network and prison, and
## the room's or the client's part. The AIs in empty seats come with T-101.
func _setup_online() -> void:
	net = NetGame.new()
	net.name = "NetGame"
	net.settings = NetSession.settings
	net.is_room = NetSession.mode == NetSession.Mode.ROOM
	net.buildings = get_buildings()
	overlay.net = net
	var network := CityNetwork.of(self)
	if network != null:
		network.mirror = not net.is_room
	prison = Prison.of(self)
	if prison != null:
		prison.mirror = not net.is_room
	net.world = NetWorld.new(self)  # Before the loop draws or takes anything.
	for thing: Node in net.world.monitors + net.world.gurneys + net.world.chairs:
		thing.set("mirror", not net.is_room)  # S-014: the room's things move and beep.
	if net.is_room:
		room = MapOnlineRoom.new()
		_add_part(room, "OnlineRoom")
		room.setup(net)
	else:
		client = MapOnlineClient.new()
		_add_part(client, "OnlineClient")
		client.setup(net)
	add_child(net)
	_setup_game_loop()
	net.world.game_loop = game_loop
	if room != null:
		room.start()
	else:
		# Escape opens the pause, the game goes on (S-013, Q6, T-164).
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		add_child(pause_menu)


## The fuses, the transformer and the exit (S-007), when the map has fuse boxes.
func _setup_game_loop() -> void:
	var boxes := get_fuse_boxes()
	if boxes.is_empty():
		return
	game_loop = GameLoop.new()
	game_loop.name = "GameLoop"
	game_loop.settings = LOOP_SETTINGS
	game_loop.hunted = prey if avatar != null else player
	if room != null:
		var team := room.online_hunted
		game_loop.hunted = team[0] if not team.is_empty() else null
		game_loop.team.assign(team)
	elif client != null:
		game_loop.mirror = true  # The room's loop decides (T-099).
		game_loop.hunted = null
	# Objectives besides fuses (S-018, Q13), for players and AI prey alike
	# (T-268).
	if client == null:
		game_loop.allowed = [
			LoopRules.Objective.CODE, LoopRules.Objective.DOWNLOAD, LoopRules.Objective.RELAY
		]
	game_loop.forced = GameLoop.parse_objectives(OS.get_environment("ECHO_OBJECTIVES"))
	add_child(game_loop)
	game_loop.setup(self, GameSession.game_seed)
	game_loop.exit_opened.connect(on_exit_opened)
	if room != null:
		return  # No screens on the server.
	var music := TensionMusic.new()  # S-012, T-146.
	music.game_loop = game_loop
	add_child(music)
	end_screen = END_SCREEN_SCENE.instantiate()
	end_screen.online = client != null
	add_child(end_screen)
	game_loop.ended.connect(_on_game_ended)
	if prey != null:
		prey.start_loop(game_loop, boxes, rng.randi() | 1)
	if avatar == null:
		var hud: LoopHud = LOOP_HUD_SCENE.instantiate()
		hud.game_loop = game_loop
		add_child(hud)


## The AI monster goes to guard the tunnel (S-007, Q4).
func on_exit_opened() -> void:
	if monster != null:
		monster.guard_exit(Prey.markers_of(get_node_or_null("GuardPoints")))


func _on_game_ended(_hunted_won: bool) -> void:
	end_screen.show_result(GameSession.role, game_loop)


## Solo: the monster opened a hiding spot with the hunted inside (S-008, Q7):
## a catch.
func _on_hidden_found(_occupant: Node3D, _by: Node3D) -> void:
	if monster_role != null:
		monster_role.prey_caught()
	elif hunted_role != null:
		hunted_role.found_hiding()


## Removes a node of the map (a part replaces the scene's player or monster).
func free_child(node: Node) -> void:
	if node != null and node.get_parent() == self:
		remove_child(node)
		node.queue_free()


## Draws a spawn marker: the hunted starts there, facing where the marker faces.
func pick_spawn() -> void:
	var spawns := get_node("PlayerSpawns").get_children()
	var marker: Node3D = spawns[rng.randi_range(0, spawns.size() - 1)]
	spawn = marker.global_position
	spawn_yaw = marker.global_rotation.y


## Every fuse box of the map (S-007).
func get_fuse_boxes() -> Array[FuseBox]:
	var found: Array[FuseBox] = []
	for node in find_children("*", "Node3D", true, false):
		if node is FuseBox:
			found.append(node)
	return found


## Every hiding spot of the map (S-008).
func get_hiding_spots() -> Array[HidingSpot]:
	var found: Array[HidingSpot] = []
	for node in find_children("*", "Node3D", true, false):
		if node is HidingSpot:
			found.append(node)
	return found


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
