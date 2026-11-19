class_name MixBench
extends Node
## Mixing bench (spec S-012, T-147): the cité des Tilleuls heard from the
## monster's ears, with typical moments played one after the other, each for a
## few seconds: footsteps near, a run, the monster's voice, everything at once,
## the music alone, the ambience alone. Opened by the start menu with "?mix" in
## the web address. The page measures the levels at the output: the current
## moment is in window.echoMixScene, "done" at the end.

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const SIREN := preload("res://assets/audio/loop/siren.wav")
## Where the listener stands, in map coordinates: open ground, on concrete.
const SPOT := Vector3(-5, 0, 18)
const SCENE_TIME := 3.0
const STEP_TIME := 0.5
## Each moment: name, buses heard, what plays.
const SCENES := [
	["walk_2m", ["Effets", "Voix"]],
	["sprint_3m", ["Effets", "Voix"]],
	["monster_3m", ["Effets", "Voix"]],
	["own_sprint", ["Effets", "Voix"]],
	["alarm_4m", ["Effets", "Voix"]],
	["scream_3m", ["Effets", "Voix"]],
	["siren_6m", ["Effets", "Voix"]],
	["music_calm", ["Musique"]],
	["music_dread", ["Musique"]],
	["ambience", ["Ambiance"]],
	["everything", ["Effets", "Voix", "Musique", "Ambiance"]],
]

var _map: GameMap
var _music: TensionMusic
var _siren: AudioStreamPlayer3D
var _index := -1
## Each bus's volume before the bench quieted some.
var _bus_db := {}
var _scene_time := 0.0
var _step_time := 0.0


## True when the mixing bench is asked for: "mix" in the web page's query.
static func is_requested() -> bool:
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		return query is String and (query as String).contains("mix")
	return OS.get_cmdline_user_args().has("--mix")


func _ready() -> void:
	get_viewport().disable_3d = true  # Only the sound counts: full speed in a slow browser.
	GameSession.role = GameSession.Role.MONSTER
	GameSession.game_seed = 1
	_map = load(MAP_PATH).instantiate()
	add_child(_map)
	for prey in [_map.prey] + _map.extra_preys:
		if prey != null:
			prey.process_mode = Node.PROCESS_MODE_DISABLED  # Quiet: only our moments.
	_map.avatar.global_position = SPOT
	_map.avatar.process_mode = Node.PROCESS_MODE_DISABLED
	_map.avatar.get_node("PlayerEars").process_mode = Node.PROCESS_MODE_ALWAYS
	_music = _map.get_node("TensionMusic")
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = SIREN
	_siren.max_distance = 60.0
	_siren.volume_db = -6.0  # As the transformer's Siren.
	_siren.top_level = true
	add_child(_siren)
	_next()


func _process(delta: float) -> void:
	if _index >= SCENES.size():
		return
	_scene_time += delta
	_step_time += delta
	if _scene_time >= SCENE_TIME:
		_next()
		return
	if _step_time >= STEP_TIME:
		_step_time = 0.0
		_play(SCENES[_index][0])


func _next() -> void:
	_index += 1
	_scene_time = 0.0
	_step_time = STEP_TIME
	_siren.stop()
	var name_now: String = SCENES[_index][0] if _index < SCENES.size() else "done"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.echoMixScene = '%s';" % name_now, true)
	print("ECHO_MIX " + name_now)
	if _index >= SCENES.size():
		return
	var heard: Array = SCENES[_index][1]
	for bus in ["Effets", "Voix", "Musique", "Ambiance"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			if not _bus_db.has(bus):
				_bus_db[bus] = AudioServer.get_bus_volume_db(index)
			# Volume, not mute: a muted bus stays silent in the browser (T-147).
			AudioServer.set_bus_volume_db(
				index, _bus_db[bus] if heard.has(bus) else SoundMath.SILENT_DB
			)
	match name_now:
		"music_calm":
			_music.hold(TensionMusic.Level.CALM)
		"music_dread", "everything":
			_music.hold(TensionMusic.Level.DREAD)
	if name_now in ["everything", "siren_6m"]:
		_siren.global_position = _ahead(6.0)
		SoundSpace.play(_siren)


## A moment's noises, every half second.
func _play(scene: String) -> void:
	var settings := NoiseBus.settings
	var ears := _map.avatar.get_ear_position()
	match scene:
		"walk_2m":
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _ahead(2.0), settings.walk_range)
		"sprint_3m":
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _ahead(3.0), settings.sprint_range)
		"monster_3m":
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _ahead(3.0), 12.0, null, true)
			if _scene_time < STEP_TIME:
				NoiseBus.emit_noise(
					NoiseEvent.Type.GROWL, _ahead(3.0) + Vector3.UP, 12.0, null, true
				)
			else:
				NoiseBus.emit_noise(
					NoiseEvent.Type.BREATH, _ahead(3.0) + Vector3.UP, 2.0, null, true
				)
		"own_sprint":
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, ears, 12.0, _map.avatar)
		"alarm_4m":
			if fmod(_scene_time, 2.0) < STEP_TIME:
				NoiseBus.emit_noise(NoiseEvent.Type.CAR_ALARM, _ahead(4.0), 40.0)
		"scream_3m":
			if fmod(_scene_time, 2.0) < STEP_TIME:
				NoiseBus.emit_noise(
					NoiseEvent.Type.SCREAM, _ahead(3.0) + Vector3.UP, 30.0, null, true
				)
		"everything":
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _ahead(2.0), settings.sprint_range)
			if fmod(_scene_time, 2.0) < STEP_TIME:
				NoiseBus.emit_noise(NoiseEvent.Type.CAR_ALARM, _ahead(4.0), 40.0)
				NoiseBus.emit_noise(
					NoiseEvent.Type.SCREAM, _ahead(3.0) + Vector3.UP, 30.0, null, true
				)


## A point on the ground this far in front of the listener.
func _ahead(distance: float) -> Vector3:
	var avatar := _map.avatar
	var forward := -avatar.global_basis.z
	forward.y = 0.0
	return avatar.global_position + forward.normalized() * distance
