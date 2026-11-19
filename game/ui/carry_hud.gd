class_name CarryHud
extends CanvasLayer
## What the hunted carries (spec S-008, Q11), in small at the bottom right:
## "2 bouteilles", "Réveil", "Pétard (F)" (S-020, T-312). Nothing when the hands are empty.

@export var player: Player

@onready var _label: Label = $Label


func _ready() -> void:
	player.inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_label.text = describe(player.inventory)


## The text for an inventory, one item kind per line.
static func describe(inventory: Inventory) -> String:
	var lines: PackedStringArray = []
	var bottles := inventory.count(Inventory.Kind.BOTTLE)
	if bottles == 1:
		lines.append(TranslationServer.translate("HUD_CARRY_BOTTLE"))
	elif bottles > 1:
		lines.append(TranslationServer.translate("HUD_CARRY_BOTTLES") % bottles)
	if inventory.count(Inventory.Kind.DECOY) > 0:
		lines.append(TranslationServer.translate("HUD_CARRY_DECOY"))
	if inventory.count(Inventory.Kind.FIRECRACKER) > 0:
		lines.append(Settings.fill(TranslationServer.translate("HUD_CARRY_FIRECRACKER")))
	return "\n".join(lines)
