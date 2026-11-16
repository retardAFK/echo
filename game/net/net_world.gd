class_name NetWorld
extends RefCounted
## The things of a map that change during an online game (S-010, T-099): fuse
## boxes, pickups (bottles and alarm clocks), car alarms, hiding spots, doors
## (S-016), the prison (S-018) and the game loop. Both sides list them in the
## same order from the same map, before anything is drawn or taken, so an
## index means the same thing everywhere.
## The room sends state() when it changes; a client shows it with apply(). What
## a hunted could not know is never in it: who hides where stays in the room.

## Noises whose maker plays its own sound (PlayerEars.SELF_VOICED) and that a
## client voices on the nearest thing of the kind, within this distance (m).
const VOICE_REACH := 3.0

var boxes: Array[FuseBox] = []
var pickups: Array[Pickup] = []
var alarms: Array[CarAlarm] = []
var spots: Array[HidingSpot] = []
var doors: Array[Door] = []
var transformer: Transformer
var prison: Prison
var game_loop: GameLoop


func _init(map: Node) -> void:
	for node in map.find_children("*", "", true, false):
		if node is FuseBox:
			boxes.append(node)
		elif node is Pickup:
			pickups.append(node)
		elif node is CarAlarm:
			alarms.append(node)
		elif node is HidingSpot:
			spots.append(node)
		elif node is Door:
			doors.append(node)
		elif node is Transformer:
			transformer = node
		elif node is Prison:
			prison = node


## Room side: [fuse in each box, each pickup still there, state of each car
## alarm, values of the game loop, where the dropped fuses lie (T-107),
## whether each door is open (S-016), the cages of the prison (S-018)].
func state() -> Array:
	var fuses := []
	for box in boxes:
		fuses.append(box.has_fuse)
	var present := []
	for pickup in pickups:
		present.append(_present(pickup))
	var ringing := []
	for alarm in alarms:
		ringing.append(alarm.state)
	var open := []
	for door in doors:
		open.append(door.is_open)
	return [
		fuses,
		present,
		ringing,
		game_loop.mirror_values() if game_loop != null else [],
		game_loop.drop_positions() if game_loop != null else [],
		open,
		prison.state() if prison != null else [],
	]


## Client side: makes the map look like the room's.
func apply(values: Array) -> void:
	if values.size() < 4:
		return
	var fuses: Array = values[0]
	for i in mini(fuses.size(), boxes.size()):
		if boxes[i].has_fuse != fuses[i]:
			boxes[i].set_fuse(fuses[i])
	var present: Array = values[1]
	for i in mini(present.size(), pickups.size()):
		if not present[i] and _present(pickups[i]):
			pickups[i].queue_free()
	var ringing: Array = values[2]
	for i in mini(ringing.size(), alarms.size()):
		# Started in the room: it rings here too, then rests on its own clock.
		if ringing[i] == CarAlarm.State.RINGING and alarms[i].state == CarAlarm.State.IDLE:
			alarms[i].interact(null)
	if game_loop != null:
		game_loop.apply_values(values[3])
		if values.size() >= 5:
			game_loop.apply_drops(values[4])
	if values.size() >= 6:
		var open: Array = values[5]
		for i in mini(open.size(), doors.size()):
			doors[i].mirror(open[i])  # Swings with its sound, like in the room.
	if values.size() >= 7 and prison != null:
		prison.apply(values[6])


## Client side: the sound of a noise made in the room by something of the map
## that plays its own sound (a fuse box, the transformer, a hiding spot).
func voice(type: NoiseEvent.Type, at: Vector3) -> void:
	var candidates: Array = []
	match type:
		NoiseEvent.Type.FUSE:
			candidates = boxes + (game_loop.drops if game_loop != null else [])
		NoiseEvent.Type.REPAIR:
			candidates = [transformer] if transformer != null else []
		NoiseEvent.Type.HIDE:
			candidates = spots
	var best: Node3D = null
	var best_distance := VOICE_REACH
	for node: Node3D in candidates:
		var distance := node.global_position.distance_to(at)
		if type == NoiseEvent.Type.REPAIR or distance <= best_distance:
			best = node
			best_distance = distance
	if best != null:
		best.voice()


## Index of a hiding spot, -1 if none.
func spot_index(spot: HidingSpot) -> int:
	return spots.find(spot) if spot != null else -1


static func _present(pickup: Variant) -> bool:  # Maybe freed: no class check.
	return is_instance_valid(pickup) and not pickup.is_queued_for_deletion()
