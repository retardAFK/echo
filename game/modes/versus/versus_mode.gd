class_name VersusMode
extends Node
## The Versus mode (spec S-024, T-372 to T-374): the monster becomes a boss
## with a health bar, the hunted fight it with flares. A child of the map,
## added by GameMap when GameSession.mode is VERSUS (the only line outside
## this folder that knows it). It gives each hunted (Player, Prey) a
## HunterKit and each monster (Monster, MonsterAvatar) a BossKit, runs the
## rules (VersusRules) and shows the HUD (VersusHud) to the local player.
## Solo for now, in the test room or the cité ("Jouer seul › Versus",
## T-375); online comes with T-381.
## To remove the mode: docs/MODULES.md, "Le mode Versus".

signal finished(winner: VersusRules.Winner)

const MODE := GameModes.VERSUS
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")
const START_MENU := "res://game/ui/start_menu.tscn"
## How far in front of a hunted's start its first chest stands, in meters.
const FIRST_CHEST_DISTANCE := 2.0

var settings: VersusSettings = SETTINGS
var rules: VersusRules
var boss: BossKit
var hunters: Array[HunterKit] = []
var hud: VersusHud
## The arena of this map (Q24), or null: the whole map (the test room).
var arena: VersusArena
var _lit: Array[Flare] = []
var _slowmo_left := 0.0
var _end_left := -1.0


## Whether the game being started is a Versus one.
static func is_on() -> bool:
	return GameSession.mode == MODE


func _ready() -> void:
	name = "VersusMode"
	_setup.call_deferred()  # Once the map's role part has placed everyone.


func _setup() -> void:
	arena = arena_of(get_parent().scene_file_path)
	if arena != null:
		var builder := ArenaBuilder.new(arena)
		get_parent().add_child(builder)
		builder.use_navigation(get_parent())
	for node in _hunted_nodes():
		var kit := HunterKit.new(self)
		hunters.append(kit)
		node.add_child(kit)
	for node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		var monster_settings: MonsterSettings = node.get(&"settings")
		monster_settings.catch_distance = 0.0  # Its own copy: blows, not catches.
		boss = BossKit.new(self)
		node.add_child(boss)
		break
	if boss == null:
		push_warning("Versus: no monster in the map")
		return
	if arena != null:
		_place_everyone()
	_gear_up()
	boss.health.phase_changed.connect(_on_phase_changed)
	NoiseBus.noise_emitted.connect(_on_noise)
	rules = VersusRules.new(settings, boss.health)
	for kit in hunters:
		rules.hunted.append(kit.vitals)
	hud = VersusHud.new(self)
	add_child(hud)


## The arena of the map at map_path, or null.
func arena_of(map_path: String) -> VersusArena:
	for each in settings.arenas:
		if each.map_path == map_path:
			return each
	return null


## Everyone to their start (Q29): the hunted side by side, the boss away.
func _place_everyone() -> void:
	for i in hunters.size():
		_place(hunters[i].body, arena.hunted_spawn(i), arena.hunted_yaw)
		hunters[i].reset_fall()
	_place(boss.body, arena.boss_spawn, arena.boss_yaw)
	boss.reset_fall()


func _place(body: Node3D, point: Vector3, yaw: float) -> void:
	body.global_position = point
	body.rotation.y = yaw
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


## The start (Q29): in an arena, a chest with the launcher by each player
## hunted and the arena's first chests; the AI preys (until they look for
## chests, T-383) and the test room get their launcher at once.
func _gear_up() -> void:
	for kit in hunters:
		if arena == null or not kit.is_local():
			kit.equip(settings.first_weapon)
			continue
		var start := kit.body.global_position
		var toward := arena.boss_spawn - start
		toward.y = 0.0
		add_chest(start + toward.normalized() * FIRST_CHEST_DISTANCE, settings.first_weapon)
	if arena != null:
		_add_arena_chests(0, settings.arena_chests, false)


## A chest holding item at point.
func add_chest(point: Vector3, item: VersusItem) -> VersusChest:
	var chest := VersusChest.new(item)
	add_child(chest)
	chest.global_position = point
	return chest


func _add_arena_chests(from: int, count: int, phase: bool) -> void:
	for i in range(from, mini(from + count, arena.chest_spots.size())):
		add_chest(arena.chest_spots[i], VersusLoadout.draw(settings.items, get_parent().rng, phase))


## A new phase (Q32): new chests, better ones.
func _on_phase_changed(index: int) -> void:
	if arena != null and index > 0:
		var from := settings.arena_chests + (index - 1) * settings.phase_chests
		_add_arena_chests(from, settings.phase_chests, true)


## A firecracker going off by the boss hurts it (Q13).
func _on_noise(event: NoiseEvent) -> void:
	if event.type != NoiseEvent.Type.FIRECRACKER or boss == null or is_over():
		return
	if event.position.distance_to(boss.body.global_position) <= settings.firecracker_radius:
		boss.health.take_hit(settings.firecracker_damage, settings.firecracker_poise)
		boss.hit_taken.emit(false)


## The kit of the hunted played on this machine, or null.
func local_hunter() -> HunterKit:
	for kit in hunters:
		if kit.is_local():
			return kit
	return null


## The boss's kit if node is the boss (a flare hit it), else null.
func boss_of(node: Node) -> BossKit:
	if boss != null and node == boss.body:
		return boss
	return null


## The standing hunted nearest to point, or null.
func nearest_standing(point: Vector3) -> HunterKit:
	var best: HunterKit
	for kit in hunters:
		if not kit.vitals.is_standing():
			continue
		if (
			best == null
			or (
				kit.body.global_position.distance_to(point)
				< best.body.global_position.distance_to(point)
			)
		):
			best = kit
	return best


## Adds a flare at position; only the newest flare_lights keep their light.
func add_flare(flare: Flare, at: Vector3) -> void:
	add_child(flare)
	flare.global_position = at
	_lit = _lit.filter(func(lit: Flare) -> bool: return is_instance_valid(lit))
	_lit.append(flare)
	while _lit.size() > settings.flare_lights:
		_lit.pop_front().light.visible = false


## A flare of shooter hit the boss (Q21): the shooter's hit marker.
func on_boss_hit(_kit: BossKit, shooter: Node3D, face: bool, _taken: float) -> void:
	if hud != null and local_hunter() != null and shooter == local_hunter().body:
		hud.show_hit(face)


func is_over() -> bool:
	return rules == null or rules.winner != VersusRules.Winner.NONE


func _physics_process(delta: float) -> void:
	if rules == null:
		return
	if rules.winner == VersusRules.Winner.NONE:
		if rules.update(delta) != VersusRules.Winner.NONE:
			_on_end()
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _slowmo_left > 0.0:
		_slowmo_left -= real
		if _slowmo_left <= 0.0:
			Engine.time_scale = 1.0
	if _end_left > 0.0:
		_end_left -= real
		if _end_left <= 0.0:
			_finish()


## The game is over: whoever listens (the test room plays again) decides
## what comes next; with nobody (a game in the cité), back to the menu.
func _finish() -> void:
	var handled := not finished.get_connections().is_empty()
	finished.emit(rules.winner)
	if not handled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file.call_deferred(START_MENU)


func _on_end() -> void:
	if rules.winner == VersusRules.Winner.HUNTED:
		Engine.time_scale = settings.kill_slowmo_scale  # The killing blow (Q1).
		_slowmo_left = settings.kill_slowmo_time
	_end_left = settings.end_delay + settings.kill_slowmo_time
	if hud != null:
		hud.show_end(rules.winner)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.disconnect(_on_noise)


func _hunted_nodes() -> Array[Node]:
	var found: Array[Node] = []
	var map := get_parent()
	var player: Variant = map.get(&"player")
	if player is Player and is_instance_valid(player) and (player as Node).is_inside_tree():
		found.append(player)
	for prey in get_tree().get_nodes_in_group(Prey.GROUP):
		if prey not in found:
			found.append(prey)
	return found
