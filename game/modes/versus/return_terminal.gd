class_name ReturnTerminal
extends StaticBody3D
## A return terminal of the Versus (spec S-025, T-414): a graphite post with
## a slanted cyan screen and an antenna. While a teammate is out and the
## terminal is still unused, it is lit: its screen glows and a cyan beam
## rises above it, seen from afar. Once used, its screen goes dark.
## ReturnTerminals places them and says what they do.

const GROUP := &"versus_terminals"
const WALLS_LAYER := 1 << 1
const SIZE := Vector3(0.8, 1.6, 0.55)
const BODY := Color(0.12, 0.16, 0.3)
const TRIM := Color(0.75, 0.78, 0.8)
const SCREEN := Color(0.1, 0.9, 1.0)
const DARK := Color(0.05, 0.07, 0.08)
const BEAM_HEIGHT := 9.0
const BEAM_RANGE := 160.0
const VISIBLE_RANGE := 70.0
const MATERIAL := preload("res://game/modes/versus/data/chest_material.tres")

## Brought someone back already: it works once.
var used := false
## A teammate is out and it can bring it back.
var lit := false
## The hunted holding interact on it, and for how long.
var holder: HunterKit
var held := 0.0
var _screen: MeshInstance3D
var _beam: MeshInstance3D


func _init() -> void:
	name = "ReturnTerminal"
	collision_layer = WALLS_LAYER


func _ready() -> void:
	add_to_group(GROUP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2.0
	add_child(shape)
	add_child(_mesh(_build_post()))
	_screen = _mesh(_build_screen(SCREEN * 2.5))
	add_child(_screen)
	_beam = _build_beam()
	add_child(_beam)
	show_state(false, false)


## Shows it used (dark) or not, lit (beam) or not.
func show_state(p_used: bool, p_lit: bool) -> void:
	used = p_used
	lit = p_lit and not p_used
	if _screen == null:
		return
	_screen.mesh = _build_screen(DARK if used else (SCREEN * 2.5 if lit else SCREEN * 0.8))
	_beam.visible = lit


## Where the one it brings back stands: in front of its screen.
func back_point() -> Vector3:
	return global_position + global_basis.z * 1.2


## The post: a base, a body with cyan stripes, a hood over the screen, a
## keypad, an antenna with a tip.
static func _build_post() -> ArrayMesh:
	var tool := BoxTool.start()
	var w := SIZE.x
	var d := SIZE.z
	BoxTool.box(tool, Vector3(0, 0.06, 0), Vector3(w + 0.2, 0.12, d + 0.2), TRIM * 0.5)
	BoxTool.box(tool, Vector3(0, 0.62, 0), Vector3(w, 1.0, d), BODY)
	for y in [0.3, 0.95]:
		BoxTool.box(tool, Vector3(0, y, 0), Vector3(w + 0.02, 0.06, d + 0.02), SCREEN * 1.6)
	BoxTool.box(tool, Vector3(0, 1.3, -0.08), Vector3(w, 0.5, d - 0.16), BODY)
	BoxTool.box(tool, Vector3(0, 1.58, 0.0), Vector3(w + 0.06, 0.06, d + 0.1), TRIM)
	BoxTool.box(tool, Vector3(0, 1.02, d / 2.0 + 0.06), Vector3(0.4, 0.05, 0.14), TRIM * 0.7)
	BoxTool.box(tool, Vector3(0.25, 1.95, -0.15), Vector3(0.04, 0.7, 0.04), TRIM)
	BoxTool.box(tool, Vector3(0.25, 2.32, -0.15), Vector3(0.1, 0.1, 0.1), SCREEN * 2.5)
	return tool.commit()


## The screen under the hood, slanted towards whoever stands in front.
static func _build_screen(color: Color) -> ArrayMesh:
	var tool := BoxTool.start()
	var at := Vector3(0, 1.3, SIZE.z / 2.0 - 0.1)
	BoxTool.box(tool, at, Vector3(SIZE.x - 0.12, 0.42, 0.03), color, 0.0, -0.25)
	return tool.commit()


static func _build_beam() -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.35, BEAM_HEIGHT, 0.35)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(SCREEN, 0.55)
	var beam := MeshInstance3D.new()
	beam.mesh = box
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = SIZE.y + 0.6 + BEAM_HEIGHT * 0.5
	beam.visibility_range_end = BEAM_RANGE
	beam.visible = false
	return beam


func _mesh(mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = MATERIAL
	instance.visibility_range_end = VISIBLE_RANGE
	return instance
