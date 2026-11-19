class_name PostItReader
extends CanvasLayer
## Writes on the HUD what the post-it in front of the hunted's crosshair says
## (spec S-018, Q13, T-271): « Post-it : 4719 » on the one with the code,
## « Post-it vierge, le code est sur un autre » on the others (just « Post-it
## vierge » in a game without a code). Maxime found the quest unclear: six
## post-its out of seven are blank, and the digits were hard to make out in
## the dark. Reading the code marks its post-it as read (CodeSpot.was_read),
## so the map screen and the keypad remind it.
##
## Added by GameMap for the hunted when the map has post-its. Remove it and
## the post-its still show their digits; nothing else depends on it.

const SETTINGS := preload("res://game/data/loop_settings.tres")

## The hunted Player, or anything with is_hidden() and a terminal.
var player: Node3D

var _label: Label


func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.theme = load(MenuStyle.THEME_PATH)
	_label.theme_type_variation = &"HudPrompt"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -120.0
	_label.offset_right = 120.0
	_label.offset_top = -66.0
	_label.offset_bottom = -52.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)


func _process(_delta: float) -> void:
	var spot := spot_in_view()
	_label.visible = spot != null
	if spot == null:
		return
	var code := spot.get_code()
	if code == "":
		var quests := Quests.of(player)
		var wanted := quests != null and quests.code != ""
		_label.text = Text.t("HUD_POST_IT_ELSEWHERE" if wanted else "HUD_POST_IT_BLANK")
	else:
		_label.text = Text.t("HUD_POST_IT_CODE", code)
		spot.was_read = true


## The nearest post-it the hunted reads now, or null.
func spot_in_view() -> CodeSpot:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return null
	if player.has_method("is_hidden") and player.is_hidden():
		return null
	if player.get("terminal") != null:
		return null  # Seated: the terminal's menu has the screen.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var angle := deg_to_rad(SETTINGS.code_read_angle)
	var best: CodeSpot = null
	var best_distance := INF
	for spot: CodeSpot in get_tree().get_nodes_in_group(CodeSpot.GROUP):
		if not spot.readable_from(eye, forward, SETTINGS.code_read_reach, angle):
			continue
		var distance := eye.distance_to(spot.global_position)
		if distance < best_distance:
			best = spot
			best_distance = distance
	return best
