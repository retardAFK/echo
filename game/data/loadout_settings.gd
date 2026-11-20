class_name LoadoutSettings
extends Resource
## The gadgets a hunted takes into a game (spec S-023, Q2 to Q4, T-352):
## how many it picks, how many charges each, and what it takes when it picked
## nothing. Ids are those of game/data/gadgets/gadgets.tres (GadgetList).

## Gadgets a hunted picks before the game, one per key (gadget_1, gadget_2).
@export_range(1, 2) var slots: int = 2
## Charges of each gadget picked: 2 x 2 keeps the 4 uses of S-020 (1 of each).
@export_range(1, 5) var charges: int = 2
## What a hunted takes when it never picked, in slot order.
@export var default_gadgets: Array[StringName] = [&"firecracker", &"smoke"]
## What the AI hunted take: only gadgets their AI knows how to use count
## (the firecracker today, PreyBrain), the others fill the slots.
@export var ai_gadgets: Array[StringName] = [&"firecracker", &"smoke"]
