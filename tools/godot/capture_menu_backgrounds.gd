extends Node
## Captures the menu backgrounds (spec S-013, Q2, T-162): views of the cité
## des Tilleuls, without the HUD, turned grey, brightened and tinted with the
## sodium ocher, saved as JPEG in assets/textures/ui/.
## xvfb-run godot --rendering-driver opengl3 --resolution 1280x720 \
##   res://tools/godot/capture_menu_backgrounds.tscn

const MAP_PATH := "res://game/maps/tilleuls/tilleuls.scn"
const OUT_DIR := "res://assets/textures/ui/"
const ORIGIN := Vector3(110, 0, 110)
## Name, eye and look-at point in plan coordinates (like the bench views).
const VIEWS := [
	["menu_parking", Vector3(112, 1.6, 168), Vector3(100, 1, 153)],
	["menu_tower", Vector3(105, 1.6, 128), Vector3(105, 6, 100)],
	["menu_shops", Vector3(66, 1.6, 122), Vector3(66, 1.5, 140)],
	["menu_square", Vector3(75, 1.6, 98), Vector3(61, 1, 81)],
]
## Raw captures are very dark: gain, then a gamma that keeps the night dark.
const GAIN := 2.6
const GAMMA := 1.35
## How much of the sodium color goes into the grey.
const TINT := 0.6
const TINT_COLOR := Color(1.1, 0.92, 0.6)
const SIZE := Vector2i(1280, 720)
const QUALITY := 0.8


func _ready() -> void:
	GameSession.role = GameSession.Role.HUNTED
	var map: Node = load(MAP_PATH).instantiate()
	add_child(map)
	var camera := Camera3D.new()
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	for frame in 30:
		await get_tree().process_frame
	for view: Array in VIEWS:
		var offset := Vector3(ORIGIN.x, 0, ORIGIN.z)
		camera.look_at_from_position(view[1] - offset, view[2] - offset)
		for frame in 20:
			await get_tree().process_frame
		_hide_hud(map)
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
		grade(image)
		var path := ProjectSettings.globalize_path(OUT_DIR + str(view[0]) + ".jpg")
		print(view[0], ": ", error_string(image.save_jpg(path, QUALITY)))
	get_tree().quit()


## Grey, brighter, a bit of sodium ocher.
static func grade(image: Image) -> void:
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var light := pow(clampf(color.get_luminance() * GAIN, 0.0, 1.0), GAMMA)
			var grey := Color(light, light, light)
			var tinted := Color(light * TINT_COLOR.r, light * TINT_COLOR.g, light * TINT_COLOR.b)
			image.set_pixel(x, y, grey.lerp(tinted, TINT).clamp())


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer or child is Control:
			child.visible = false
		else:
			_hide_hud(child)
