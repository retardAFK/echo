extends GutTest
## The list of gadgets (spec S-023, T-351): every gadget a hunted can carry is
## one GadgetDef in game/data/gadgets/gadgets.tres, and every one of them
## follows the same contract, so adding or removing a gadget touches no
## player, network or HUD code (docs/MODULES.md, "Ajouter un gadget").

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")


func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(1, 0.1, 2)
	return player


func test_the_list_has_the_four_gadgets_of_s020() -> void:
	var ids: Array[StringName] = []
	for gadget_def in GadgetList.default().gadgets:
		ids.append(gadget_def.id)
	assert_eq(ids, [&"firecracker", &"can_wire", &"walkman", &"smoke"] as Array[StringName])


func test_each_gadget_is_complete_and_unique() -> void:
	var kinds := {}
	for gadget_def in GadgetList.default().gadgets:
		assert_ne(gadget_def.id, &"", "an id")
		assert_not_null(gadget_def.scene, "%s: a scene" % gadget_def.id)
		assert_false(kinds.has(gadget_def.kind), "%s: its own inventory kind" % gadget_def.id)
		kinds[gadget_def.kind] = true
		assert_ne(Text.t(gadget_def.name_key), gadget_def.name_key, "%s: a name" % gadget_def.id)
		assert_ne(Text.t(gadget_def.help_key), gadget_def.help_key, "%s: a help" % gadget_def.id)
		var node := gadget_def.scene.instantiate()
		assert_true(node.has_method("deploy"), "%s: deploy(user)" % gadget_def.id)
		node.free()


func test_the_list_finds_a_gadget_by_kind_and_by_id() -> void:
	var gadgets := GadgetList.default()
	assert_eq(gadgets.by_kind(Inventory.Kind.WALKMAN).id, &"walkman")
	assert_eq(gadgets.by_id(&"smoke").kind, Inventory.Kind.SMOKE)
	assert_null(gadgets.by_kind(Inventory.Kind.BOTTLE), "a bottle is not a gadget")
	assert_null(gadgets.by_id(&"nothing"))


func test_the_player_uses_every_gadget_of_the_list() -> void:
	_floor()
	var player := _player()
	await wait_physics_frames(2)
	for gadget_def in GadgetList.default().gadgets:
		player.inventory.set_count(gadget_def.kind, 1)
		watch_signals(player)
		var gadget := GadgetUse.use(player, gadget_def.kind)
		assert_not_null(gadget, "%s is used" % gadget_def.id)
		if gadget == null:
			continue
		assert_true(gadget.is_inside_tree(), "%s is in the world" % gadget_def.id)
		assert_eq(player.inventory.count(gadget_def.kind), 0, "%s: one used" % gadget_def.id)
		assert_signal_emitted_with_parameters(player, "ruse_used", [gadget_def.id])
		assert_null(GadgetUse.use(player, gadget_def.kind), "%s: none left" % gadget_def.id)
		gadget.free()


func test_the_hud_shows_each_gadget_carried() -> void:
	var inventory := Inventory.new(preload("res://game/data/ruse_settings.tres"))
	for gadget_def in GadgetList.default().gadgets:
		inventory.set_count(gadget_def.kind, 0)
	assert_eq(CarryHud.describe(inventory), "")
	for gadget_def in GadgetList.default().gadgets:
		var picked: Array[StringName] = [gadget_def.id]
		inventory.set_count(gadget_def.kind, 1)
		assert_string_contains(
			CarryHud.describe(inventory, false, picked), Text.t(gadget_def.name_key) + " ×1"
		)
		assert_eq(CarryHud.describe(inventory), "", "a gadget not picked is not shown")
		inventory.set_count(gadget_def.kind, 0)
