class_name LoopRules
extends RefCounted
## Rules of the game loop (spec S-007), testable without a scene: where the
## fuses go, how many the hunted carries and placed, when the exit opens.

var fuse_count: int
## Fuses in the hunted's pockets.
var carried := 0
## Fuses placed in the transformer.
var placed := 0


func _init(p_fuse_count: int) -> void:
	fuse_count = p_fuse_count


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


func is_repaired() -> bool:
	return placed >= fuse_count


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
