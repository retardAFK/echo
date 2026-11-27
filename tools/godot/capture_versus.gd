extends Node
## Screenshots of the Versus arena as a player sees it (spec S-025, T-401 and
## T-405), to check the open doors, the look and the effects with one's own
## eyes, and prints the draw calls of each view. The map plays a Versus game
## with the AI boss; a camera of its own takes each view.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     res://tools/godot/capture_versus.tscn -- [out_dir] [view,view...]

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const SETTLE_FRAMES := 12
const VISUAL_SETTINGS := preload("res://game/data/visual_settings.tres")
const ORIGIN := Vector3(110, 0, 110)

## Name, eye (plan x, height, plan y), look-at point.
const VIEWS := [
	["place", Vector3(96, 1.7, 122), Vector3(130, 2.0, 95)],
	["porte_tour_sud", Vector3(108, 1.7, 118), Vector3(108, 1.4, 108)],
	["hall_tour", Vector3(108, 1.7, 106), Vector3(108, 1.4, 96)],
	["centre_social_ouest", Vector3(132, 1.7, 72), Vector3(145, 1.4, 72)],
	["toit_centre", Vector3(150, 6.0, 80), Vector3(120, 2.0, 100)],
	["parking", Vector3(150, 1.7, 120), Vector3(170, 1.0, 100)],
	# Seen through the player's own camera, behind its shoulder (T-402): the
	# player stands at the eye point (its feet) and looks at the target.
	["joueur_place", Vector3(100, 0, 118), Vector3(130, 1.5, 95)],
	["joueur_porte_tour", Vector3(108, 0, 116), Vector3(108, 1.4, 104)],
	["joueur_boss", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	# The same, firing the light machine gun at the boss (T-403): tracers,
	# hit marker and damage numbers.
	["joueur_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	# T-404: the precision rifle zoomed in, the sonic shotgun up close, and
	# open chests with a gun of each rarity (their beams).
	["joueur_fusil_tir", Vector3(136, 0, 100), Vector3(152, 1.5, 88)],
	["joueur_pompe_tir", Vector3(140, 0, 96), Vector3(143.5, 1.5, 94)],
	["joueur_coffres", Vector3(100, 0, 118), Vector3(130, 1.5, 95)],
	# T-409: the gun models in the hands, in the first person.
	["joueur_1p_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_fusil_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_pompe_tir", Vector3(140, 0, 96), Vector3(143.5, 1.5, 94)],
	# T-412 and T-413: aiming (right click held), the assault rifle.
	["joueur_assaut_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_vise_assaut_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_assaut_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_vise_assaut_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_vise_tir", Vector3(140, 0, 96), Vector3(150, 1.5, 90)],
	["joueur_1p_vise_pompe_tir", Vector3(140, 0, 96), Vector3(143.5, 1.5, 94)],
	["joueur_vise_fusil_tir", Vector3(130, 0, 104), Vector3(152, 1.5, 88)],
	["joueur_1p_vise_fusil_tir", Vector3(130, 0, 104), Vector3(152, 1.5, 88)],
	# T-413: the boss's fireball flying at the player, then bursting by it.
	["joueur_feu", Vector3(140, 0, 96), Vector3(152, 1.5, 88)],
	["joueur_feu_boum", Vector3(140, 0, 96), Vector3(152, 1.5, 88)],
	# T-414: a teammate out, the return terminal lit before the player; the
	# player downed with a syringe.
	["joueur_borne", Vector3(113.4, 0, 114.5), Vector3(112, 1.2, 116)],
	["joueur_seringue", Vector3(100, 0, 118), Vector3(130, 1.5, 95)],
	# T-406: the zone after its second step, the player outside it.
	["joueur_zone", Vector3(96, 0, 132), Vector3(110, 3.0, 110)],
]
## The gun a firing view holds, by a word of its name; else the first one.
const GUNS := {
	"_fusil": &"precision_rifle", "_pompe": &"sonic_shotgun", "_assaut": &"assault_rifle"
}
## Views whose name ends with this fire at the boss while they settle.
const FIRE_SUFFIX := "_tir"
## Views whose name has this are seen in the first person (T-409).
const FIRST_PERSON := "_1p"
## Views whose name has this aim, right click held (T-412).
const AIMING := "_vise"
## Views whose name starts with this are seen through the player's camera.
const PLAYER_PREFIX := "joueur_"


func _ready() -> void:
	var out_dir := "user://versus"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED
	var map: Node3D = load(MAP_PATH).instantiate()
	add_child(map)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var camera := Camera3D.new()
	add_child(camera)
	camera.far = VISUAL_SETTINGS.view_distance
	camera.near = VISUAL_SETTINGS.near_clip
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	for view: Array in VIEWS:
		if not only.is_empty() and not only.has(view[0]):
			continue
		var eye: Vector3 = view[1] - ORIGIN
		var target: Vector3 = view[2] - ORIGIN
		eye.y = view[1].y
		target.y = view[2].y
		if String(view[0]).begins_with(PLAYER_PREFIX):
			_stand_player(map, eye, target, view[0])
		else:
			camera.make_current()
			camera.look_at_from_position(eye, target)
		var firing := String(view[0]).ends_with(FIRE_SUFFIX) or String(view[0]).contains("_feu")
		# Slow time while it fires: a tracer lasts a tenth of a second, less
		# than a frame of this slow renderer.
		Engine.time_scale = 0.15 if firing else 1.0
		for i in SETTLE_FRAMES:
			if String(view[0]).ends_with(FIRE_SUFFIX):
				_fire(map)
			if String(view[0]).contains("_feu") and i == 0:
				_throw_fire(map, String(view[0]).ends_with("_boum"))
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % view[0]))
		print("%-20s draw calls %4d" % [view[0], draws])
	get_tree().quit()


## The player at feet, looking at target, its own view current.
func _stand_player(map: Node, feet: Vector3, target: Vector3, view_name: String) -> void:
	var player: Player = map.get("player")
	player.global_position = feet
	var gap := target - (feet + Vector3.UP * 1.6)
	player.set_look(atan2(-gap.x, -gap.z), atan2(gap.y, Vector2(gap.x, gap.z).length()))
	var versus := map.get_node("VersusMode") as VersusMode
	if versus.view != null:
		versus.view.first_person = view_name.contains(FIRST_PERSON)
		versus.view.call(&"_apply")  # As the V key does.
		if not versus.view.first_person:
			versus.view.camera.make_current()
	var at_boss := (
		view_name.ends_with("_boss")
		or view_name.ends_with(FIRE_SUFFIX)
		or view_name.contains("_feu")
	)
	if versus.boss != null and at_boss:
		versus.boss.body.global_position = target - Vector3.UP * 1.5  # In view.
	if view_name.ends_with(FIRE_SUFFIX):
		versus.boss.body.set_physics_process(false)  # It stays to be shot.
		var gun := versus.settings.first_weapon
		for word: String in GUNS:
			if view_name.contains(word):
				gun = versus.item(GUNS[word], 2)
		versus.local_hunter().equip(gun)
		versus.local_hunter()._cooldown = 0.0  # Fires at once (time is slowed).
		if view_name.contains(AIMING):
			Input.action_press("scan")
		else:
			Input.action_release("scan")
	if view_name == "joueur_coffres":
		_open_chests(versus, feet, target)
	if view_name.contains("_borne") or view_name.contains("_seringue"):
		_second_chances(versus, view_name)
	if view_name == "joueur_zone" and versus.zone != null:
		var settings := versus.settings
		versus.rules.clock = settings.zone_step_times[1] + settings.zone_shrink_time + 1.0


## Four open chests between feet and target, a gun of each rarity in them.
func _open_chests(versus: VersusMode, feet: Vector3, target: Vector3) -> void:
	var ahead := Vector3(target.x - feet.x, 0.0, target.z - feet.z).normalized()
	var side := ahead.cross(Vector3.UP)
	var guns := [&"light_smg", &"sonic_shotgun", &"precision_rifle", &"light_smg"]
	for rarity in 4:
		var at := feet + ahead * (6.0 + rarity * 2.0) + side * (rarity - 1.5) * 2.5
		var chest := versus.add_chest(at, versus.item(guns[rarity], rarity))
		chest.look_at(feet, Vector3.UP)
		chest.open(null, versus.settings)


## T-414: an AI teammate out (the terminals light up), or the player
## downed with a syringe in its first tool slot.
func _second_chances(versus: VersusMode, view_name: String) -> void:
	versus.boss.body.global_position = Vector3(60, 0, 0)  # Out of the way.
	versus.boss.body.set_physics_process(false)
	versus.boss.set_physics_process(false)
	if view_name.contains("_seringue"):
		var player := versus.local_hunter()
		player.equip(versus.item(&"syringe"))
		versus.rules.hunted.append(HuntedVitals.new(versus.settings))  # Not over.
		player.take_blow(versus.settings.hunted_health)
		return
	var mate: HunterKit
	for kit in versus.hunters:
		if kit != versus.local_hunter():
			mate = kit
	if mate == null:  # Solo: a teammate of its own, out of sight.
		var body := CharacterBody3D.new()
		versus.add_child(body)
		body.global_position = Vector3(0, -40, 0)
		mate = HunterKit.new(versus)
		body.add_child(mate)
		mate.set_physics_process(false)
		versus.hunters.append(mate)
		versus.rules.hunted.append(mate.vitals)
	mate.vitals.revives_left = 0
	mate.vitals.hurt(99)


## The boss throws a fireball at the player (T-413): aimed at its chest,
## or, to see the burst, at the ground just before it.
func _throw_fire(map: Node, burst: bool) -> void:
	var versus := map.get_node("VersusMode") as VersusMode
	var player: Player = map.get("player")
	var boss := versus.boss
	boss.body.set_physics_process(false)
	var from := boss.eyes() + Vector3.DOWN * 0.3
	var target := player.global_position + Vector3.UP * 1.2
	if burst:
		target = player.global_position.lerp(from, 0.3)
		target.y = 0.0
	var direction := (target - from).normalized()
	var ball := versus.fire.cast(from + direction * 1.4, direction * versus.settings.fireball_speed)
	if burst:
		ball.global_position = target - direction * 0.5  # Bursts at once.
	else:
		ball.global_position = target - direction * 14.0  # Seen on its way.


## One shot of the player's gun, as soon as it can fire again.
func _fire(map: Node) -> void:
	var hunter := (map.get_node("VersusMode") as VersusMode).local_hunter()
	hunter.fire()
