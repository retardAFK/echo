class_name TestRoom
extends Node
## The test room (spec S-023, Q8 and Q9, T-356 and T-357): the greybox map
## with the stations of stations.tres, each with its sign, and no end. A child
## of the map (test_room.tscn); it sets things up once the map is ready.
## - The hunted's gadgets, bottles and alarm clock come back every second.
## - The monster is a dummy: the game's own AI monster on its patrol, which
##   hears, chases and is fooled as in a game, but never catches.
## - F6 (switch_test_role) plays the other role: the monster, with an AI prey
##   as the hunted dummy that walks and hides, to try the scan.
## - The noise rings (F4) are shown from the start.
## - Versus (spec S-024, T-374): open_versus() opens it with the Versus mode
##   prototype; no refill (the Versus has its own weapons), and the room
##   starts again when someone wins.
## To add a station: docs/MODULES.md, "Un poste de la salle d'essai".

const PATH := "res://game/maps/test_room/test_room.tscn"
const SIGN_HEIGHT := 2.2
const REFILL_TIME := 1.0
const THEME := preload("res://game/ui/theme/echo_theme.tres")

@export var stations: TestStationList

var _refill_left := 0.0

@onready var map: GameMap = get_parent()


## Opens the test room as role (the menu, and F6), in the Traque.
static func open(tree: SceneTree, role: GameSession.Role) -> void:
	GameSession.mode = &"hunt"
	_open(tree, role)


## Opens the test room as role with the Versus prototype (S-024, T-374).
static func open_versus(tree: SceneTree, role: GameSession.Role) -> void:
	GameSession.mode = VersusMode.MODE
	_open(tree, role)


static func _open(tree: SceneTree, role: GameSession.Role) -> void:
	GameSession.role = role
	GameSession.online_seat = -1
	LoadingScreen.open(tree, PATH)


func _ready() -> void:
	_setup.call_deferred()  # Once GameMap is ready and has set the role's part up.


func _setup() -> void:
	for station in stations.stations:
		_add_station(station)
	for monster: Node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		var settings: MonsterSettings = monster.get(&"settings")
		settings.catch_distance = 0.0  # Its own copy: a dummy that never catches.
	for debug: Node in map.find_children("*", "NoiseDebug", true, false):
		(debug as NoiseDebug).set_enabled(true)
	var hint := Label.new()
	hint.name = "TestRoomHint"
	hint.text = Text.t(_hint_key())
	hint.theme = THEME
	hint.theme_type_variation = &"HudLabel"
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = 4.0
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	var versus := map.get_node_or_null("VersusMode") as VersusMode
	if versus != null:
		versus.finished.connect(func(_winner: VersusRules.Winner) -> void: _again())


func _hint_key() -> String:
	if not VersusMode.is_on():
		return "TEST_ROOM_HINT"
	if GameSession.role == GameSession.Role.MONSTER:
		return "VERSUS_TEST_HINT_BOSS"
	return "VERSUS_TEST_HINT"


## Starts the room again in the same role and mode (a Versus game ended).
func _again() -> void:
	_open(get_tree(), GameSession.role)


func _add_station(station: TestStation) -> void:
	var thing: Node3D = station.scene.instantiate()
	thing.name = station.name_key.to_pascal_case()
	for property: String in station.properties:
		thing.set(property, station.properties[property])
	map.add_child(thing)
	thing.position = station.position
	thing.rotation.y = deg_to_rad(station.yaw_degrees)
	var sign_label := Label3D.new()
	sign_label.name = "Sign"
	sign_label.text = Text.t(station.name_key)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.pixel_size = 0.01
	sign_label.top_level = true
	thing.add_child(sign_label)
	sign_label.global_position = thing.global_position + Vector3.UP * SIGN_HEIGHT


func _physics_process(delta: float) -> void:
	_refill_left -= delta
	if _refill_left > 0.0:
		return
	_refill_left = REFILL_TIME
	var player := map.player if is_instance_valid(map.player) else null
	if player != null and player.inventory != null and not VersusMode.is_on():
		refill(player)


## Gives the hunted back all its gadgets, bottles and alarm clock.
static func refill(player: Player) -> void:
	Loadout.equip(player.inventory, player.loadout)
	for kind in [Inventory.Kind.BOTTLE, Inventory.Kind.DECOY]:
		player.inventory.set_count(kind, player.inventory.capacity(kind))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_test_role"):
		var other := GameSession.Role.HUNTED
		if GameSession.role == GameSession.Role.HUNTED:
			other = GameSession.Role.MONSTER
		_open(get_tree(), other)  # Same mode (S-024).
