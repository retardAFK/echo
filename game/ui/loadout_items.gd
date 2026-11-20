class_name LoadoutItems
extends RefCounted
## The two menu entries that pick the hunted's gadgets (spec S-023, Q3,
## T-352): "GADGET 1 : PÉTARD", "GADGET 2 : FUMIGÈNE". Choosing one moves it
## to the next gadget of the list that the other slot does not hold, and
## saves the pick in the settings. Shared by the solo role choice and the
## online waiting room, which only add KEYS to their MenuList.

const KEYS: Array[String] = ["MENU_GADGET_1", "MENU_GADGET_2"]


## Writes the gadget picked on each entry of list.
static func refresh(list: MenuList) -> void:
	var ids := Settings.get_loadout()
	for slot in KEYS.size():
		var entry := list.item(KEYS[slot])
		if entry == null:
			continue
		entry.visible = slot < ids.size()
		if slot < ids.size():
			var gadget_def := GadgetList.default().by_id(ids[slot])
			entry.text = Text.t(KEYS[slot], Text.t(gadget_def.name_key)).to_upper()


## Handles the choice of an entry of list: true if it was a gadget entry.
static func choose(list: MenuList, key: String) -> bool:
	var slot := KEYS.find(key)
	if slot < 0:
		return false
	Settings.set_loadout(Loadout.cycled(Settings.get_loadout(), slot))
	refresh(list)
	return true


## What the gadget on the entry key does, or "" if key is not a gadget entry.
static func help(key: String) -> String:
	var slot := KEYS.find(key)
	var ids := Settings.get_loadout()
	if slot < 0 or slot >= ids.size():
		return ""
	return Text.t(GadgetList.default().by_id(ids[slot]).help_key)
