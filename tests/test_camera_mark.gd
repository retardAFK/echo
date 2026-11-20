extends GutTest
## From a terminal, the monster seen through a camera is marked 5 s for the
## whole team (S-020, T-337, piste N5).

const TERMINAL_SCENE := preload("res://game/entities/network/terminal.tscn")
const CAMERA_SCENE := preload("res://game/entities/network/security_camera.tscn")
const SETTINGS := preload("res://game/data/network_settings.tres")

var _network: CityNetwork
var _camera: SecurityCamera
var _monster: Node3D


func before_each() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var terminal: Terminal = TERMINAL_SCENE.instantiate()
	root.add_child(terminal)
	_camera = CAMERA_SCENE.instantiate()
	root.add_child(_camera)
	_camera.set_physics_process(false)  # Not sweeping: it looks at the origin.
	_camera.transform = Transform3D(
		Basis.looking_at(Vector3(0, 1, 0) - Vector3(6, 3, 6), Vector3.UP), Vector3(6, 3, 6)
	)
	_network = CityNetwork.new()
	root.add_child(_network)
	_network.set_physics_process(false)  # Driven by hand.
	_monster = Node3D.new()
	_monster.add_to_group(Prison.MONSTERS_GROUP)
	root.add_child(_monster)


func after_each() -> void:
	for node in get_tree().get_nodes_in_group(Ping.GROUP):
		node.free()


func _watch() -> void:
	var watcher := Node3D.new()
	add_child_autofree(watcher)
	_network.watch(watcher, _camera)


func _marks() -> Array[Node]:
	return get_tree().get_nodes_in_group(Ping.GROUP)


func test_settings_follow_the_roadmap() -> void:
	assert_eq(SETTINGS.camera_mark_time, 5.0)


func test_a_watched_camera_marks_the_monster_it_sees_for_5_s() -> void:
	_watch()
	_network._mark_monsters(0.1)
	var marks := _marks()
	assert_eq(marks.size(), 1)
	var mark := marks[0] as Ping
	assert_eq(mark.kind, Ping.Kind.MONSTER)
	assert_eq(mark.global_position, _monster.global_position)
	assert_eq(mark.left, SETTINGS.camera_mark_time)
	for i in 10:
		_network._mark_monsters(0.4)
	assert_eq(_marks().size(), 1, "not again while the mark shows")
	_network._mark_monsters(1.5)
	assert_eq(_marks().size(), 2, "renewed while it still sees it")


func test_an_unwatched_camera_marks_nothing() -> void:
	_network._mark_monsters(0.1)
	assert_eq(_marks().size(), 0)


func test_a_monster_out_of_its_view_is_not_marked() -> void:
	_monster.position = Vector3(30, 0, 30)  # Behind the camera.
	_watch()
	_network._mark_monsters(0.1)
	assert_eq(_marks().size(), 0)


func test_a_smashed_camera_marks_nothing() -> void:
	_watch()
	_camera.smash()
	_network._mark_monsters(0.1)
	assert_eq(_marks().size(), 0)


func test_online_clients_only_show_the_room_s_marks() -> void:
	_network.mirror = true
	_watch()
	_network._physics_process(0.5)
	assert_eq(_marks().size(), 0, "the room marks, not a client")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var net := NetGame.new()
	parent.add_child(net)
	net.apply_event([NetGame.Event.PING, Vector3(1, 0, 2), Ping.Kind.MONSTER, 5.0])
	assert_eq((_marks()[0] as Ping).left, 5.0, "as long as the room's")
