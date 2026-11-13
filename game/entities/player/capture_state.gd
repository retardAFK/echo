class_name CaptureState
extends Node3D
## The capture rule of an online game (S-010, Q2, T-107), for one hunted on
## the room: a child of its Player, or of an AI Prey in an empty seat (T-101).
## Caught once, the hunted is CAPTURED: on its knees where it was, it neither
## moves nor acts, and calls for help (a faint CALL noise, regularly). A free
## teammate frees it by holding "interact" next to it for rescue_time, with a
## RESCUE noise at the start and at the end. Caught a second time, it is OUT:
## eliminated, it watches a teammate.
## Solo never uses it: a catch there ends the game.

## The state changed: captured, freed or out.
signal changed(state: State)

enum State { FREE, CAPTURED, OUT }

var state := State.FREE
## Times the monster caught it.
var catches := 0
var progress: HoldProgress

var _call_left := 0.0
var _settings: PlayerSettings
var _noise: NoiseSettings = NoiseBus.settings

@onready var _hunted: Node3D = get_parent()


func _ready() -> void:
	_settings = _hunted.get("motion") if _hunted is Prey else _hunted.get("settings")
	if _settings == null:
		_settings = PlayerSettings.new()
	progress = HoldProgress.new(_settings.rescue_time)


## The monster caught it: captured the first time, out the second. Returns
## the new state; a hunted not free cannot be caught.
func catch() -> State:
	if state != State.FREE:
		return state
	catches += 1
	_set_state(State.CAPTURED if catches == 1 else State.OUT)
	return state


## Takes the place of another (an AI replacing a hunted who left, T-102):
## the same catches and state, without telling anyone.
func copy_from(other: CaptureState) -> void:
	catches = other.catches
	state = other.state
	if state == State.CAPTURED:
		add_to_group(Interactable.GROUP)


func is_free() -> bool:
	return state == State.FREE


func _set_state(value: State) -> void:
	state = value
	progress.done = 0.0
	_call_left = 0.0  # Calls at once.
	if state == State.CAPTURED:
		add_to_group(Interactable.GROUP)
	elif is_in_group(Interactable.GROUP):
		remove_from_group(Interactable.GROUP)
	changed.emit(state)


func _physics_process(delta: float) -> void:
	if state != State.CAPTURED:
		return
	_call_left -= delta
	if _call_left <= 0.0:
		_call_left += _noise.call_interval
		NoiseBus.emit_noise(
			NoiseEvent.Type.CALL, _hunted.get_eye_position(), _noise.call_range, _hunted
		)


func get_prompt() -> String:
	return "HUD_INTERACT_RESCUE" if state == State.CAPTURED else ""


func can_interact(from: Vector3) -> bool:
	if state != State.CAPTURED:
		return false
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= _settings.rescue_reach and absf(gap.y) < 2.0


## Only a free teammate frees it.
func wanted_by(user: Node) -> bool:
	return user != _hunted and is_free_hunted(user)


## Whether a node is a hunted that may act: a Player or an AI Prey, not
## captured nor out.
static func is_free_hunted(node: Node) -> bool:
	if not (node is Player or node is Prey):
		return false
	var capture: CaptureState = node.get("capture")
	return capture == null or capture.is_free()


## A single press does nothing: it is freed by holding.
func interact(_user: Node) -> void:
	pass


func hold(user: Node, delta: float) -> void:
	if state != State.CAPTURED or not wanted_by(user):
		return
	if progress.done == 0.0:
		_rescue_noise(user)
	if progress.advance(delta):
		_rescue_noise(user)
		_set_state(State.FREE)


func release(_user: Node) -> void:
	progress.release()


func get_hold_ratio() -> float:
	return progress.get_ratio()


func _rescue_noise(user: Node) -> void:
	NoiseBus.emit_noise(
		NoiseEvent.Type.RESCUE, global_position + Vector3.UP, _noise.rescue_range, user
	)
