class_name BossFire
extends Node
## The boss's fireballs (spec S-025, T-413): BossKit throws one (right click
## for a played boss, at range for the AI), a Fireball flies and bursts; each
## standing hunted within fireball_radius of the burst loses
## fireball_damage points (a roll's shield saves it) and is thrown back.
## The burst shows an orange ball of fire that swells, with its boom.
## Online: the room sends FIREBALL (where from, velocity: the clients show a
## harmless copy) and BLAST (where it burst: the copy nearest goes, and the
## burst shows). A child of VersusMode; remove it and the boss has no fire.

const BURST := Color(1.0, 0.5, 0.1, 0.85)
const BURST_CORE := Color(1.0, 0.9, 0.5, 0.9)
const BURST_LIFE := 0.45

var mode: VersusMode
## The copies flying on a client, for BLAST to take down.
var _shown: Array[Fireball] = []


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "BossFire"


## Throws a fireball from at with velocity: harmful on the room (or
## offline), a copy that only shows on a client. Thrower: what it never hits.
func cast(at: Vector3, velocity: Vector3, thrower: CollisionObject3D = null) -> Fireball:
	var ball := Fireball.new()
	ball.fire = self
	ball.velocity = velocity
	ball.thrower = thrower
	ball.harmful = not mode.mirror
	mode.add_child(ball)
	ball.global_position = at
	if mode.sounds != null:
		mode.sounds.at_point(&"fireball_cast", at)
	if mode.mirror:
		_shown = _shown.filter(func(each: Fireball) -> bool: return is_instance_valid(each))
		_shown.append(ball)
	elif mode.link != null:
		mode.link.send([VersusNet.Event.FIREBALL, at, velocity])
	return ball


## The first standing hunted the ball, going from from to to, passes within
## a third of the burst's radius of (its chest), or null.
func hunted_near(from: Vector3, to: Vector3) -> Variant:
	var reach := mode.settings.fireball_radius / 3.0
	for kit in mode.hunters:
		if not kit.vitals.is_standing():
			continue
		var chest := kit.body.global_position + Vector3.UP
		var closest := Geometry3D.get_closest_point_to_segment(chest, from, to)
		if closest.distance_to(chest) <= reach:
			return closest
	return null


## The ball bursts at point (the room): the hunted around are hurt and
## thrown back, then everyone sees the burst.
func explode(point: Vector3) -> void:
	var settings := mode.settings
	for kit in mode.hunters:
		if not kit.vitals.is_standing():
			continue
		var offset := kit.body.global_position + Vector3.UP - point
		if offset.length() > settings.fireball_radius:
			continue
		if kit.take_blow(settings.fireball_damage):
			var away := Vector3(offset.x, 0.0, offset.z)
			if away.length() < 0.1:
				away = Vector3.FORWARD
			kit.knock(away.normalized() * settings.fireball_knock)
	NoiseBus.emit_noise(NoiseEvent.Type.SHOT, point, settings.fireball_radius * 4.0, null)
	burst(point)
	if mode.link != null and not mode.mirror:
		mode.link.send([VersusNet.Event.BLAST, point])


## The burst at point: a swelling ball of fire and its boom; on a client,
## the copy flying nearest to it goes.
func burst(point: Vector3) -> void:
	var radius := mode.settings.fireball_radius
	for part: Array in [[radius, BURST], [radius * 0.55, BURST_CORE]]:
		var ball := FlashBurst.new(part[0], part[1], BURST_LIFE)
		mode.add_child(ball)
		ball.global_position = point
	if mode.sounds != null:
		mode.sounds.at_point(&"fireball_boom", point)
	if not mode.mirror:
		return
	var nearest: Fireball
	for ball in _shown:
		if not is_instance_valid(ball):
			continue
		if nearest == null or _gap(ball, point) < _gap(nearest, point):
			nearest = ball
	if nearest != null:
		_shown.erase(nearest)
		nearest.queue_free()


static func _gap(ball: Fireball, point: Vector3) -> float:
	return ball.global_position.distance_to(point)
