class_name PreyTasks
extends RefCounted
## What the AI prey does for the objectives besides fuses (spec S-018, Q13,
## T-268), testable without the prey's moves: it chooses its next task, says
## where to go, what to hold "interact" on there, and when it is done.
## - CODE: it reads the post-its one by one, nearest first, until it finds
##   the code, then sits at the transformer's keypad and types it.
## - DOWNLOAD: it sits at the terminal of the download and starts it, goes
##   on with the rest, comes back for the floppy disk and takes it to the
##   transformer like a fuse.
## - RELAY: each prey takes one of the two switches; it throws its own when
##   the other one is down, when a teammate waits at it, after
##   relay_patience seconds, or at once with no free teammate in the game;
##   then it runs to the other one if it is still up.
## With nothing left but a download running, it waits by the terminal.
## First of all, it frees a teammate waiting in a cage of the prison while the
## monster is far from it; and when it starts a download, it sets off the
## loudspeaker farthest from that terminal, to draw the monster away.

enum Kind { NONE, RESCUE, READ, KEYPAD, DOWNLOAD, DISK, RELAY, WAIT }

## Seconds between two keys typed on the keypad.
const KEY_TIME := 0.4
## Seconds it waits at its relay switch before throwing it anyway.
const RELAY_PATIENCE := 30.0
## Seconds it stands still when it waits for a download.
const WAIT_TIME := 3.0

var kind := Kind.NONE
## The node of the task: a post-it, a terminal, the disk, a switch.
var node: Node3D
## The code once read on a post-it.
var known_code := ""

var _prey: Node3D
var _quests: Quests
## The post-its it already read.
var _read: Array[Node] = []
var _typed := 0
var _key_left := 0.0
var _waited := 0.0


func _init(prey: Node3D, quests: Quests) -> void:
	_prey = prey
	_quests = quests


## Chooses the next task, or NONE when there is nothing to do. The prey
## carries neither a fuse nor the disk (it takes them to the transformer).
func choose() -> Kind:
	kind = Kind.NONE
	node = null
	_waited = 0.0
	if _quests == null:
		_pick(Kind.RESCUE, _jailed_teammate())
		return kind
	var rules := _quests.rules
	var jailed := _jailed_teammate()
	if jailed != null:
		_pick(Kind.RESCUE, jailed)
	elif _quests.disk != null:
		_pick(Kind.DISK, _quests.disk)
	elif _quests.wants_code() and known_code != "":
		_pick(Kind.KEYPAD, _keypad())
	elif _quests.wants_code():
		_pick(Kind.READ, _next_post_it())
	elif _quests.offers_download(_quests.download_terminal) and _quests.download_terminal.is_on():
		_pick(Kind.DOWNLOAD, _quests.download_terminal)
	elif not rules.is_done(LoopRules.Objective.RELAY) and not _quests.relays.is_empty():
		_pick(Kind.RELAY, _relay_switch())
	elif _download_running():
		_pick(Kind.WAIT, _quests.download_terminal)
	return kind


## Where to go for the task.
func point() -> Vector3:
	match kind:
		Kind.RESCUE:
			return (node as CaptureState).rescue_point()
		Kind.READ:
			var front := node.global_basis.z
			return node.global_position + front * 1.2 + Vector3.DOWN * 1.4
		Kind.KEYPAD, Kind.DOWNLOAD:
			return (node as Terminal).seat_point()
		Kind.RELAY:
			return (node as RelaySwitch).get_approach_point()
		Kind.WAIT:
			return (node as Terminal).seat_point() + node.global_basis.z * 1.5
	return node.global_position if node != null else _prey.global_position


## Whether to run there: the other relay switch is already down.
func is_rush() -> bool:
	return kind == Kind.RELAY and _quests.relays.any(func(s: RelaySwitch) -> bool: return s.is_down)


## Arrived: whether it has work to hold there (else it chooses again).
func arrive() -> bool:
	match kind:
		Kind.READ:
			_read.append(node)
			var code := (node as CodeSpot).get_code()
			if code != "":
				known_code = code
			return false
		Kind.KEYPAD, Kind.DOWNLOAD:
			_typed = 0
			_key_left = KEY_TIME
			return (node as Terminal).is_on()
		Kind.DISK:
			return is_instance_valid(node)
	return kind in [Kind.RESCUE, Kind.RELAY, Kind.WAIT]


## What it holds "interact" on: a terminal until it sits, the disk; nothing
## for a switch (pressed once) or while it waits.
func work_target() -> Node:
	match kind:
		Kind.KEYPAD, Kind.DOWNLOAD:
			var terminal := node as Terminal
			return terminal if terminal.user != _prey else null
		Kind.DISK:
			return node if is_instance_valid(node) else null
		Kind.RESCUE:
			return node if _wants_rescue(node as CaptureState) else null
	return null


## One frame of work. Returns true once the task is over (done or lost).
func work(delta: float) -> bool:
	var over := true
	match kind:
		Kind.KEYPAD:
			over = _type_code(delta)
		Kind.DOWNLOAD:
			over = _start_download()
		Kind.DISK:
			over = not is_instance_valid(node) or _quests.carries_disk(_prey)
		Kind.RESCUE:
			over = not _wants_rescue(node as CaptureState)
		Kind.RELAY:
			over = _throw(delta)
		Kind.WAIT:
			_waited += delta
			over = _waited >= WAIT_TIME or not _download_running()
	return over


## Gets up from a terminal it sat at (fled, or captured).
func drop() -> void:
	if not is_instance_valid(node):
		return
	var terminal := node as Terminal
	if terminal != null and terminal.user == _prey:
		terminal.leave()


func _start_download() -> bool:
	var terminal := node as Terminal
	if not terminal.is_on():
		return true
	if terminal.user != _prey:
		return false
	_quests.start_download(terminal)
	_lure_away(terminal)
	terminal.leave()
	return true


func _type_code(delta: float) -> bool:
	var keypad := node as Terminal
	if not keypad.is_on() or not _quests.wants_code():
		if keypad.user == _prey:
			keypad.leave()
		return true
	if keypad.user != _prey:
		return false
	_key_left -= delta
	if _key_left > 0.0:
		return false
	_key_left = KEY_TIME
	if _typed >= known_code.length():
		known_code = ""  # Not taken: it read it wrong, it looks again.
		_read.clear()
		keypad.leave()
		return true
	_quests.type_digit(keypad, int(known_code[_typed]))
	_typed += 1
	return false


func _throw(delta: float) -> bool:
	var switch := node as RelaySwitch
	if switch == null or switch.is_down or _quests.rules.is_done(LoopRules.Objective.RELAY):
		return true
	_waited += delta
	_quests.ready_at_relay(_prey)
	if _quests.relay_partner_ready(_prey) or _waited >= RELAY_PATIENCE or _alone():
		switch.interact(_prey)
		return true
	return false


## Its own switch, or the other one once its own is down.
func _relay_switch() -> RelaySwitch:
	var own := _quests.claim_relay(_prey)
	if own == null or not own.is_down:
		return own
	for switch in _quests.relays:
		if not switch.is_down:
			return switch
	return own


## No free teammate in the game (solo has no capture rule at all).
func _alone() -> bool:
	for capture: CaptureState in _prey.get_tree().get_nodes_in_group(CaptureState.GROUP):
		if capture.get_parent() != _prey and capture.state == CaptureState.State.FREE:
			return false
	return true


## A teammate in a cage, the monster far from it, nearest first.
func _jailed_teammate() -> CaptureState:
	var best: CaptureState = null
	for node in _prey.get_tree().get_nodes_in_group(Interactable.GROUP):
		var captured := node as CaptureState
		if captured == null or not _wants_rescue(captured):
			continue
		var here := _prey.global_position
		if (
			best == null
			or captured.global_position.distance_to(here) < best.global_position.distance_to(here)
		):
			best = captured
	return best


func _wants_rescue(captured: CaptureState) -> bool:
	if captured == null or not is_instance_valid(captured):
		return false
	if captured.state != CaptureState.State.CAPTURED or captured.get_cage() == null:
		return false
	if not captured.wanted_by(_prey):
		return false
	var monster: Node3D = _prey.get("monster")
	var safe: float = _prey.settings.rescue_safe_distance
	return monster == null or monster.global_position.distance_to(captured.global_position) >= safe


## Sets off the unused loudspeaker farthest from a terminal (S-018, Q11).
func _lure_away(terminal: Terminal) -> void:
	var network := CityNetwork.of(terminal)
	if network == null:
		return
	var best: Loudspeaker = null
	for speaker in network.speakers:
		if speaker.used:
			continue
		var at := terminal.global_position
		if (
			best == null
			or speaker.global_position.distance_to(at) > best.global_position.distance_to(at)
		):
			best = speaker
	if best != null:
		best.trigger()


func _pick(new_kind: Kind, new_node: Node3D) -> void:
	if new_node == null:
		return
	kind = new_kind
	node = new_node


func _download_running() -> bool:
	return (
		_quests.download_terminal != null
		and _quests.download_done >= 0.0
		and _quests.disk == null
		and not _quests.is_disk_carried()
		and not _quests.rules.is_done(LoopRules.Objective.DOWNLOAD)
	)


func _keypad() -> Terminal:
	for terminal: Terminal in _prey.get_tree().get_nodes_in_group(Terminal.GROUP):
		if terminal.kind == Terminal.Kind.CODE:
			return terminal
	return null


## The nearest post-it not read yet; all of them again once read.
func _next_post_it() -> CodeSpot:
	var spots := _prey.get_tree().get_nodes_in_group(CodeSpot.GROUP)
	if spots.all(func(spot: Node) -> bool: return spot in _read):
		_read.clear()
	var best: CodeSpot = null
	for spot: CodeSpot in spots:
		if spot in _read:
			continue
		var here := _prey.global_position
		if (
			best == null
			or spot.global_position.distance_to(here) < best.global_position.distance_to(here)
		):
			best = spot
	return best
