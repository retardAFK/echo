class_name MapOnlineClient
extends Node
## Online game, a player's screen (S-010, T-097; S-022, T-433): the client
## plays only its own avatar (the monster with MapMonsterRole, or its hunted
## with HuntedHuds) and sees the others as puppets. Noises, scans, catches,
## the map's changes and the game loop come from the room (T-098, T-099),
## which it only mirrors. It shows what the room reports of a catch (T-107),
## lets an eliminated hunted watch a teammate, and connects again after a cut
## (T-102). GameMap adds it on a client before the game loop.

const MONSTER_SETTINGS := preload("res://game/data/monster_settings.tres")

var map: GameMap

var _net: NetGame
## Hunted: what its screen shows of its own player, hidden once it watches a
## teammate (T-107).
var _own_huds: Array[Node] = []


## Called once added, before the game loop.
func setup(net: NetGame) -> void:
	_net = net
	if GameSession.online_seat == LobbyState.MONSTER_SEAT:
		var monster_role := MapMonsterRole.new()
		monster_role.name = "MonsterRole"
		monster_role.map = map
		map.monster_role = monster_role
		map.add_child(monster_role)
		monster_role.setup()  # Builds the local monster and its view...
		map.free_child(map.prey)  # ...without the AI prey: the hunted are puppets.
		map.prey = null
		map.overlay.prey = null
		net.own = map.avatar
	else:
		_own_huds = HuntedHuds.add_own(map)
		_own_huds.append(map.gauge)
		if map.prison != null:
			var prison_hud := PrisonHud.new()
			prison_hud.prison = map.prison
			map.add_child(prison_hud)
			_own_huds.append(prison_hud)
		_own_huds.append_array(HuntedHuds.add_network(map))
		_own_huds.append_array(map.player.find_children("*", "CanvasLayer", true, false))
		map.overlay.monster = null
		map.free_child(map.monster)  # The room runs the monster; here it is a puppet.
		map.monster = null
		net.own = map.player
		net.spectating.connect(_on_spectating)
	net.caught_reported.connect(_on_caught_reported)
	# The next game launched while this one's end screen is up (T-099), or
	# this one again after a cut (T-102).
	NetSession.game_started.connect(_on_next_game)
	NetSession.left.connect(_on_connection_lost)
	NetSession.unreachable.connect(_on_rejoin_failed)
	NetSession.refused.connect(_on_rejoin_failed.unbind(1))
	map.add_child(ShaderWarmup.new())


## T-102: the connection to the room broke. It connects again with its token:
## the room gives its place back and the game starts again here, as it is in
## the room.
func _on_connection_lost() -> void:
	map.caught_screen.show_for(NetSession.settings.room_connect_timeout, "HUD_RECONNECTING")
	NetSession.rejoin()


## The room cannot be reached again: back to the online menu.
func _on_rejoin_failed() -> void:
	NetSession.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file(EndScreen.LOBBY_SCENE)


func _on_next_game(state: LobbyState) -> void:
	LobbyMenu.enter_game(get_tree(), state)


## The room says a hunted was caught or freed (T-107). Its player sees that it
## is captured, freed, or out; the monster sees that it caught someone.
func _on_caught_reported(seat: int, state: CaptureState.State) -> void:
	var avatar := map.avatar
	var settings: MonsterSettings = avatar.settings if avatar != null else MONSTER_SETTINGS
	if avatar != null:
		if state != CaptureState.State.FREE:
			map.caught_screen.show_for(settings.caught_screen_time, "HUD_PREY_CAUGHT")
	elif seat == GameSession.online_seat:
		var keys := {
			CaptureState.State.CAPTURED: "HUD_CAPTURED",
			CaptureState.State.FREE: "HUD_RESCUED",
			CaptureState.State.OUT: "HUD_ELIMINATED",
		}
		var catcher: NetPuppet = _net.puppets.get(LobbyState.MONSTER_SEAT)
		if (
			state != CaptureState.State.FREE
			and catcher != null
			and catcher.visible
			and map.player != null
		):
			# Seized (S-011, T-127): the head turns to the monster first.
			map.player.watch_catcher(catcher.get_eye_position(), settings.catch_show_time)
			await get_tree().create_timer(settings.catch_show_time, false).timeout
		map.caught_screen.show_for(settings.caught_screen_time, keys[state])


## Out of the game, the hunted watches a teammate (T-107).
func _on_spectating() -> void:
	for hud in _own_huds:
		if is_instance_valid(hud):
			hud.set("visible", false)
			hud.process_mode = Node.PROCESS_MODE_DISABLED
	var view := SpectatorView.new()
	view.name = "SpectatorView"
	view.net = _net
	map.add_child(view)
