extends GutTest
## Scene files stay safe to export (T-028).
##
## A scene that changes a property of a child of an instanced scene, without
## making that instance's children editable, works in the editor but loses the
## change in the exported game. The scan volume of the greybox building was lost
## this way in the web build.


func test_no_override_of_instanced_children() -> void:
	var offenders: Array[String] = []
	for path in _scenes("res://game"):
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			if line.begins_with("[node ") and line.contains(' index="'):
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [] as Array[String], "set the value on the instance root instead")


func test_building_volume_comes_from_its_size() -> void:
	var building: Building = load("res://game/entities/building/building.tscn").instantiate()
	building.size = Vector3(4, 2, 3)
	add_child_autofree(building)
	assert_true(building.contains(building.global_position + Vector3(1.9, 0.9, 1.4)))
	assert_false(building.contains(building.global_position + Vector3(2.1, 0, 0)))


func _scenes(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scenes(dir.path_join(sub)))
	return found
