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
## Online (T-267), the room sends state() in NetWorld; a client's mirror
## shows it with apply().

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

## The map of the game.
var map_node: Node
## Online client: the room decides; this one shows what it says.
var mirror := false

## AI prey at the relay switches (T-268): RelaySwitch -> prey that goes
## there, and prey -> game time it last waited at its switch.
var _relay_claims := {}
var _relay_ready := {}
var _clock := 0.0
## What each keypad got so far: Terminal -> digits typed.
var _typed := {}
var _disk_noise_left := 0.0
## Seconds left to throw the second relay switch, 0 when none is down.
var _relay_left := 0.0
## Online client: some hunted carries the floppy disk.
var _disk_carried := false


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
	map_node = map
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
			terminal
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


## A hunted carries the floppy disk (on a client: one of them does).
func carries_disk(user: Node) -> bool:
	if mirror:
		return user != null and _disk_carried
	return user != null and user == disk_carrier


## Someone carries the floppy disk.
func is_disk_carried() -> bool:
	return _disk_carried if mirror else disk_carrier != null


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
	_clock += delta
	if mirror:
		return
	_download(delta)
	if _relay_left > 0.0:
		_relay_left -= delta
		if _relay_left <= 0.0:
			for switch in relays:
				switch.set_down(false)
			changed.emit()


## An AI prey takes a relay switch nobody else goes to (or the first one).
func claim_relay(prey: Node) -> RelaySwitch:
	for switch in relays:
		if _relay_claims.get(switch) == prey:
			return switch
	for switch in relays:
		var other: Variant = _relay_claims.get(switch)
		if other == null or not is_instance_valid(other) or not CaptureState.is_free_hunted(other):
			_relay_claims[switch] = prey
			return switch
	return relays[0] if not relays.is_empty() else null


## An AI prey stands at its relay switch, ready to throw it.
func ready_at_relay(prey: Node) -> void:
	_relay_ready[prey] = _clock


## Whether a prey at its switch may throw it: the other one is down, or a
## teammate stands ready at it.
func relay_partner_ready(prey: Node) -> bool:
	for switch in relays:
		if _relay_claims.get(switch) == prey:
			continue
		if switch.is_down:
			return true
		var other: Variant = _relay_claims.get(switch)
		if other != null and _clock - float(_relay_ready.get(other, -10.0)) < 0.5:
			return true
	return false


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
	map_node.add_child(disk)
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


## Room side: [objectives, those still to do, index of the post-it with the
## code (-1), the code, index of the download's terminal (-1), the download
## in percent (-1 before it starts), where the floppy disk lies (null), whether
## someone carries it, indexes of the relay switches drawn, each one down,
## [terminal index, digits typed] per keypad in use].
func state() -> Array:
	var spots := _all(map_node, CodeSpot)
	var terminals := _all(map_node, Terminal)
	var switches := _all(map_node, RelaySwitch)
	var typed := []
	for terminal: Terminal in _typed:
		typed.append([terminals.find(terminal), _typed[terminal]])
	var ratio := download_ratio()
	return [
		rules.objectives.duplicate(),
		rules.pending.duplicate(),
		spots.find(code_spot) if code_spot != null else -1,
		code,
		terminals.find(download_terminal) if download_terminal != null else -1,
		roundi(ratio * 100.0) if ratio >= 0.0 else -1,
		disk.global_position if disk != null else null,
		disk_carrier != null,
		relays.map(func(switch: RelaySwitch) -> int: return switches.find(switch)),
		relays.map(func(switch: RelaySwitch) -> bool: return switch.is_down),
		typed,
	]


## Client side: shows the room's objectives.
func apply(values: Array) -> void:
	if values.size() < 11:
		return
	var before := [rules.objectives.duplicate(), rules.pending.duplicate(), _disk_carried]
	if Array(values[0]) != Array(rules.objectives):
		rules.set_objectives(values[0])
	rules.pending.assign(values[1])
	var spots := _all(map_node, CodeSpot)
	code = values[3]
	var spot_at: int = values[2]
	code_spot = spots[spot_at] if spot_at >= 0 and spot_at < spots.size() else null
	for spot: CodeSpot in spots:
		spot.show_code(code if spot == code_spot else "")
	var terminals := _all(map_node, Terminal)
	var terminal_at: int = values[4]
	download_terminal = (
		terminals[terminal_at] if terminal_at >= 0 and terminal_at < terminals.size() else null
	)
	download_done = values[5] / 100.0 * settings.download_time if values[5] >= 0 else -1.0
	_mirror_disk(values[6])
	_disk_carried = values[7]
	var switches := _all(map_node, RelaySwitch)
	relays.clear()
	for i in (values[8] as Array).size():
		var at: int = values[8][i]
		if at >= 0 and at < switches.size():
			relays.append(switches[at])
			switches[at].set_down(values[9][i])
	for switch: RelaySwitch in switches:
		switch.armed = switch in relays and not rules.is_done(LoopRules.Objective.RELAY)
	_typed.clear()
	for entry: Array in values[10]:
		if entry[0] >= 0 and entry[0] < terminals.size():
			_typed[terminals[entry[0]]] = entry[1]
	if str(before) != str([rules.objectives, rules.pending, _disk_carried]):
		changed.emit()


## Client side: the floppy disk lies where the room says, or nowhere.
func _mirror_disk(at: Variant) -> void:
	if at == null:
		if disk != null:
			disk.queue_free()
			disk = null
		return
	if disk != null and disk.global_position.is_equal_approx(at):
		return
	if disk == null:
		disk = DISK_SCENE.instantiate()
		disk.has_fuse = true
		map_node.add_child(disk)
	disk.global_position = at


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
