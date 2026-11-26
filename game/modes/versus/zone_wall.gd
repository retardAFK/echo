class_name ZoneWall
extends MeshInstance3D
## The edge of the Versus zone (spec S-025, Q6, T-406): a tall see-through
## violet wall, a cylinder open at both ends that follows the zone's radius
## as the clock runs. One draw call. VersusMode adds it with the zone.

const HEIGHT := 60.0
const COLOR := Color(0.55, 0.25, 1.0, 0.28)

var mode: VersusMode
var zone: VersusZone


func _init(p_mode: VersusMode, p_zone: VersusZone) -> void:
	mode = p_mode
	zone = p_zone
	name = "ZoneWall"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 64
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = COLOR
	cylinder.material = material
	mesh = cylinder
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var radius := zone.radius(mode.rules.clock) if mode.rules != null else zone.start_radius
	global_position = Vector3(zone.centre.x, HEIGHT * 0.5 - 10.0, zone.centre.y)
	scale = Vector3(radius, HEIGHT, radius)
