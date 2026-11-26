class_name ViewModel
extends Node3D
## What a Versus player sees of itself (spec S-024, Q18, Q19, Q22, T-372 and
## T-373): the hunted's two forearms holding the flare launcher, or the
## boss's two clawed arms. A child of the player's camera. Prototype: built
## from boxes in one mesh per arm (no skeleton), animated by code: sway while
## walking, recoil, reload, claw swipe, charge. The real models come with
## tools/blender/viewmodels.py (T-385) and replace build_*().

enum Kind { HUNTER, BOSS }

const SHADER := preload("res://game/modes/versus/viewmodel.gdshader")
## Size of the hunted's arms and launcher on screen.
const HUNTER_SCALE := 0.8
const SLEEVE := Color(0.22, 0.27, 0.32)
const GLOVE := Color(0.12, 0.11, 0.1)
const LAUNCHER := Color(0.55, 0.1, 0.08)
const METAL := Color(0.25, 0.26, 0.27)
const SKIN := Color(0.3, 0.33, 0.28)
const CLAW := Color(0.78, 0.74, 0.62)
## Sway: meters and radians per meter per second of speed.
const SWAY := 0.012
const SWAY_RATE := 1.6
## Recoil spring: how hard it comes back, and how fast it settles.
const SPRING := 140.0
const DAMPING := 14.0
## Claw swipe: seconds and swing angle in radians.
const SWIPE_TIME := 0.22
const SWIPE_ANGLE := 1.6

var kind := Kind.HUNTER
## Speed of its body, for the sway, set by its kit.
var speed := 0.0
var _left: MeshInstance3D
var _right: MeshInstance3D
var _material: ShaderMaterial
var _kick := 0.0
var _kick_speed := 0.0
var _phase := 0.0
var _swipe_left := 0.0
var _raise := 0.0
var _raise_target := 0.0
var _flash := 0.0


func _init(p_kind := Kind.HUNTER) -> void:
	kind = p_kind
	name = "ViewModel"


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_left = MeshInstance3D.new()
	_right = MeshInstance3D.new()
	for arm: MeshInstance3D in [_left, _right]:
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.material_override = _material
		add_child(arm)
	if kind == Kind.HUNTER:
		scale = Vector3.ONE * HUNTER_SCALE
		_left.mesh = build_hunter_left()
		_right.mesh = build_hunter_right()
	else:
		_left.mesh = build_boss_arm(-1.0)
		_right.mesh = build_boss_arm(1.0)
		_left.position = Vector3(-0.3, -0.3, -0.15)
		_right.position = Vector3(0.3, -0.3, -0.15)


## Recoil of a shot (Q18).
func kick(strength := 1.0) -> void:
	_kick_speed += strength * 3.0


## The boss's claw swipe (Q19).
func swipe() -> void:
	_swipe_left = SWIPE_TIME


## Arms lowered (0) to raised (1): down, reloading, charging.
func lower(amount: float) -> void:
	_raise_target = -amount


## A white or red flash on the arms (a hit landed, a blow taken).
func flash(color: Color) -> void:
	_material.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
	_flash = 1.0


func _process(delta: float) -> void:
	_phase += delta * (SWAY_RATE + speed * 1.2)
	var sway := minf(speed, 7.0) * SWAY
	_kick_speed += (-SPRING * _kick - DAMPING * _kick_speed) * delta
	_kick += _kick_speed * delta
	_raise = move_toward(_raise, _raise_target, delta * 3.0)
	position = Vector3(sin(_phase) * sway, -absf(cos(_phase)) * sway + _raise * 0.35, _kick * 0.08)
	rotation = Vector3(_kick * 0.25 + _raise * 0.6, 0.0, sin(_phase) * sway * 0.5)
	if kind == Kind.BOSS:
		_swipe_left = maxf(_swipe_left - delta, 0.0)
		var t := 1.0 - _swipe_left / SWIPE_TIME if _swipe_left > 0.0 else 0.0
		_right.rotation = Vector3(0.0, sin(t * PI) * SWIPE_ANGLE, sin(t * PI) * 0.6)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_material.set_shader_parameter("flash", _flash * 0.6)


## The hunted's right forearm, glove and flare launcher.
static func build_hunter_right() -> ArrayMesh:
	var tool := _start()
	_box(tool, Vector3(0.2, -0.27, -0.12), Vector3(0.09, 0.09, 0.32), SLEEVE, -0.25)
	_box(tool, Vector3(0.17, -0.22, -0.32), Vector3(0.08, 0.1, 0.1), GLOVE)
	_box(tool, Vector3(0.17, -0.17, -0.43), Vector3(0.07, 0.08, 0.34), LAUNCHER)
	_box(tool, Vector3(0.17, -0.155, -0.62), Vector3(0.09, 0.09, 0.06), METAL)
	_box(tool, Vector3(0.17, -0.25, -0.36), Vector3(0.04, 0.12, 0.05), GLOVE)
	_box(tool, Vector3(0.17, -0.12, -0.36), Vector3(0.02, 0.02, 0.04), METAL)
	return tool.commit()


## The hunted's left forearm and glove, under the launcher's barrel.
static func build_hunter_left() -> ArrayMesh:
	var tool := _start()
	_box(tool, Vector3(-0.02, -0.33, -0.2), Vector3(0.09, 0.09, 0.32), SLEEVE, 0.5)
	_box(tool, Vector3(0.12, -0.23, -0.5), Vector3(0.09, 0.07, 0.11), GLOVE)
	return tool.commit()


## One of the boss's arms, side -1 (left) or 1 (right), around its shoulder.
static func build_boss_arm(side: float) -> ArrayMesh:
	var tool := _start()
	_box(tool, Vector3(0.0, 0.0, -0.18), Vector3(0.14, 0.14, 0.42), SKIN, side * 0.15)
	_box(tool, Vector3(side * -0.04, 0.03, -0.42), Vector3(0.16, 0.06, 0.12), SKIN)
	for i in 3:
		var x := side * -0.04 + (i - 1) * 0.05
		_box(tool, Vector3(x, 0.03, -0.6), Vector3(0.018, 0.018, 0.26), CLAW, 0.0, -0.12)
	return tool.commit()


static func _start() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## Adds a box at center, of size, turned yaw then pitch (radians).
static func _box(
	tool: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw := 0.0, pitch := 0.0
) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var half := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var up: Vector3 = face[1]
		var side: Vector3 = face[2]
		var corners: Array[Vector3] = []
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local := normal + side * corner.x + up * corner.y
			corners.append(center + basis * (local * half))
		tool.set_color(color)
		tool.set_normal(basis * normal)
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_color(color)
			tool.set_normal(basis * normal)
			tool.add_vertex(corners[index])
