class_name VersusHud
extends CanvasLayer
## The Versus HUD (spec S-024, Q21, Q23, T-372 and T-373), drawn by code:
## the boss bar and its phase at the bottom, the hit marker on the crosshair,
## and for the hunted its hit points, stamina and flares, for the boss its
## rage. A red edge when hurt, the result at the end. Under the crosshair,
## what holding interact does (open a chest, revive, finish, Q5 and Q30)
## and how far along it is.

const THEME := preload("res://game/ui/theme/echo_theme.tres")
const BAR_COLOR := Color(0.62, 0.08, 0.06)
const BAR_BACK := Color(0, 0, 0, 0.6)
const RAGE_COLOR := Color(0.85, 0.15, 0.4)
const STAMINA_COLOR := Color(0.75, 0.75, 0.6)
const FACE_COLOR := Color(1.0, 0.2, 0.15)
const LASER_COLOR := Color(0.62, 0.3, 1.0)

var mode: VersusMode
var _canvas: Control
var _hit_left := 0.0
var _hit_face := false
var _hurt_left := 0.0
var _end_text := ""


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


func show_end(winner: VersusRules.Winner) -> void:
	var key := "VERSUS_HUNTED_WIN" if winner == VersusRules.Winner.HUNTED else "VERSUS_BOSS_WIN"
	_end_text = Text.t(key)


func _process(delta: float) -> void:
	_hit_left = maxf(_hit_left - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var size := _canvas.size
	var font := _canvas.get_theme_default_font()
	var boss := mode.boss
	if boss == null:
		return
	# The boss bar (Q7, Q8), bottom middle.
	var width := size.x * 0.5
	var bar := Rect2(Vector2((size.x - width) * 0.5, size.y - 56.0), Vector2(width, 10.0))
	_canvas.draw_rect(bar.grow(2.0), BAR_BACK)
	_canvas.draw_rect(Rect2(bar.position, Vector2(width * boss.health.ratio(), 10.0)), BAR_COLOR)
	var phase := boss.health.current_phase()
	var title := Text.t("VERSUS_BOSS_NAME")
	if phase != null:
		title += "  ·  " + Text.t(phase.name_key)
	if boss.health.is_kneeling():
		title += "  ·  " + Text.t("VERSUS_KNEEL")
	_canvas.draw_string(font, bar.position + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_LEFT)
	var hunter := mode.local_hunter()
	if hunter != null:
		_draw_hunter(hunter, size, font)
	elif boss.is_local():
		_draw_boss(boss, size, font)
	if _hit_left > 0.0:
		var color := FACE_COLOR if _hit_face else Color.WHITE
		var c := size * 0.5
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_canvas.draw_line(c + corner * 4.0, c + corner * 10.0, color, 2.0)
	if _hurt_left > 0.0:
		var edge := Color(0.8, 0.0, 0.0, _hurt_left)
		for rect: Rect2 in [
			Rect2(0, 0, size.x, 18),
			Rect2(0, size.y - 18, size.x, 18),
			Rect2(0, 0, 18, size.y),
			Rect2(size.x - 18, 0, 18, size.y)
		]:
			_canvas.draw_rect(rect, edge)
	if _end_text != "":
		_canvas.draw_string(
			font, Vector2(0, size.y * 0.4), _end_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32
		)


func _draw_hunter(hunter: HunterKit, size: Vector2, font: Font) -> void:
	for i in mode.settings.hunted_health:
		var color := BAR_COLOR if i < hunter.vitals.health else BAR_BACK
		_canvas.draw_rect(Rect2(8.0 + i * 14.0, size.y - 112.0, 10.0, 10.0), color)
	_canvas.draw_rect(Rect2(8, size.y - 98, 80, 3), BAR_BACK)
	_canvas.draw_rect(Rect2(8, size.y - 98, 80 * hunter.stamina.value, 3), STAMINA_COLOR)
	var right := Vector2(size.x - 208, size.y - 70)
	_canvas.draw_string(font, right, weapon_line(hunter), HORIZONTAL_ALIGNMENT_RIGHT, 200)
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
	if hunter.vitals.is_out():
		_draw_prompt(Text.t("VERSUS_OUT"), -1.0, size, font)
	elif hunter.vitals.is_down():
		_draw_down(hunter, size, font)
	elif not _draw_revive_prompt(hunter, size, font):
		_draw_chest_prompt(hunter, size, font)


## Downed (Q5): the seconds left, and a teammate's revive under way.
func _draw_down(hunter: HunterKit, size: Vector2, font: Font) -> void:
	var text := Text.t("VERSUS_DOWN_TIME", ceili(hunter.vitals.down_left))
	var ratio := -1.0
	for other in mode.hunters:
		if other.revive.target == hunter:
			text = Text.t("VERSUS_BEING_REVIVED")
			ratio = other.revive.ratio(other.revive_time())
	_draw_prompt(text, ratio, size, font)


## A downed teammate in reach (Q5); false if none.
func _draw_revive_prompt(hunter: HunterKit, size: Vector2, font: Font) -> bool:
	var reach := mode.settings.revive_reach
	if DownedHold.nearest(mode.hunters, hunter.body.global_position, reach, hunter) == null:
		return false
	var ratio := hunter.revive.ratio(hunter.revive_time())
	_draw_prompt(Text.with_keys("VERSUS_REVIVE"), ratio, size, font)
	return true


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


## What the hunted holds, for the HUD: its weapon and flares, or empty hands.
static func weapon_line(hunter: HunterKit) -> String:
	if hunter.vitals.is_down():
		return Text.t("VERSUS_DOWN")
	var weapon := hunter.loadout.weapon
	if weapon == null:
		return Text.t("VERSUS_NO_WEAPON")
	if weapon.id == &"flare_launcher":
		if hunter.reloading:
			return Text.t("VERSUS_RELOADING")
		return Text.t("VERSUS_FLARES", [hunter.clip, hunter.loadout.spare_flares])
	return Text.t(weapon.name_key)


## Under the crosshair: what holding interact on the chest in sight does,
## and how far along it is (Q30).
func _draw_chest_prompt(hunter: HunterKit, size: Vector2, font: Font) -> void:
	var chest := hunter.chest if hunter.chest != null else hunter.chest_in_reach()
	if chest == null or (chest.is_open and chest.item == null):
		return
	var text := Text.with_keys("VERSUS_CHEST_OPEN")
	if chest.is_open:
		text = Text.with_keys("VERSUS_CHEST_TAKE", Text.t(chest.item.name_key))
	_draw_prompt(text, hunter.chest_held / chest.hold_time(mode.settings), size, font)


func _draw_boss(boss: BossKit, size: Vector2, font: Font) -> void:
	_canvas.draw_rect(Rect2(8, size.y - 80, 100, 4), BAR_BACK)
	_canvas.draw_rect(Rect2(8, size.y - 80, 100 * boss.health.rage / 100.0, 4), RAGE_COLOR)
	var rage := Text.t("VERSUS_RAGE")
	if boss.health.in_fury():
		rage = Text.t("VERSUS_FURY")
	elif boss.health.rage >= 100.0:
		rage = Text.t("VERSUS_FURY_READY")
	_canvas.draw_string(font, Vector2(8, size.y - 86), rage, HORIZONTAL_ALIGNMENT_LEFT)
	var reach := mode.settings.finish_reach
	if DownedHold.nearest(mode.hunters, boss.body.global_position, reach) != null:
		var ratio := boss.finish.ratio(mode.settings.finish_time)
		_draw_prompt(Text.with_keys("VERSUS_FINISH"), ratio, size, font)
