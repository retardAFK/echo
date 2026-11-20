class_name Inventory
extends RefCounted
## What a hunted carries (spec S-008): bottles to throw (Q1) and alarm clocks
## to place (Q3), a firecracker (S-020, T-312), a can wire (T-333), a walkman
## (T-334), a smoke bomb (T-335), each up to a cap from RuseSettings. The player and the AI
## prey each have one.

signal changed

enum Kind { BOTTLE, DECOY, FIRECRACKER, CAN_WIRE, WALKMAN, SMOKE }

var settings: RuseSettings

var _counts := {
	Kind.BOTTLE: 0,
	Kind.DECOY: 0,
	Kind.FIRECRACKER: 0,
	Kind.CAN_WIRE: 0,
	Kind.WALKMAN: 0,
	Kind.SMOKE: 0
}


func _init(p_settings: RuseSettings) -> void:
	settings = p_settings
	_counts[Kind.FIRECRACKER] = settings.start_firecrackers  # One per game.
	_counts[Kind.CAN_WIRE] = settings.start_can_wires  # One per game too.
	_counts[Kind.WALKMAN] = settings.start_walkmen  # T-334.
	_counts[Kind.SMOKE] = settings.start_smoke_bombs  # T-335.


func count(kind: Kind) -> int:
	return _counts[kind]


func capacity(kind: Kind) -> int:
	match kind:
		Kind.BOTTLE:
			return settings.max_bottles
		Kind.DECOY:
			return settings.max_decoys
		Kind.CAN_WIRE:
			return settings.max_can_wires
		Kind.WALKMAN:
			return settings.max_walkmen
		Kind.SMOKE:
			return settings.max_smoke_bombs
	return settings.max_firecrackers


func can_take(kind: Kind) -> bool:
	return count(kind) < capacity(kind)


## Adds one item if there is room. Returns whether it was taken.
func take(kind: Kind) -> bool:
	if not can_take(kind):
		return false
	_counts[kind] += 1
	changed.emit()
	return true


## Sets how many items of a kind are carried, as the room says (S-010, T-099).
func set_count(kind: Kind, value: int) -> void:
	value = clampi(value, 0, capacity(kind))
	if value != _counts[kind]:
		_counts[kind] = value
		changed.emit()


## Removes one item if there is any. Returns whether one was used.
func use(kind: Kind) -> bool:
	if count(kind) <= 0:
		return false
	_counts[kind] -= 1
	changed.emit()
	return true
