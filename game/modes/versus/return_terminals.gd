class_name ReturnTerminals
extends Node
## The return terminals of the Versus (spec S-025, T-414): a second chance
## for a hunted who is out. One ReturnTerminal stands at each terminal_spots
## of the arena. A standing hunted holds interact by one (terminal_reach,
## terminal_time) while a teammate is out: the first one out comes back
## standing in front of the terminal (HuntedVitals.bring_back), the
## terminal goes dark (it works once), a banner tells everyone, and its hum
## tells the boss where (terminal_noise_range).
## Online: the room sends TERMINALS ([used, lit] of each, in order) when it
## changes and to a player whose map is ready; a client copies it (mirror).
## A child of VersusMode (mode.terminals). To remove them: the line that
## creates it in VersusMode; HunterKit and KitPrompts then skip them.

var mode: VersusMode
var _sent := []


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "ReturnTerminals"


func _ready() -> void:
	if mode.arena == null:
		return
	for i in mode.arena.terminal_spots.size():
		add(mode.arena.terminal_spots[i], mode.arena.terminal_yaw(i))


## A terminal at point, its screen facing yaw.
func add(point: Vector3, yaw := 0.0) -> ReturnTerminal:
	var terminal := ReturnTerminal.new()
	add_child(terminal)
	terminal.global_position = point
	terminal.rotation.y = yaw
	return terminal


func all() -> Array[ReturnTerminal]:
	var found: Array[ReturnTerminal] = []
	for child in get_children():
		if child is ReturnTerminal:
			found.append(child)
	return found


## The first hunted who is out, or null.
func first_out() -> HunterKit:
	for kit in mode.hunters:
		if kit.vitals.is_out():
			return kit
	return null


## How many terminals can still bring someone back.
func ready_count() -> int:
	var count := 0
	for terminal in all():
		if not terminal.used:
			count += 1
	return count


## The unused terminal within terminal_reach of kit, or null.
func in_reach(kit: HunterKit) -> ReturnTerminal:
	var reach := mode.settings.terminal_reach
	for terminal in all():
		if terminal.used:
			continue
		var gap := terminal.global_position - kit.body.global_position
		gap.y *= 0.5
		if gap.length() <= reach:
			return terminal
	return null


## Where the lit terminals are (for the AI preys to go).
func lit_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for terminal in all():
		if terminal.lit:
			points.append(terminal.global_position)
	return points


## One frame of interact held (held) or not by kit (standing): true while
## it works a terminal (no chest then).
func hold(kit: HunterKit, held: bool, delta: float) -> bool:
	var terminal := in_reach(kit) if held and first_out() != null else null
	for each in all():
		if each.holder == kit and each != terminal:
			each.holder = null
			each.held = 0.0
	if terminal == null:
		return false
	if terminal.holder != kit:
		if terminal.holder != null and is_instance_valid(terminal.holder):
			return false  # A teammate works it already.
		terminal.holder = kit
		terminal.held = 0.0
		NoiseBus.emit_noise(
			NoiseEvent.Type.RESCUE,
			terminal.global_position,
			mode.settings.terminal_noise_range,
			kit.body
		)
	terminal.held += delta
	if terminal.held >= mode.settings.terminal_time:
		bring_back(terminal, first_out())
	return true


## The terminal brings out_kit back (the room, or solo).
func bring_back(terminal: ReturnTerminal, out_kit: HunterKit) -> bool:
	if terminal.used or out_kit == null or not out_kit.vitals.bring_back():
		return false
	terminal.holder = null
	terminal.held = 0.0
	terminal.show_state(true, false)
	var body := out_kit.body
	body.global_position = terminal.back_point()
	body.velocity = Vector3.ZERO
	out_kit.reset_fall()
	mode.announce("VERSUS_BACK_BANNER")
	return true


## How far kit is in working its terminal (0 to 1), or -1 for none.
func ratio_of(kit: HunterKit) -> float:
	for terminal in all():
		if terminal.holder == kit:
			return clampf(terminal.held / mode.settings.terminal_time, 0.0, 1.0)
	return -1.0


## The values sent to the clients: [used, lit] of each terminal.
func values() -> Array:
	var list := []
	for terminal in all():
		list.append([terminal.used, terminal.lit])
	return list


## A client's copy: what the room says of each terminal.
func mirror(list: Array) -> void:
	var terminals := all()
	for i in mini(list.size(), terminals.size()):
		var entry: Array = list[i]
		terminals[i].show_state(entry[0], entry[1])


## The room (or solo): lights the terminals while a teammate is out, and
## tells the clients when that changes.
func _physics_process(_delta: float) -> void:
	if mode.mirror:
		return
	var someone_out := first_out() != null
	for terminal in all():
		if terminal.lit != (someone_out and not terminal.used):
			terminal.show_state(terminal.used, someone_out)
	var now := values()
	if now != _sent:
		_sent = now
		if mode.link != null:
			mode.link.send([VersusNet.Event.TERMINALS, now])
