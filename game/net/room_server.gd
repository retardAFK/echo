extends Node
## A room process (S-010, T-094): one game, started by the lobby with
## `-- --room <slot> --code <code>`. Listens on its port and stops when
## nobody has been in it for room_idle_timeout.

@export var settings: NetSettings = preload("res://game/data/net_settings.tres")

var _link: RoomLink


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
	_link.players_changed.connect(_on_players_changed)
	_link.idle_expired.connect(_on_idle_expired)


func _on_players_changed(count: int) -> void:
	print("ECHO_ROOM %s players %d" % [ServerBoot.room_code, count])


func _on_idle_expired() -> void:
	print("ECHO_ROOM %s empty, stopping" % ServerBoot.room_code)
	get_tree().quit()
