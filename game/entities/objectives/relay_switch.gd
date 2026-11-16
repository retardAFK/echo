class_name RelaySwitch
extends Node3D
## A relay switch of the cité (spec S-018, Q13): a lever box on a wall, its
## front toward +Z, origin on the floor like a fuse box. When the game has a
## RELAY objective, two of them, in two buildings, are armed: a hunted
## throws one with "interact" (a SWITCH noise), and the relay holds if the
## other is thrown within relay_window; else the first one clicks back.
## GameLoop's Quests decide; the switch shows it.

## A hunted threw it.
signal thrown(user: Node)

const GROUP := &"relay_switches"
const SOUND := preload("res://assets/audio/interiors/crash_bar.wav")

@export var settings: LoopSettings
@export var building_name := ""

## Drawn for this game: it can be thrown.
var armed := false
var is_down := false

@onready var _lever: Node3D = $Lever
@onready var _lamp: MeshInstance3D = $Lamp
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)
	_sound.stream = SOUND
	DrawRange.limit(self, DrawRange.SMALL)
	_show(false)


## Where to stand to throw it.
func get_approach_point() -> Vector3:
	return global_position + global_basis.z * 0.9


func get_prompt() -> String:
	return "HUD_INTERACT_RELAY" if armed and not is_down else ""


func can_interact(from: Vector3) -> bool:
	if not armed or is_down:
		return false
	var gap := from - global_position
	return Vector2(gap.x, gap.z).length() <= settings.fuse_reach and absf(gap.y) < 2.0


func wanted_by(user: Node) -> bool:
	return CaptureState.is_free_hunted(user) and not Door.is_monster(user)


## A press throws it.
func interact(user: Node) -> void:
	if can_interact((user as Node3D).global_position if user is Node3D else global_position):
		thrown.emit(user)


## Down (thrown) or back up, with its clack.
func set_down(down: bool) -> void:
	if down == is_down:
		return
	is_down = down
	_show(true)


## Online client: its clack heard from the room.
func voice() -> void:
	_sound.play()


func _show(sound: bool) -> void:
	_lever.rotation.x = deg_to_rad(-60.0 if is_down else 60.0)
	_lamp.visible = is_down
	if sound and is_inside_tree():
		_sound.play()
