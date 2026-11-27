extends GutTest
## The gun models of the Versus (spec S-025, T-409): the models, the arms of
## a hunted reaching for what it holds, the guns in the hunted's hands.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const HUNTED_BODY := preload("res://game/entities/hunted_body/hunted_body.tscn")
const GUNS: Array[StringName] = [
	&"light_smg", &"precision_rifle", &"sonic_shotgun", &"assault_rifle"
]

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func test_each_gun_has_a_model_with_a_glow() -> void:
	for id in GUNS:
		assert_true(GunModel.has_model(id), "%s has a model" % id)
		var gun := GunModel.instance(id, Color.GOLD) as MeshInstance3D
		assert_not_null(gun)
		add_child_autofree(gun)
		var glowing := 0
		for surface in gun.mesh.get_surface_count():
			var lit := gun.mesh.surface_get_material(surface) as StandardMaterial3D
			if lit != null and lit.resource_name == GunModel.GLOW_MATERIAL:
				glowing += 1
				assert_eq(lit.albedo_color, Color.GOLD, "the glow takes the rarity's color")
		assert_eq(glowing, 1, "one glowing material")
		assert_lt(GunModel.fore_grip(id).z, 0.0, "the left hand ahead of the right")
	assert_false(GunModel.has_model(&"uv_laser"), "the laser keeps its boxes")
	assert_null(GunModel.instance(&"uv_laser", Color.WHITE))


func test_the_elbow_bends_between_shoulder_and_wrist() -> void:
	var shoulder := Vector3(0.2, 1.4, 0.0)
	var goal := Vector3(0.2, 1.2, -0.35)
	var elbow := HoldPose.elbow_point(shoulder, goal, 0.25, 0.25, Vector3.DOWN)
	assert_almost_eq(elbow.distance_to(shoulder), 0.25, 0.001, "the upper arm keeps its length")
	assert_almost_eq(elbow.distance_to(goal), 0.25, 0.001, "and the forearm")
	assert_lt(elbow.y, (shoulder.y + goal.y) * 0.5, "bent down")
	var far := HoldPose.elbow_point(
		shoulder, shoulder + Vector3.FORWARD * 2.0, 0.25, 0.25, Vector3.DOWN
	)
	assert_almost_eq(far.distance_to(shoulder), 0.25, 0.001)
	assert_almost_eq(far.y, shoulder.y, 0.03, "straight towards a goal out of reach")


func test_a_hunted_body_holds_and_puts_away() -> void:
	var body: HuntedBody = HUNTED_BODY.instantiate()
	add_child_autofree(body)
	var gun := Node3D.new()
	body.hold(gun, Vector3(0, 0, -0.2))
	assert_eq(body.held, gun)
	assert_eq(gun.get_child_count(), 2, "the two wrists' places")
	body.show_state(PlayerMotion.Gait.WALK, 0.0, true)
	assert_false(gun.is_visible_in_tree(), "away while it kneels")
	body.show_state(PlayerMotion.Gait.WALK, 0.0, false)
	assert_true(gun.is_visible_in_tree())
	body.hold(null)
	assert_null(body.held)


func test_the_hunted_hold_the_gun_of_their_kit() -> void:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	var versus: VersusMode = map.get_node("VersusMode")
	var kit := versus.local_hunter()
	kit.equip(versus.item(&"precision_rifle", 3))
	await wait_process_frames(2)
	var shown := HeldGuns.body_of(kit.body)
	assert_not_null(shown, "the player's own body, seen in the third person")
	assert_not_null(shown.held, "the rifle in its hands")
	var mesh := (shown.held as MeshInstance3D).mesh
	var lit := mesh.surface_get_material(_glow_surface(mesh)) as StandardMaterial3D
	assert_eq(lit.albedo_color, versus.settings.rarities[3].color)
	versus.held_guns.apply(5, "sonic_shotgun", 2)
	assert_eq(
		versus.held_guns.events(),
		[[VersusNet.Event.GUN, 5, "sonic_shotgun", 2]],
		"what a joining player is told"
	)


func _glow_surface(mesh: Mesh) -> int:
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface).resource_name == GunModel.GLOW_MATERIAL:
			return surface
	return -1
