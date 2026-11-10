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
## Escape frees the mouse; Escape again goes back to the start menu.
## If the map has a PlayerSpawns node, the hunted (or the AI prey) starts on one
## of its Marker3D children, drawn at random (S-006). Scannable buildings are the
## Building nodes of the map, wherever they are.

const MENU_SCENE := "res://game/ui/start_menu.tscn"
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MARKERS_SCENE := preload("res://game/ui/noise_markers.tscn")
const SCAN_RETICLE_SCENE := preload("res://game/ui/scan_reticle.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const LOOP_HUD_SCENE := preload("res://game/ui/loop_hud.tscn")
const END_SCREEN_SCENE := preload("res://game/ui/end_screen.tscn")
## Size of the F4 markers for the prey's wander points and hiding spots, in meters.
const POINT_MARKER_SIZE := 0.3

var avatar: MonsterAvatar
var markers: NoiseMarkers
var prey: Prey
## The game loop (S-007), null on a map without fuse boxes.
var game_loop: GameLoop
## Shown when the game loop ends (S-007, Q6).
var end_screen: EndScreen

var _rng := RandomNumberGenerator.new()

@onready var _player: Player = $Player
@onready var _monster: Monster = $Monster
@onready var _caught_screen: CaughtScreen = $CaughtScreen
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _gauge: NoiseGauge = $NoiseGauge
@onready var _spawn: Vector3 = _player.global_position
@onready var _spawn_yaw: float = _player.rotation.y


func _ready() -> void:
	_rng.randomize()
	if not get_spawn_points().is_empty():
		_pick_spawn()
		_player.global_position = _spawn
		_player.rotation.y = _spawn_yaw
	if GameSession.role == GameSession.Role.MONSTER:
		_setup_monster_role()
	else:
		_monster.player = _player
		_monster.player_caught.connect(_on_player_caught)
	_setup_game_loop()


func _input(event: InputEvent) -> void:
	# _input runs before the player's _unhandled_input, so the first Escape
	# only frees the mouse and the second one, mouse already free, opens the menu.
	if event.is_action_pressed("release_mouse") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		get_tree().change_scene_to_file(MENU_SCENE)


func _setup_monster_role() -> void:
	avatar = AVATAR_SCENE.instantiate()
	add_child(avatar)
	avatar.global_transform = _monster.global_transform
	markers = MARKERS_SCENE.instantiate()
	markers.monster = avatar
	add_child(markers)
	var reticle: ScanReticle = SCAN_RETICLE_SCENE.instantiate()
	reticle.monster = avatar
	add_child(reticle)
	var scan_look := ScanLook.new()
	scan_look.monster = avatar
	scan_look.night = $WorldEnvironment
	add_child(scan_look)
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
	game_loop.setup(self)
	end_screen = END_SCREEN_SCENE.instantiate()
	add_child(end_screen)
	game_loop.ended.connect(_on_game_ended)
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
	if avatar == null or _caught_screen.visible or (game_loop != null and game_loop.is_over):
		return
	var gap := prey.global_position - avatar.global_position
	if Vector2(gap.x, gap.z).length() <= avatar.settings.catch_distance:
		_on_prey_caught()


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
