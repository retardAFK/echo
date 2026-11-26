class_name VersusLoadout
extends RefCounted
## What a Versus hunted carries (spec S-024, Q13, Q31, T-377): one weapon,
## two tools with their uses, and its spare flares. Pure, for tests.
## Taking an item from a chest gives back what goes into the chest instead:
## the old weapon, or the oldest tool when both slots are taken.

const TOOL_SLOTS := 2

var weapon: VersusItem
var tools: Array[VersusItem] = []
var uses: Array[int] = []
## Flares left besides those in the launcher.
var spare_flares := 0


## Takes item; returns what it leaves in the chest (null: nothing).
func take(item: VersusItem) -> VersusItem:
	match item.slot:
		VersusItem.Slot.WEAPON:
			var old := weapon
			weapon = item
			return old
		VersusItem.Slot.AMMO:
			spare_flares += item.uses
			return null
	var left: VersusItem
	if tools.size() >= TOOL_SLOTS:
		left = tools.pop_front()
		uses.pop_front()
	tools.append(item)
	uses.append(item.uses)
	return left


func has_weapon(id: StringName) -> bool:
	return weapon != null and weapon.id == id


## The tool in slot, or null.
func tool_in(slot: int) -> VersusItem:
	return tools[slot] if slot >= 0 and slot < tools.size() else null


## Spends a use of the tool in slot; true if there was one. An empty tool
## leaves its slot.
func spend(slot: int) -> bool:
	if tool_in(slot) == null or uses[slot] <= 0:
		return false
	uses[slot] -= 1
	if uses[slot] == 0:
		tools.remove_at(slot)
		uses.remove_at(slot)
	return true


## Takes up to wanted flares from the spares; returns how many.
func draw_flares(wanted: int) -> int:
	var given := mini(wanted, spare_flares)
	spare_flares -= given
	return given


## What a chest holds (Q31), drawn among items by weight, or phase_weight
## for the chests of a new phase.
static func draw(
	items: Array[VersusItem], rng: RandomNumberGenerator, phase := false
) -> VersusItem:
	var total := 0.0
	for item in items:
		total += item.phase_weight if phase else item.weight
	if total <= 0.0:
		return null
	var pick := rng.randf() * total
	for item in items:
		pick -= item.phase_weight if phase else item.weight
		if pick < 0.0:
			return item
	return items[-1]
