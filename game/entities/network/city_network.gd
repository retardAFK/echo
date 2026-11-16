class_name CityNetwork
extends Node
## The network of the cité (spec S-018, part B): its terminals and its
## security cameras (loudspeakers, shutters, the guard terminal and the
## objectives join it with T-264 to T-266). It lists them in a fixed order,
## the same on the room and on every client, says what a terminal's menu
## offers, carries out what a hunted picks there (a PICK action), and keeps
## who watches which camera.
## Online, the room sends state() in NetWorld; a client shows it with apply().

## What a line of a terminal's menu does.
enum Entry { CAMERA }

const GROUP := &"city_network"

var terminals: Array[Terminal] = []
var cameras: Array[SecurityCamera] = []
## Online client: the room decides.
var mirror := false:
	set(value):
		mirror = value
		for terminal in terminals:
			terminal.mirror = value

## Who watches which camera: watcher -> SecurityCamera.
var _watching := {}


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


## The lines of a terminal's menu, in order: [Entry, index, label key].
func entries_for(_terminal: Terminal) -> Array:
	var entries := []
	for i in cameras.size():
		entries.append([Entry.CAMERA, i, cameras[i].label_key])
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


func _physics_process(_delta: float) -> void:
	if mirror:
		return
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


## Room side: [[off, in use] per terminal, [watched, broken] per camera].
func state() -> Array:
	var used := []
	for terminal in terminals:
		used.append([not terminal.is_on(), terminal.is_in_use()])
	var seen := []
	for camera in cameras:
		seen.append([camera.is_watched(), camera.broken])
	return [used, seen]


## Client side: shows what the room says.
func apply(values: Array) -> void:
	if values.size() < 2:
		return
	var used: Array = values[0]
	for i in mini(used.size(), terminals.size()):
		terminals[i].mirror_state(used[i][0], used[i][1])
	var seen: Array = values[1]
	for i in mini(seen.size(), cameras.size()):
		cameras[i].mirror_state(seen[i][0], seen[i][1])
