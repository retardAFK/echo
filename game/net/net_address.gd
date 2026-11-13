class_name NetAddress
extends RefCounted
## Where a client finds the lobby and a room (S-010, T-094). On this machine
## ("ws://") each listens on its own port; online ("wss://") everything goes
## through port 443 and Caddy routes by path: /lobby, /s1 to /s8.


static func is_local(server_address: String) -> bool:
	return server_address.begins_with("ws://")


static func lobby_url(settings: NetSettings) -> String:
	if is_local(settings.server_address):
		return "%s:%d" % [settings.server_address, settings.lobby_port]
	return settings.server_address + "/lobby"


## Address of room number slot (from 1), which listens on port.
static func room_url(settings: NetSettings, slot: int, port: int) -> String:
	if is_local(settings.server_address):
		return "%s:%d" % [settings.server_address, port]
	return "%s/s%d" % [settings.server_address, slot]


## The version of this build, which a server must match. "dev" when not
## stamped by the CI.
static func build_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if version != "" else "dev"
