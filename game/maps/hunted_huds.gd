class_name HuntedHuds
extends RefCounted
## What the hunted's screen shows of its own player (S-022, T-433), added to
## the map in solo (MapHuntedRole) and online (MapOnlineClient): what it
## carries, the hiding mask, the highlights of what it can use, its map
## (S-017), and the network's screens (S-018). The map's other screens (pause,
## end, loop HUD) belong to GameMap. To add a hunted HUD, add it here.

const CARRY_HUD_SCENE := preload("res://game/ui/carry_hud.tscn")
const HIDE_MASK_SCENE := preload("res://game/ui/hide_mask.tscn")
const HIGHLIGHTS_SCENE := preload("res://game/ui/interact_highlights.tscn")
const MAP_SCREEN_SCENE := preload("res://game/ui/map_screen.tscn")


## The player's own HUDs: what it carries, the hiding mask, the highlights,
## and its map if the map has a plan (map.map_screen). Returns them, the map
## screen included.
static func add_own(map: GameMap) -> Array[Node]:
	var carry: CarryHud = CARRY_HUD_SCENE.instantiate()
	carry.player = map.player
	map.add_child(carry)
	var mask: HideMask = HIDE_MASK_SCENE.instantiate()
	mask.player = map.player
	map.add_child(mask)
	var highlights: InteractHighlights = HIGHLIGHTS_SCENE.instantiate()
	highlights.player = map.player
	map.add_child(highlights)
	var huds: Array[Node] = [carry, mask, highlights]
	var map_screen := _add_map_screen(map)
	if map_screen != null:
		huds.append(map_screen)
	return huds


## The hunted's view of a security camera and its terminal menu (S-018), and
## what a post-it says (T-271), if the map has a network. Returns them.
static func add_network(map: GameMap) -> Array[Node]:
	var huds: Array[Node] = []
	if CityNetwork.of(map) == null:
		return huds
	var feed := SecurityFeed.new()
	feed.player = map.player
	feed.prison = map.prison
	map.add_child(feed)
	var menu := TerminalMenu.new()
	menu.player = map.player
	map.add_child(menu)
	huds.assign([feed, menu])
	if map.get_tree().get_first_node_in_group(CodeSpot.GROUP) != null:
		var reader := PostItReader.new()  # What a post-it says (T-271).
		reader.player = map.player
		map.add_child(reader)
		huds.append(reader)
	return huds


## The hunted's map (S-017, T-252), if the map has a plan.
static func _add_map_screen(map: GameMap) -> MapScreen:
	var plan := MapPlan.for_scene(map.scene_file_path)
	if plan == null:
		return null
	map.map_screen = MAP_SCREEN_SCENE.instantiate()
	map.map_screen.plan = plan
	map.map_screen.player = map.player
	map.add_child(map.map_screen)
	return map.map_screen
