class_name NetGame
extends Node
## The online part of a game on a map (S-010, T-097), added by GameMap.
## Room side: each physics frame, the commands of every place go to its
## avatar; snapshot_rate times a second, each player gets a snapshot with its
## own state and the others it sees (NetVisibility).
## Client side: the player's own avatar is predicted (Prediction) and nudged
## to the room's position; the others are NetPuppets moved between snapshots.
## Snapshot: {"ack": last command applied, "you": [position, velocity, yaw,
## gait, hidden, hold ratio, bottles, alarm clocks, hiding spot index, held,
## terminal index, camera index (S-018)],
## "others": [[seat, position, yaw, gait, down, gesture], ...]}: those it
## sees with its own eyes or through the camera it watches (S-018); gesture is
## what its body shows (S-011): a HuntedBody.Gesture, or for the monster a
## MonsterBody.Action.
## A spectator (a hunted out of the game, T-107) gets instead what the
## teammate it watches sees: {"ack", "watch": seat, "pitch": its head pitch,
## "others": that teammate first, then those it sees}; it presses "interact"
## to watch the next one.
## Events (T-098), sent reliably as they happen:
## - [NOISE, type, position, range]: to the monster, every noise but its own;
##   to a hunted, only those its ears hear (NoiseBus.can_hear), never its own,
##   never who made it. The client plays it through NoiseBus.
## - [SCAN, building index, scanned]: to the hunted, so the lights flicker.
## - [CAUGHT, seat, CaptureState.State]: to everyone, when the monster
##   catches a hunted (captured, or out the second time) or a teammate frees
##   it (T-107).
## - [WORLD, NetWorld.state()]: to everyone, when the map or the loop changes
##   (T-099); the client's map and loop only mirror the room's.
## - [BOTTLE, position, velocity] and [DECOY, position]: to everyone, a bottle
##   thrown or an alarm clock placed; the client plays its own copy.
## - [CRUSH, position]: to everyone, the monster crushed a ringing alarm clock.
## - [CLOCK, NetWorld.clock() + [room fps]]: to everyone, once a second (S-020, T-300):
##   the game time and the wind, which change every frame and so are not in
##   WORLD (which would then go out with every snapshot).

## Room side: a human monster touched a hunted; GameMap captures it.
signal hunted_caught(hunted: Node3D)
## Client side: the room says the hunted in a seat was caught or freed.
signal caught_reported(seat: int, state: CaptureState.State)
## Client side: this player is out of the game and watches a teammate.
signal spectating

enum Event { NOISE, SCAN, CAUGHT, WORLD, BOTTLE, DECOY, CRUSH, CLOCK }

## Seconds between two CLOCK events (T-300).
const CLOCK_INTERVAL := 1.0
## Window of the network measures of the F3 overlay, in seconds (T-303).
const NET_STATS_WINDOW := 5.0

## Layers that block sight between players: the ground and props, and walls.
const SIGHT_MASK := 1 | NoiseBus.WALLS_COLLISION_MASK
const BOTTLE_SCENE := preload("res://game/entities/bottle/thrown_bottle.tscn")
const DECOY_SCENE := preload("res://game/entities/decoy/decoy.tscn")

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var is_room := false
## The scannable buildings of the map, in the same order on both sides.
var buildings: Array[Building] = []
## The things of the map that change, and the game loop (T-099).
var world: NetWorld
## Room side without network (tests): the events sent, as [place, event].
var sent_events := []
## Room side: avatar of each human place (Player or MonsterAvatar), by place.
var avatars := {}
## Room side: seat of each avatar, by place; and the AI monster, if any.
var seats := {}
var ai_monster: Node3D
## Room side: the AI preys in the empty hunted seats (T-101), by seat.
var ai_hunted := {}
## Client side: the avatar played here.
var own: Node3D
var prediction: Prediction
## Client side: the others, by seat.
var puppets := {}
## Client side: largest gap seen between prediction and room, for tests.
var worst_error := 0.0
## Client side, for the F3 overlay (S-020, T-303): the gap at the last
## snapshot, the largest over the last NET_STATS_WINDOW seconds, the size in
## bytes of the last WORLD message and how many came in that window, and the
## room's frames per second (sent with CLOCK).
var last_error := 0.0
var recent_worst_error := 0.0
var world_bytes := 0
var world_count := 0
## Client side: WORLD messages received since the start (tests, T-303).
var world_total := 0
var room_fps := 0.0
## Client side, spectator (T-107): the seat watched (-1 if none) and where
## its head looks up or down.
var watched_seat := -1
var watched_pitch := 0.0
var is_spectator := false

var _send_left := 0.0
var _clock_left := 0.0
var _stats_left := NET_STATS_WINDOW
var _window_worst := 0.0
var _window_worlds := 0
var _acked := {}
var _sent_world := []
## Room side: the teammate each spectator's place watches.
var _watching := {}


func _ready() -> void:
	# Before the avatars on the room (commands first), after them on a client
	# (record where the frame left the player).
	process_physics_priority = -10 if is_room else 10
	if is_room:
		NoiseBus.noise_emitted.connect(_on_noise_emitted)
		if NetSession.link != null:
			NetSession.link.place_ready.connect(_on_place_ready)
		for i in buildings.size():
			buildings[i].scan_changed.connect(_on_scan_changed.bind(i))
		get_parent().child_entered_tree.connect(_on_map_child_added)
	else:
		if own != null:
			own.mirror_world = true
			NoiseBus.mirror = true
			NoiseBus.local_source = own
		prediction = Prediction.new(settings)
		NetSession.snapshot_received.connect(apply_snapshot)
		NetSession.event_received.connect(apply_event)
		if NetSession.link != null:
			NetSession.link.say_ready()  # The room sends the map as it is now.


func _exit_tree() -> void:
	for connection: Array in [
		[NoiseBus.noise_emitted, _on_noise_emitted],
		[NetSession.snapshot_received, apply_snapshot],
		[NetSession.event_received, apply_event],
		[NetSession.link.place_ready if NetSession.link != null else Signal(), _on_place_ready],
	]:
		var event: Signal = connection[0]
		if not event.is_null() and event.is_connected(connection[1]):
			event.disconnect(connection[1])
	if not is_room:
		NoiseBus.mirror = false
		NoiseBus.local_source = null


## Room side: a human's avatar for a place, in a seat.
func add_avatar(place: int, seat: int, avatar: Node3D) -> void:
	avatars[place] = avatar
	seats[place] = seat


## Room side: the player of a place left and an AI plays for it (T-102).
func remove_avatar(place: int) -> void:
	avatars.erase(place)
	seats.erase(place)
	_watching.erase(place)
	_acked.erase(place)


## Room side: spectators watching a hunted now watch who took its place.
func replace_watched(old: Node3D, new: Node3D) -> void:
	for place in _watching:
		if _watching[place] == old:
			_watching[place] = new


func _physics_process(delta: float) -> void:
	if is_room:
		if NetSession.link == null:
			return  # A room being set up, or a test without network.
		_apply_commands()
		_check_catches()
		_send_left -= delta
		if _send_left <= 0.0:
			_send_left = maxf(_send_left + 1.0 / settings.snapshot_rate, 0.0)
			send_world()
			_send_snapshots()
		_clock_left -= delta
		if _clock_left <= 0.0:
			_clock_left = CLOCK_INTERVAL
			send_clock()
	elif own != null and not is_spectator:
		prediction.record(own.commands.seq, own.global_position)
		own.global_position += prediction.step(delta)


func _process(delta: float) -> void:
	if is_room:
		return
	_stats_left -= delta
	if _stats_left <= 0.0:
		_stats_left = NET_STATS_WINDOW
		recent_worst_error = _window_worst
		world_count = _window_worlds
		_window_worst = 0.0
		_window_worlds = 0
	var time := Time.get_ticks_msec() / 1000.0 - settings.interpolation_delay
	for puppet: NetPuppet in puppets.values():
		puppet.show_at(time, settings.max_extrapolation)


func _apply_commands() -> void:
	var link := NetSession.link
	for place in avatars:
		var avatar: Node3D = avatars[place]
		var received := link.commands_for(place)
		if _watching.has(place):
			for action in received.take_actions():
				if action == PlayerCommands.Action.INTERACT:
					_watching[place] = _next_watched(_watching[place])
			continue
		avatar.commands.copy_held(received)
		for action in received.take_actions():
			avatar.commands.push(action)
		_acked[place] = received.seq


## Room side: a human monster catches a hunted it touches, as in solo (not
## through a floor, not in a hiding spot).
func _check_catches() -> void:
	var monster := _human_monster()
	if monster == null:
		return
	for entry in _entities():
		var hunted: Node3D = entry[1]
		if (
			hunted == monster
			or HidingSpot.is_hidden(hunted)
			or not CaptureState.is_free_hunted(hunted)
		):
			continue
		var gap := hunted.global_position - monster.global_position
		if (
			Vector2(gap.x, gap.z).length() <= monster.settings.catch_distance
			and absf(gap.y) <= monster.settings.catch_height
		):
			monster.catch_count += 1
			monster.gesture.play(MonsterBody.Action.CATCH, MonsterAvatar.BODY_SETTINGS.catch_time)
			MonsterNoise.scream(monster)
			hunted_caught.emit(hunted)  # GameMap applies the capture rule and tells everyone.


func _human_monster() -> MonsterAvatar:
	for place in avatars:
		if seats[place] == LobbyState.MONSTER_SEAT:
			return avatars[place]
	return null


## Room side: tells everyone the hunted in a seat was caught or freed.
func report_caught(seat: int, state := CaptureState.State.CAPTURED) -> void:
	_send_to_all([Event.CAUGHT, seat, state])


## Room side: a hunted is out of the game (T-107); its place watches a
## teammate from now on.
func spectate(hunted: Node3D) -> void:
	for place in avatars:
		if avatars[place] == hunted:
			_watching[place] = _next_watched(null)


## Room side: the hunted still in the game after current, by seat, going round.
func _next_watched(current: Node3D) -> Node3D:
	var in_game := []
	for entry in _entities():
		if entry[0] != LobbyState.MONSTER_SEAT:
			in_game.append(entry)
	if in_game.is_empty():
		return null
	in_game.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var index := -1
	for i in in_game.size():
		if in_game[i][1] == current:
			index = i
	return in_game[(index + 1) % in_game.size()][1]


## Whether a hunted is out of the game (caught twice, T-107).
static func is_out(node: Node3D) -> bool:
	var capture: CaptureState = node.get("capture")
	return capture != null and capture.state == CaptureState.State.OUT


## Room side: the seat of an avatar or an AI prey, -1 if none.
func seat_of(node: Node3D) -> int:
	for place in avatars:
		if avatars[place] == node:
			return seats[place]
	for seat in ai_hunted:
		if ai_hunted[seat] == node:
			return seat
	return -1


## Room side: what of a noise goes to a viewer, empty if nothing. The monster
## gets every noise but its own (its screen filters by hearing and scan, as in
## solo); a hunted only what its ears hear. Never who made it.
static func noise_message(event: NoiseEvent, viewer: Node3D, viewer_is_monster: bool) -> Array:
	if event.source == viewer or event.noise_range <= 0.0:
		return []
	if viewer_is_monster and event.masked:
		return []  # Lost in a ventilation zone (S-014, Q5).
	if not viewer_is_monster and not NoiseBus.can_hear(event, viewer.get_eye_position()):
		return []
	return [Event.NOISE, event.type, event.position, event.noise_range, event.by_monster]


## A spectator hears what the teammate it watches hears.
func _on_noise_emitted(event: NoiseEvent) -> void:
	for place in avatars:
		var listener: Node3D = _watching.get(place, avatars[place])
		if listener == null or not is_instance_valid(listener):
			continue
		var message := noise_message(event, listener, seats[place] == LobbyState.MONSTER_SEAT)
		if not message.is_empty():
			_send_event(place, message)


## Only the hunted are told: the monster scans on its own screen already.
func _on_scan_changed(scanned: bool, index: int) -> void:
	for place in avatars:
		if seats[place] != LobbyState.MONSTER_SEAT:
			_send_event(place, [Event.SCAN, index, scanned])


func _send_event(place: int, event: Array) -> void:
	if NetSession.link == null:
		sent_events.append([place, event])
	else:
		NetSession.link.send_event(place, event)


## Room side: sends the state of the map and the loop to everyone, if it
## changed since the last time.
func send_world() -> void:
	if world == null:
		return
	var state := world.state()
	if state == _sent_world:
		return
	_sent_world = state.duplicate(true)
	_send_to_all([Event.WORLD, state])


## Room side: the game time and the wind to everyone (T-300).
func send_clock() -> void:
	if world != null:
		_send_to_all([Event.CLOCK, world.clock() + [Engine.get_frames_per_second()]])


## Room side: a player's map is ready (at the start, or back after a cut,
## T-102): it gets the map and the loop as they are now.
func _on_place_ready(place: int) -> void:
	if world != null and avatars.has(place):
		_send_event(place, [Event.WORLD, world.state()])
		_send_event(place, [Event.CLOCK, world.clock() + [Engine.get_frames_per_second()]])


func _send_to_all(event: Array) -> void:
	for place in avatars:
		_send_event(place, event)


## Room side: a bottle thrown or an alarm clock placed on the map, sent once
## the thrower has set where it starts (the same frame).
func _on_map_child_added(node: Node) -> void:
	if node is ThrownBottle or node is Decoy:
		_announce.call_deferred(node)


func _announce(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	if node is ThrownBottle:
		_send_to_all([Event.BOTTLE, node.global_position, (node as ThrownBottle).linear_velocity])
	elif node is Decoy:
		_send_to_all([Event.DECOY, node.global_position])
		(node as Decoy).crushed.connect(
			func() -> void: _send_to_all([Event.CRUSH, node.global_position])
		)


func _send_snapshots() -> void:
	for place in avatars:
		NetSession.link.send_snapshot(place, snapshot_for(place))


## Room side: what the player in a place is sent.
func snapshot_for(place: int) -> Dictionary:
	if _watching.has(place):
		return _spectator_snapshot(place)
	var viewer: Node3D = avatars[place]
	var hidden: bool = viewer.has_method("is_hidden") and viewer.is_hidden()
	var inventory: Inventory = viewer.get("inventory")
	var spot: HidingSpot = viewer.get("hiding_in")
	return {
		"ack": _acked.get(place, 0),
		"you":
		[
			viewer.global_position,
			viewer.velocity,
			viewer.rotation.y,
			_gait(viewer),
			hidden,
			viewer.get_hold_ratio(),
			inventory.count(Inventory.Kind.BOTTLE) if inventory != null else 0,
			inventory.count(Inventory.Kind.DECOY) if inventory != null else 0,
			world.spot_index(spot) if world != null else -1,
			viewer.get("held") == true,
			world.network.terminal_index(viewer.get("terminal")) if _has_network() else -1,
			world.network.camera_index(viewer) if _has_network() else -1,
		],
		"others": _seen_by(viewer),
	}


func _has_network() -> bool:
	return world != null and world.network != null


## What a spectator sees: what the teammate it watches sees, that teammate
## first. A teammate out of the game in the meantime makes way for the next.
func _spectator_snapshot(place: int) -> Dictionary:
	var watched: Node3D = _watching[place]
	if watched == null or not is_instance_valid(watched) or is_out(watched):
		watched = _next_watched(null)
		_watching[place] = watched
	var snapshot := {"ack": _acked.get(place, 0), "watch": -1, "pitch": 0.0, "others": []}
	if watched == null:
		return snapshot
	var seat := seat_of(watched)
	snapshot["watch"] = seat
	snapshot["pitch"] = watched.get_pitch() if watched.has_method("get_pitch") else 0.0
	snapshot["others"] = [_entry(seat, watched)] + _seen_by(watched)
	return snapshot


## The others a player sees, as snapshot entries: with its own eyes, or
## through the camera it watches (S-018).
func _seen_by(viewer: Node3D) -> Array:
	var camera: SecurityCamera = world.network.watched_by(viewer) if _has_network() else null
	var others := []
	for other in _entities():
		if other[1] == viewer:
			continue
		if sees(viewer, other[1]) or (camera != null and camera_sees(camera, other[1])):
			others.append(_entry(other[0], other[1]))
	return others


## Room side: whether a camera sees target; a hiding spot hides from it too.
func camera_sees(camera: SecurityCamera, target: Node3D) -> bool:
	if HidingSpot.is_hidden(target):
		return false
	var skip: Array[RID] = [target.get_rid()]
	return camera.sees(target.get_eye_position(), skip)


func _entry(seat: int, node: Node3D) -> Array:
	return [
		seat,
		node.global_position,
		node.rotation.y,
		_gait(node),
		node.get("held") == true,
		_gesture(node),
	]


## Room side: whether viewer sees target, walls and hiding spots included.
func sees(viewer: Node3D, target: Node3D) -> bool:
	var eye: Vector3 = viewer.get_eye_position()
	var aim: Vector3 = target.get_eye_position()
	if HidingSpot.is_revealed(target, eye, -viewer.global_basis.z):
		return true  # Right beside a makeshift spot, facing it (S-016, Q6).
	var target_hidden := HidingSpot.is_hidden(target)
	if target_hidden or eye.distance_to(aim) > settings.sight_range:
		return false  # No ray needed.
	var query := PhysicsRayQueryParameters3D.create(eye, aim, SIGHT_MASK)
	query.exclude = [viewer.get_rid(), target.get_rid()]
	var clear := viewer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return NetVisibility.sees(eye, -viewer.global_basis.z, aim, false, clear, settings)


## Every player and AI on the room still in the game, as [seat, node].
func _entities() -> Array:
	var found := []
	for place in avatars:
		if not is_out(avatars[place]):
			found.append([seats[place], avatars[place]])
	for seat in ai_hunted:
		if not is_out(ai_hunted[seat]):
			found.append([seat, ai_hunted[seat]])
	if ai_monster != null:
		found.append([LobbyState.MONSTER_SEAT, ai_monster])
	return found


## What its body shows: a hunted's gesture, or the monster's action.
func _gesture(node: Node3D) -> int:
	if node.has_method("get_gesture"):
		return node.get_gesture()
	if "body_action" in node:
		return node.body_action
	return 0


func _gait(node: Node3D) -> int:
	if node.has_method("get_gait"):
		return node.get_gait()
	return 0


## Client side: the network measures for the F3 overlay (T-303), "" on the room.
func describe() -> String:
	if is_room:
		return ""
	return (
		"NET gap %.2f m, worst %.2f m (%d s)\nNET map %d B, %d in %d s, room %.0f fps"
		% [
			last_error,
			maxf(recent_worst_error, _window_worst),
			NET_STATS_WINDOW,
			world_bytes,
			world_count,
			NET_STATS_WINDOW,
			room_fps,
		]
	)


## Client side: reads a snapshot from the room.
func apply_snapshot(snapshot: Dictionary) -> void:
	if own == null:
		return
	if snapshot.has("watch"):
		_watch(snapshot["watch"], snapshot.get("pitch", 0.0))
	var you: Array = snapshot.get("you", [])
	if you.size() >= 1:
		var server_position: Vector3 = you[0]
		var ack: int = snapshot.get("ack", 0)
		if not prediction.started or (ack > prediction.floor_seq and not prediction.knows(ack)):
			# First snapshot, or a frame too old to compare: go where the room has us.
			own.global_position = server_position
			prediction.restart(own.commands.seq)
		elif ack > prediction.floor_seq:
			last_error = prediction.error_at(ack, server_position).length()
			worst_error = maxf(worst_error, last_error)
			_window_worst = maxf(_window_worst, last_error)
			own.global_position += prediction.reconcile(ack, server_position)
		if you.size() >= 9:
			_apply_own_state(you)
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	for entry: Array in snapshot.get("others", []):
		var seat: int = entry[0]
		seen[seat] = true
		var puppet := _puppet(seat)
		if not puppet.visible:
			puppet.buffer = SnapshotBuffer.new()  # Back in sight: no slide from where it was lost.
			puppet.restart_motion()
			puppet.visible = true
		puppet.buffer.push(now, entry[1], entry[2])
		if entry.size() >= 4:
			puppet.gait = entry[3]
		puppet.set_down(entry.size() >= 5 and entry[4])
		puppet.gesture = entry[5] if entry.size() >= 6 else 0
	for seat in puppets:
		if not seen.has(seat):
			puppets[seat].visible = false


## Client side: plays an event from the room.
func apply_event(event: Array) -> void:
	if event.is_empty():
		return
	match event[0]:
		Event.NOISE when event.size() >= 4:
			var type: NoiseEvent.Type = event[1]
			NoiseBus.emit_noise(type, event[2], event[3], null, event.size() >= 5 and event[4])
			if world != null:
				world.voice(type, event[2])
		Event.SCAN when event.size() == 3:
			var index: int = event[1]
			if index >= 0 and index < buildings.size():
				buildings[index].scanned = event[2]
		Event.CAUGHT when event.size() == 3:
			caught_reported.emit(event[1], event[2])
		Event.WORLD when event.size() == 2 and world != null:
			world_bytes = var_to_bytes(event).size()
			_window_worlds += 1
			world_total += 1
			world.apply(event[1])
		Event.CLOCK when event.size() == 2 and world != null:
			world.apply_clock(event[1])
			var clock: Array = event[1]
			if clock.size() >= 4:
				room_fps = clock[3]
		Event.BOTTLE when event.size() == 3:
			var bottle: ThrownBottle = _spawn_copy(BOTTLE_SCENE, event[1])
			bottle.linear_velocity = event[2]
		Event.DECOY when event.size() == 2:
			_spawn_copy(DECOY_SCENE, event[1])
		Event.CRUSH when event.size() == 2:
			_crush_near(event[1])


## Client side, spectator (T-107): the room sends what a teammate sees. The
## player's own avatar stops; SpectatorView shows the teammate's view.
func _watch(seat: int, pitch: float) -> void:
	watched_seat = seat
	watched_pitch = pitch
	if is_spectator:
		return
	is_spectator = true
	own.process_mode = Node.PROCESS_MODE_DISABLED
	own.visible = false
	var body := own.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body != null:
		body.disabled = true
	spectating.emit()


## Client side: what the room says of the player's own avatar beyond where it
## is: progress of what it holds, what it carries, where it hides, whether it
## is captured.
func _apply_own_state(you: Array) -> void:
	own.remote_hold_ratio = you[5]
	if own is Player and you.size() >= 10:
		(own as Player).held = you[9]
	var inventory: Inventory = own.get("inventory")
	if inventory != null:
		inventory.set_count(Inventory.Kind.BOTTLE, you[6])
		inventory.set_count(Inventory.Kind.DECOY, you[7])
	if not own is Player or world == null:
		return
	var player := own as Player
	if you.size() >= 12 and world.network != null:
		_apply_network_state(player, you[10], you[11])
	var index: int = you[8]
	var spot: HidingSpot = world.spots[index] if index >= 0 and index < world.spots.size() else null
	if spot == player.hiding_in:
		return
	if player.hiding_in != null:
		player.hiding_in.occupant = null
		player.leave_hiding()
	if spot != null:
		spot.occupant = player
		player.hide_in(spot)
	prediction.restart(player.commands.seq)  # Moved by the room, not by its steps.


## Client side: the terminal the room has the player sit at, and the camera
## it watches through (S-018).
func _apply_network_state(player: Player, terminal_at: int, camera_at: int) -> void:
	var network := world.network
	var terminal: Terminal = (
		network.terminals[terminal_at]
		if terminal_at >= 0 and terminal_at < network.terminals.size()
		else null
	)
	if terminal != player.terminal:
		player.terminal = terminal
		prediction.restart(player.commands.seq)  # Moved by the room, not by its steps.
	var camera: SecurityCamera = (
		network.cameras[camera_at]
		if camera_at >= 0 and camera_at < network.cameras.size()
		else null
	)
	if camera != player.watching:
		player.watching = camera


func _spawn_copy(scene: PackedScene, at: Vector3) -> Node3D:
	var copy: Node3D = scene.instantiate()
	get_parent().add_child(copy)
	copy.global_position = at
	return copy


func _crush_near(at: Vector3) -> void:
	var nearest: Decoy = null
	var best := NetWorld.VOICE_REACH
	for node in get_tree().get_nodes_in_group(Decoy.GROUP):
		var decoy := node as Decoy
		if decoy != null and decoy.global_position.distance_to(at) <= best:
			nearest = decoy
			best = decoy.global_position.distance_to(at)
	if nearest != null:
		nearest.crush()


func _puppet(seat: int) -> NetPuppet:
	if not puppets.has(seat):
		var puppet := NetPuppet.new()
		puppet.name = "Puppet%d" % seat
		puppet.seat = seat
		puppet.kind = (
			NetPuppet.Kind.MONSTER if seat == LobbyState.MONSTER_SEAT else NetPuppet.Kind.HUNTED
		)
		puppet.visible = false
		get_parent().add_child(puppet)
		puppets[seat] = puppet
	return puppets[seat]
