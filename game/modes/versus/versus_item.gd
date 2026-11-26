class_name VersusItem
extends Resource
## A weapon or a tool of the Versus (spec S-024, Q13, Q29 to Q33, T-377),
## found in chests. A hunted carries one weapon (left click) and two tools
## (keys gadget_1 and gadget_2). One .tres per item in data/items/, listed
## in items of versus_settings.tres; HunterKit does what id says. To add an
## item: docs/MODULES.md, "Le mode Versus".

enum Slot { WEAPON, TOOL, AMMO }

## &"light_smg", &"uv_laser", &"sonic_cannon", &"medkit",
## &"firecracker", &"smoke", &"ammo".
@export var id: StringName
@export var slot := Slot.TOOL
## Key of its name in strings.csv.
@export var name_key := ""
## Uses of a tool (charges); shots a box of ammo gives.
@export_range(0, 60) var uses := 1
## How likely a chest of the start, then a chest of a new phase, holds it
## (0: never; the light machine gun is only in each hunted's first chest).
@export_range(0.0, 10.0, 0.5) var weight := 1.0
@export_range(0.0, 10.0, 0.5) var phase_weight := 1.0
## For the gadgets of the Traque used as Versus tools (firecracker, smoke):
## their Inventory.Kind, else -1.
@export var gadget_kind := -1
## For a gun (S-025, T-403): how it shoots, else null (the UV laser has
## its own beam, UvLaser).
@export var weapon: VersusWeapon
