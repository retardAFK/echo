class_name Tracer
extends MeshInstance3D
## The bright line of a Versus shot (spec S-025, Q2, T-403), from the muzzle
## to where the ray stopped: unshaded, it thins out to nothing in LIFE
## seconds, then frees itself. One mesh and one material per color, shared.

const LIFE := 0.1
const WIDTH := 0.06

static var _mesh: BoxMesh
static var _materials := {}

var _left := LIFE


## A tracer from from to to, in color.
static func between(from: Vector3, to: Vector3, color: Color) -> Tracer:
	var tracer := Tracer.new()
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3.ONE
	tracer.mesh = _mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.material_override = material_of(color)
	tracer.set_meta(&"from", from)
	tracer.set_meta(&"to", to)
	return tracer


static func material_of(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]


func _ready() -> void:
	var from: Vector3 = get_meta(&"from")
	var to: Vector3 = get_meta(&"to")
	var length := maxf(from.distance_to(to), 0.01)
	global_position = (from + to) * 0.5
	if length > 0.01 and absf((to - from).normalized().dot(Vector3.UP)) < 0.999:
		look_at(to, Vector3.UP)
	elif length > 0.01:
		look_at(to, Vector3.FORWARD)
	scale = Vector3(WIDTH, WIDTH, length)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var width := WIDTH * _left / LIFE
	scale = Vector3(width, width, scale.z)
