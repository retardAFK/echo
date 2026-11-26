class_name MapMonsterRole
extends Node
## Monster role (S-004; S-022, T-433): the AI monster and the hunted player
## are replaced by the playable monster, standing where the AI monster
## starts, with its noise markers, scan reticle and scan look, and an AI prey
## starting where the hunted does. Touching the prey catches it: "caught"
## screen, and the prey wanders again from the point farthest from the
## monster; with fuse boxes (S-007), the monster wins.
## GameMap adds it in solo when GameSession.role is MONSTER; MapOnlineClient
## adds it for the monster's player, then removes the AI prey.
## The simulations and the bench (S-007, S-009, T-100) also use it to add AI
## preys and to let an AI monster play instead of the player.

const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MARKERS_SCENE := preload("res://game/ui/noise_markers.tscn")
const SCAN_RETICLE_SCENE := preload("res://game/ui/scan_reticle.tscn")
const INTERACT_PROMPT_SCENE := preload("res://game/ui/interact_prompt.tscn")
const MONSTER_SCENE := preload("res://game/entities/monster/monster.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
## Size of the F4 markers for the prey's wander points and hiding spots, in meters.
const POINT_MARKER_SIZE := 0.3

var map: GameMap


## Called once added: builds the monster, its view and the AI prey, and
## removes the AI monster and the hunted player.
func setup() -> void:
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	map.avatar = avatar
	map.add_child(avatar)
	avatar.global_transform = map.monster.global_transform
	map.markers = MARKERS_SCENE.instantiate()
	map.markers.monster = avatar
	map.add_child(map.markers)
	var reticle: ScanReticle = SCAN_RETICLE_SCENE.instantiate()
	reticle.monster = avatar
	reticle.buildings = map.get_buildings()
	map.add_child(reticle)
	var scan_look := ScanLook.new()
	scan_look.monster = avatar
	scan_look.night = map.get_node("WorldEnvironment")
	map.add_child(scan_look)
	var prompt: InteractPrompt = INTERACT_PROMPT_SCENE.instantiate()
	prompt.player = avatar  # Opening hiding spots (S-008, Q7).
	map.add_child(prompt)
	var prey: Prey = PREY_SCENE.instantiate()
	map.prey = prey
	prey.wander_route = map.get_node("PreyRoute")
	prey.hiding_spots = map.get_node("HidingSpots")
	prey.monster = avatar
	prey.buildings = map.get_buildings()
	prey.position = map.spawn  # Before entering the tree, so no first footstep jump.
	prey.rotation.y = map.spawn_yaw
	map.add_child(prey)
	map.overlay.player = null
	map.overlay.monster = null
	map.overlay.avatar = avatar
	map.overlay.prey = prey
	_add_point_markers(map.get_node("PreyRoute"))
	_add_point_markers(map.get_node("HidingSpots"))
	map.gauge.visible = false
	map.free_child(map.player)
	map.free_child(map.monster)
	map.player = null
	map.monster = null


func _physics_process(_delta: float) -> void:
	var avatar := map.avatar
	var prey := map.prey
	if (
		avatar == null
		or prey == null
		or map.caught_screen.visible
		or (map.game_loop != null and map.game_loop.is_over)
	):
		return
	if HidingSpot.is_hidden(prey):
		return  # Only opening the hiding spot catches it (S-008, Q7).
	var gap := prey.global_position - avatar.global_position
	if (
		Vector2(gap.x, gap.z).length() <= avatar.settings.catch_distance
		and absf(gap.y) <= avatar.settings.catch_height
	):  # Not through a floor (T-079).
		prey_caught()


## The monster caught the prey, by touch or in its hiding spot, with its cry
## (S-012, T-145).
func prey_caught() -> void:
	var avatar := map.avatar
	avatar.catch_count += 1
	MonsterNoise.scream(avatar)
	if map.game_loop != null:
		map.game_loop.finish(false)  # The monster wins (S-007, Q7).
		return
	map.caught_screen.show_for(avatar.settings.caught_screen_time, "HUD_PREY_CAUGHT")
	var points := Prey.markers_of(map.get_node("PreyRoute"))
	var index := MonsterBrain.farthest_index(points, avatar.global_position)
	map.prey.respawn(points[index], index)


## Small pale boxes on the prey's points, shown with F4 (noise debug).
func _add_point_markers(parent: Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * POINT_MARKER_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = map.avatar.settings.debug_cone_color
	mesh.material = material
	for point: Node3D in parent.get_children():
		var marker := MeshInstance3D.new()
		marker.mesh = mesh
		marker.position.y = POINT_MARKER_SIZE / 2.0
		marker.visible = false
		marker.add_to_group(NoiseDebug.DEBUG_GROUP)
		point.add_child(marker)


## Simulations (S-010, T-100): count AI preys in all, each starting at least
## spawn_spacing from the others, all looking for the same fuses.
func add_ai_preys(count: int) -> void:
	var boxes := map.get_fuse_boxes()
	var markers := GameMap.far_apart(
		map.get_node("PlayerSpawns").get_children(), count, LOOP_SETTINGS.spawn_spacing, map.rng
	)
	for i in count:
		var each: Prey = map.prey
		if i > 0:
			each = PREY_SCENE.instantiate()
			each.name = "Prey%d" % (i + 1)
			each.wander_route = map.get_node("PreyRoute")
			each.hiding_spots = map.get_node("HidingSpots")
			each.monster = map.avatar
			each.buildings = map.get_buildings()
		var marker: Node3D = markers[i % markers.size()]
		(each.get_node("Body") as HuntedBody).role = (i % HuntedBody.Role.size()) as HuntedBody.Role
		each.position = marker.global_position
		each.rotation.y = marker.global_rotation.y
		if i > 0:
			map.add_child(each)
			map.extra_preys.append(each)
		if map.game_loop == null:
			continue  # A game mode without the loop (the Versus, S-024): they wander.
		if i > 0:
			map.game_loop.add_hunted(each)
		each.start_loop(map.game_loop, boxes, map.rng.randi() | 1)  # From its new place.


## An AI prey caught by the AI monster: out of the game, out of the way. The
## monster wins once none is free (one prey: at the first catch).
func _on_ai_prey_caught(caught: Node3D, monster: Monster) -> void:
	map.game_loop.hunted_out(caught)
	if map.game_loop.is_over:
		return
	monster.forget(caught)
	caught.process_mode = Node.PROCESS_MODE_DISABLED
	caught.global_position = Vector3(0, -60, 0)


## The playable monster is put away, out of sight and hearing, and an AI
## monster hunts the AI prey instead, as it would hunt the player. Used by the
## game simulation (S-007) and the bench mode (S-009).
func play_ai_against_ai() -> Monster:
	var spawn: Node3D = map.get_node("MonsterSpawn").get_child(0)
	map.avatar.process_mode = Node.PROCESS_MODE_DISABLED
	map.avatar.global_position = Vector3(0, -50, 0)
	var monster: Monster = MONSTER_SCENE.instantiate()
	monster.patrol_route = map.get_node("PatrolRoute")
	monster.buildings = map.get_buildings()
	monster.player = map.prey
	for other in map.extra_preys:
		monster.others.append(other)
	monster.position = spawn.global_position
	map.add_child(monster)
	for each: Prey in [map.prey] + map.extra_preys:
		each.monster = monster
	if map.game_loop == null:
		return monster  # A game mode without the loop (S-024): its own rules.
	monster.hunted_caught.connect(_on_ai_prey_caught.bind(monster))
	map.game_loop.exit_opened.connect(
		monster.guard_exit.bind(Prey.markers_of(map.get_node("GuardPoints")))
	)
	return monster
