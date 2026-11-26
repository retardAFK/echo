extends GutTest
## The Versus mode stays a module that can be removed (spec S-024, plan,
## T-374): outside game/modes/versus/, only the files listed here name it.

const MODULE := "res://game/modes/versus/"
const CLASSES: Array[String] = [
	"VersusMode",
	"VersusItem",
	"VersusLoadout",
	"VersusChest",
	"UvLaser",
	"HunterTools",
	"BoxTool",
	"VersusRules",
	"VersusSettings",
	"VersusPhase",
	"VersusHud",
	"BossKit",
	"BossHealth",
	"HunterKit",
	"HuntedVitals",
	"ShotMath",
	"ViewModel",
	"Flare",
	"VersusArena",
	"ArenaPiece",
	"ArenaBuilder",
	"FallRules",
	"FallWatch",
]
## The only files outside the module allowed to name it (docs/MODULES.md).
const ALLOWED: Array[String] = [
	"res://game/maps/game_map.gd",
	"res://game/maps/test_room/test_room.gd",
]


func test_only_the_listed_files_name_the_versus() -> void:
	var offenders: Array[String] = []
	for path in _scripts("res://game/"):
		if path.begins_with(MODULE) or path in ALLOWED:
			continue
		var source := FileAccess.get_file_as_string(path)
		for name in CLASSES:
			if RegEx.create_from_string("\\b%s\\b" % name).search(source) != null:
				offenders.append("%s names %s" % [path, name])
	assert_eq(offenders, [] as Array[String], "see docs/MODULES.md, « Le mode Versus »")


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder + file)
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder + sub + "/"))
	return found
