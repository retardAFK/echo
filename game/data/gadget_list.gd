class_name GadgetList
extends Resource
## Every gadget a hunted can carry (spec S-023, T-351), in the order the HUD
## shows them. The one list lives in game/data/gadgets/gadgets.tres: adding or
## removing a gadget is one GadgetDef .tres, its entity, and one line here
## (docs/MODULES.md, "Ajouter un gadget").

const PATH := "res://game/data/gadgets/gadgets.tres"

@export var gadgets: Array[GadgetDef] = []


## The list the game uses. Loaded, not preloaded: the gadgets' scripts use
## GadgetUse, which reads this list, and a preload would make a cycle.
static func default() -> GadgetList:
	return load(PATH)


## The gadget that counts as kind in the Inventory, or null.
func by_kind(kind: Inventory.Kind) -> GadgetDef:
	for gadget in gadgets:
		if gadget.kind == kind:
			return gadget
	return null


## The gadget called id, or null.
func by_id(id: StringName) -> GadgetDef:
	for gadget in gadgets:
		if gadget.id == id:
			return gadget
	return null
