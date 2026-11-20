class_name CanWire
extends Node3D
## A string of tin cans the hunted stretched across a passage (S-020, T-333,
## piste R5). Once armed, the monster's feet crossing the string yank it: the
## cans rattle, a noise heard far by the hunted, who learn the monster went
## by. It only rattles once. The hunted step over it; the monster can see it
## and go around. The string runs along the node's local X axis, centred on it:
## the player places it across the way it faces. Online, only the room yanks
## it (mirror on the clients' copies, which only play the rattle).

signal rattled

## Group of the can wires placed in the world, for the monsters.
const GROUP := &"can_wires"
## Height of the string above the ground, in meters.
const HEIGHT := 0.15

@export var settings: RuseSettings

## Seconds before it can rattle, so the one who placed it can step away.
var arm_left := 0.0
var done := false
## A client's copy of the room's wire: the room says when it rattles.
var mirror := false

@onready var _rattle: AudioStreamPlayer3D = $Rattle
@onready var _string: MeshInstance3D = $Model/String
@onready var _cans: Array[Node3D] = [$Model/CanLeft, $Model/CanRight]


## Yanks every armed wire whose string a monster's feet are on. Returns how
## many rattled.
static func yank_near(monster: Node3D) -> int:
	var count := 0
	for node in monster.get_tree().get_nodes_in_group(GROUP):
		var wire := node as CanWire
		if wire != null and wire.is_armed() and wire.crossed_by(monster.global_position):
			wire.rattle(monster)
			count += 1
	return count


func _ready() -> void:
	add_to_group(GROUP)
	RetroSurface.apply_to(self, RetroSurface.DEFAULT_SETTINGS)
	arm_left = settings.can_wire_arm_time
	_rattle.max_distance = settings.can_wire_sound_distance
	var half := settings.can_wire_length / 2.0
	_string.scale.x = settings.can_wire_length
	_cans[0].position.x = -half
	_cans[1].position.x = half


func _physics_process(delta: float) -> void:
	arm_left = maxf(arm_left - delta, 0.0)


func is_armed() -> bool:
	return not done and not mirror and arm_left <= 0.0


## The two ends of the string, in world space.
func ends() -> Array[Vector3]:
	var half := global_basis.x.normalized() * settings.can_wire_length / 2.0
	return [global_position - half, global_position + half]


## True if feet at this world position stand on the string (flat distance).
func crossed_by(feet: Vector3) -> bool:
	var points := ends()
	var flat := Vector3(feet.x, points[0].y, feet.z)
	var closest := Geometry3D.get_closest_point_to_segment(flat, points[0], points[1])
	return flat.distance_to(closest) <= settings.can_wire_trigger_distance


## The cans rattle (once): the noise for the hunted when a monster yanked it
## (none on a client's copy, the room sent it). Returns whether it rattled.
func rattle(monster: Node = null) -> bool:
	if done:
		return false
	done = true
	_string.visible = false  # Snapped; the cans lie where they fell.
	SoundSpace.play(_rattle)
	if monster != null:
		NoiseBus.emit_noise(
			NoiseEvent.Type.CANS,
			global_position + Vector3.UP * HEIGHT,
			settings.can_wire_range,
			self
		)
	rattled.emit()
	return true
