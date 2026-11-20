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
##
## The passages to climb over (T-340) have their own check, vault_offenders():
## a wall below their top, open above it, and free floor to land on both sides.

## Farthest an object may stand from a wall or a floor, in meters.
const MAX_GAP := 0.3
## Rays from the object's origin: 16 around it, flat, and one down.
const AROUND := 16
## How far the rays look, in meters (beyond, the gap is reported as this).
const REACH := 3.0
## The map's walls, its ground and floors, the masts (MapKit layers).
const MASK := 1 | (1 << 1)
## A body landing over a passage: a capsule this wide and tall, its foot
## LANDING_LIFT above the floor (steps and kerbs under it are fine).
const LANDING_RADIUS := 0.3
const LANDING_HEIGHT := 1.6
const LANDING_LIFT := 0.15


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


## The passages to climb over under root.
static func vaults(root: Node) -> Array[Vault]:
	var found: Array[Vault] = []
	for node in root.find_children("*", "", true, false):
		if node is Vault:
			found.append(node)
	return found


## Every passage to climb over (Vault) that does not sit on a wall or has
## no room to land on a side, as lines "Vault3 at (x, y, z): why".
static func vault_offenders(root: Node) -> Array[String]:
	var lines: Array[String] = []
	for vault in vaults(root):
		for why in vault_faults(vault):
			lines.append("%s at %s: %s" % [vault.name, vault.global_position, why])
	return lines


## What is wrong with a passage: no wall below its top, a wall above it, or
## a side without free floor to land on. Empty when it is right.
static func vault_faults(vault: Vault) -> Array[String]:
	var faults: Array[String] = []
	var space := vault.get_world_3d().direct_space_state
	var away := vault.thickness / 2.0 + vault.settings.landing_distance
	var cross := func(height: float) -> bool:
		var a := vault.to_global(Vector3(0, height, -away))
		var b := vault.to_global(Vector3(0, height, away))
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, MASK)).is_empty()
	if not cross.call(vault.top / 2.0):
		faults.append("no wall below its top")
	if cross.call(vault.top + 0.3):
		faults.append("a wall above its top")
	var body := CapsuleShape3D.new()
	body.radius = LANDING_RADIUS
	body.height = LANDING_HEIGHT
	for side: float in [-1.0, 1.0]:
		var land := vault.to_global(Vector3(0, 0, side * away))
		var down := PhysicsRayQueryParameters3D.create(
			land + Vector3.UP * 0.5, land + Vector3.DOWN * 0.5, MASK
		)
		if space.intersect_ray(down).is_empty():
			faults.append("no floor on side %+d" % side)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = body
		query.collision_mask = MASK
		var lift := LANDING_HEIGHT / 2.0 + LANDING_LIFT
		query.transform = Transform3D(Basis.IDENTITY, land + Vector3.UP * lift)
		if not space.intersect_shape(query, 1).is_empty():
			faults.append("no room to land on side %+d" % side)
	return faults
