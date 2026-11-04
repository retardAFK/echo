extends SceneTree
## Bakes the greybox navigation mesh and saves it to the repository (spec S-003).
## Run after changing the greybox walls:
##   godot --headless -s tools/godot/bake_navmesh.gd

const MAP_PATH := "res://game/maps/greybox_test.tscn"
const NAVMESH_PATH := "res://game/maps/greybox_test_navmesh.tres"


var _map: Node


func _initialize() -> void:
	_map = load(MAP_PATH).instantiate()
	root.add_child(_map)


func _process(_delta: float) -> bool:
	var region: NavigationRegion3D = _map.get_node("NavigationRegion3D")
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	var error := ResourceSaver.save(mesh, NAVMESH_PATH)
	print("Baked %d polygons, save error %d" % [mesh.get_polygon_count(), error])
	quit(error)
	return true
