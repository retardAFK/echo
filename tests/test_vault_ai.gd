extends GutTest
## The AIs take the windows and low walls (spec S-020, T-340, piste E6,
## validated by Maxime on 20/11/2026): navigation links across each passage
## of the cité, at the cost of each side's climbing time, and the AI monster
## and prey climb when their path goes over one.

const CITE_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const GREYBOX_SCENE := preload("res://game/maps/greybox_test.tscn")
const VAULT_SCENE := preload("res://game/entities/vault/vault.tscn")
const SETTINGS := preload("res://game/data/vault_settings.tres")


func test_links_cost_the_climbing_time_of_each_side() -> void:
	var vault: Vault = VAULT_SCENE.instantiate()
	add_child_autofree(vault)
	var monster: NavigationLink3D = vault.get_node("Link%d" % Vault.MONSTER_LAYER)
	var hunted: NavigationLink3D = vault.get_node("Link%d" % Vault.HUNTED_LAYER)
	assert_eq(monster.navigation_layers, 1 << (Vault.MONSTER_LAYER - 1))
	assert_eq(hunted.navigation_layers, 1 << (Vault.HUNTED_LAYER - 1))
	assert_eq(monster.enter_cost, SETTINGS.monster_link_cost)
	assert_eq(hunted.enter_cost, SETTINGS.hunted_link_cost)
	assert_gt(monster.enter_cost, hunted.enter_cost, "the monster is slower over")
	assert_true(monster.bidirectional and hunted.bidirectional)


func test_across_finds_the_passage_between_two_path_points() -> void:
	var vault: Vault = VAULT_SCENE.instantiate()
	add_child_autofree(vault)
	var tree := get_tree()
	assert_eq(Vault.across(tree, Vector3(0, 0, -1), Vector3(0, 0, 1)), vault, "over it")
	assert_null(Vault.across(tree, Vector3(0, 0, -1), Vector3(0.5, 0, -2)), "same side")
	assert_null(Vault.across(tree, Vector3(0, 0, -3), Vector3(0, 0, 1)), "out of reach")
	assert_null(Vault.across(tree, Vector3(0, 0, -1), Vector3(4, 0, 1)), "past its end")


## Without the links, each passage of the cité is a wall: the way around is
## long. With them, both sides of the hunt go straight over.
func test_every_passage_of_the_cite_is_a_shortcut_for_both_sides() -> void:
	var map: Node = CITE_SCENE.instantiate()
	add_child_autofree(map)
	var nav_map := (map as Node3D).get_world_3d().navigation_map
	var probe := (PlacementCheck.vaults(map)[0] as Node3D).global_position
	for i in 300:  # The navigation server syncs its map in the background.
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
			continue
		if NavigationServer3D.map_get_closest_point(nav_map, probe) != Vector3.ZERO:
			break
	var vaults := PlacementCheck.vaults(map)
	assert_eq(vaults.size(), 10)
	for vault in vaults:
		var away := vault.thickness / 2.0 + SETTINGS.landing_distance + 0.3
		var a := vault.to_global(Vector3(0, 0, -away))
		var b := vault.to_global(Vector3(0, 0, away))
		var around := _length(NavigationServer3D.map_get_path(nav_map, a, b, true, 1))
		assert_gt(around, 4.0, "%s: no way through without it" % vault.name)
		for layer: int in [Vault.MONSTER_LAYER, Vault.HUNTED_LAYER]:
			var layers: int = 1 | (1 << (layer - 1))
			var path := NavigationServer3D.map_get_path(nav_map, a, b, true, layers)
			var ends := path.size() > 0 and path[-1].distance_to(b) < 0.6
			assert_true(ends, "%s, layer %d: reaches the far side" % [vault.name, layer])
			assert_lt(_length(path), 3.5, "%s, layer %d: straight over" % [vault.name, layer])


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## A passage across the AI's way, a meter ahead: it climbs over at its own pace.
func _block_the_way(body: Node3D, agent: NavigationAgent3D) -> Vault:
	var next := agent.get_next_path_position()
	var direction := next - body.global_position
	direction.y = 0.0
	direction = direction.normalized()
	var vault: Vault = VAULT_SCENE.instantiate()
	add_child_autofree(vault)
	vault.global_position = body.global_position + direction * 1.0
	vault.global_position.y = body.global_position.y
	vault.look_at(vault.global_position + direction, Vector3.UP)
	return vault


func test_the_ai_monster_climbs_over_in_its_time() -> void:
	var map: Node = GREYBOX_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	await wait_physics_frames(10)
	var agent: NavigationAgent3D = monster.get_node("NavigationAgent3D")
	assert_true(agent.get_navigation_layer_value(Vault.MONSTER_LAYER), "plans over passages")
	_block_the_way(monster, agent)
	await wait_physics_frames(30)
	assert_true(monster.vault_motion.is_active(), "getting over")
	assert_eq(monster.vault_motion.duration, SETTINGS.monster_time)


func test_the_ai_prey_climbs_over_in_its_time() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: Node = GREYBOX_SCENE.instantiate()
	add_child_autofree(map)
	var avatar: Node3D = map.get_node("MonsterAvatar")
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	avatar.global_position = Vector3(18, 0, -18)
	var prey: Prey = map.prey
	await wait_physics_frames(10)
	var agent: NavigationAgent3D = prey.get_node("NavigationAgent3D")
	assert_true(agent.get_navigation_layer_value(Vault.HUNTED_LAYER), "plans over passages")
	assert_false(agent.get_navigation_layer_value(Vault.MONSTER_LAYER), "not the monster's")
	_block_the_way(prey, agent)
	await wait_physics_frames(30)
	GameSession.role = GameSession.Role.HUNTED
	assert_true(prey.vault_motion.is_active(), "getting over")
	assert_eq(prey.vault_motion.duration, SETTINGS.hunted_time)
