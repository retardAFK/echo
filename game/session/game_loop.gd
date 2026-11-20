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

const DROPPED_FUSE_SCENE := preload("res://game/entities/fuse_box/dropped_fuse.tscn")
const CHASE_SETTINGS := preload("res://game/data/chase_settings.tres")

@export var settings: LoopSettings

## Who looks for the fuses: the hunted player, or the AI prey.
var hunted: Node
## Every hunted of the game (S-010, T-100), hunted included: any of them
## takes fuses, places those it carries, and wins for all by getting out.
## Set before the loop enters the tree; just [hunted] when left empty.
var team: Array[Node] = []
var rules: LoopRules
## Noises made by the hunted since the start.
var noise_count := 0
## Chases, escapes and mean distance for the end screen (S-020, T-322).
var chases: ChaseStats
## Scans started by the monster since the start.
var scan_count := 0
## Ruses used by the hunted since the start (S-008, Q11).
var ruse_count := 0
## The boxes that got a fuse this game.
var fused_boxes: Array = []
var transformer: Transformer
var gate: ExitGate
var exit_zone: ExitZone
## Seconds of siren left.
var siren_left := 0.0
var is_over := false
var hunted_won := false
## Online client (S-010, T-099): draws nothing and decides nothing; the room's
## loop sends its values (mirror_values) and this one shows them (apply_values).
var mirror := false
## Fuses dropped on the ground by captured hunted (T-107), still there.
var drops: Array[FuseBox] = []
## The objectives other than fuses this game may draw (S-018, Q13), among
## those the map offers. Empty: fuses only (settings.fuse_count of them).
var allowed: Array = []
## The objectives of the game, imposed (ECHO_OBJECTIVES, tests); else drawn.
var forced: Array = []
## The objectives other than fuses (S-018), null on a client.
var quests: Quests

## Game seconds since the start (see get_duration). An online client gets the
## room's once a second (S-020, T-300) and counts on its own in between.
var elapsed := 0.0
## Frames drawn and their time during the game, for the average frames per
## second of the summary (S-009, Q7).
var _frames := 0
var _frame_time := 0.0
var _siren_noise_left := 0.0
var _rng := RandomNumberGenerator.new()
## Fuses each hunted carries, when the team has several.
var _carried := {}
## Hunted out of the game (caught for good).
var _out: Array[Node] = []
## Every fuse box of the map.
var _boxes: Array = []
## Hunted captured and waiting for a teammate (S-010, T-107).
var _captured: Array[Node] = []
var _map: Node
var _exit_opened := false


func _ready() -> void:
	rules = LoopRules.new(settings.fuse_count)
	chases = ChaseStats.new(CHASE_SETTINGS)
	if not mirror:  # Clients copy the room's figures (NetWorld.clock()).
		var watch := ChaseWatch.new()
		watch.name = "ChaseWatch"
		watch.game_loop = self
		watch.settings = CHASE_SETTINGS
		add_child(watch)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	if team.is_empty() and hunted != null:
		team = [hunted]
	for member in team:
		if member.has_signal(&"ruse_used"):
			member.ruse_used.connect(_on_ruse_used)


## Adds a hunted to a loop already started (an extra AI prey, T-100).
func add_hunted(node: Node) -> void:
	if node in team:
		return
	team.append(node)
	if node.has_signal(&"ruse_used"):
		node.ruse_used.connect(_on_ruse_used)


## Online (T-102): an AI takes the place of a hunted who left, or the hunted
## comes back in the AI's place: the same fuses, captured or out the same.
func replace_hunted(old: Node, new: Node) -> void:
	var index := team.find(old)
	if index < 0:
		return
	team[index] = new
	if hunted == old:
		hunted = new
	if _carried.has(old):
		_carried[new] = _carried[old]
		_carried.erase(old)
	for list: Array[Node] in [_captured, _out]:
		var at := list.find(old)
		if at >= 0:
			list[at] = new
	if new.has_signal(&"ruse_used") and not new.ruse_used.is_connected(_on_ruse_used):
		new.ruse_used.connect(_on_ruse_used)


func is_hunted(node: Node) -> bool:
	return node != null and (node == hunted or node in team)


## Fuses a hunted carries. Alone, it carries all those found and not placed;
## on a client, the team's (the room decides who places them).
func carried_by(node: Node) -> int:
	if mirror or team.size() <= 1:
		return rules.carried if mirror or is_hunted(node) else 0
	return _carried.get(node, 0)


## A hunted is caught for good (T-100): the monster wins once none is free.
func hunted_out(node: Node) -> void:
	if not is_hunted(node) or node in _out:
		return
	_out.append(node)
	_captured.erase(node)
	chases.leave(node.get_instance_id())
	if free_count() <= 0:
		finish(false)
		return
	# Its fuses go back into the empty boxes nearest to where it was caught.
	for i in carried_by(node):
		var box := _nearest_empty_box((node as Node3D).global_position)
		if box == null:
			break
		box.set_fuse(true)
		rules.carried -= 1
		_carried[node] -= 1
	if quests != null:
		quests.drop_disk(node)
	fuses_changed.emit(rules.found(), rules.placed)


func _nearest_empty_box(at: Vector3) -> FuseBox:
	var best: FuseBox = null
	for box: FuseBox in _boxes:
		if box.has_fuse:
			continue
		if (
			best == null
			or box.global_position.distance_to(at) < best.global_position.distance_to(at)
		):
			best = box
	return best


## Hunted still in the game, neither out nor captured.
func free_count() -> int:
	return team.size() - _out.size() - _captured.size()


## Online (S-010, T-107): a hunted captured on its knees, or freed by a
## teammate. The monster wins once none is free.
func set_captured(node: Node, captured: bool) -> void:
	if not is_hunted(node) or node in _out or (node in _captured) == captured:
		return
	if not captured:
		_captured.erase(node)
		return
	_captured.append(node)
	drop_fuses(node)
	if free_count() <= 0:
		finish(false)


func is_captured(node: Node) -> bool:
	return node in _captured


## The fuses a hunted carries fall at its feet (T-107): any hunted picks them
## up again, like from a fuse box.
func drop_fuses(node: Node) -> void:
	if quests != null:
		quests.drop_disk(node)
	var count := carried_by(node)
	if count <= 0 or _map == null:
		return
	var at := (node as Node3D).global_position
	for i in count:
		var drop := spawn_drop(at + Vector3(0.3 * i, 0.0, 0.0))
		drop.fuse_taken.connect(_on_fuse_taken)
		drop.fuse_taken.connect(_on_drop_taken.bind(drop))
		rules.carried -= 1
		if _carried.has(node):
			_carried[node] -= 1
	fuses_changed.emit(rules.found(), rules.placed)


## A fuse lying on the ground at a point (on a client, a copy of the room's).
func spawn_drop(at: Vector3) -> FuseBox:
	var drop: FuseBox = DROPPED_FUSE_SCENE.instantiate()
	drop.has_fuse = true
	_map.add_child(drop)
	drop.global_position = at
	drops.append(drop)
	return drop


## Where the dropped fuses still lie.
func drop_positions() -> Array:
	return drops.map(func(drop: FuseBox) -> Vector3: return drop.global_position)


## Client side: the dropped fuses are those of the room.
func apply_drops(positions: Array) -> void:
	for drop in drops.duplicate():
		if not positions.any(
			func(at: Vector3) -> bool: return at.is_equal_approx(drop.global_position)
		):
			_remove_drop(drop)
	for at: Vector3 in positions:
		if not drops.any(
			func(drop: FuseBox) -> bool: return at.is_equal_approx(drop.global_position)
		):
			spawn_drop(at)


func _on_drop_taken(_user: Node, drop: FuseBox) -> void:
	_remove_drop(drop)


func _remove_drop(drop: FuseBox) -> void:
	drops.erase(drop)
	if is_instance_valid(drop):
		drop.queue_free()


## Starts the game on a map: draws the fuses among its boxes (Q1) and wires
## the transformer, the exit and the scans. A seed of 0 draws a new game each
## time; tests give a fixed one.
func setup(map: Node, rng_seed := 0) -> void:
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	var by_building := {}
	_map = map
	_boxes = _all(map, FuseBox)
	if mirror:
		_add_quests()
		_wire(map)
		fuses_changed.emit(rules.found(), rules.placed)
		return
	for box: FuseBox in _all(map, FuseBox):
		box.set_fuse(false)
		if not box.fuse_taken.is_connected(_on_fuse_taken):
			box.fuse_taken.connect(_on_fuse_taken)
		if not by_building.has(box.building_name):
			by_building[box.building_name] = []
		by_building[box.building_name].append(box)
	_draw_objectives(map)
	fused_boxes = LoopRules.draw_fuses(by_building, rules.fuse_count, _rng)
	for box: FuseBox in fused_boxes:
		box.set_fuse(true)
	_draw_decoys(map)
	for building: Building in _all(map, Building):
		building.scan_changed.connect(_on_scan_changed)
	_wire(map)
	var zones: Array = _all(map, ExitZone)
	if not zones.is_empty():
		exit_zone = zones[0]
		exit_zone.reached.connect(_on_exit_reached)
	fuses_changed.emit(rules.found(), rules.placed)


## The objectives of the game (S-018, Q13): imposed, or drawn among those
## allowed; only those the map offers; fuses only when none is.
func _draw_objectives(map: Node) -> void:
	var offered := Quests.offered_by(map, settings) + [LoopRules.Objective.FUSE]
	var kinds: Array = forced.filter(func(kind: int) -> bool: return kind in offered)
	if kinds.is_empty():
		var drawable := allowed.filter(func(kind: int) -> bool: return kind in offered)
		if drawable.is_empty():
			return  # settings.fuse_count fuses, as before S-018.
		kinds = LoopRules.draw_objectives(drawable, settings.objectives_per_game, _rng)
	rules.set_objectives(kinds)
	_add_quests()
	quests.setup(map, rules, _rng)


## The node of the objectives besides fuses; on a client, it shows the
## room's (T-267).
func _add_quests() -> void:
	quests = Quests.new()
	quests.name = "Quests"
	quests.settings = settings
	quests.rules = rules
	quests.mirror = mirror
	quests.map_node = _map
	add_child(quests)
	quests.changed.connect(_on_quests_changed)


func _on_quests_changed() -> void:
	fuses_changed.emit(rules.found(), rules.placed)
	if transformer != null:
		transformer.update_label()
	if rules.is_repaired():
		_open_exit()


## Parses an imposed list of objectives, such as "fuse,code,download,relay".
static func parse_objectives(text: String) -> Array:
	var kinds := []
	for word in text.to_lower().split(",", false):
		var kind: int = LoopRules.Objective.keys().find(word.strip_edges().to_upper())
		if kind >= 0:
			kinds.append(kind)
	return kinds


## The transformer and the gate of the map.
func _wire(map: Node) -> void:
	var found: Array = _all(map, Transformer)
	if not found.is_empty():
		transformer = found[0]
		transformer.game_loop = self
		transformer.update_label()
	found = _all(map, ExitGate)
	if not found.is_empty():
		gate = found[0]


## Game seconds since the start, frozen when it ends. Counted from the
## physics frames, so a pause (S-009, Q6) does not count.
func get_duration() -> float:
	return elapsed


func is_exit_open() -> bool:
	return rules.is_repaired()


## Places one fuse carried by user in the transformer (any of them when
## user is null or plays alone). The third one opens the exit.
func place_fuse(user: Node = null) -> void:
	if team.size() > 1 and user != null:
		if carried_by(user) <= 0:
			return
		_carried[user] -= 1
	if not rules.place_fuse():
		return
	fuses_changed.emit(rules.found(), rules.placed)
	if rules.is_repaired():
		_open_exit()


## Room side: what a client's mirror loop needs, see apply_values(). The game
## time and the counts of the end screen are not in it: they change with
## every frame or every footstep, and go with NetWorld.clock once a second
## (S-020, T-301).
func mirror_values() -> Array:
	return [rules.carried, rules.placed, is_over, hunted_won]


## Client side: shows the room's loop: fuses, transformer, siren and exit,
## the numbers of the end screen, and the end itself.
func apply_values(values: Array) -> void:
	if values.size() < 4:
		return
	var was_repaired := rules.is_repaired()
	if values[0] != rules.carried or values[1] != rules.placed:
		rules.carried = values[0]
		rules.placed = values[1]
		fuses_changed.emit(rules.found(), rules.placed)
		if transformer != null:
			transformer.update_label()
	if rules.is_repaired() and not was_repaired:
		_open_exit()
	if values[2] and not is_over:
		finish(values[3])


## Ends the game once: the hunted won (got out) or lost (caught).
func finish(won: bool) -> void:
	if is_over:
		return
	is_over = true
	hunted_won = won
	chases.finish(won)
	ended.emit(won)


func _process(delta: float) -> void:
	if not is_over:
		_frames += 1
		_frame_time += delta


## Average frames per second during the game, 0 before the first frame.
func get_average_fps() -> float:
	return _frames / _frame_time if _frame_time > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if not is_over:
		elapsed += delta
	if siren_left <= 0.0:
		return
	siren_left -= delta
	_siren_noise_left -= delta
	if _siren_noise_left <= 0.0:
		_siren_noise_left = settings.siren_noise_interval
		var at := transformer.global_position + Vector3.UP * 2.0
		NoiseBus.emit_noise(NoiseEvent.Type.SIREN, at, settings.siren_range, transformer)


func _open_exit() -> void:
	if _exit_opened:
		return
	_exit_opened = true
	if transformer != null:
		siren_left = settings.siren_time
		_siren_noise_left = 0.0
		transformer.start_siren()
	if gate != null:
		gate.open()
	exit_opened.emit()


func _on_exit_reached(body: Node3D) -> void:
	if is_hunted(body) and body not in _out and body not in _captured and is_exit_open():
		finish(true)


func _on_fuse_taken(user: Node) -> void:
	if not is_hunted(user):
		return
	_carried[user] = _carried.get(user, 0) + 1
	rules.take_fuse()
	fuses_changed.emit(rules.found(), rules.placed)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if is_hunted(event.source) and not is_over:
		noise_count += 1


func _on_ruse_used(_kind: StringName) -> void:
	if not is_over:
		ruse_count += 1


func _on_scan_changed(is_scanned: bool) -> void:
	if is_scanned and not is_over:
		scan_count += 1


## Keeps decoys_per_game alarm clocks among their places, takes the others
## away (S-008, Q3).
func _draw_decoys(map: Node) -> void:
	var decoys := _all(map, Pickup).filter(
		func(pickup: Pickup) -> bool: return pickup.kind == Inventory.Kind.DECOY
	)
	if decoys.is_empty():
		return
	decoys.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	var kept := LoopRules.draw(decoys, decoys[0].settings.decoys_per_game, _rng)
	for decoy: Pickup in decoys:
		if decoy not in kept:
			decoy.get_parent().remove_child(decoy)
			decoy.queue_free()


static func _all(map: Node, type: Variant) -> Array:
	return map.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return is_instance_of(node, type)
	)
