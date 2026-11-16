class_name SecurityFeed
extends CanvasLayer
## The view of a security camera (spec S-018, Q11): while the hunted watches
## through one (Player.watching), the screen turns green and coarse
## (security_feed.gdshader) and a caption gives the camera's name. In a cage,
## a hint says that "interact" goes through the cameras (Q8).

const SHADER := preload("res://game/fx/security_feed.gdshader")
const CAPTION_COLOR := Color(0.55, 1.0, 0.6)

var player: Player
## Where the captured wait (online), and its seat (GameSession.online_seat
## when left at -1).
var prison: Prison
var seat := -1

var _filter: ColorRect
var _caption: Label
var _hint: Label
var _material: ShaderMaterial


func _ready() -> void:
	layer = 5  # Over the scene, under the other screens.
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_filter = ColorRect.new()
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.material = _material
	add_child(_filter)
	_caption = _label(Control.PRESET_TOP_LEFT, 10.0)
	_hint = _label(Control.PRESET_CENTER_BOTTOM, -40.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_show(null)


func _process(_delta: float) -> void:
	var camera: SecurityCamera = null
	if is_instance_valid(player) and is_instance_valid(player.watching):
		camera = player.watching
	_show(camera)
	if camera != null:
		_material.set_shader_parameter(&"time_seed", floorf(Time.get_ticks_msec() / 80.0))
	_hint.visible = is_caged()
	if _hint.visible:
		_hint.text = Settings.fill(tr("HUD_PRISON_CAMERAS"))


## Waiting in a cage: "interact" goes through the cameras.
func is_caged() -> bool:
	if prison == null or not is_instance_valid(player) or not player.held:
		return false
	return prison.cage_of_seat(seat if seat >= 0 else GameSession.online_seat) != null


func _show(camera: SecurityCamera) -> void:
	_filter.visible = camera != null
	_caption.visible = camera != null
	if camera != null:
		var network := CityNetwork.of(player)
		var number := network.cameras.find(camera) + 1 if network != null else 0
		_caption.text = tr("HUD_CAMERA_CAPTION") % [number, tr(camera.label_key)]


## The caption or the hint, in the green of the screens.
func _label(preset: Control.LayoutPreset, top: float) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.offset_left = 14.0 if preset == Control.PRESET_TOP_LEFT else -200.0
	label.offset_right = 300.0 if preset == Control.PRESET_TOP_LEFT else 200.0
	label.offset_top = top
	label.offset_bottom = top + 14.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_color_override(&"font_color", CAPTION_COLOR)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 10)
	add_child(label)
	return label


func get_caption() -> String:
	return _caption.text if _caption.visible else ""
