class_name VersusEndScreen
extends CanvasLayer
## The end of a Versus game (spec S-024, Q2, Q28, T-380), built by code:
## who won (and how: the boss beaten, nobody standing, or dawn), how long it
## lasted, one line per hunted (damage, face hits, revives) and the card of
## the best player (MVP), which "Copier la carte" puts in the clipboard to
## share. "Rejouer" starts again, "Menu" goes back to the start menu. The
## game is paused behind it. Added by VersusMode.

const THEME := preload("res://game/ui/theme/echo_theme.tres")
const MENU_SCENE := "res://game/ui/start_menu.tscn"

## Tests turn this off to stay on the map after a choice.
var change_scene := true
## The text "Copier la carte" copies.
var card := ""
var title: Label
var stats: Label
var mvp_label: Label
var replay_button: Button
var menu_button: Button
var copy_button: Button


func _init() -> void:
	name = "VersusEndScreen"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.75)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.theme = THEME
	add_child(back)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 12)
	back.add_child(box)
	title = _label(box, 28)
	stats = _label(box, 14)
	mvp_label = _label(box, 18)
	mvp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	copy_button = _button(box, "VERSUS_COPY_CARD", copy_card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	replay_button = _button(row, "END_REPLAY", replay)
	menu_button = _button(row, "END_MENU", go_to_menu)


## The title key of the end, seen from the role played here.
static func title_key(winner: VersusRules.Winner, dawn: bool, as_boss: bool) -> String:
	if winner == VersusRules.Winner.HUNTED:
		return "VERSUS_HUNTED_WIN"
	if dawn:
		return "VERSUS_END_DAWN"
	return "VERSUS_BOSS_WIN" if not as_boss else "VERSUS_BOSS_WIN_YOU"


## Shows the end of mode's game and pauses it.
func show_result(mode: VersusMode) -> void:
	var rules := mode.rules
	var dawn := rules.time_left() <= 0.0
	var as_boss := mode.local_hunter() == null
	title.text = Text.t(title_key(rules.winner, dawn, as_boss))
	var lines: Array[String] = [Text.t("END_DURATION", EndScreen.format_duration(rules.clock))]
	lines.append_array(mode.stats.lines(mode.hunters))
	stats.text = "\n".join(lines)
	var best := mode.stats.mvp(mode.hunters)
	mvp_label.text = ""
	if best != null:
		mvp_label.text = Text.t("VERSUS_MVP", VersusStats.name_of(mode.hunters, best))
	card = Text.t("VERSUS_CARD", [title.text, EndScreen.format_duration(rules.clock)])
	if best != null:
		card += "\n" + mvp_label.text
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	replay_button.grab_focus()


func copy_card() -> void:
	DisplayServer.clipboard_set(card)
	copy_button.text = Text.t("END_COPIED")


func replay() -> void:
	get_tree().paused = false
	if change_scene:
		get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	if change_scene:
		get_tree().change_scene_to_file(MENU_SCENE)


func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Control, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = Text.t(key)
	button.pressed.connect(action)
	# Focused like hovered: the theme's focus font is dark, for the hover box.
	button.add_theme_stylebox_override("focus", THEME.get_stylebox("hover", "Button"))
	parent.add_child(button)
	return button
