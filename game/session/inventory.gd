class_name Inventory
extends RefCounted
## What a hunted carries (spec S-008): bottles to throw (Q1) and alarm clocks
## to place (Q3), each up to a cap from RuseSettings. The player and the AI
## prey each have one.

signal changed

enum Kind { BOTTLE, DECOY }

var settings: RuseSettings

var _counts := {Kind.BOTTLE: 0, Kind.DECOY: 0}


func _init(p_settings: RuseSettings) -> void:
	settings = p_settings


func count(kind: Kind) -> int:
	return _counts[kind]


func capacity(kind: Kind) -> int:
	return settings.max_bottles if kind == Kind.BOTTLE else settings.max_decoys


func can_take(kind: Kind) -> bool:
	return count(kind) < capacity(kind)


## Adds one item if there is room. Returns whether it was taken.
func take(kind: Kind) -> bool:
	if not can_take(kind):
		return false
	_counts[kind] += 1
	changed.emit()
	return true


## Removes one item if there is any. Returns whether one was used.
func use(kind: Kind) -> bool:
	if count(kind) <= 0:
		return false
	_counts[kind] -= 1
	changed.emit()
	return true
