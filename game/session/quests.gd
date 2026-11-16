class_name Quests
extends Node
## The objectives of a game other than fuses (spec S-018, Q13), drawn by
## GameLoop among those the map offers:
## - CODE: 4 digits written on one post-it (CodeSpot) somewhere in the cité,
##   typed on the transformer's keypad (a CODE terminal). A wrong code beeps.
## - DOWNLOAD: a terminal of the network (drawn) offers a download. Started,
##   it runs download_time even if nobody stays, the disk scratching (a DISK
##   noise); switching the terminal off starts it over. A floppy disk then
##   lies by the terminal, taken like a fuse and placed at the transformer;
##   it falls where its carrier is captured.
## - RELAY: two relay switches in two buildings are armed; both must be
##   thrown within relay_window, else the first one clicks back.
## GameLoop adds it as a child and tells it what to draw (setup).

## An objective was done, or something shown changed.
signal changed

const GROUP := &"quests"
const DISK_SCENE := preload("res://game/entities/objectives/floppy_disk.tscn")
const CODE_LENGTH := 4

var settings: LoopSettings
var rules: LoopRules
## The code to type, "" when the game has none.
var code := ""
## The post-it showing it.
var code_spot: CodeSpot
## The terminal offering the download, or null.
var download_terminal: Terminal
## Seconds of download done, -1 before it starts.
var download_done := -1.0
## The floppy disk lying somewhere, or null.
var disk: FloppyDisk
## The hunted carrying the floppy disk, or null.
var disk_carrier: Node
## The two relay switches armed this game.
var relays: Array[RelaySwitch] = []

## What each keypad got so far: Terminal -> digits typed.
var _typed := {}
var _disk_noise_left := 0.0
## Seconds left to throw the second relay switch, 0 when none is down.
var _relay_left := 0.0
var _map: Node


static func of(node: Node) -> Quests:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Quests


func _ready() -> void:
	add_to_group(GROUP)


## The objectives the map offers besides fuses: a code if it has post-its
## and a keypad, a download if it has a plain terminal, a relay if two of
## its switches make a pair.
static func offered_by(map: Node, p_settings: LoopSettings) -> Array:
	var kinds := []
	if not _all(map, CodeSpot).is_empty() and not _terminals(map, Terminal.Kind.CODE).is_empty():
		kinds.append(LoopRules.Objective.CODE)
	if not _terminals(map, Terminal.Kind.NORMAL).is_empty():
		kinds.append(LoopRules.Objective.DOWNLOAD)
	var pair := LoopRules.draw_relays(_switch_places(map), p_settings.relay_max_distance, null)
	if not pair.is_empty():
		kinds.append(LoopRules.Objective.RELAY)
	return kinds


## Prepares the drawn objectives (rules.objectives) on the map.
func setup(map: Node, p_rules: LoopRules, rng: RandomNumberGenerator) -> void:
	_map = map
	rules = p_rules
	for spot: CodeSpot in _all(map, CodeSpot):
		spot.show_code("")
	if LoopRules.Objective.CODE in rules.objectives:
		for i in CODE_LENGTH:
			code += str(rng.randi_range(0, 9))
		var spots := _all(map, CodeSpot)
		code_spot = spots[rng.randi_range(0, spots.size() - 1)]
		code_spot.show_code(code)
	if LoopRules.Objective.DOWNLOAD in rules.objectives:
		var plain := _terminals(map, Terminal.Kind.NORMAL)
		download_terminal = plain[rng.randi_range(0, plain.size() - 1)]
	var switches := _all(map, RelaySwitch)
	if LoopRules.Objective.RELAY in rules.objectives:
		for i: int in LoopRules.draw_relays(_switch_places(map), settings.relay_max_distance, rng):
			relays.append(switches[i])
	for switch: RelaySwitch in switches:
		switch.armed = switch in relays
		if switch.armed and not switch.thrown.is_connected(_on_thrown):
			switch.thrown.connect(_on_thrown.bind(switch))


func wants_code() -> bool:
	return code != "" and not rules.is_done(LoopRules.Objective.CODE)


## The digits typed so far on a keypad.
func typed_on(terminal: Terminal) -> String:
	return _typed.get(terminal, "")


## A digit typed on a keypad: at the fourth, right or wrong (a beep).
func type_digit(terminal: Terminal, digit: int) -> void:
	if not wants_code():
		return
	var typed: String = typed_on(terminal) + str(digit)
	if typed.length() < CODE_LENGTH:
		_typed[terminal] = typed
		return
	_typed.erase(terminal)
	if typed == code:
		_complete(LoopRules.Objective.CODE)
	else:
		NoiseBus.emit_noise(
			NoiseEvent.Type.BEEP,
			terminal.global_position + Vector3.UP,
			settings.beep_range,
			terminal.user
		)
		changed.emit()


## Whether the terminal offers the download now: not started, or started
## over after the monster switched it off.
func offers_download(terminal: Terminal) -> bool:
	return terminal != null and terminal == download_terminal and download_done < 0.0


## The download from 0 to 1, -1 before it starts.
func download_ratio() -> float:
	return download_done / settings.download_time if download_done >= 0.0 else -1.0


func start_download(terminal: Terminal) -> void:
	if offers_download(terminal) and terminal.is_on():
		download_done = 0.0
		_disk_noise_left = 0.0


## A hunted carries the floppy disk.
func carries_disk(user: Node) -> bool:
	return user != null and user == disk_carrier


## The floppy disk is placed in the transformer.
func place_disk(user: Node) -> void:
	if carries_disk(user):
		disk_carrier = null
		_complete(LoopRules.Objective.DOWNLOAD)


## Its carrier is captured: the floppy disk falls at its feet.
func drop_disk(user: Node) -> void:
	if carries_disk(user):
		disk_carrier = null
		_spawn_disk((user as Node3D).global_position)


func _physics_process(delta: float) -> void:
	_download(delta)
	if _relay_left > 0.0:
		_relay_left -= delta
		if _relay_left <= 0.0:
			for switch in relays:
				switch.set_down(false)
			changed.emit()


func _download(delta: float) -> void:
	if download_done < 0.0 or disk != null or disk_carrier != null:
		return
	if rules.is_done(LoopRules.Objective.DOWNLOAD):
		return
	if not download_terminal.is_on():
		download_done = -1.0  # Switched off: start over.
		changed.emit()
		return
	download_done += delta
	_disk_noise_left -= delta
	if _disk_noise_left <= 0.0:
		_disk_noise_left = settings.disk_noise_interval
		NoiseBus.emit_noise(
			NoiseEvent.Type.DISK,
			download_terminal.global_position + Vector3.UP,
			settings.disk_noise_range,
			download_terminal
		)
	if download_done >= settings.download_time:
		_spawn_disk(download_terminal.to_global(Vector3(0.75, 0.0, 0.5)))
		changed.emit()


func _spawn_disk(at: Vector3) -> void:
	disk = DISK_SCENE.instantiate()
	disk.has_fuse = true
	_map.add_child(disk)
	disk.global_position = at
	disk.fuse_taken.connect(_on_disk_taken)


func _on_disk_taken(user: Node) -> void:
	disk_carrier = user
	if is_instance_valid(disk):
		disk.queue_free()
	disk = null
	changed.emit()


func _on_thrown(user: Node, switch: RelaySwitch) -> void:
	if rules.is_done(LoopRules.Objective.RELAY) or switch.is_down:
		return
	switch.set_down(true)
	NoiseBus.emit_noise(
		NoiseEvent.Type.SWITCH, switch.global_position + Vector3.UP, settings.relay_range, user
	)
	if relays.all(func(each: RelaySwitch) -> bool: return each.is_down):
		_relay_left = 0.0
		for each in relays:
			each.armed = false
		_complete(LoopRules.Objective.RELAY)
	else:
		_relay_left = settings.relay_window
		changed.emit()


func _complete(kind: int) -> void:
	rules.complete(kind)
	changed.emit()


static func _switch_places(map: Node) -> Array:
	return _all(map, RelaySwitch).map(
		func(switch: RelaySwitch) -> Array: return [switch.building_name, switch.global_position]
	)


static func _terminals(map: Node, kind: Terminal.Kind) -> Array:
	return _all(map, Terminal).filter(
		func(terminal: Terminal) -> bool: return terminal.kind == kind
	)


static func _all(map: Node, type: Variant) -> Array:
	return map.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return is_instance_of(node, type)
	)
