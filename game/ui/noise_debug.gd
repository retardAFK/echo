class_name NoiseDebug
extends Node3D
## Noise debug view (spec S-002, T-011): F4 shows a ring on the ground for each
## noise, sized to its range, fading out, and reveals the test probes.

const DEBUG_GROUP := "noise_debug"
const RING_SEGMENTS := 48
const MAX_RINGS := 8
## Lift above the floor so rings do not flicker against it.
const GROUND_OFFSET := 0.02

var settings: NoiseSettings = NoiseBus.settings
var enabled := false
var _rings: Array[Dictionary] = []


func _ready() -> void:
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_noise_debug"):
		set_enabled(not enabled)


func _process(delta: float) -> void:
	for ring in _rings.duplicate():
		ring.age += delta
		if ring.age >= settings.debug_ring_lifetime:
			_remove_ring(ring)
		else:
			ring.material.albedo_color.a = 1.0 - ring.age / settings.debug_ring_lifetime


func set_enabled(value: bool) -> void:
	enabled = value
	get_tree().call_group(DEBUG_GROUP, "set_visible", enabled)
	if not enabled:
		for ring in _rings.duplicate():
			_remove_ring(ring)


func get_ring_count() -> int:
	return _rings.size()


func _on_noise_emitted(event: NoiseEvent) -> void:
	if not enabled or event.noise_range <= 0.0:
		return
	if _rings.size() >= MAX_RINGS:
		_remove_ring(_rings[0])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = settings.noise_color
	var mesh := MeshInstance3D.new()
	mesh.mesh = _circle(event.noise_range)
	mesh.material_override = material
	add_child(mesh)
	mesh.global_position = event.position + Vector3.UP * (GROUND_OFFSET - settings.emit_height)
	_rings.append({"node": mesh, "material": material, "age": 0.0})


func _remove_ring(ring: Dictionary) -> void:
	ring.node.queue_free()
	_rings.erase(ring)


func _circle(radius: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in RING_SEGMENTS + 1:
		var angle := TAU * i / RING_SEGMENTS
		mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	mesh.surface_end()
	return mesh
