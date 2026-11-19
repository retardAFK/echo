extends GutTest
## The texts of the game (T-450): every key the code names exists in
## game/i18n/strings.csv, every line of the file is used, and nothing but
## Text talks to TranslationServer. See game/i18n/README.md.

const CSV_PATH := "res://game/i18n/strings.csv"
## Folders whose scripts, scenes and resources name text keys.
const SCANNED := ["res://game", "res://tools"]
const EXTENSIONS := ["gd", "tscn", "tres"]
## The one script allowed to call TranslationServer.
const DOOR := "res://game/i18n/text.gd"

var _texts := {}
## Every "UPPER_CASE" string literal found, with the file it is in.
var _literals := {}


func before_all() -> void:
	_texts = _read_csv()
	for root: String in SCANNED:
		for path in _files(root):
			var source := FileAccess.get_file_as_string(path)
			var found := RegEx.create_from_string('"([A-Z][A-Z0-9]*_[A-Z0-9_]+)"')
			for m in found.search_all(source):
				_literals[m.get_string(1)] = path


func test_every_line_has_a_french_text() -> void:
	assert_gt(_texts.size(), 100, "the file is read")
	for key: String in _texts:
		assert_ne(_texts[key], "", "%s has a French text" % key)


func test_every_key_named_in_the_code_exists() -> void:
	var families := _families()
	for literal: String in _literals:
		if not families.has(literal.get_slice("_", 0)) or literal.ends_with("_"):
			continue
		var exists: bool = (
			_texts.has(literal)
			or (_texts.has(literal + Text.ONE) and _texts.has(literal + Text.MANY))
		)
		assert_true(exists, "%s (%s) is in strings.csv" % [literal, _literals[literal]])


func test_every_line_of_the_file_is_used() -> void:
	var prefixes: Array[String] = []
	for literal: String in _literals:
		if literal.ends_with("_"):
			prefixes.append(literal)
	for key: String in _texts:
		var used := _literals.has(key)
		for suffix in [Text.ONE, Text.MANY]:
			if key.ends_with(suffix) and _literals.has(key.trim_suffix(suffix)):
				used = true
		for prefix in prefixes:
			if key.begins_with(prefix):
				used = true
		assert_true(used, "%s is used by the game (else remove its line)" % key)


## Keys made from an enum or a list: each value has its text.
func test_built_keys_exist() -> void:
	for objective: String in LoopRules.Objective.keys():
		if objective != "FUSE":
			assert_true(_texts.has("MAP_OBJECTIVE_" + objective), objective)
	for setting: String in UserSettings.CHOICES:
		for choice: String in UserSettings.CHOICES[setting]:
			assert_true(_texts.has("OPTIONS_CHOICE_" + choice.to_upper()), choice)


func test_only_text_translates() -> void:
	var direct := RegEx.create_from_string("TranslationServer\\.translate|(?<![\\w.])tr\\(")
	for path in _files("res://game"):
		if path == DOOR or not path.ends_with(".gd"):
			continue
		var m := direct.search(FileAccess.get_file_as_string(path))
		assert_null(m, "%s goes through Text" % path)


func test_plurals_agree_in_french() -> void:
	TranslationServer.set_locale("fr")
	assert_eq(Text.count("HUD_CARRY_BOTTLES", 1), "1 bouteille")
	assert_eq(Text.count("HUD_CARRY_BOTTLES", 3), "3 bouteilles")
	assert_eq(Text.decimal(1.5), "1,50")
	assert_eq(Text.t("HUD_DISTANCE", 12), "12 m")


## First words of the keys of the file (HUD, MENU...): a literal starting
## with one of them is meant to be a text key.
func _families() -> Dictionary:
	var out := {}
	for key: String in _texts:
		out[key.get_slice("_", 0)] = true
	return out


func _read_csv() -> Dictionary:
	var out := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := file.get_csv_line()
	assert_eq(Array(header), ["keys", "fr"], "one key column, one French column")
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		assert_false(out.has(line[0]), "%s is written once" % line[0])
		out[line[0]] = line[1]
	return out


func _files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_files(root.path_join(sub)))
	for file in dir.get_files():
		if EXTENSIONS.has(file.get_extension()):
			out.append(root.path_join(file))
	return out
