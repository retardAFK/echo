extends GutTest
## Dependency rules of the entities (S-022, T-434, docs/ARCHITECTURE.md §6):
## an entity does not know the network (comments aside). The online part of the map
## (MapOnlineClient, MapOnlineRoom) and NetGame wire the entities instead.

const ENTITIES := "res://game/entities"
const FORBIDDEN: Array[String] = ["NetSession", "NetGame", "RoomLink"]


func test_no_entity_knows_the_network() -> void:
	var scripts := _scripts(ENTITIES)
	assert_gt(scripts.size(), 20, "the entity scripts are found")
	var found: Array[String] = []
	for path in scripts:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.get_slice("#", 0)  # Comments may name them.
			for name in FORBIDDEN:
				if code.contains(name):
					found.append("%s: %s" % [path, line.strip_edges()])
	assert_eq(found, [] as Array[String], "entities using the network")


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found
