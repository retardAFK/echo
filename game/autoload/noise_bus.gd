extends Node
## Central noise service (constitution 2.4, spec S-002).
## Every noise source goes through emit_noise; listeners connect to noise_emitted.
## A noise is masked (lost for the monster) in a ventilation zone (S-014) or
## near the railway while a train passes (AmbientTrain, S-020, T-332).

signal noise_emitted(event: NoiseEvent)

## Physics layer 2, named "walls" in the project settings: what muffles noise.
const WALLS_COLLISION_MASK := 1 << 1

var settings: NoiseSettings = preload("res://game/data/noise_settings.tres")
## On an online client (S-010, T-099) the world only mirrors the room's, so
## only the local avatar (local_source) and the room (no source) make noise:
## the room already sends what is heard.
var mirror := false
var local_source: Node
## A gust of wind blows over the cité (S-012, T-144): set by CityWind.
var wind_gust := false


## Announces a noise to every listener and returns it. by_monster is for a
## copy of a noise the monster made somewhere else (an online client).
func emit_noise(
	type: NoiseEvent.Type,
	position: Vector3,
	noise_range: float,
	source: Node = null,
	by_monster := false
) -> NoiseEvent:
	noise_range = wind_cut(position, noise_range)
	var event := NoiseEvent.new(type, position, noise_range, source)
	event.by_monster = by_monster or (source != null and Door.is_monster(source))
	if noise_range <= settings.ventilation_mask and is_inside_tree():
		event.masked = Ventilation.covers(get_tree(), position)
	if not event.masked and is_inside_tree():
		event.masked = AmbientTrain.covers(get_tree(), position)  # S-020, T-332.
	if mirror and source != null and source != local_source:
		return event
	noise_emitted.emit(event)
	return event


## A small noise outdoors during a gust carries less far (S-012, Q8).
func wind_cut(position: Vector3, noise_range: float) -> float:
	if not wind_gust or noise_range > settings.wind_small_range or not is_inside_tree():
		return noise_range
	if Building.any_contains(get_tree(), position):
		return noise_range
	return noise_range * settings.wind_factor


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
