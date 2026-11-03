extends Node
## Central noise service (constitution 2.4, spec S-002).
## Every noise source goes through emit_noise; listeners connect to noise_emitted.

signal noise_emitted(event: NoiseEvent)

## Physics layer 2, named "walls" in the project settings: what muffles noise.
const WALLS_COLLISION_MASK := 1 << 1

var settings: NoiseSettings = preload("res://game/data/noise_settings.tres")


## Announces a noise to every listener and returns it.
func emit_noise(
	type: NoiseEvent.Type, position: Vector3, noise_range: float, source: Node = null
) -> NoiseEvent:
	var event := NoiseEvent.new(type, position, noise_range, source)
	noise_emitted.emit(event)
	return event


## Counts the distinct walls crossed by a straight line, up to max_walls_counted.
func walls_between(from: Vector3, to: Vector3) -> int:
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, WALLS_COLLISION_MASK)
	var excluded: Array[RID] = []
	var walls := 0
	while walls < settings.max_walls_counted:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		walls += 1
		excluded.append(hit["rid"])
	return walls


## Range of a noise as perceived from a listener position, walls included.
func perceived_range(event: NoiseEvent, listener_position: Vector3) -> float:
	var walls := walls_between(event.position, listener_position)
	return NoiseMath.perceived_range(event.noise_range, walls, settings)


## Whether a listener at this position hears the noise.
func can_hear(event: NoiseEvent, listener_position: Vector3) -> bool:
	var distance := event.position.distance_to(listener_position)
	if distance > event.noise_range:
		return false  # Too far even in open space: skip the raycasts.
	return distance <= perceived_range(event, listener_position)
