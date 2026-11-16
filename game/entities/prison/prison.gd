class_name Prison
extends Node3D
## The prison of an online game (spec S-018, part A): its cages are its Cage
## children. On the room, a captured hunted is locked in a free cage after the
## black screen (Q2) and waits there: its stay is counted down, the clock
## stopped while the monster is near (Q6); at zero it is out. A free teammate
## frees it on site by holding "interact" at the grille (CaptureState, Q3), the
## guard's terminal opens every cage at once (Q4).
## Solo never uses it. On an online client it only shows what the room says.

## Room side: the stay of the hunted in a cage is over.
signal timed_out(hunted: Node3D)
## The guard's terminal opened every cage, with the bell (Q4).
signal opened_all

## Monsters are in this group (AI and playable), for the clock (Q6).
const MONSTERS_GROUP := &"monsters"
## Where the bell rings, above the middle cage.
const BELL_HEIGHT := 2.0

@export var settings: PrisonSettings

## Online client: what the room says decides.
var mirror := false
var cages: Array[Cage] = []


func _ready() -> void:
	for child in get_children():
		if child is Cage:
			cages.append(child)


## The prison of a map, or null.
static func of(map: Node) -> Prison:
	var found := map.find_children("*", "Prison", true, false)
	return found[0] if not found.is_empty() else null


func free_cage() -> Cage:
	for cage in cages:
		if cage.is_free():
			return cage
	return null


## The cage a hunted waits in, or null.
func cage_of(hunted: Node3D) -> Cage:
	for cage in cages:
		if cage.occupant == hunted:
			return cage
	return null


## Locks a hunted caught this many times in a free cage, standing inside,
## facing the corridor. Returns the cage, or null if none is free.
func jail(hunted: Node3D, seat: int, catches: int) -> Cage:
	var cage := free_cage()
	if cage == null:
		return null
	cage.lock(hunted, seat, PrisonRules.stay_for(catches, settings))
	hunted.global_position = cage.inside_point()
	hunted.rotation.y = cage.inside_yaw()
	if hunted is CharacterBody3D:
		(hunted as CharacterBody3D).velocity = Vector3.ZERO
	return cage


## The hunted leaves its cage: freed (the gate opens) or out (it stays shut).
func release(hunted: Node3D, open: bool) -> void:
	var cage := cage_of(hunted)
	if cage != null:
		cage.empty(open)


## The guard's terminal (Q4): the bell rings (a BELL noise, played by the
## ears of those who hear it) and every occupied cage opens. Returns the
## hunted freed; their capture rule frees them.
func open_all() -> Array[Node3D]:
	var freed: Array[Node3D] = []
	for cage in cages:
		if cage.occupant != null:
			freed.append(cage.occupant)
	NoiseBus.emit_noise(NoiseEvent.Type.BELL, bell_position(), settings.bell_range, self)
	opened_all.emit()
	return freed


func bell_position() -> Vector3:
	if cages.is_empty():
		return global_position
	return cages[cages.size() / 2].global_position + Vector3.UP * BELL_HEIGHT


func _physics_process(delta: float) -> void:
	if mirror:
		return
	for cage in cages:
		if cage.occupant == null:
			continue
		cage.time_left = PrisonRules.tick(
			cage.time_left, delta, _monster_distance(cage.global_position), settings
		)
		if cage.time_left <= 0.0:
			var hunted := cage.occupant
			cage.empty(false)
			timed_out.emit(hunted)


## Distance to the nearest monster, -1 if none.
func _monster_distance(at: Vector3) -> float:
	var best := -1.0
	for node in get_tree().get_nodes_in_group(MONSTERS_GROUP):
		var distance: float = (node as Node3D).global_position.distance_to(at)
		if best < 0.0 or distance < best:
			best = distance
	return best


## Room side: [[seat inside or -1, gate open, whole seconds left], ...].
func state() -> Array:
	var values := []
	for cage in cages:
		values.append([cage.occupant_seat, cage.is_open, ceili(cage.time_left)])
	return values


## Client side: shows the room's cages.
func apply(values: Array) -> void:
	for i in mini(values.size(), cages.size()):
		var entry: Array = values[i]
		if entry.size() >= 3:
			cages[i].mirror(entry[0], entry[1], entry[2])


## Client side: the cage this seat waits in, or null.
func cage_of_seat(seat: int) -> Cage:
	for cage in cages:
		if cage.occupant_seat == seat:
			return cage
	return null
