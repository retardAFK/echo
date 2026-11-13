class_name LobbyRegistry
extends RefCounted
## Which room slot holds which game code (S-010, T-094). Pure bookkeeping,
## used by the lobby server.

var _codes: Array[String] = []


func _init(max_rooms: int) -> void:
	_codes.resize(max_rooms)
	_codes.fill("")


## Takes a free slot for a new game and returns it (from 1) with its code,
## as [slot, code], or [] if every slot is busy.
func open(rng: RandomNumberGenerator) -> Array:
	var free := _codes.find("")
	if free < 0:
		return []
	var code := RoomCode.generate(rng, _codes)
	_codes[free] = code
	return [free + 1, code]


## The slot (from 1) of a code, or 0 if no game has it.
func find(code: String) -> int:
	return _codes.find(code) + 1 if code != "" else 0


## Frees a slot when its room has stopped.
func close(slot: int) -> void:
	if slot >= 1 and slot <= _codes.size():
		_codes[slot - 1] = ""


func code_of(slot: int) -> String:
	return _codes[slot - 1]


func open_count() -> int:
	return _codes.size() - _codes.count("")
