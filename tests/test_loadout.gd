extends GutTest
## The 2 gadgets a hunted picks before the game (spec S-023, Q2 to Q4, T-352,
## T-353): Loadout, the settings that keep it, the lobby that carries it and
## the keys 1 and 2 that use it.

const TEST_PATH := "user://test_loadout.cfg"
const SETTINGS := preload("res://game/data/ruse_settings.tres")

var _saved_path := ""


func before_each() -> void:
	_saved_path = Settings.path
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.load_file()


func after_each() -> void:
	Settings.reset()
	DirAccess.remove_absolute(TEST_PATH)
	Settings.path = _saved_path
	Settings.load_file()


func test_the_settings_follow_the_spec() -> void:
	assert_eq(Loadout.SETTINGS.slots, 2)
	assert_eq(Loadout.SETTINGS.charges, 2)
	assert_eq(Loadout.default_ids(), [&"firecracker", &"smoke"] as Array[StringName])
	assert_eq(Loadout.default_ids(true).size(), 2, "the AI hunted picks too")


func test_a_loadout_is_always_valid() -> void:
	assert_eq(Loadout.sanitize([]), Loadout.default_ids(), "nothing picked: the default")
	assert_eq(
		Loadout.sanitize([&"walkman", &"walkman", &"nothing"]),
		[&"walkman", &"firecracker"] as Array[StringName],
		"no unknown, no twice the same, filled from the default"
	)
	assert_eq(Loadout.sanitize(["can_wire", "smoke", "walkman"]).size(), 2, "cut to the slots")


func test_cycling_a_slot_skips_the_other_slot() -> void:
	var ids: Array[StringName] = [&"firecracker", &"can_wire"]
	assert_eq(Loadout.cycled(ids, 0), [&"walkman", &"can_wire"] as Array[StringName])
	assert_eq(Loadout.cycled(ids, 1), [&"firecracker", &"walkman"] as Array[StringName])
	var seen := {}
	for i in GadgetList.default().gadgets.size():
		ids = Loadout.cycled(ids, 0)
		seen[ids[0]] = true
	assert_eq(seen.size(), GadgetList.default().gadgets.size() - 1, "every gadget but slot 2's")


func test_the_network_form_round_trips_and_resists_tampering() -> void:
	var ids: Array[StringName] = [&"smoke", &"walkman"]
	assert_eq(Loadout.from_indexes(Loadout.to_indexes(ids)), ids)
	assert_eq(Loadout.from_indexes([99, -1, "x", 2.0]).size(), 2, "always a valid loadout")
	assert_eq(Loadout.from_indexes([99, -1, "x", 2.0])[0], &"walkman")


func test_equip_gives_charges_of_the_picked_gadgets_only() -> void:
	var inventory := Inventory.new(SETTINGS)
	Loadout.equip(inventory, [&"can_wire", &"walkman"] as Array[StringName])
	assert_eq(inventory.count(Inventory.Kind.CAN_WIRE), 2)
	assert_eq(inventory.count(Inventory.Kind.WALKMAN), 2)
	assert_eq(inventory.count(Inventory.Kind.FIRECRACKER), 0)
	assert_eq(inventory.count(Inventory.Kind.SMOKE), 0)
	assert_eq(
		Loadout.kind_in([&"can_wire", &"walkman"] as Array[StringName], 1), Inventory.Kind.WALKMAN
	)
	assert_eq(Loadout.kind_in([&"can_wire"] as Array[StringName], 1), -1, "an empty slot")


func test_the_pick_is_saved_in_the_settings() -> void:
	assert_eq(Settings.get_loadout(), Loadout.default_ids())
	Settings.set_loadout([&"walkman", &"can_wire"])
	Settings.load_file()
	assert_eq(Settings.get_loadout(), [&"walkman", &"can_wire"] as Array[StringName])
	Settings.reset()
	assert_eq(Settings.get_loadout(), Loadout.default_ids())


func test_the_lobby_carries_each_pick_to_the_room() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(1)
	lobby.add_player(2)
	lobby.set_loadout(2, [&"walkman", &"can_wire"])
	lobby.set_loadout(9, [&"walkman", &"can_wire"])  # Not in the room.
	assert_true(lobby.to_dict()["loadouts"].is_empty(), "never sent to the clients (Q4)")
	var copy := LobbyState.from_dict(lobby.to_dict(true))
	assert_eq(copy.loadout_of(2), [&"walkman", &"can_wire"] as Array[StringName])
	assert_eq(copy.loadout_of(1), Loadout.default_ids(), "nothing picked: the default")
	assert_false(copy.loadouts.has(9))
	lobby.remove_player(2)
	assert_false(lobby.loadouts.has(2), "gone with its player")
	lobby.set_ready(1, true)
	lobby.start(1)
	lobby.set_loadout(1, [&"smoke"])
	assert_eq(lobby.loadout_of(1), Loadout.default_ids(), "fixed once the game started")


func test_the_items_cycle_the_slots_through_the_settings() -> void:
	var list := MenuList.new()
	list.keys = PackedStringArray(LoadoutItems.KEYS)
	add_child_autofree(list)
	LoadoutItems.refresh(list)
	assert_string_contains(list.item("MENU_GADGET_1").text, "PÉTARD")
	assert_true(LoadoutItems.choose(list, "MENU_GADGET_2"))
	assert_eq(Settings.get_loadout(), Loadout.cycled(Loadout.default_ids(), 1))
	assert_false(LoadoutItems.choose(list, "MENU_BACK"), "not a gadget item")
	assert_ne(LoadoutItems.help("MENU_GADGET_1"), "")
