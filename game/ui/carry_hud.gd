class_name CarryHud
extends CanvasLayer
## What the hunted carries (spec S-008, Q11), in small at the bottom right:
## "2 bouteilles", "Réveil : 15 s (molette)", "Pétard (F)", "Fil à canettes (T)" (S-020). Nothing
## when the hands are empty.

@export var player: Player

var _shown_short := false

@onready var _label: Label = $Label


func _ready() -> void:
	player.inventory.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if player.decoy_short != _shown_short:
		_refresh()  # The delay chosen with the mouse wheel (T-313).


func _refresh() -> void:
	_shown_short = player.decoy_short
	_label.text = describe(player.inventory, _shown_short)


## The text for an inventory, one item kind per line.
## With short, the alarm clock is set to its short delay (S-020, T-313).
static func describe(inventory: Inventory, short := false) -> String:
	var lines: PackedStringArray = []
	var bottles := inventory.count(Inventory.Kind.BOTTLE)
	if bottles > 0:
		lines.append(Text.count("HUD_CARRY_BOTTLES", bottles))
	if inventory.count(Inventory.Kind.DECOY) > 0:
		var settings := inventory.settings
		var delay := settings.decoy_short_delay if short else settings.decoy_delay
		lines.append(Text.t("HUD_CARRY_DECOY", roundi(delay)))
	if inventory.count(Inventory.Kind.FIRECRACKER) > 0:
		lines.append(Text.with_keys("HUD_CARRY_FIRECRACKER"))
	if inventory.count(Inventory.Kind.CAN_WIRE) > 0:
		lines.append(Text.with_keys("HUD_CARRY_CAN_WIRE"))
	return "\n".join(lines)
