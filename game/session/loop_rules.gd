class_name LoopRules
extends RefCounted
## Rules of the game loop (spec S-007), testable without a scene: where the
## fuses go, how many the hunted carries and placed, when the exit opens.
## Since S-018 (Q13) a game has objectives drawn at random: fuses, and maybe
## a code, a download and a relay; the exit opens once all are done.

## The kinds of objective (S-018, Q13).
enum Objective { FUSE, CODE, DOWNLOAD, RELAY }

## Fuses to place: the FUSE objectives of the game.
var fuse_count: int
## Every objective of the game, as drawn.
var objectives: Array[int] = []
## The objectives other than fuses not done yet.
var pending: Array[int] = []
## Fuses in the hunted's pockets.
var carried := 0
## Fuses placed in the transformer.
var placed := 0


func _init(p_fuse_count: int) -> void:
	fuse_count = p_fuse_count
	for i in fuse_count:
		objectives.append(Objective.FUSE)


## The objectives of a game: as many fuses to place as FUSE in it, and the
## others to do.
func set_objectives(kinds: Array) -> void:
	objectives.assign(kinds)
	fuse_count = kinds.count(Objective.FUSE)
	pending.assign(kinds.filter(func(kind: int) -> bool: return kind != Objective.FUSE))


## An objective other than fuses is done. Returns false if it was not to do.
func complete(kind: int) -> bool:
	if kind not in pending:
		return false
	pending.erase(kind)
	return true


## Whether the game has this objective and it is done.
func is_done(kind: int) -> bool:
	if kind == Objective.FUSE:
		return placed >= fuse_count
	return kind in objectives and kind not in pending


## Draws the objectives of a game (Q13): count of them, at least one fuse,
## never twice the same other kind, only among the kinds available (the map
## offers them and every AI hunted can do them). FUSE need not be listed.
static func draw_objectives(available: Array, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var drawn: Array[int] = [Objective.FUSE]
	var others := available.filter(func(kind: int) -> bool: return kind != Objective.FUSE)
	others.sort()
	while drawn.size() < count:
		var choices: Array = [Objective.FUSE] + others
		var kind: int = choices[rng.randi_range(0, choices.size() - 1)]
		drawn.append(kind)
		others.erase(kind)
	return drawn


## The two relay switches of a game (Q13): in two different buildings, at
## most max_distance apart. switches: [building name, position] each.
## Returns their indexes, or [] if no pair will do (the first pair without rng).
static func draw_relays(switches: Array, max_distance: float, rng: RandomNumberGenerator) -> Array:
	var pairs := []
	for i in switches.size():
		for j in range(i + 1, switches.size()):
			var a: Array = switches[i]
			var b: Array = switches[j]
			if a[0] != b[0] and (a[1] as Vector3).distance_to(b[1]) <= max_distance:
				pairs.append([i, j])
	if pairs.is_empty():
		return []
	return pairs[rng.randi_range(0, pairs.size() - 1)] if rng != null else pairs[0]


## Draws the fuse boxes that get a fuse (Q1): count different buildings, then
## one box in each. boxes_by_building maps a building name to its boxes.
static func draw_fuses(
	boxes_by_building: Dictionary, count: int, rng: RandomNumberGenerator
) -> Array:
	var names: Array = boxes_by_building.keys()
	names.sort()  # Same draw for the same seed, whatever the dictionary order.
	_shuffle(names, rng)
	var chosen := []
	for building_name: String in names.slice(0, count):
		var boxes: Array = boxes_by_building[building_name]
		if not boxes.is_empty():
			chosen.append(boxes[rng.randi_range(0, boxes.size() - 1)])
	return chosen


## Draws count items among these (S-008: the alarm clocks of a game).
static func draw(items: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var shuffled := items.duplicate()
	_shuffle(shuffled, rng)
	return shuffled.slice(0, count)


## Fuses found so far, carried or placed.
func found() -> int:
	return carried + placed


func take_fuse() -> void:
	carried += 1


## Places one carried fuse. Returns false if there was none to place.
func place_fuse() -> bool:
	if carried <= 0:
		return false
	carried -= 1
	placed += 1
	return true


## Fuses the transformer still waits for.
func missing() -> int:
	return maxi(fuse_count - placed, 0)


## Objectives done so far: each fuse placed, and each other objective done.
## The monster rises one stage per objective (S-023, Q5).
func done_count() -> int:
	return mini(placed, fuse_count) + objectives.size() - fuse_count - pending.size()


## Every objective done: the exit opens.
func is_repaired() -> bool:
	return placed >= fuse_count and pending.is_empty()


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
