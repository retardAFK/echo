class_name ScanReticle
extends CanvasLayer
## The monster's scan reticle (spec S-005, Q5, T-032), A and C mockups merged
## at Maxime's request: a small crosshair in the middle of the view and,
## while a building is scanned, a dotted frame with locked corners around it,
## its distance, the word "listening" with a sound meter of what the scan
## hears, and the scan gauge under the frame. Without a scan, the gauge is a
## thin line under the crosshair. Always pale, never orange: orange is noise.
## Under the gauge, a line of text says what the scan can do (S-009, T-086):
## the name of the scannable building aimed at and how to scan it, "too far"
## with its distance, or why the scan button did nothing.

## Layout, in pixels of the 640 x 360 internal resolution.
const CROSS_GAP := 4.0
const CROSS_LENGTH := 5.0
const BRACKET := 10.0
const OUTER_GAP := 4.0
const OUTER_BRACKET := 4.0
const DOT_STEP := 4.0
const IDLE_GAUGE_WIDTH := 48.0
const IDLE_GAUGE_OFFSET := 12.0
const FRAME_GAUGE_OFFSET := 4.0
const LABEL_OFFSET := 4.0
const METER_GAP := 6.0
const METER_STEP := 3.0
const METER_HEIGHT := 7.0
const FONT_SIZE := 10
## Opacity of the secondary lines, and of the gauge while too low to scan.
const DIM_ALPHA := 0.45
## Sound meter: bars, how often it moves, how fast a loud noise fades.
const METER_BARS := 12
const METER_RATE := 15.0
const METER_DECAY := 2.5
## Faint hum on the meter while the scan hears nothing.
const METER_HUM := 0.12
## Gap between the idle gauge and the hint text under it.
const HINT_OFFSET := 14.0

@export var monster: MonsterAvatar
## Scannable buildings of the map, named when nothing scannable is aimed at.
var buildings: Array[Building] = []

## Sound meter levels, from 0 to 1, oldest first.
var meter: Array[float] = []
## Loudest noise heard by the scan recently, from 0 to 1, fading out.
var level := 0.0

## Why the last scan did not start, shown until _miss_time runs out.
var _miss_text := ""
var _miss_time := 0.0
var _meter_time := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _canvas: Control = $Canvas


func _ready() -> void:
	meter.resize(METER_BARS)
	meter.fill(0.0)
	_canvas.draw.connect(_draw_reticle)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	monster.scan_missed.connect(_on_scan_missed)


func _process(delta: float) -> void:
	update_meter(delta)
	_miss_time = maxf(_miss_time - delta, 0.0)
	_canvas.queue_redraw()


## The line of text under the gauge: why the scan did not start (for a few
## seconds after the button), or what the crosshair is on. Empty while
## scanning or when nothing scannable is aimed at.
func hint_text() -> String:
	if monster.scan.active:
		return ""
	if _miss_time > 0.0:
		return _miss_text
	if monster.aimed_building != null:
		var aimed := monster.aimed_building.get_display_name()
		if monster.scan.can_start():
			return tr("HUD_SCAN_HINT") % aimed
		return tr("HUD_SCAN_RECHARGING") % aimed
	if monster.far_building != null:
		var far := monster.far_building
		return tr("HUD_SCAN_TOO_FAR") % [far.get_display_name(), _far_distance(far)]
	return ""


## Text for a scan that did not start.
func miss_text(reason: MonsterAvatar.ScanMiss) -> String:
	match reason:
		MonsterAvatar.ScanMiss.GAUGE_LOW:
			return tr("HUD_SCAN_GAUGE_LOW")
		MonsterAvatar.ScanMiss.TOO_FAR:
			var far := monster.aim_far_building()
			var label := far.get_display_name() if far != null else tr("BUILDING_DEFAULT")
			return tr("HUD_SCAN_TOO_FAR") % [label, _far_distance(far)]
	var names: Array[String] = []
	for building in buildings:
		if not names.has(building.get_display_name()):
			names.append(building.get_display_name())
	return tr("HUD_SCAN_NOTHING") % ", ".join(names)


func _far_distance(building: Building) -> String:
	if building == null:
		return ""
	return NoiseMarkers.distance_text(building.distance_to(monster.get_camera().global_position))


func _on_scan_missed(reason: MonsterAvatar.ScanMiss) -> void:
	_miss_text = miss_text(reason)
	_miss_time = monster.settings.scan_miss_message_time


## Screen rectangle around a building's box, or an empty one when the box is
## behind the camera.
static func frame_rect(camera: Camera3D, building: Building) -> Rect2:
	var box := building.get_box_transform()
	var half := building.size / 2.0
	var rect := Rect2()
	var first := true
	for corner in 8:
		var local := Vector3(
			half.x * (1 if corner & 1 else -1),
			half.y * (1 if corner & 2 else -1),
			half.z * (1 if corner & 4 else -1)
		)
		var point := box * local
		if camera.is_position_behind(point):
			return Rect2()
		var screen := camera.unproject_position(point)
		if first:
			rect = Rect2(screen, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(screen)
	return rect


## Moves the sound meter: a new bar METER_RATE times per second, as high as
## the loudest recent noise inside the building, over a faint hum.
func update_meter(delta: float) -> void:
	level = maxf(level - METER_DECAY * delta, 0.0)
	if monster.scan_target == null:
		return
	_meter_time += delta
	if _meter_time < 1.0 / METER_RATE:
		return
	_meter_time = 0.0
	meter.pop_front()
	meter.append(maxf(level, _rng.randf_range(0.0, METER_HUM)))


func _on_noise_emitted(event: NoiseEvent) -> void:
	if monster == null or not monster.scan_reveals(event):
		return
	var loudness := clampf(event.noise_range / NoiseBus.settings.gauge_full_range, 0.0, 1.0)
	level = maxf(level, loudness)


func _draw_reticle() -> void:
	var pale := monster.settings.scan_bar_color
	var dim := Color(pale, DIM_ALPHA)
	var center := _canvas.size / 2.0
	_draw_cross(center, pale if monster.scan.active else dim)
	var frame := Rect2()
	if monster.scan_target != null:
		frame = frame_rect(monster.get_camera(), monster.scan_target)
	if frame.has_area():
		_draw_frame(frame, pale, dim)
		_draw_gauge(Vector2(frame.position.x, frame.end.y + FRAME_GAUGE_OFFSET), frame.size.x, pale)
	else:
		var start := center + Vector2(-IDLE_GAUGE_WIDTH / 2.0, IDLE_GAUGE_OFFSET)
		_draw_gauge(start, IDLE_GAUGE_WIDTH, pale)
	var hint := hint_text()
	if not hint.is_empty():
		var at := Vector2(0.0, center.y + IDLE_GAUGE_OFFSET + HINT_OFFSET)
		_canvas.draw_string(
			ThemeDB.fallback_font,
			at,
			hint,
			HORIZONTAL_ALIGNMENT_CENTER,
			_canvas.size.x,
			FONT_SIZE,
			pale
		)


func _draw_cross(center: Vector2, color: Color) -> void:
	# Rectangles, not lines: a 1 px line can fall between two pixels and vanish.
	var c := center.floor()
	_canvas.draw_rect(Rect2(c.x + CROSS_GAP, c.y, CROSS_LENGTH, 1), color)
	_canvas.draw_rect(Rect2(c.x - CROSS_GAP - CROSS_LENGTH + 1, c.y, CROSS_LENGTH, 1), color)
	_canvas.draw_rect(Rect2(c.x, c.y + CROSS_GAP, 1, CROSS_LENGTH), color)
	_canvas.draw_rect(Rect2(c.x, c.y - CROSS_GAP - CROSS_LENGTH + 1, 1, CROSS_LENGTH), color)


func _draw_frame(frame: Rect2, pale: Color, dim: Color) -> void:
	# Dotted frame.
	var x := frame.position.x
	while x <= frame.end.x:
		_canvas.draw_rect(Rect2(x, frame.position.y, 1, 1), pale)
		_canvas.draw_rect(Rect2(x, frame.end.y, 1, 1), pale)
		x += DOT_STEP
	var y := frame.position.y
	while y <= frame.end.y:
		_canvas.draw_rect(Rect2(frame.position.x, y, 1, 1), pale)
		_canvas.draw_rect(Rect2(frame.end.x, y, 1, 1), pale)
		y += DOT_STEP
	# Locked corners, and a dim outer set.
	_draw_corners(frame, BRACKET, pale, 2.0)
	_draw_corners(frame.grow(OUTER_GAP), OUTER_BRACKET, dim, 1.0)
	# "Listening" and the sound meter above the frame.
	var font := ThemeDB.fallback_font
	var label := TranslationServer.translate("HUD_SCAN_LISTENING")
	var base := frame.position - Vector2(0, LABEL_OFFSET)
	_canvas.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, pale)
	var meter_x := (
		base.x + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + METER_GAP
	)
	for i in meter.size():
		var height := maxf(1.0, round(meter[i] * METER_HEIGHT))
		var bar_x := meter_x + i * METER_STEP
		_canvas.draw_rect(Rect2(bar_x, base.y - height, 1, height), pale)
	# Distance under the bottom right corner.
	var distance := NoiseMarkers.distance_text(
		monster.get_camera().global_position.distance_to(monster.scan_target.global_position)
	)
	var size := font.get_string_size(distance, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var at := Vector2(frame.end.x - size.x, frame.end.y + FRAME_GAUGE_OFFSET + 2.0 + size.y)
	_canvas.draw_string(font, at, distance, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, dim)


func _draw_corners(frame: Rect2, length: float, color: Color, width: float) -> void:
	var corners := [
		[frame.position, Vector2(1, 1)],
		[Vector2(frame.end.x, frame.position.y), Vector2(-1, 1)],
		[Vector2(frame.position.x, frame.end.y), Vector2(1, -1)],
		[frame.end, Vector2(-1, -1)],
	]
	for corner: Array in corners:
		var point: Vector2 = corner[0]
		var sign: Vector2 = corner[1]
		_canvas.draw_line(point, point + Vector2(sign.x * length, 0), color, width)
		_canvas.draw_line(point, point + Vector2(0, sign.y * length), color, width)


func _draw_gauge(start: Vector2, width: float, pale: Color) -> void:
	var gauge := monster.scan
	var track := Color(pale, DIM_ALPHA * DIM_ALPHA)
	_canvas.draw_rect(Rect2(start, Vector2(width, 1)), track)
	var fill := pale if gauge.active or gauge.can_start() else Color(pale, DIM_ALPHA)
	_canvas.draw_rect(Rect2(start, Vector2(width * gauge.get_ratio(), 1)), fill)
