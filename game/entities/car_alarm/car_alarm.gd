class_name CarAlarm
extends Node3D
## A parked car whose alarm the hunted can set off (spec S-006, T-042).
## Pressing "interact" next to it makes it ring: an alarm noise at the car, every
## noise_interval, for ring_time, through NoiseBus, so it draws the monster to
## the car, away from the hunted who ran off. Then it rests before it can ring again.

signal alarm_started
signal alarm_stopped

enum State { IDLE, RINGING, RESTING }

@export var settings: CarAlarmSettings

var state := State.IDLE

var _timer := 0.0
var _noise_timer := 0.0
var _flash_timer := 0.0

@onready var _lights: Array[OmniLight3D] = [$HazardLeft, $HazardRight]


func _ready() -> void:
	add_to_group(Interactable.GROUP)
	_set_lights(false)


## Translation key of the hint shown to the hunted in reach, empty if none.
func get_prompt() -> String:
	return "HUD_INTERACT_CAR_ALARM" if state == State.IDLE else ""


## Whether a hunted standing at this position can set the alarm off.
func can_interact(from: Vector3) -> bool:
	if state != State.IDLE:
		return false
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= settings.trigger_distance


func interact(_user: Node) -> void:
	if state != State.IDLE:
		return
	state = State.RINGING
	_timer = settings.ring_time
	_noise_timer = 0.0
	_flash_timer = 0.0
	alarm_started.emit()


func _physics_process(delta: float) -> void:
	match state:
		State.RINGING:
			_ring(delta)
		State.RESTING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.IDLE


func _ring(delta: float) -> void:
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer += settings.noise_interval
		NoiseBus.emit_noise(
			NoiseEvent.Type.CAR_ALARM, global_position + Vector3.UP, settings.alarm_range, self
		)
	_flash_timer += delta
	_set_lights(fmod(_flash_timer * settings.flash_rate, 1.0) < 0.5)
	_timer -= delta
	if _timer <= 0.0:
		state = State.RESTING
		_timer = settings.rest_time
		_set_lights(false)
		alarm_stopped.emit()


## Hidden lights cost nothing to draw: they only exist while they blink on.
func _set_lights(lit: bool) -> void:
	for light in _lights:
		light.light_energy = settings.flash_energy
		light.visible = lit
