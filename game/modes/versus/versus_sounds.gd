class_name VersusSounds
extends Node
## The sounds of the Versus arcade (spec S-025, T-410), made by
## tools/audio/versus_sounds.py (assets/audio/versus/): each gun's shot where
## it is fired, the hit tick and the head ding of one's own hits, reloading,
## a chest opening, the flash grenade, the zone about to close. Shots and
## bursts play in the world (SoundSpace: farther is quieter, walls muffle);
## what only concerns the player (its hits, its reload, the zone) plays flat.
## The same calls on the room and on a client (VersusNet passes them on).
## A child of VersusMode; remove it and the Versus is silent but plays.

const STREAMS := {
	&"smg_shot": preload("res://assets/audio/versus/smg_shot.wav"),
	&"rifle_shot": preload("res://assets/audio/versus/rifle_shot.wav"),
	&"shotgun_shot": preload("res://assets/audio/versus/shotgun_shot.wav"),
	&"hit": preload("res://assets/audio/versus/hit.wav"),
	&"hit_face": preload("res://assets/audio/versus/hit_face.wav"),
	&"reload": preload("res://assets/audio/versus/reload.wav"),
	&"chest_open": preload("res://assets/audio/versus/chest_open.wav"),
	&"flash": preload("res://assets/audio/versus/flash.wav"),
	&"zone_warning": preload("res://assets/audio/versus/zone_warning.wav"),
}
## The shot of each gun, by item id. Adding a gun: its line here (a gun
## without one fires the light machine gun's).
const GUN_SOUNDS := {
	&"light_smg": &"smg_shot",
	&"precision_rifle": &"rifle_shot",
	&"sonic_shotgun": &"shotgun_shot",
}
## The banners that come with a sound (VersusMode.announce).
const BANNER_SOUNDS := {"VERSUS_ZONE_SOON": &"zone_warning"}
## How far a sound in the world carries (meters), and how many play at once.
const RANGE := 70.0
const VOICES := 12
## Hit ticks closer together than this make one (the UV laser's beam).
const HIT_GAP := 0.09
const BUS := &"Effets"

var mode: VersusMode
var _world: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0
## Shots already heard this frame, by sound and place (the shotgun's
## pellets make one).
var _this_frame := {}
var _hit_wait := 0.0
var _was_reloading := false
var _open_chests := {}


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "VersusSounds"


func _ready() -> void:
	for i in VOICES:
		var world := AudioStreamPlayer3D.new()
		world.bus = BUS
		world.max_distance = RANGE
		add_child(world)
		_world.append(world)
	for i in 3:
		var flat := AudioStreamPlayer.new()
		flat.bus = BUS
		add_child(flat)
		_flat.append(flat)


## A gun of item id fired from at (once a frame for a place, whatever the
## pellets).
func shot(gun_id: StringName, at: Vector3) -> void:
	var sound: StringName = GUN_SOUNDS.get(gun_id, &"smg_shot")
	var key := [sound, at.snapped(Vector3.ONE * 0.5)]
	if _this_frame.has(key):
		return
	_this_frame[key] = true
	at_point(sound, at)


## A sound of STREAMS where it happens in the world.
func at_point(sound: StringName, point: Vector3) -> void:
	if not is_inside_tree() or not STREAMS.has(sound):
		return
	var player := _world[_next]
	_next = (_next + 1) % _world.size()
	player.global_position = point
	player.stream = STREAMS[sound]
	SoundSpace.play(player)


## A sound of STREAMS for the player only, the same everywhere.
func flat(sound: StringName) -> void:
	if not is_inside_tree() or not STREAMS.has(sound):
		return
	for player in _flat:
		if not player.playing:
			player.stream = STREAMS[sound]
			player.play()
			return
	_flat[0].stream = STREAMS[sound]
	_flat[0].play()


## One's own shot hit the boss: a tick, or a ding at the head.
func hit(face: bool) -> void:
	if _hit_wait > 0.0 and not face:
		return
	_hit_wait = HIT_GAP
	flat(&"hit_face" if face else &"hit")


## A banner shows (VersusMode.announce): its sound, if it has one.
func banner(key: String) -> void:
	if BANNER_SOUNDS.has(key):
		flat(BANNER_SOUNDS[key])


func _process(delta: float) -> void:
	_this_frame.clear()
	_hit_wait = maxf(_hit_wait - delta, 0.0)
	var own := mode.local_hunter()
	var reloading := own != null and own.reloading
	if reloading and not _was_reloading:
		flat(&"reload")
	_was_reloading = reloading
	for chest: VersusChest in get_tree().get_nodes_in_group(VersusChest.GROUP):
		if chest.is_open and not _open_chests.has(chest):
			_open_chests[chest] = true
			at_point(&"chest_open", chest.global_position + Vector3.UP)
