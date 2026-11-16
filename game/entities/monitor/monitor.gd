class_name Monitor
extends Node3D
## A monitor of the hospital (spec S-014, Q6): a hunted switches it on with
## "interact"; it beeps loud (a MONITOR noise of monitor_range every
## monitor_interval) for monitor_time, then falls silent for good. A decoy
## like an alarm clock, but placed, not thrown, and used once per game. The
## monster holds "interact" on it for monitor_off_hold to switch it off.

enum State { IDLE, BEEPING, SPENT }

const GROUP := &"monitors"
const SCREEN_OFF := Color(0.02, 0.04, 0.03)
const SCREEN_ON := Color(0.25, 1.0, 0.45)

@export var settings: HospitalSettings

var state := State.IDLE
## Seconds it still beeps.
var beeping_left := 0.0
## Online client: the room decides; it only shows the state.
var mirror := false

var _next_beep := 0.0
var _off: HoldProgress
var _screen_material: StandardMaterial3D

@onready var _screen: MeshInstance3D = $Screen


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)
	add_to_group(Terminal.MONSTER_GROUP)
	_off = HoldProgress.new(settings.monitor_off_hold)
	_screen_material = StandardMaterial3D.new()
	_screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.material_override = _screen_material
	DrawRange.limit(self, DrawRange.INDOOR)
	_show()


## Within reach of a body standing at this position.
func can_interact(from: Vector3) -> bool:
	if state == State.SPENT:
		return false
	var gap := global_position - from
	return Vector2(gap.x, gap.z).length() <= settings.monitor_reach and absf(gap.y) < 2.0


## A hunted switches an idle one on; the monster switches a beeping one off.
func wanted_by(who: Node) -> bool:
	if Door.is_monster(who):
		return state == State.BEEPING
	return state == State.IDLE


func get_prompt() -> String:
	return "HUD_INTERACT_MONITOR" if state == State.IDLE else ""


func get_prompt_for(who: Node) -> String:
	if not wanted_by(who):
		return ""
	return "HUD_MONSTER_MONITOR_OFF" if Door.is_monster(who) else "HUD_INTERACT_MONITOR"


## Switched on by a hunted (or by the room's state on a client).
func interact(who: Node = null) -> void:
	if state != State.IDLE or Door.is_monster(who):
		return
	state = State.BEEPING
	beeping_left = settings.monitor_time
	_next_beep = 0.0
	_show()


func hold(who: Node, delta: float) -> void:
	if wanted_by(who) and Door.is_monster(who) and _off.advance(delta):
		switch_off()


func release(_who: Node) -> void:
	_off.release()


func get_hold_ratio() -> float:
	return _off.get_ratio()


## Silent for the rest of the game.
func switch_off() -> void:
	state = State.SPENT
	beeping_left = 0.0
	_show()


func _physics_process(delta: float) -> void:
	if mirror or state != State.BEEPING:
		return
	_next_beep -= delta
	if _next_beep <= 0.0:
		_next_beep += settings.monitor_interval
		NoiseBus.emit_noise(
			NoiseEvent.Type.MONITOR, _screen.global_position, settings.monitor_range, self
		)
	beeping_left -= delta
	if beeping_left <= 0.0:
		switch_off()


## Online client: what the room says of it.
func mirror_state(room_state: State) -> void:
	if room_state != state:
		state = room_state
		_show()


func _show() -> void:
	if _screen_material != null:
		_screen_material.albedo_color = SCREEN_ON if state == State.BEEPING else SCREEN_OFF
