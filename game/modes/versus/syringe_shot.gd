class_name SyringeShot
extends RefCounted
## The adrenaline syringe (spec S-025, T-414): a tool found in chests that a
## downed hunted uses on itself. Its player presses the tool's key (an AI
## prey uses it at once); after syringe_time it stands up alone, as if a
## teammate had revived it (one revive used), and the syringe is spent. If
## the boss finishes it first, the syringe is kept for nothing. HunterKit
## holds one and updates it while it is down; KitPrompts shows it.
## To remove it: the syringe's line in items of versus_settings.tres.

const ID := &"syringe"

## Seconds left of the injection under way, or -1.0 for none.
var left := -1.0


## The tool slot holding a syringe, or -1.
static func slot_of(kit: HunterKit) -> int:
	for slot in VersusLoadout.TOOL_SLOTS:
		var item := kit.loadout.tool_in(slot)
		if item != null and item.id == ID:
			return slot
	return -1


## Whether an injection is under way.
func is_going() -> bool:
	return left >= 0.0


## How far the injection is, from 0 to 1.
func ratio(settings: VersusSettings) -> float:
	if not is_going():
		return 0.0
	return clampf(1.0 - left / settings.syringe_time, 0.0, 1.0)


## One frame of kit while it is down: starts the injection on its key,
## then gets it up once done.
func update(kit: HunterKit, delta: float) -> void:
	var slot := slot_of(kit)
	if not kit.vitals.is_down() or slot < 0:
		left = -1.0
		return
	if not is_going():
		if _wants(kit, slot):
			left = kit.mode.settings.syringe_time
		return
	left -= delta
	if left > 0.0:
		return
	left = -1.0
	if kit.vitals.revive():
		kit.loadout.spend(slot)


static func _wants(kit: HunterKit, slot: int) -> bool:
	if not kit.is_played():
		return true  # An AI prey: at once.
	var flag := PlayerCommands.FLAG_TOOL_1 if slot == 0 else PlayerCommands.FLAG_TOOL_2
	return kit.keys.pressed(flag)
