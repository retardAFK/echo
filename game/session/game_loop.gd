class_name GameLoop
extends Node
## One game of the loop (spec S-007): puts the fuses in their boxes, counts the
## fuses the hunted found and placed, wails the siren and opens the exit once
## the transformer is repaired, and says when the game ends. It also keeps the
## numbers shown at the end (duration, noises made by the hunted, scans of the
## monster). The hunted is the player, or the AI prey when the player is the
## monster. GameMap adds it when the map has fuse boxes.

## The number of fuses found (carried or placed) or placed changed.
signal fuses_changed(found: int, placed: int)
## The transformer is repaired: the siren wails and the exit opens (Q4).
signal exit_opened
## The game is over: the hunted got out (won) or was caught.
signal ended(hunted_won: bool)

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
var transformer: Transformer
var gate: ExitGate
var exit_zone: ExitZone
## Seconds of siren left.
var siren_left := 0.0
var is_over := false
var hunted_won := false

var _started_msec := 0
var _ended_msec := 0
var _siren_noise_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	rules = LoopRules.new(settings.fuse_count)
	_started_msec = Time.get_ticks_msec()
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


## Starts the game on a map: draws the fuses among its boxes (Q1) and wires
## the transformer, the exit and the scans. A seed of 0 draws a new game each
## time; tests give a fixed one.
func setup(map: Node, rng_seed := 0) -> void:
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	var by_building := {}
	for box: FuseBox in _all(map, FuseBox):
		box.set_fuse(false)
		if not box.fuse_taken.is_connected(_on_fuse_taken):
			box.fuse_taken.connect(_on_fuse_taken)
		if not by_building.has(box.building_name):
			by_building[box.building_name] = []
		by_building[box.building_name].append(box)
	fused_boxes = LoopRules.draw_fuses(by_building, settings.fuse_count, _rng)
	for box: FuseBox in fused_boxes:
		box.set_fuse(true)
	for building: Building in _all(map, Building):
		building.scan_changed.connect(_on_scan_changed)
	var found: Array = _all(map, Transformer)
	if not found.is_empty():
		transformer = found[0]
		transformer.game_loop = self
		transformer.update_label()
	found = _all(map, ExitGate)
	if not found.is_empty():
		gate = found[0]
	found = _all(map, ExitZone)
	if not found.is_empty():
		exit_zone = found[0]
		exit_zone.reached.connect(_on_exit_reached)
	fuses_changed.emit(rules.found(), rules.placed)


## Seconds since the start of the game, frozen when it ends.
func get_duration() -> float:
	var now := _ended_msec if is_over else Time.get_ticks_msec()
	return (now - _started_msec) / 1000.0


func is_exit_open() -> bool:
	return rules.is_repaired()


## Places one carried fuse in the transformer. The third one opens the exit.
func place_fuse() -> void:
	if not rules.place_fuse():
		return
	fuses_changed.emit(rules.found(), rules.placed)
	if rules.is_repaired():
		_open_exit()


## Ends the game once: the hunted won (got out) or lost (caught).
func finish(won: bool) -> void:
	if is_over:
		return
	is_over = true
	hunted_won = won
	_ended_msec = Time.get_ticks_msec()
	ended.emit(won)


func _physics_process(delta: float) -> void:
	if siren_left <= 0.0:
		return
	siren_left -= delta
	_siren_noise_left -= delta
	if _siren_noise_left <= 0.0:
		_siren_noise_left = settings.siren_noise_interval
		var at := transformer.global_position + Vector3.UP * 2.0
		NoiseBus.emit_noise(NoiseEvent.Type.SIREN, at, settings.siren_range, transformer)


func _open_exit() -> void:
	if transformer != null:
		siren_left = settings.siren_time
		_siren_noise_left = 0.0
	if gate != null:
		gate.open()
	exit_opened.emit()


func _on_exit_reached(body: Node3D) -> void:
	if body == hunted and is_exit_open():
		finish(true)


func _on_fuse_taken(user: Node) -> void:
	if user != hunted:
		return
	rules.take_fuse()
	fuses_changed.emit(rules.found(), rules.placed)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if hunted != null and event.source == hunted and not is_over:
		noise_count += 1


func _on_scan_changed(is_scanned: bool) -> void:
	if is_scanned and not is_over:
		scan_count += 1


static func _all(map: Node, type: Variant) -> Array:
	return map.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return is_instance_of(node, type)
	)
