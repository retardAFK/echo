class_name Gurney
extends AnimatableBody3D
## A hospital gurney (spec S-014, Q7). A hunted takes it with "interact" and
## pushes it in front of it (a ROLL noise of gurney_walk_range, or
## gurney_run_range when run); "interact" again lets go. Left across a door
## or the corridor, it blocks the way (world layer: bodies, not the sight nor
## the noise). The monster shoves it over by holding "interact" for
## gurney_shove_hold, or by running into it: a ROLL noise of
## gurney_shove_range, and it lies on its side out of the way for good.

const GROUP := &"gurneys"
## Collision layer and mask: the world (bodies bump into it), and it bumps
## into the world and the walls when pushed.
const LAYER := 1
const MASK := 3

@export var settings: HospitalSettings

## The hunted pushing it, or null.
var pusher: Node3D
## Shoved over by the monster: out of the way, nobody takes it any more.
var tipped := false
## Online client: the room moves it.
var mirror := false

var _shove: HoldProgress
var _next_roll := 0.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)
	add_to_group(Terminal.MONSTER_GROUP)
	sync_to_physics = false
	collision_layer = LAYER
	collision_mask = MASK
	_shove = HoldProgress.new(settings.gurney_shove_hold)
	DrawRange.limit(self, DrawRange.INDOOR)


func can_interact(from: Vector3) -> bool:
	if tipped or pusher != null:
		return false
	var gap := global_position - from
	return Vector2(gap.x, gap.z).length() <= settings.gurney_reach and absf(gap.y) < 1.5


## A hunted takes a free one; the monster shoves one over.
func wanted_by(_who: Node) -> bool:
	return not tipped and pusher == null


func get_prompt() -> String:
	return "HUD_INTERACT_GURNEY" if wanted_by(null) else ""


func get_prompt_for(who: Node) -> String:
	if not wanted_by(who):
		return ""
	return "HUD_MONSTER_SHOVE_GURNEY" if Door.is_monster(who) else "HUD_INTERACT_GURNEY"


## Taken by a hunted.
func interact(who: Node = null) -> void:
	if who == null or Door.is_monster(who) or not wanted_by(who):
		return
	pusher = who as Node3D
	if who is PhysicsBody3D:
		add_collision_exception_with(who)
		(who as PhysicsBody3D).add_collision_exception_with(self)
	if "pushing" in who:
		who.set("pushing", self)  # Pushed in front until "interact" again.
	_next_roll = 0.0


## Let go where it stands.
func drop() -> void:
	if pusher == null:
		return
	var who := pusher
	pusher = null
	if is_instance_valid(who):
		if who is PhysicsBody3D:
			remove_collision_exception_with(who)
			(who as PhysicsBody3D).remove_collision_exception_with(self)
		if "pushing" in who and who.get("pushing") == self:
			who.set("pushing", null)


func hold(who: Node, delta: float) -> void:
	if Door.is_monster(who) and wanted_by(who) and _shove.advance(delta):
		shove(who)


func release(_who: Node) -> void:
	_shove.release()


func get_hold_ratio() -> float:
	return _shove.get_ratio()


## Shoved over by the monster: on its side, out of the way, for good.
func shove(who: Node = null) -> void:
	if tipped:
		return
	drop()
	tipped = true
	collision_layer = 0
	_show_tipped()
	NoiseBus.emit_noise(NoiseEvent.Type.ROLL, global_position, settings.gurney_shove_range, who)


## Rolls to where the hunted pushing it wants it: gurney_lead in front of its
## feet, along its heading. Slips out of its hands if a wall holds it back.
## Returns where it got.
func follow(delta: float) -> Vector3:
	if pusher == null or mirror:
		return global_position
	var heading := -pusher.global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	var wanted := pusher.global_position + heading * settings.gurney_lead
	wanted.y = global_position.y
	var before := global_position
	var motion := wanted - before
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	var target_yaw := atan2(-heading.x, -heading.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 8.0))
	var speed := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	speed /= maxf(delta, 0.0001)
	_roll(speed, delta)
	if global_position.distance_to(wanted) > settings.gurney_slip:
		drop()  # Stuck against a wall or a jamb.
	return global_position


func _roll(speed: float, delta: float) -> void:
	if speed < 0.3:
		return
	_next_roll -= delta
	if _next_roll > 0.0:
		return
	_next_roll = settings.roll_interval
	var noise_range := (
		settings.gurney_run_range
		if speed >= settings.gurney_run_speed
		else settings.gurney_walk_range
	)
	NoiseBus.emit_noise(NoiseEvent.Type.ROLL, global_position, noise_range, self)


## The gurney nearest a body walking from `from` along `direction`, standing
## upright within `reach` in front of it, or null.
static func ahead(tree: SceneTree, from: Vector3, direction: Vector3, reach: float) -> Gurney:
	var flat_direction := Vector2(direction.x, direction.z)
	if flat_direction.length_squared() < 0.0001:
		return null
	flat_direction = flat_direction.normalized()
	var best: Gurney = null
	var best_distance := reach
	for node in tree.get_nodes_in_group(GROUP):
		var gurney := node as Gurney
		if gurney.tipped or absf(gurney.global_position.y - from.y) > 1.5:
			continue
		var flat := Vector2(gurney.global_position.x - from.x, gurney.global_position.z - from.z)
		var distance := flat.length()
		if distance > best_distance:
			continue
		if distance > 0.01 and flat_direction.dot(flat / distance) < 0.3:
			continue
		best = gurney
		best_distance = distance
	return best


## Online: [x, y, z, yaw, tipped].
func state() -> Array:
	var at := global_position
	return [
		snappedf(at.x, 0.01),
		snappedf(at.y, 0.01),
		snappedf(at.z, 0.01),
		snappedf(rotation.y, 0.01),
		tipped
	]


## Online client: where the room says it is.
func mirror_state(values: Array) -> void:
	global_position = Vector3(values[0], values[1], values[2])
	rotation.y = values[3]
	if values[4] and not tipped:
		tipped = true
		collision_layer = 0
		_show_tipped()


func _show_tipped() -> void:
	_model.rotation.z = PI / 2.0
	_model.position.y = 0.45
