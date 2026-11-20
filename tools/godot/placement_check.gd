class_name PlacementCheck
extends RefCounted
## Checks that the network's objects touch the map (spec S-020, T-325, piste
## L2): every camera, terminal, loudspeaker and relay switch must be within
## max_gap of a wall, a floor or a mast. Errors like the camera hanging in
## the air at the ramp (T-315) or the keypad standing away from the
## transformer (T-316) then fail the tests instead of coming back unseen.
## tests/test_tilleuls_placements.gd runs it on the cité in the CI.
##
## To check a new kind of object: add its class to the list in objects().

## Farthest an object may stand from a wall or a floor, in meters.
const MAX_GAP := 0.3
## Rays from the object's origin: 16 around it, flat, and one down.
const AROUND := 16
## How far the rays look, in meters (beyond, the gap is reported as this).
const REACH := 3.0
## The map's walls, its ground and floors, the masts (MapKit layers).
const MASK := 1 | (1 << 1)


## The objects to check under root: cameras, terminals, loudspeakers, relays.
static func objects(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in root.find_children("*", "", true, false):
		if node is SecurityCamera or node is Terminal or node is Loudspeaker or node is RelaySwitch:
			found.append(node)
	return found


## The gap between an object's origin and the nearest wall or floor, in
## meters (REACH when nothing is that close). Its own bodies are skipped.
static func gap(object: Node3D) -> float:
	var space := object.get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for node in [object] + object.find_children("*", "", true, false):
		if node is CollisionObject3D:
			skip.append((node as CollisionObject3D).get_rid())
	var from := object.global_position
	var directions: Array[Vector3] = [Vector3.DOWN]
	for i in AROUND:
		directions.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * i / AROUND))
	var best := REACH
	for direction in directions:
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * REACH, MASK)
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit:
			best = minf(best, from.distance_to(hit.position))
	return best


## Every object further than MAX_GAP from a wall or a floor, as lines
## "Name at (x, y, z): 0.45 m".
static func offenders(root: Node) -> Array[String]:
	var lines: Array[String] = []
	for object in objects(root):
		var each := gap(object)
		if each > MAX_GAP:
			lines.append("%s at %s: %.2f m" % [object.name, object.global_position, each])
	return lines
