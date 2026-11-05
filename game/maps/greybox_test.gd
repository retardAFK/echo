extends Node3D
## Greybox test map (specs S-001 to S-004).
## Hunted role: wires the AI monster to the player and handles a catch (Q4 of
## S-003): "caught" screen, player back to the start, monster back on patrol.
## Monster role (S-004): the AI monster and the hunted player are replaced by
## the playable monster, standing where the AI monster starts, and an AI prey
## starting where the hunted does. Touching the prey catches it: "caught"
## screen, and the prey wanders again from the point farthest from the monster.
## Escape frees the mouse; Escape again goes back to the start menu.

const MENU_SCENE := "res://game/ui/start_menu.tscn"
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MARKERS_SCENE := preload("res://game/ui/noise_markers.tscn")
const SCAN_RETICLE_SCENE := preload("res://game/ui/scan_reticle.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")
## Size of the F4 markers for the prey's wander points and hiding spots, in meters.
const POINT_MARKER_SIZE := 0.3

var avatar: MonsterAvatar
var markers: NoiseMarkers
var prey: Prey

@onready var _player: Player = $Player
@onready var _monster: Monster = $Monster
@onready var _caught_screen: CaughtScreen = $CaughtScreen
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _gauge: NoiseGauge = $NoiseGauge
@onready var _spawn: Vector3 = _player.global_position


func _ready() -> void:
	if GameSession.role == GameSession.Role.MONSTER:
		_setup_monster_role()
		return
	_monster.player = _player
	_monster.player_caught.connect(_on_player_caught)


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
	prey.buildings = [$Building]
	prey.position = _spawn  # Before entering the tree, so no first footstep jump.
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


func _physics_process(_delta: float) -> void:
	if avatar == null or _caught_screen.visible:
		return
	var gap := prey.global_position - avatar.global_position
	if Vector2(gap.x, gap.z).length() <= avatar.settings.catch_distance:
		_on_prey_caught()


func _on_prey_caught() -> void:
	avatar.catch_count += 1
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


func _on_player_caught() -> void:
	_caught_screen.show_for(_monster.settings.caught_screen_time)
	_player.global_position = _spawn
	_player.velocity = Vector3.ZERO
	_monster.reset_to_patrol(_spawn)
