extends Node3D
## Greybox test map (specs S-001 to S-004).
## Hunted role: wires the AI monster to the player and handles a catch (Q4 of
## S-003): "caught" screen, player back to the start, monster back on patrol.
## Monster role (S-004): the AI monster and the hunted player are replaced by
## the playable monster, standing where the AI monster starts.
## Escape frees the mouse; Escape again goes back to the start menu.

const MENU_SCENE := "res://game/ui/start_menu.tscn"
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MARKERS_SCENE := preload("res://game/ui/noise_markers.tscn")
const SCAN_BAR_SCENE := preload("res://game/ui/scan_bar.tscn")

var avatar: MonsterAvatar
var markers: NoiseMarkers

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
	var scan_bar: ScanBar = SCAN_BAR_SCENE.instantiate()
	scan_bar.monster = avatar
	add_child(scan_bar)
	_overlay.player = null
	_overlay.monster = null
	_gauge.visible = false
	for node: Node in [_player, _monster]:
		remove_child(node)
		node.queue_free()
	_player = null
	_monster = null


func _on_player_caught() -> void:
	_caught_screen.show_for(_monster.settings.caught_screen_time)
	_player.global_position = _spawn
	_player.velocity = Vector3.ZERO
	_monster.reset_to_patrol(_spawn)
