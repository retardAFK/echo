class_name GadgetDef
extends Resource
## One gadget a hunted can carry (spec S-023, T-351): what it is called, what
## it counts as in the Inventory, the scene placed in the world, and the HUD
## line that shows it. The gadget's scene root script does the rest with
## deploy(user: Player) -> StringName (see docs/MODULES.md, "Ajouter un
## gadget"): it puts itself in the world and returns the ruse it counts as
## (Player.ruse_used), or &"" if it could not be used. GadgetUse calls it.
## Every gadget is listed in game/data/gadgets/gadgets.tres (GadgetList): the
## player, the HUD and the tests read that list, never a gadget by name.

## Short name, also the ruse it counts as by default: &"firecracker".
@export var id: StringName
## What it counts as in the hunted's Inventory.
@export var kind: Inventory.Kind = Inventory.Kind.FIRECRACKER
## The scene placed in the world; its root script has deploy(user: Player).
@export var scene: PackedScene
## Keys of game/i18n/strings.csv: its name ("Pétard"), and one sentence on
## what it does, shown when the hunted picks its gadgets.
@export var name_key := ""
@export var help_key := ""
