class_name Ping
extends Node3D
## A team mark (spec S-020, T-328, piste A1): a hunted presses "ping" (G or
## the middle button) and its teammates see "Monstre" or "Ici" there, with the
## distance, for settings.time seconds (PingMarkers). No voice in the game:
## this is how the hunted talk, and the AI hunted understand it too (a
## "monstre ici" mark near one makes it run from the monster).
## Made by the Player (in solo and on the room); online, the room sends it to
## the hunted only (NetGame), never to the monster, and the clients copy it.

enum Kind { MONSTER, HERE }

const GROUP := &"pings"

@export var settings: PingSettings
var kind := Kind.HERE
## Seconds it still shows.
var left := 0.0
## Online client: a copy of the room's, it warns nobody.
var mirror := false


func _ready() -> void:
	add_to_group(GROUP)
	left = settings.time
	if kind == Kind.MONSTER and not mirror:
		for prey: Node in get_tree().get_nodes_in_group(Prey.GROUP):
			(prey as Prey).warn_of_monster(global_position, settings.ai_flee_range)


func _process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		queue_free()


## What a hunted marks, looking from eye along forward: the monster when the
## aim passes within monster_radius of one it sees (its position), else the
## first thing the aim meets within reach. Empty when it meets nothing.
## Returns [Kind, position].
static func aim(
	eye: Vector3,
	forward: Vector3,
	monsters: Array,
	space: PhysicsDirectSpaceState3D,
	skip: Array[RID],
	p_settings: PingSettings
) -> Array:
	var end := eye + forward * p_settings.reach
	var query := PhysicsRayQueryParameters3D.create(eye, end, NetGame.SIGHT_MASK)
	query.exclude = skip
	var hit := space.intersect_ray(query)
	var reach := eye.distance_to(hit.position) if hit else p_settings.reach
	for monster: Node3D in monsters:
		var body: Vector3 = monster.global_position + Vector3.UP
		var along := (body - eye).dot(forward)
		if along < 0.0 or along > reach + p_settings.monster_radius:
			continue
		if (eye + forward * along).distance_to(body) <= p_settings.monster_radius:
			return [Kind.MONSTER, monster.global_position]
	if not hit:
		return []
	return [Kind.HERE, hit.position]
