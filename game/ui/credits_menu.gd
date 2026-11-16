class_name CreditsMenu
extends Control
## The credits (spec S-013, T-167): the content of CREDITS.md, read in the
## game so the two never differ. Each section of the file becomes a heading,
## each line of its tables an entry (asset, author, licence; the paths of the
## repository left out). Paragraphs and the development tools, which are not
## in the exported game, are skipped. Up and down (or the wheel) scroll,
## Escape or Enter go back.

signal closed

const PATH := "res://CREDITS.md"
## Sections of CREDITS.md left out of the game.
const SKIPPED := ["Outils de développement"]
## Columns of a table shown in the game, when the table has them.
const COLUMNS := ["Asset", "Auteur", "Licence"]
## Pixels scrolled by one key press.
const STEP := 24

@onready var _scroll: ScrollContainer = %Scroll
@onready var _lines: VBoxContainer = %Lines


## Headings ([true, text]) and entries ([false, text]) of a CREDITS.md text.
static func parse(text: String) -> Array:
	var out := []
	var skipping := false
	var header: PackedStringArray = []
	var code := RegEx.create_from_string("\\s*,?\\s*\\(?`[^`]*`\\)?")
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("## "):
			var heading := line.substr(3)
			skipping = SKIPPED.has(heading)
			header = []
			if not skipping:
				out.append([true, heading])
		elif skipping or not line.begins_with("|") or line.begins_with("|---"):
			continue
		elif header.is_empty():
			header = _cells(line)
		else:
			var cells := _cells(line)
			var parts: PackedStringArray = []
			for index in mini(cells.size(), header.size()):
				if COLUMNS.has(header[index]):
					var cell := code.sub(cells[index], "", true).replace("**", "").strip_edges()
					if cell != "":
						parts.append(cell)
			if not parts.is_empty():
				out.append([false, " · ".join(parts)])
	return out


static func _cells(line: String) -> PackedStringArray:
	var cells: PackedStringArray = []
	for cell in line.trim_prefix("|").trim_suffix("|").split("|"):
		cells.append(cell.strip_edges())
	return cells


func _ready() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	var entries := parse(file.get_as_text()) if file != null else []
	for entry: Array in entries:
		var label := Label.new()
		label.text = entry[1]
		label.theme_type_variation = &"SubLabel" if entry[0] else &"BodyLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry[0] and _lines.get_child_count() > 0:
			label.custom_minimum_size.y = 22.0  # Room above a new section.
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_lines.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close()
	elif event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += STEP
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= STEP
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_scroll.scroll_vertical = 0


func close() -> void:
	visible = false
	closed.emit()


## The shown lines, for the tests.
func get_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for label: Label in _lines.get_children():
		lines.append(label.text)
	return lines
