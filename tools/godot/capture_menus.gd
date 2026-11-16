extends Node
## Screenshots of every menu screen of S-013 (T-168) at the window size given
## to Godot: home, solo role choice, options (each tab), credits, online entry
## with the digicode, loading screen, pause over the game.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --resolution 1920x1080 tools/godot/capture_menus.tscn -- <out_dir>

const START := "res://game/ui/start_menu.tscn"
const LOBBY := "res://game/ui/lobby_menu.tscn"
const LOADING := "res://game/ui/loading_screen.tscn"
const MAP := "res://game/maps/tilleuls/tilleuls.scn"
const SETTLE_FRAMES := 8

var _out := ""


func _ready() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var size := get_viewport().get_visible_rect().size
	print("capture_menus window ", DisplayServer.window_get_size(), " canvas ", size)
	var menu: StartMenu = load(START).instantiate()
	menu.change_scene = false
	add_child(menu)
	await _shot("menu_accueil")
	menu.show_solo()
	await _shot("menu_seul")
	menu.show_home()
	menu.show_options()
	var options: OptionsMenu = menu.get_node("%Options")
	for tab in OptionsMenu.TABS.size():
		options.show_tab(tab)
		await _shot("menu_options_%d" % (tab + 1))
	options.close()
	menu.show_credits()
	await _shot("menu_credits")
	menu.queue_free()
	var lobby: LobbyMenu = load(LOBBY).instantiate()
	lobby.change_scene = false
	add_child(lobby)
	await _shot("menu_en_ligne")
	lobby.queue_free()
	GameSession.role = GameSession.Role.HUNTED
	var read: bool = Settings.get_value(LoadingScreen.flag_of(GameSession.Role.HUNTED))
	Settings.set_value(LoadingScreen.flag_of(GameSession.Role.HUNTED), false)
	var loading: LoadingScreen = load(LOADING).instantiate()
	loading.change_scene = false
	LoadingScreen.target = MAP
	add_child(loading)
	await _shot("menu_chargement")
	while not loading.is_waiting():
		await get_tree().process_frame
	await _shot("menu_premiers_pas")
	Settings.set_value(LoadingScreen.flag_of(GameSession.Role.HUNTED), read)
	loading.queue_free()
	var map: GameMap = load(MAP).instantiate()
	add_child(map)
	await get_tree().process_frame
	map.get_node("DebugOverlay").visible = false
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	await _shot("jeu")
	map.pause_menu.pause()
	await _shot("menu_pause")
	get_tree().paused = false
	get_tree().quit()


func _shot(name: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
