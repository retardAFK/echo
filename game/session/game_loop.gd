class_name GameLoop
extends Node
## One game of the loop (spec S-007): puts the fuses in their boxes, counts the
## fuses the hunted found and placed, and keeps the numbers shown at the end
## (duration, noises made by the hunted, scans of the monster). The hunted is
## the player, or the AI prey when the player is the monster. GameMap adds it
## when the map has fuse boxes.

## The number of fuses found (carried or placed) or placed changed.
signal fuses_changed(found: int, placed: int)

@export var settings: LoopSettings

## Who looks for the fuses: the hunted player, or the AI prey.
var hunted: Node
var rules: LoopRules
## Noises made by the hunted since the start.
var noise_count := 0
## Scans started by the monster since the start.
var scan_count := 0
## The boxes that got a fuse this game.
var fused_boxes: Array = []

var _started_msec := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	rules = LoopRules.new(settings.fuse_count)
	_started_msec = Time.get_ticks_msec()
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


## Starts the game: draws the fuses among the boxes (Q1). A seed of 0 draws a
## new game each time; tests give a fixed one.
func setup(boxes: Array, buildings: Array, rng_seed := 0) -> void:
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	var by_building := {}
	for box: FuseBox in boxes:
		box.set_fuse(false)
		if not box.fuse_taken.is_connected(_on_fuse_taken):
			box.fuse_taken.connect(_on_fuse_taken)
		if not by_building.has(box.building_name):
			by_building[box.building_name] = []
		by_building[box.building_name].append(box)
	fused_boxes = LoopRules.draw_fuses(by_building, settings.fuse_count, _rng)
	for box: FuseBox in fused_boxes:
		box.set_fuse(true)
	for building: Building in buildings:
		building.scan_changed.connect(_on_scan_changed)
	fuses_changed.emit(rules.found(), rules.placed)


## Seconds since the start of the game.
func get_duration() -> float:
	return (Time.get_ticks_msec() - _started_msec) / 1000.0


func _on_fuse_taken(user: Node) -> void:
	if user != hunted:
		return
	rules.take_fuse()
	fuses_changed.emit(rules.found(), rules.placed)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if hunted != null and event.source == hunted:
		noise_count += 1


func _on_scan_changed(is_scanned: bool) -> void:
	if is_scanned:
		scan_count += 1
