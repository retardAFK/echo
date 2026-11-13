extends Node
## A room process (S-010, T-094): one game, started by the lobby with
## `-- --room <slot> --code <code>`. Listens on its port and stops when
## nobody has been in it for room_idle_timeout.
## During a game it measures its load (T-103): time of its physics frames
## and memory, printed every LOAD_REPORT_TIME seconds and at the end.

## Seconds between two load reports during a game.
const LOAD_REPORT_TIME := 30.0
## Frames at the start of a game left out of the worst frame: the map settles.
const WARMUP_FRAMES := 120

@export var settings: NetSettings = preload("res://game/data/net_settings.tres")
@export var map_scene: PackedScene = preload("res://game/maps/tilleuls/tilleuls.tscn")

var _link: RoomLink
var _frames := 0
var _physics_total := 0.0
var _physics_worst := 0.0
var _report_left := LOAD_REPORT_TIME


func _ready() -> void:
	var port := settings.first_room_port + ServerBoot.room_slot - 1
	NetSession.settings = settings
	var error := NetSession.host(port)
	if error != OK:
		printerr("ECHO_ROOM %s cannot listen on %d: %s" % [ServerBoot.room_code, port, error])
		get_tree().quit(1)
		return
	print("ECHO_ROOM %s listening on %d" % [ServerBoot.room_code, port])
	_link = NetSession.link
	_link.lobby.code = ServerBoot.room_code
	_link.game_started.connect(_on_game_started)
	_link.game_ended.connect(_on_game_ended)
	_link.players_changed.connect(_on_players_changed)
	_link.idle_expired.connect(_on_idle_expired)


func _on_players_changed(count: int) -> void:
	print("ECHO_ROOM %s players %d" % [ServerBoot.room_code, count])


func _on_idle_expired() -> void:
	print("ECHO_ROOM %s empty, stopping" % ServerBoot.room_code)
	get_tree().quit()


func _on_game_started(state: Dictionary) -> void:
	print("ECHO_ROOM %s started, seats %s" % [ServerBoot.room_code, state["seats"]])
	_frames = 0
	_physics_total = 0.0
	_physics_worst = 0.0
	_report_left = LOAD_REPORT_TIME
	GameSession.online_lobby = LobbyState.from_dict(state)
	add_child(map_scene.instantiate())  # A child, so this node keeps the room going.


## Back to the waiting room: the map goes, the next launch brings a new one.
func _on_game_ended() -> void:
	print("ECHO_ROOM %s game over, load %s" % [ServerBoot.room_code, load_text()])
	for child in get_children():
		if child is GameMap:
			remove_child(child)
			child.queue_free()


func _physics_process(delta: float) -> void:
	if _link == null or not _link.lobby.started:
		return
	var spent := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frames += 1
	_physics_total += spent
	if _frames > WARMUP_FRAMES:
		_physics_worst = maxf(_physics_worst, spent)
	_report_left -= delta
	if _report_left <= 0.0:
		_report_left = LOAD_REPORT_TIME
		print("ECHO_ROOM %s load %s" % [ServerBoot.room_code, load_text()])


## The load of the game so far: physics frame time and memory.
func load_text() -> String:
	var average := _physics_total / _frames if _frames > 0 else 0.0
	var memory := _resident_memory_mb()
	return (
		"physics avg %.2f ms max %.2f ms over %d frames, memory %.0f MB"
		% [average, _physics_worst, _frames, memory]
	)


## Memory the process holds (Linux: VmRSS), in MB; the engine's own count
## is empty in release builds.
func _resident_memory_mb() -> float:
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	while status != null and not status.eof_reached():
		var line := status.get_line()
		if line.begins_with("VmRSS:"):
			return line.split(":")[1].strip_edges().split(" ")[0].to_float() / 1024.0
	return OS.get_static_memory_usage() / 1048576.0
