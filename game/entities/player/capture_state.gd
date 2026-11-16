class_name CaptureState
extends Node3D
## The capture rule of an online game (S-010, Q2, T-107), for one hunted on
## the room: a child of its Player, or of an AI Prey in an empty seat (T-101).
## Caught once, the hunted is CAPTURED: on its knees where it was, it neither
## moves nor acts, and calls for help (a faint CALL noise, regularly). A free
## teammate frees it by holding "interact" next to it for rescue_time, with a
## RESCUE noise at the start and at the end. Caught a second time, it is OUT:
## eliminated, it watches a teammate.
## With a prison on the map (S-018, part A), the rule changes: caught once or
## twice, the hunted is CAPTURED and waits in a cage, silent; caught a third
## time, or left in its cage until its stay is over, it is OUT. A teammate
## frees it at the cage's grille (prison_settings: 4 s, a CAGE noise of 8 m).
## Solo never uses it: a catch there ends the game.

## The state changed: captured, freed or out.
signal changed(state: State)

enum State { FREE, CAPTURED, OUT }

## Every hunted's capture rule, free or not (T-268).
const GROUP := &"capture_states"

var state := State.FREE
## Times the monster caught it.
var catches := 0
var progress: HoldProgress
## The prison of the map (S-018), or null: then the hunted waits where it was
## caught. The map sets it before the first catch.
var prison: Prison:
	set(value):
		prison = value
		if prison != null and progress != null:
			progress.duration = prison.settings.free_time

var _call_left := 0.0
var _settings: PlayerSettings
var _noise: NoiseSettings = NoiseBus.settings

@onready var _hunted: Node3D = get_parent()


func _ready() -> void:
	add_to_group(GROUP)
	_settings = _hunted.get("motion") if _hunted is Prey else _hunted.get("settings")
	if _settings == null:
		_settings = PlayerSettings.new()
	progress = HoldProgress.new(
		prison.settings.free_time if prison != null else _settings.rescue_time
	)


## The monster caught it: captured the first time, out the second (with a
## prison: out the third). Returns the new state; a hunted not free cannot be
## caught.
func catch() -> State:
	if state != State.FREE:
		return state
	catches += 1
	var out := PrisonRules.is_out(catches, prison.settings) if prison != null else catches >= 2
	_set_state(State.OUT if out else State.CAPTURED)
	return state


## Its stay in the prison is over (S-018, Q5): out of the game.
func time_out() -> void:
	if state == State.CAPTURED:
		_set_state(State.OUT)


## The cage it waits in, or null (not in prison, or not yet: black screen).
func get_cage() -> Cage:
	return prison.cage_of(_hunted) if prison != null else null


## Freed all at once by the guard's terminal (S-018, Q4).
func set_free() -> void:
	if state == State.CAPTURED:
		_set_state(State.FREE)


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
	if state != State.CAPTURED or prison != null:
		return  # In prison it makes no noise (S-018, Q7).
	_call_left -= delta
	if _call_left <= 0.0:
		_call_left += _noise.call_interval
		NoiseBus.emit_noise(
			NoiseEvent.Type.CALL, _hunted.get_eye_position(), _noise.call_range, _hunted
		)


func get_prompt() -> String:
	if state != State.CAPTURED:
		return ""
	return "HUD_INTERACT_FREE_CAGE" if prison != null else "HUD_INTERACT_RESCUE"


## Where a teammate stands to free it: beside it, or before its cage's grille.
func rescue_point() -> Vector3:
	var cage := get_cage()
	return cage.outside_point() if cage != null else global_position


func can_interact(from: Vector3) -> bool:
	if state != State.CAPTURED:
		return false
	var reach := _settings.rescue_reach
	var at := global_position
	if prison != null:
		var cage := get_cage()
		if cage == null:
			return false  # Not in its cage yet.
		at = cage.outside_point()
		reach = prison.settings.free_reach
	var gap := from - at
	return Vector2(gap.x, gap.z).length() <= reach and absf(gap.y) < 2.0


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
	var cage := get_cage()
	if cage != null:
		NoiseBus.emit_noise(
			NoiseEvent.Type.CAGE,
			cage.global_position + Vector3.UP,
			prison.settings.free_range,
			user
		)
		return
	NoiseBus.emit_noise(
		NoiseEvent.Type.RESCUE, global_position + Vector3.UP, _noise.rescue_range, user
	)
