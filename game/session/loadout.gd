class_name Loadout
extends RefCounted
## The gadgets a hunted picked for a game (spec S-023, Q2 to Q4, T-352), as
## gadget ids in slot order: slot 0 is used with the key gadget_1, slot 1 with
## gadget_2. Pure: the menus, the settings, the lobby, the player and the AI
## all go through it, so a loadout is always valid (known gadgets, no twice
## the same, exactly LoadoutSettings.slots of them).

const SETTINGS := preload("res://game/data/loadout_settings.tres")


## ids made valid: unknown or repeated ids dropped, cut to the number of
## slots, then filled with the default gadgets, then with the list's order.
static func sanitize(ids: Array, gadgets: GadgetList = null) -> Array[StringName]:
	if gadgets == null:
		gadgets = GadgetList.default()
	var kept: Array[StringName] = []
	var fill: Array = ids.duplicate()
	fill.append_array(SETTINGS.default_gadgets)
	for gadget_def in gadgets.gadgets:
		fill.append(gadget_def.id)
	for id: Variant in fill:
		var name := StringName(str(id))
		if kept.size() < SETTINGS.slots and gadgets.by_id(name) != null and not kept.has(name):
			kept.append(name)
	return kept


## The default loadout of a human, or of an AI hunted.
static func default_ids(ai := false) -> Array[StringName]:
	return sanitize(SETTINGS.ai_gadgets if ai else SETTINGS.default_gadgets)


## The Inventory kind of the gadget in a slot, or -1 for an empty slot.
static func kind_in(ids: Array[StringName], slot: int) -> int:
	if slot < 0 or slot >= ids.size():
		return -1
	var gadget_def := GadgetList.default().by_id(ids[slot])
	return gadget_def.kind if gadget_def != null else -1


## Gives inventory the charges of the gadgets in ids, and none of the others.
static func equip(inventory: Inventory, ids: Array[StringName]) -> void:
	for gadget_def in GadgetList.default().gadgets:
		inventory.set_count(gadget_def.kind, SETTINGS.charges if ids.has(gadget_def.id) else 0)


## The loadout with the gadget of slot changed to the next one of the list
## that the other slots do not hold (the menus cycle with it).
static func cycled(ids: Array[StringName], slot: int) -> Array[StringName]:
	var gadgets := GadgetList.default().gadgets
	var result := sanitize(ids)
	if slot < 0 or slot >= result.size():
		return result
	var start := 0
	for i in gadgets.size():
		if gadgets[i].id == result[slot]:
			start = i
	for step in range(1, gadgets.size()):
		var candidate: StringName = gadgets[(start + step) % gadgets.size()].id
		if not result.has(candidate):
			result[slot] = candidate
			break
	return result


## Places of the gadgets in the list, for the network (small and closed: a
## tampered client can only name gadgets that exist).
static func to_indexes(ids: Array[StringName]) -> Array[int]:
	var gadgets := GadgetList.default().gadgets
	var indexes: Array[int] = []
	for id in ids:
		for i in gadgets.size():
			if gadgets[i].id == id:
				indexes.append(i)
	return indexes


## What to_indexes() wrote, made valid.
static func from_indexes(indexes: Array) -> Array[StringName]:
	var gadgets := GadgetList.default().gadgets
	var ids: Array = []
	for index: Variant in indexes:
		var i := int(index) if (index is int or index is float) else -1
		if i >= 0 and i < gadgets.size():
			ids.append(gadgets[i].id)
	return sanitize(ids)
