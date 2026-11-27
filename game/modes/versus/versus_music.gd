class_name VersusMusic
extends Node
## The music of the Versus arcade (spec S-025, T-410), made by
## tools/audio/versus_music.py: an upbeat electro loop in place of the
## tension music of the Hunt (TensionMusic is taken off the map). Two layers
## start together and stay in time: the groove always plays; the rush comes
## in for the last minute (dawn_warning) and while the boss is within
## RUSH_RANGE of the camera, and goes out slowly. On the Musique bus.
## A child of VersusMode; remove it and the Hunt's music plays.

const LAYERS: Array[AudioStream] = [
	preload("res://assets/audio/versus/versus_groove.wav"),
	preload("res://assets/audio/versus/versus_rush.wav"),
]
const BUS := &"Musique"
## The boss this close (meters) brings the rush in.
const RUSH_RANGE := 25.0
## How fast the rush comes in and goes out (gain per second).
const RUSH_IN := 2.0
const RUSH_OUT := 0.3
const SILENT_DB := -60.0

var mode: VersusMode
## How loud the rush is, 0 to 1.
var rush := 0.0
var _players: Array[AudioStreamPlayer] = []


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "VersusMusic"


func _ready() -> void:
	var tension := mode.get_parent().get_node_or_null("TensionMusic")
	if tension != null:
		tension.queue_free()
	for stream in LAYERS:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = BUS
		add_child(player)
		_players.append(player)
	_players[1].volume_db = SILENT_DB
	for player in _players:
		player.play()  # Together, so the loops stay in time.


## Whether the rush should play now: the last minute, or the boss near.
func wants_rush() -> bool:
	if (
		mode.rules != null
		and mode.rules.clock >= mode.settings.match_time - mode.settings.dawn_warning
	):
		return true
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var boss_at: Variant = null
	if mode.boss != null:
		boss_at = mode.boss.body.global_position
	else:  # A hunted's client: the boss's puppet.
		var puppet := get_tree().get_first_node_in_group(TensionMusic.PUPPETS_GROUP) as Node3D
		if puppet != null and puppet.visible:
			boss_at = puppet.global_position
	if camera == null or boss_at == null:
		return false
	return camera.global_position.distance_to(boss_at) <= RUSH_RANGE


func _process(delta: float) -> void:
	var target := 1.0 if wants_rush() else 0.0
	rush = move_toward(rush, target, delta * (RUSH_IN if target > rush else RUSH_OUT))
	_players[1].volume_db = linear_to_db(maxf(rush, 0.001))
