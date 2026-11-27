class_name VersusHud
extends CanvasLayer
## The Versus HUD (spec S-024, Q21, Q23, T-372 and T-373), drawn by code:
## the boss bar and its phase at the bottom, the hit marker on the crosshair
## and the damage numbers over the boss (S-025, T-403: white on the body,
## yellow in the face, bigger the harder),
## and for the hunted its hit points, stamina and ammo, for the boss its
## rage. A red edge when hurt, the result at the end. Under the crosshair,
## what holding interact does (open a chest, revive, finish, Q5 and Q30)
## and how far along it is. At the top, the clock and dawn near (Q3); a
## boss that hides too long is shown in red to the hunted (Q4).
## Aiming (T-412): a holographic sight in the middle, a glass pane in its
## frame with a glowing red ring, ticks and dot.

const THEME := preload("res://game/ui/theme/echo_theme.tres")
const BAR_COLOR := Color(0.62, 0.08, 0.06)
const BAR_BACK := Color(0, 0, 0, 0.6)
const RAGE_COLOR := Color(0.85, 0.15, 0.4)
const STAMINA_COLOR := Color(0.75, 0.75, 0.6)
const FACE_COLOR := Color(1.0, 0.2, 0.15)
const LASER_COLOR := Color(0.62, 0.3, 1.0)
## The "right click: aim" reminder under the weapon (T-416).
const HINT_COLOR := Color(0.55, 0.95, 1.0, 0.85)
const DAWN_COLOR := Color(1.0, 0.6, 0.3)
const TRACKED_COLOR := Color(1.0, 0.1, 0.05)
const NUMBER_FACE := Color(1.0, 0.86, 0.15)
const BANNER_BACK := Color(0.08, 0.05, 0.2, 0.75)
const ZONE_COLOR := Color(0.75, 0.45, 1.0)
const HOLO_RED := Color(1.0, 0.16, 0.1)
const HOLO_GLASS := Color(0.55, 0.85, 1.0, 0.07)
const HOLO_FRAME := Color(0.1, 0.11, 0.13, 0.9)
## The holographic sight's window (pixels at 720 lines high) and its ring.
const HOLO_SIZE := Vector2(230, 150)
const HOLO_RING := 34.0
## Seconds a banner stays.
const BANNER_TIME := 2.5
## Steady hits (the UV laser) add up into the same number for this long.
const STEADY_TIME := 0.4

var mode: VersusMode
var _canvas: Control
var _hit_left := 0.0
var _hit_face := false
var _hurt_left := 0.0
## Seconds left, and in all, of the boss's white screen (a flash grenade).
var _blind_left := 0.0
## The banners waiting, the one shown (text) and how long it has been.
var _banners: Array[String] = []
var _banner := ""
var _banner_age := BANNER_TIME
var _blind_time := 1.0
var _end_text := ""
## The damage numbers on screen: [point, amount, face, age, steady, drift].
var _numbers: Array = []


func _init(p_mode: VersusMode) -> void:
	mode = p_mode
	name = "VersusHud"


func _ready() -> void:
	_canvas = Control.new()
	_canvas.theme = THEME
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	var hunter := mode.local_hunter()
	if hunter != null:
		hunter.hurt.connect(func(_damage: int) -> void: _hurt_left = 0.5)


## The hit marker (Q21): white on the body, red in the face.
func show_hit(face: bool) -> void:
	_hit_left = mode.settings.hit_marker_time
	_hit_face = face


## A damage number at point (S-025, Q4): taken points, in the face or not;
## steady hits (the laser's beam) add up into the last steady number, and
## the pellets of one shot (same frame) into one.
func show_damage(point: Vector3, taken: float, face: bool, steady := false) -> void:
	if not _numbers.is_empty():
		var last: Array = _numbers[-1]
		# The laser's beam adds up for a while; a shotgun's pellets, in the
		# same frame, make one number.
		var same_shot: bool = not steady and not last[4] and last[3] == 0.0
		if (steady and last[4] and last[3] < STEADY_TIME) or same_shot:
			last[1] += taken
			last[2] = last[2] or face
			return
	var drift := randf_range(-24.0, 24.0)
	_numbers.append([point, taken, face, 0.0, steady, drift])
	if _numbers.size() > 24:
		_numbers.pop_front()


## A banner at the top (S-025, Q4): an event everyone sees, its text from
## key and values (a value that is a text key is translated here).
func show_banner(key: String, values: Array = []) -> void:
	var shown := []
	for value: Variant in values:
		var is_key := value is String and (value as String).begins_with("VERSUS_")
		shown.append(Text.t(value) if is_key else value)
	_banners.append(Text.t(key, shown) if not shown.is_empty() else Text.t(key))


## The boss played here is blinded by a flash grenade (S-025, T-404): a
## white screen that fades in seconds.
func show_blind(seconds: float) -> void:
	_blind_left = seconds
	_blind_time = maxf(seconds, 0.01)


func show_end(winner: VersusRules.Winner) -> void:
	var key := "VERSUS_HUNTED_WIN" if winner == VersusRules.Winner.HUNTED else "VERSUS_BOSS_WIN"
	_end_text = Text.t(key)


func _process(delta: float) -> void:
	_hit_left = maxf(_hit_left - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_blind_left = maxf(_blind_left - delta, 0.0)
	_banner_age += delta
	if _banner_age >= BANNER_TIME and not _banners.is_empty():
		_banner = _banners.pop_front()
		_banner_age = 0.0
	elif _banner_age >= BANNER_TIME:
		_banner = ""
	for number: Array in _numbers:
		number[3] += delta
	var life := mode.settings.damage_number_time
	_numbers = _numbers.filter(func(number: Array) -> bool: return number[3] < life)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var size := _canvas.size
	var font := _canvas.get_theme_default_font()
	var health := mode.boss_health()
	if health == null:
		return
	var hunter := mode.local_hunter()
	if hunter != null:
		_draw_sight(size)  # Under the rest of the HUD.
	# The boss bar (Q7, Q8), bottom middle.
	var width := size.x * 0.5
	var bar := Rect2(Vector2((size.x - width) * 0.5, size.y - 56.0), Vector2(width, 10.0))
	_canvas.draw_rect(bar.grow(2.0), BAR_BACK)
	_canvas.draw_rect(Rect2(bar.position, Vector2(width * health.ratio(), 10.0)), BAR_COLOR)
	var phase := health.current_phase()
	var title := Text.t("VERSUS_BOSS_NAME")
	if phase != null:
		title += "  ·  " + Text.t(phase.name_key)
	if health.is_kneeling():
		title += "  ·  " + Text.t("VERSUS_KNEEL")
	_canvas.draw_string(font, bar.position + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_clock(size, font)
	_draw_banner(size, font)
	_draw_zone(size, font)
	if hunter != null:
		_draw_hunter(hunter, size, font)
		_draw_tracked(size)
	elif mode.boss != null and mode.boss.is_local():
		_draw_boss(mode.boss, size, font)
	if _hit_left > 0.0:
		var color := FACE_COLOR if _hit_face else Color.WHITE
		var c := size * 0.5
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_canvas.draw_line(c + corner * 4.0, c + corner * 10.0, color, 2.0)
	_draw_numbers(font)
	if _hurt_left > 0.0:
		var edge := Color(0.8, 0.0, 0.0, _hurt_left)
		for rect: Rect2 in [
			Rect2(0, 0, size.x, 18),
			Rect2(0, size.y - 18, size.x, 18),
			Rect2(0, 0, 18, size.y),
			Rect2(size.x - 18, 0, 18, size.y)
		]:
			_canvas.draw_rect(rect, edge)
	if _blind_left > 0.0:
		var white := Color(1, 1, 1, clampf(_blind_left / _blind_time * 1.3, 0.0, 0.95))
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), white)
	if _end_text != "":
		_canvas.draw_string(
			font, Vector2(0, size.y * 0.4), _end_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32
		)


## While it aims (T-412): a holographic sight that fades in as the gun
## comes up: a glass pane in a dark frame (thicker at the bottom, its
## housing), a glowing red ring with four ticks and a dot in the middle.
func _draw_sight(size: Vector2) -> void:
	var zoom := mode.view.zoom() if mode.view != null else 0.0
	if zoom <= 0.0:
		return
	var alpha := smoothstep(0.2, 0.9, zoom)
	var unit := size.y / 720.0
	var c := size * 0.5
	var pane := Rect2(c - HOLO_SIZE * unit * 0.5, HOLO_SIZE * unit)
	_canvas.draw_rect(pane, Color(HOLO_GLASS, HOLO_GLASS.a * alpha))
	var frame := Color(HOLO_FRAME, HOLO_FRAME.a * alpha)
	var edge := Color(0.32, 0.34, 0.38, alpha)  # The lit rim of the frame.
	var p := pane.position
	var w := pane.size.x
	var h := pane.size.y
	for part: Rect2 in [
		Rect2(p + Vector2(-12, -7) * unit, Vector2(w + 24 * unit, 7 * unit)),  # Hood.
		Rect2(p + Vector2(-12, 0) * unit, Vector2(12 * unit, h)),  # Sides.
		Rect2(p + Vector2(w, 0), Vector2(12 * unit, h)),
		Rect2(p + Vector2(-12 * unit, h), Vector2(w + 24 * unit, 26 * unit)),  # Housing.
	]:
		_canvas.draw_rect(part, frame)
	_canvas.draw_rect(pane.grow(1.0), edge, false, 1.5 * unit)
	var button := Rect2(p + Vector2(w - 34 * unit, h + 8 * unit), Vector2(18, 8) * unit)
	_canvas.draw_rect(button, edge)
	var ring := HOLO_RING * unit
	for glow in 3:  # A soft glow, then the sharp ring.
		var color := Color(HOLO_RED, 0.12 * alpha)
		_canvas.draw_arc(c, ring, 0.0, TAU, 48, color, (9.0 - glow * 3.0) * unit, true)
	var red := Color(HOLO_RED, alpha)
	_canvas.draw_arc(c, ring, 0.0, TAU, 48, red, 2.0 * unit, true)
	for axis: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_canvas.draw_line(c + axis * ring, c + axis * (ring - 8.0 * unit), red, 2.0 * unit)
	_canvas.draw_circle(c, 5.0 * unit, Color(HOLO_RED, 0.25 * alpha))
	_canvas.draw_circle(c, 2.5 * unit, red)


## The damage numbers (S-025, Q4): they jump up from where the shot hit,
## grow with the damage, and fade out.
func _draw_numbers(font: Font) -> void:
	var camera := _canvas.get_viewport().get_camera_3d()
	if camera == null:
		return
	var life := mode.settings.damage_number_time
	for number: Array in _numbers:
		var point: Vector3 = number[0]
		if camera.is_position_behind(point):
			continue
		var age: float = number[3]
		var t := age / life
		var at := camera.unproject_position(point)
		at += Vector2(number[5] * t, -60.0 * t - 18.0)
		var amount: float = number[1]
		var text := str(maxi(roundi(amount), 1))
		var size := clampi(14 + roundi(amount * 0.4), 14, 30) + (6 if number[2] else 0)
		var pop := 1.0 + maxf(0.0, 0.15 - age) * 3.0  # It pops when it appears.
		size = roundi(size * pop)
		var color: Color = NUMBER_FACE if number[2] else Color.WHITE
		color.a = clampf((1.0 - t) * 2.5, 0.0, 1.0)
		var outline := Color(0.0, 0.0, 0.0, color.a * 0.8)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var origin := at - Vector2(width * 0.5, 0.0)
		_canvas.draw_string_outline(
			font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, outline
		)
		_canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## The clock, top middle, and dawn near (Q3).
func _draw_clock(size: Vector2, font: Font) -> void:
	var rules := mode.rules
	if rules == null:
		return
	var left := ceili(rules.time_left())
	var clock := Text.t("VERSUS_CLOCK", [left / 60, left % 60])
	var color := DAWN_COLOR if rules.dawn_near() else Color.WHITE
	_canvas.draw_string(font, Vector2(0, 28), clock, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, color)
	if rules.dawn_near():
		var dawn := Text.t("VERSUS_DAWN_NEAR")
		_canvas.draw_string(
			font, Vector2(0, 46), dawn, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, color
		)
	elif mode.tracked_position() != null and mode.boss != null and mode.boss.is_local():
		var tracked := Text.t("VERSUS_TRACKED")
		_canvas.draw_string(
			font, Vector2(0, 46), tracked, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, TRACKED_COLOR
		)


## The banner of the last event, under the clock.
func _draw_banner(size: Vector2, font: Font) -> void:
	if _banner == "":
		return
	var alpha := clampf((BANNER_TIME - _banner_age) * 3.0, 0.0, 1.0)
	var width := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0
	var back := Rect2((size.x - width) * 0.5, 62.0, width, 30.0)
	_canvas.draw_rect(back, Color(BANNER_BACK, BANNER_BACK.a * alpha))
	_canvas.draw_string(
		font,
		Vector2(0, 84),
		_banner,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		18,
		Color(1, 1, 1, alpha)
	)


## The zone (S-025, Q6): when it shrinks next, and a warning while this
## machine's player is outside it.
func _draw_zone(size: Vector2, font: Font) -> void:
	var zone := mode.zone
	if zone == null or mode.rules == null:
		return
	var clock := mode.rules.clock
	var next := zone.next_step(clock)
	var line := ""
	if next[1] > 0.0:
		var wait := ceili(next[1])
		line = Text.t("VERSUS_ZONE_NEXT", [wait / 60, wait % 60])
	elif next[1] == 0.0:
		line = Text.t("VERSUS_ZONE_SHRINKS")
	if line != "":
		_canvas.draw_string(
			font, Vector2(size.x - 216, 28), line, HORIZONTAL_ALIGNMENT_RIGHT, 200, 14, ZONE_COLOR
		)
	var own := _own_body()
	if own != null and zone.is_outside(own.global_position, clock):
		var warning := Text.t(
			"VERSUS_OUTSIDE_ZONE", [ceili(zone.distance_out(own.global_position, clock))]
		)
		_canvas.draw_string(
			font,
			Vector2(0, size.y * 0.5 - 60),
			warning,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			22,
			ZONE_COLOR
		)


## This machine's player's body, hunted or boss, or null.
func _own_body() -> Node3D:
	var hunter := mode.local_hunter()
	if hunter != null:
		return hunter.body
	if mode.boss != null and mode.boss.is_local():
		return mode.boss.body
	return null


## A boss that has not attacked for long is shown in red (Q4).
func _draw_tracked(size: Vector2) -> void:
	var tracked: Variant = mode.tracked_position()
	if tracked == null:
		return
	var camera := _canvas.get_viewport().get_camera_3d()
	var point: Vector3 = tracked + Vector3.UP * 1.2
	if camera == null or camera.is_position_behind(point):
		return
	var at := camera.unproject_position(point)
	at = at.clamp(Vector2(12, 12), size - Vector2(12, 12))
	var diamond := PackedVector2Array(
		[at + Vector2(0, -9), at + Vector2(7, 0), at + Vector2(0, 9), at + Vector2(-7, 0)]
	)
	_canvas.draw_colored_polygon(diamond, TRACKED_COLOR)


func _draw_hunter(hunter: HunterKit, size: Vector2, font: Font) -> void:
	for i in mode.settings.hunted_health:
		var color := BAR_COLOR if i < hunter.vitals.health else BAR_BACK
		_canvas.draw_rect(Rect2(8.0 + i * 14.0, size.y - 112.0, 10.0, 10.0), color)
	_canvas.draw_rect(Rect2(8, size.y - 98, 80, 3), BAR_BACK)
	_canvas.draw_rect(Rect2(8, size.y - 98, 80 * hunter.stamina.value, 3), STAMINA_COLOR)
	var right := Vector2(size.x - 408, size.y - 70)
	var rarity := VersusRarity.of(hunter.loadout.weapon, mode.settings.rarities)
	var tint := (
		rarity.color if rarity != null and hunter.loadout.weapon.weapon != null else Color.WHITE
	)
	_canvas.draw_string(font, right, weapon_line(hunter), HORIZONTAL_ALIGNMENT_RIGHT, 400, 16, tint)
	if shows_aim_hint(hunter):
		var hint_at := Vector2(size.x - 408, size.y - 54)
		_canvas.draw_string(
			font,
			hint_at,
			Text.t("VERSUS_AIM_HINT"),
			HORIZONTAL_ALIGNMENT_RIGHT,
			400,
			10,
			HINT_COLOR
		)
	if hunter.laser != null:
		var battery := Rect2(size.x - 88, size.y - 64, 80, 3)
		_canvas.draw_rect(battery, BAR_BACK)
		battery.size.x *= hunter.laser.ratio()
		_canvas.draw_rect(battery, LASER_COLOR)
	for slot in VersusLoadout.TOOL_SLOTS:
		var item := hunter.loadout.tool_in(slot)
		if item == null:
			continue
		var line := Text.with_keys(
			"VERSUS_TOOL_LINE",
			["{gadget_%d}" % (slot + 1), Text.t(item.name_key), hunter.loadout.uses[slot]]
		)
		_canvas.draw_string(
			font,
			Vector2(size.x - 208, size.y - 44 + slot * 12),
			line,
			HORIZONTAL_ALIGNMENT_RIGHT,
			200,
			10
		)
	_draw_kit_prompt(hunter.shown_prompt(), size, font)


## What holding interact does (KitPrompts), under the crosshair.
func _draw_kit_prompt(prompt: Array, size: Vector2, font: Font) -> void:
	if prompt.size() >= 3:
		_draw_prompt(KitPrompts.text_of(prompt), prompt[2], size, font)


## A text under the crosshair and, if ratio is 0 or more, a progress bar.
func _draw_prompt(text: String, ratio: float, size: Vector2, font: Font) -> void:
	var at := Vector2(0, size.y * 0.5 + 24)
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10)
	if ratio <= 0.0:
		return
	var bar := Rect2(size.x * 0.5 - 30, size.y * 0.5 + 30, 60, 3)
	_canvas.draw_rect(bar, BAR_BACK)
	bar.size.x *= clampf(ratio, 0.0, 1.0)
	_canvas.draw_rect(bar, STAMINA_COLOR)


## True when the HUD reminds the player that right click aims (T-416): a
## gun that aims in hand, standing, not aiming yet.
static func shows_aim_hint(hunter: HunterKit) -> bool:
	var gun := hunter.loadout.gun()
	return (
		hunter.body is Player
		and gun != null
		and gun.zoom_fov > 0.0
		and hunter.vitals.is_standing()
		and not hunter.aiming
	)


## What the hunted holds, for the HUD: its weapon and ammo (clip / spare),
## or empty hands.
static func weapon_line(hunter: HunterKit) -> String:
	if hunter.vitals.is_down():
		return Text.t("VERSUS_DOWN")
	var weapon := hunter.loadout.weapon
	if weapon == null:
		return Text.t("VERSUS_NO_WEAPON")
	if weapon.weapon != null:
		if hunter.reloading:
			return Text.t("VERSUS_RELOADING")
		var ammo := Text.t("VERSUS_AMMO", [hunter.clip, hunter.loadout.spare_ammo])
		return Text.t(weapon.name_key) + "  " + ammo
	return Text.t(weapon.name_key)


func _draw_boss(boss: BossKit, size: Vector2, font: Font) -> void:
	_canvas.draw_rect(Rect2(8, size.y - 80, 100, 4), BAR_BACK)
	_canvas.draw_rect(Rect2(8, size.y - 80, 100 * boss.health.rage / 100.0, 4), RAGE_COLOR)
	var rage := Text.t("VERSUS_RAGE")
	if boss.health.in_fury():
		rage = Text.t("VERSUS_FURY")
	elif boss.health.rage >= 100.0:
		rage = Text.t("VERSUS_FURY_READY")
	_canvas.draw_string(font, Vector2(8, size.y - 86), rage, HORIZONTAL_ALIGNMENT_LEFT)
	if boss.can_leap():
		var leap := Text.with_keys("VERSUS_LEAP_READY")
		_canvas.draw_string(font, Vector2(8, size.y - 100), leap, HORIZONTAL_ALIGNMENT_LEFT)
	var fire := Text.t("VERSUS_FIREBALL_READY")  # T-413.
	var fire_color := Color(1.0, 0.55, 0.15)
	if boss.fire_wait > 0.0:
		fire = Text.t("VERSUS_FIREBALL_WAIT", [ceili(boss.fire_wait)])
		fire_color = Color(1, 1, 1, 0.6)
	_canvas.draw_string(
		font, Vector2(8, size.y - 114), fire, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, fire_color
	)
	_draw_kit_prompt(boss.shown_prompt(), size, font)
