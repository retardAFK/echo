class_name NoiseMarkers
extends CanvasLayer
## What the playable monster hears (spec S-004, Q2, D-008): every noise from
## someone else that reaches its ears (NoiseBus, walls included) is shown as an
## orange ring where it happened, seen through walls, with its distance in
## meters. It fades out in a few seconds. The building scan (T-023) adds the
## noises it reveals with show_noise().

const MARKER_SCENE := preload("res://game/ui/noise_marker.tscn")

## The playable monster: listens from get_ear_position(), looks through get_camera().
@export var monster: Node3D

var _markers: Array[NoiseMarker] = []
var _positions: Array[Vector3] = []
var _ages: Array[float] = []
var _next := 0


## "11 m": distance rounded to the meter, through the HUD_DISTANCE key.
static func distance_text(meters: float) -> String:
	return TranslationServer.translate("HUD_DISTANCE") % roundi(meters)


## Opacity of a marker of a given age, from 1 when heard to 0 when gone.
static func fade_alpha(age: float, fade_time: float) -> float:
	return clampf(1.0 - age / fade_time, 0.0, 1.0)


func _ready() -> void:
	var settings := _settings()
	for i in settings.marker_count:
		var marker: NoiseMarker = MARKER_SCENE.instantiate()
		marker.color = NoiseBus.settings.noise_color
		marker.radius = settings.marker_radius
		marker.visible = false
		add_child(marker)
		_markers.append(marker)
		_positions.append(Vector3.ZERO)
		_ages.append(settings.marker_fade_time)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


func _process(delta: float) -> void:
	var camera: Camera3D = monster.get_camera()
	var fade_time := _settings().marker_fade_time
	for i in _markers.size():
		var marker := _markers[i]
		_ages[i] += delta
		var alpha := fade_alpha(_ages[i], fade_time)
		var point := _positions[i]
		marker.visible = alpha > 0.0 and not camera.is_position_behind(point)
		if marker.visible:
			marker.position = camera.unproject_position(point)
			marker.modulate.a = alpha


## Shows a noise, whatever its range. Returns the marker used.
func show_noise(event: NoiseEvent) -> NoiseMarker:
	var i := _next
	_next = (_next + 1) % _markers.size()
	_positions[i] = event.position
	_ages[i] = 0.0
	var marker := _markers[i]
	marker.set_text(distance_text(monster.get_ear_position().distance_to(event.position)))
	return marker


## Markers still fading.
func get_active_count() -> int:
	var fade_time := _settings().marker_fade_time
	return _ages.filter(func(age: float) -> bool: return age < fade_time).size()


func _settings() -> MonsterSettings:
	return monster.settings


func _on_noise_emitted(event: NoiseEvent) -> void:
	if monster == null or event.source == monster or event.masked:
		return
	if monster.has_method("scan_reveals") and monster.scan_reveals(event):
		show_noise(event)  # The scan hears it, however faint (S-004, Q3).
	elif event.noise_range > 0.0 and NoiseBus.can_hear(event, monster.get_ear_position()):
		show_noise(event)
