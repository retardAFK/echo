extends Node
## Screenshots of the HUD in game (S-013, T-165): the hunted at a terminal of
## the tower with its menu, the hunted in the street with a prompt, the end
## screen; with "monster" after the folder, the monster with a noise marker.
## Hides the developer overlay.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     tools/godot/capture_hud.tscn -- <out_dir> [monster]

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
const ORIGIN := Vector3(110, 0, 110)
const SETTLE_FRAMES := 10


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	if args.size() > 1 and args[1] == "monster":
		await _monster(out)
		get_tree().quit()
		return
	GameSession.role = GameSession.Role.HUNTED
	var map: GameMap = load(MAP_PATH).instantiate()
	add_child(map)
	await get_tree().process_frame
	map.get_node("DebugOverlay").visible = false
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	var player: Player = map.get_node("Player")
	var terminal: Terminal = _nearest_terminal(Vector3(115, 0, 106) - ORIGIN)
	player.global_position = terminal.seat_point()
	player.look_at(terminal.global_position + Vector3.UP, Vector3.UP)
	terminal.sit(player)
	await _shot(out, "hud_terminal")
	terminal.leave()
	player.global_position = Vector3(104, 0, 150) - ORIGIN
	player.look_at(Vector3(106.5, 1, 153.5) - ORIGIN, Vector3.UP)
	await _shot(out, "hud_rue")
	map.game_loop.hunted_won = true
	map.end_screen.show_result(GameSession.Role.HUNTED, map.game_loop)
	await _shot(out, "hud_fin")
	get_tree().quit()


## The monster in the middle of the cité, with a footstep heard nearby.
func _monster(out: String) -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = load(MAP_PATH).instantiate()
	add_child(map)
	await get_tree().process_frame
	map.get_node("DebugOverlay").visible = false
	var avatar := map.avatar
	var heard := avatar.global_position + avatar.global_basis.x * 8.0 - avatar.global_basis.z * 10.0
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, heard, 40.0)
	await _shot(out, "hud_monstre")


func _nearest_terminal(at: Vector3) -> Terminal:
	var best: Terminal = null
	for terminal: Terminal in get_tree().get_nodes_in_group(Terminal.GROUP):
		if (
			best == null
			or terminal.global_position.distance_to(at) < best.global_position.distance_to(at)
		):
			best = terminal
	return best


func _shot(out: String, name: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
