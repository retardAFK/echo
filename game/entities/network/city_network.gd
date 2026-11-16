class_name CityNetwork
extends Node
## The network of the cité (spec S-018, part B): its terminals and its
## security cameras, its loudspeakers and metal shutters, and the guard's
## terminal that opens the prison (Q4) (the objectives join it with T-266).
## It lists them in a fixed order, the same on the room and on every client,
## says what a terminal's menu offers, carries out what a hunted picks there
## (a PICK action), and keeps who watches which camera.
## Online, the room sends state() in NetWorld; a client shows it with apply().

## What a line of a terminal's menu does.
enum Entry { CAMERA, SPEAKER, SHUTTER, OPEN_CAGES }

const GROUP := &"city_network"

var terminals: Array[Terminal] = []
var cameras: Array[SecurityCamera] = []
var speakers: Array[Loudspeaker] = []
var shutters: Array[RemoteShutter] = []
## The prison the guard's terminal opens, or null.
var prison: Prison
## Online client: the room decides.
var mirror := false:
	set(value):
		mirror = value
		for terminal in terminals:
			terminal.mirror = value
		for speaker in speakers:
			speaker.mirror = value
		for shutter in shutters:
			shutter.mirror = value

## Who watches which camera: watcher -> SecurityCamera.
var _watching := {}
## Guard terminals opening the cages: Terminal -> seconds done.
var _opening := {}


static func of(node: Node) -> CityNetwork:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as CityNetwork


func _ready() -> void:
	add_to_group(GROUP)
	var map := get_parent()
	for node in map.find_children("*", "", true, false):
		if node is Terminal:
			terminals.append(node)
			(node as Terminal).left.connect(_on_left)
		elif node is SecurityCamera:
			cameras.append(node)
		elif node is Loudspeaker:
			speakers.append(node)
		elif node is RemoteShutter:
			shutters.append(node)
		elif node is Prison:
			prison = node


## The lines of a terminal's menu, in order: [Entry, index, label key]. The
## guard's terminal ends with "open the cages", when there is a prison.
func entries_for(terminal: Terminal) -> Array:
	var entries := []
	for i in cameras.size():
		entries.append([Entry.CAMERA, i, cameras[i].label_key])
	for i in speakers.size():
		entries.append([Entry.SPEAKER, i, speakers[i].label_key])
	for i in shutters.size():
		entries.append([Entry.SHUTTER, i, shutters[i].label_key])
	if terminal != null and terminal.kind == Terminal.Kind.GUARD and prison != null:
		entries.append([Entry.OPEN_CAGES, 0, "HUD_TERMINAL_OPEN_CAGES"])
	return entries


## A hunted at a terminal picks line n (from 0) of its menu.
func pick(user: Node3D, n: int) -> void:
	var terminal: Terminal = user.get("terminal")
	if terminal == null or mirror:
		return
	var entries := entries_for(terminal)
	if n < 0 or n >= entries.size():
		return
	var entry: Array = entries[n]
	match entry[0]:
		Entry.CAMERA:
			var camera := cameras[entry[1]]
			watch(user, null if watched_by(user) == camera else camera)
		Entry.SPEAKER:
			speakers[entry[1]].trigger()
		Entry.SHUTTER:
			shutters[entry[1]].lower()
		Entry.OPEN_CAGES:
			if has_prisoners() and not _opening.has(terminal):
				_opening[terminal] = 0.0


## Someone waits in a cage of the prison.
func has_prisoners() -> bool:
	return prison != null and prison.cages.any(func(cage: Cage) -> bool: return cage.is_occupied())


## The guard's terminal (Q4): seated there for guard_time, every cage opens
## with the bell. Getting up, or the monster switching it off, starts over.
func _open_cages(delta: float) -> void:
	for terminal: Terminal in _opening.keys():
		if terminal.user == null or not terminal.is_on():
			_opening.erase(terminal)
			terminal.progress = 0.0
			continue
		_opening[terminal] += delta
		terminal.progress = minf(_opening[terminal] / prison.settings.guard_time, 1.0)
		if terminal.progress >= 1.0:
			_opening.erase(terminal)
			terminal.progress = 0.0
			for hunted in prison.open_all():
				var capture: CaptureState = hunted.get("capture")
				if capture != null:
					capture.set_free()


## A captured hunted in its cage (Q8) goes to the next working camera, and
## back to its own eyes after the last.
func next_camera(user: Node3D) -> void:
	if mirror:
		return
	var start := cameras.find(watched_by(user)) + 1
	for i in range(start, cameras.size()):
		if not cameras[i].broken:
			watch(user, cameras[i])
			return
	watch(user, null)


## Someone watches through a camera, or back through its own eyes (null).
func watch(user: Node3D, camera: SecurityCamera) -> void:
	if camera != null and camera.broken:
		camera = null
	var before: SecurityCamera = _watching.get(user)
	if camera == before:
		return
	if camera == null:
		_watching.erase(user)
	else:
		_watching[user] = camera
	if "watching" in user:
		user.watching = camera
	_count(before)
	_count(camera)


func watched_by(user: Node) -> SecurityCamera:
	var camera: SecurityCamera = _watching.get(user)
	return camera


## The camera someone watches, as an index, -1 for its own eyes.
func camera_index(user: Node) -> int:
	return cameras.find(watched_by(user)) if _watching.has(user) else -1


func terminal_index(terminal: Terminal) -> int:
	return terminals.find(terminal) if terminal != null else -1


func _physics_process(delta: float) -> void:
	if mirror:
		return
	_open_cages(delta)
	for user: Variant in _watching.keys():
		var camera: SecurityCamera = _watching[user]
		if not is_instance_valid(user):
			_forget(user)
		elif camera.broken or not _may_watch(user):
			watch(user, null)


## At a terminal, or waiting in a cage.
func _may_watch(user: Node) -> bool:
	if user.get("terminal") != null:
		return true
	var capture: CaptureState = user.get("capture")
	return capture != null and capture.get_cage() != null and user.get("held") == true


func _on_left(user: Node3D) -> void:
	if is_instance_valid(user) and user.get("held") != true:
		watch(user, null)


func _forget(user: Variant) -> void:
	var camera: SecurityCamera = _watching[user]
	_watching.erase(user)
	_count(camera)


func _count(camera: SecurityCamera) -> void:
	if camera == null:
		return
	var count := 0
	for user: Variant in _watching:
		if _watching[user] == camera:
			count += 1
	camera.set_watchers(count)


## Room side: [[off, in use, progress in percent] per terminal, [watched,
## broken] per camera, used per loudspeaker, [down, whole seconds before it
## is ready] per shutter].
func state() -> Array:
	var used := []
	for terminal in terminals:
		used.append([not terminal.is_on(), terminal.is_in_use(), roundi(terminal.progress * 100.0)])
	var seen := []
	for camera in cameras:
		seen.append([camera.is_watched(), camera.broken])
	var blared := []
	for speaker in speakers:
		blared.append(speaker.used)
	var lowered := []
	for shutter in shutters:
		lowered.append([shutter.is_down(), ceili(shutter.recharge_left)])
	return [used, seen, blared, lowered]


## Client side: shows what the room says.
func apply(values: Array) -> void:
	if values.size() < 2:
		return
	var used: Array = values[0]
	for i in mini(used.size(), terminals.size()):
		terminals[i].mirror_state(used[i][0], used[i][1])
		if used[i].size() >= 3:
			terminals[i].progress = used[i][2] / 100.0
	var seen: Array = values[1]
	for i in mini(seen.size(), cameras.size()):
		cameras[i].mirror_state(seen[i][0], seen[i][1])
	if values.size() < 4:
		return
	var blared: Array = values[2]
	for i in mini(blared.size(), speakers.size()):
		speakers[i].mirror_state(blared[i])
	var lowered: Array = values[3]
	for i in mini(lowered.size(), shutters.size()):
		shutters[i].mirror_state(lowered[i][0], lowered[i][1])
