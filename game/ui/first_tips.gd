class_name FirstTips
extends CanvasLayer
## First-time tips (spec S-020, T-329, piste U1): the first time the hunted
## sees a hiding spot, a terminal or a fuse box, a bubble at the top of the
## screen says what it is for. Seen once, never again: the flag "tip_<kind>"
## is saved with the settings (UserSettings.FLAGS), and "Réinitialiser" in
## the options shows them again. Added by HuntedHuds for the hunted's screen.
## To add a tip: a kind in KINDS and TEXTS, its flag "tip_<kind>" in
## UserSettings.FLAGS, its text in game/i18n/strings.csv, and a line in
## kind_of(). To remove one, the same in reverse.

const SETTINGS := preload("res://game/data/tip_settings.tres")
## Kinds of things with a tip, in the order they are looked for.
const KINDS: Array[String] = ["hiding_spot", "terminal", "fuse_box"]
## The text of each kind's bubble (written out, so the key test finds them).
const TEXTS := {
	"hiding_spot": "TIP_HIDING_SPOT",
	"terminal": "TIP_TERMINAL",
	"fuse_box": "TIP_FUSE_BOX",
}
## Height looked at above the node's origin, in meters.
const LIFT := 0.8
## A ray stopping this close to the point still sees it (its own body).
const SEEN_SLACK := 0.6

var settings: TipSettings = SETTINGS
## The bubble's text key now, "" when none shows.
var showing := ""
## Kinds seen but not shown yet, oldest first.
var waiting: Array[String] = []

var _show_left := 0.0
var _check_left := 0.0
var _panel: PanelContainer
var _label: Label


func _init() -> void:
	layer = 9
	name = "FirstTips"


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.theme = preload("res://game/ui/theme/echo_theme.tres")
	_panel.theme_type_variation = &"InfoPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -170.0
	_panel.offset_right = 170.0
	_panel.offset_top = 12.0
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_label.theme_type_variation = &"HudPrompt"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


## The kind of tip of a node, or "" if it has none.
static func kind_of(node: Node) -> String:
	if node is HidingSpot:
		return "hiding_spot"
	if node is Terminal:
		return "terminal"
	if node is FuseBox:
		return "fuse_box"
	return ""


static func flag_of(kind: String) -> String:
	return "tip_" + kind


static func text_of(kind: String) -> String:
	return TEXTS.get(kind, "")


## Whether an eye at camera sees point: close enough, in the camera's view
## and no wall between them.
static func sees(
	camera: Camera3D, point: Vector3, space: PhysicsDirectSpaceState3D, p_settings: TipSettings
) -> bool:
	var eye := camera.global_position
	if eye.distance_to(point) > p_settings.see_range or not camera.is_position_in_frustum(point):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point, NetGame.SIGHT_MASK)
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) <= SEEN_SLACK


## Whether the tip of a kind was already seen (saved).
static func was_seen(kind: String) -> bool:
	return bool(Settings.get_value(flag_of(kind)))


func _process(delta: float) -> void:
	if showing != "":
		_show_left -= delta
		if _show_left <= 0.0:
			showing = ""
			_panel.visible = false
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = settings.check_interval
		look_around()
	if showing == "" and not waiting.is_empty():
		_show(waiting.pop_front())


## Looks for a thing with a tip not seen yet; the first one seen is queued
## and saved as seen at once.
func look_around() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camera.is_inside_tree():
		return
	var space := camera.get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var kind := kind_of(node)
		if kind == "" or waiting.has(kind) or was_seen(kind):
			continue
		var point := (node as Node3D).global_position + Vector3.UP * LIFT
		if sees(camera, point, space, settings):
			Settings.set_value(flag_of(kind), true)
			waiting.append(kind)


func _show(kind: String) -> void:
	showing = text_of(kind)
	_show_left = settings.show_time
	_label.text = Text.with_keys(showing)
	_panel.visible = true
