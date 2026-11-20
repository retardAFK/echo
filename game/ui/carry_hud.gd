class_name CarryHud
extends CanvasLayer
## What the hunted carries (spec S-008, Q11), in small at the bottom right:
## "2 bouteilles", "Réveil : 15 s (molette)", and the gadgets picked, one per
## key (S-023, T-353): "Pétard ×2 (1)", "Fumigène ×1 (2)". Nothing when the
## hands are empty.

## HUD line of each gadget slot, with the key of the slot (S-023, T-353).
const SLOT_KEYS: Array[String] = ["HUD_CARRY_GADGET_1", "HUD_CARRY_GADGET_2"]

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
	_label.text = describe(player.inventory, _shown_short, player.loadout)


## The text for an inventory, one item kind per line.
## With short, the alarm clock is set to its short delay (S-020, T-313).
## The gadgets are those of loadout, in slot order with the key of the slot.
static func describe(
	inventory: Inventory, short := false, loadout: Array[StringName] = []
) -> String:
	var lines: PackedStringArray = []
	var bottles := inventory.count(Inventory.Kind.BOTTLE)
	if bottles > 0:
		lines.append(Text.count("HUD_CARRY_BOTTLES", bottles))
	if inventory.count(Inventory.Kind.DECOY) > 0:
		var settings := inventory.settings
		var delay := settings.decoy_short_delay if short else settings.decoy_delay
		lines.append(Text.t("HUD_CARRY_DECOY", roundi(delay)))
	for slot in mini(loadout.size(), SLOT_KEYS.size()):
		var gadget_def := GadgetList.default().by_id(loadout[slot])
		var left := inventory.count(gadget_def.kind) if gadget_def != null else 0
		if left > 0:
			lines.append(Text.with_keys(SLOT_KEYS[slot], [Text.t(gadget_def.name_key), left]))
	return "\n".join(lines)
