class_name TensionMusic
extends Node
## The music (spec S-012, Q9): no melody, three looping layers started together
## on the Musique bus. The background is always there; the pulse joins in when
## the monster is near, the shrill strings when it is very near, and for
## everyone once the exit is open. Read by steps, without direction, slow to
## change: one knows "it is close", never "it is there".
## Hunted: distance from the camera to the monster (its puppet online).
## Monster: the pulse while it heard a noise nearby a moment ago.
## Hunted, with the same distance (S-020, T-326, piste S2): the monster within
## duck_range lowers the Ambiance and Musique buses by duck_db, so that its
## steps get through the wind and the music. The web build has no bus effect
## (docs/PIEGES.md): the bus volume itself goes down from the options' volume,
## and a volume changed in the options meanwhile becomes the new base.

enum Level { CALM, UNEASE, DREAD }

const LAYERS: Array[AudioStream] = [
	preload("res://assets/audio/music/music_base.wav"),
	preload("res://assets/audio/music/music_unease.wav"),
	preload("res://assets/audio/music/music_dread.wav"),
]
## The monster's puppet on an online client (NetPuppet) joins this group.
const PUPPETS_GROUP := &"monster_puppets"
const BUS := &"Musique"
const SILENT_GAIN := 0.001
## The buses lowered when the monster is near (T-326).
const DUCKED_BUSES: Array[StringName] = [&"Ambiance", &"Musique"]

var audio: AudioSettings = preload("res://game/data/audio_settings.tres")
## Opens the strings for everyone once the exit is open; may stay null.
var game_loop: GameLoop
var level := Level.CALM
## Seconds since the level last changed.
var held_for := 0.0
## Loudness of each layer, from 0 to 1.
var gains: Array[float] = [1.0, 0.0, 0.0]
## How much the duck is in, from 0 (not at all) to 1 (duck_db) (T-326).
var duck := 0.0
## Ducked bus -> [the options' volume, the volume set last], in decibels.
var _duck_base := {}

var _players: Array[AudioStreamPlayer] = []
var _heard_ago := INF


func _ready() -> void:
	name = "TensionMusic"
	for i in LAYERS.size():
		var player := AudioStreamPlayer.new()
		player.name = "Layer%d" % i
		player.stream = LAYERS[i]
		player.bus = BUS
		add_child(player)
		_players.append(player)
	_apply_gains()
	for player in _players:
		player.play()  # Together, so the loops stay in time.
	NoiseBus.noise_emitted.connect(_on_noise)


func _process(delta: float) -> void:
	_heard_ago += delta
	var listener := get_viewport().get_camera_3d() if is_inside_tree() else null
	var exit_open := game_loop != null and game_loop.is_exit_open()
	var target: Level
	var near := false
	if listener != null and _monster_of(listener) != null:
		target = monster_target(_heard_ago, exit_open, audio)
	else:
		var distance := _monster_distance(listener)
		target = target_level(distance, exit_open, audio)
		near = ducks(distance, audio)
	update(delta, target)
	update_duck(delta, near)


## Moves the level towards target (kept at least level_hold) and fades the layers.
func update(delta: float, target: Level) -> void:
	held_for += delta
	var next := next_level(level, target, held_for, audio)
	if next != level:
		level = next
		held_for = 0.0
	for i in range(1, gains.size()):
		gains[i] = fade(gains[i], level >= i, delta, audio)
	_apply_gains()


## Moves the duck towards in or out over duck_time and applies it (T-326).
func update_duck(delta: float, near: bool) -> void:
	duck = move_toward(duck, 1.0 if near else 0.0, delta / audio.duck_time)
	_apply_duck()


## Whether the monster at this distance lowers the wind and the music (-1: no
## monster).
static func ducks(distance: float, p_audio: AudioSettings) -> bool:
	return distance >= 0.0 and distance <= p_audio.duck_range


func _exit_tree() -> void:
	duck = 0.0
	_apply_duck()  # The menus after the game are not lowered.


func _apply_duck() -> void:
	for bus in DUCKED_BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var current := AudioServer.get_bus_volume_db(index)
		var entry: Array = _duck_base.get(bus, [current, current])
		if not is_equal_approx(current, entry[1]):
			entry = [current, current]  # Changed in the options meanwhile.
		var volume: float = entry[0] + audio.duck_db * duck
		AudioServer.set_bus_volume_db(index, volume)
		_duck_base[bus] = [entry[0], volume]


## Sets a level and its layers at once, without the slow fades (mixing bench).
func hold(p_level: Level) -> void:
	set_process(false)
	level = p_level
	for i in range(1, gains.size()):
		gains[i] = 1.0 if level >= i else 0.0
	_apply_gains()


## The level the distance to the monster asks for (-1: no monster).
static func target_level(distance: float, exit_open: bool, p_audio: AudioSettings) -> Level:
	if exit_open or (distance >= 0.0 and distance <= p_audio.dread_range):
		return Level.DREAD
	if distance >= 0.0 and distance <= p_audio.unease_range:
		return Level.UNEASE
	return Level.CALM


## The monster's level: the pulse while it heard a noise nearby a moment ago.
static func monster_target(heard_ago: float, exit_open: bool, p_audio: AudioSettings) -> Level:
	if exit_open:
		return Level.DREAD
	return Level.UNEASE if heard_ago <= p_audio.monster_heard_memory else Level.CALM


## A level changes at most once every level_hold seconds (S-012, Q9).
static func next_level(
	current: Level, target: Level, p_held_for: float, p_audio: AudioSettings
) -> Level:
	if target == current or p_held_for < p_audio.level_hold:
		return current
	return target


## A layer comes in over layer_rise seconds, goes away over layer_fall.
static func fade(gain: float, on: bool, delta: float, p_audio: AudioSettings) -> float:
	if on:
		return minf(gain + delta / p_audio.layer_rise, 1.0)
	return maxf(gain - delta / p_audio.layer_fall, 0.0)


func _apply_gains() -> void:
	for i in _players.size():
		var db: float = audio.layer_db[i]
		_players[i].volume_db = linear_to_db(maxf(gains[i], SILENT_GAIN)) + db


## The playable monster whose camera this is, or null.
func _monster_of(camera: Node) -> MonsterAvatar:
	var node := camera
	while node != null:
		if node is MonsterAvatar:
			return node
		node = node.get_parent()
	return null


## Distance from the listener to the nearest monster, -1 if none.
func _monster_distance(listener: Camera3D) -> float:
	if listener == null:
		return -1.0
	var best := -1.0
	var tree := get_tree()
	for node in (
		tree.get_nodes_in_group(Prison.MONSTERS_GROUP) + tree.get_nodes_in_group(PUPPETS_GROUP)
	):
		var monster := node as Node3D
		if monster == null or not monster.is_inside_tree():
			continue
		var distance := monster.global_position.distance_to(listener.global_position)
		if best < 0.0 or distance < best:
			best = distance
	return best


func _on_noise(event: NoiseEvent) -> void:
	if event.by_monster or event.noise_range <= 0.0 or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or _monster_of(camera) == null:
		return
	if (
		event.position.distance_to(camera.global_position) <= audio.monster_heard_range
		and NoiseBus.can_hear(event, camera.global_position)
	):
		_heard_ago = 0.0
