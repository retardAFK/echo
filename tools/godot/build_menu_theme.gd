extends SceneTree
## Builds game/ui/theme/echo_theme.tres from MenuStyle (spec S-013, T-162).
## godot --headless -s res://tools/godot/build_menu_theme.gd
## Run it again after any change to MenuStyle; the theme file is not edited
## by hand.

const STYLE := preload("res://game/ui/theme/menu_style.gd")


func _init() -> void:
	var error := ResourceSaver.save(build(), STYLE.THEME_PATH)
	print("menu theme saved: ", error_string(error))
	quit(0 if error == OK else 1)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(STYLE.FONT_BODY)
	theme.default_font_size = STYLE.SIZE_BODY
	theme.set_color("font_color", "Label", STYLE.TEXT)
	_menu_items(theme)
	_labels(theme)
	_panels(theme)
	_digicode_and_intercom(theme)
	_hud(theme)
	_scroll_bars(theme)
	return theme


static func _font(path: String, spacing: int) -> Font:
	if spacing == 0:
		return load(path)
	var font := FontVariation.new()
	font.base_font = load(path)
	font.spacing_glyph = spacing
	return font


static func _flat(color: Color, margins: Vector4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box


static func _empty(margins: Vector4) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box


## Menu entries: plain text, a sodium band with dark text when chosen.
static func _menu_items(theme: Theme) -> void:
	var margins := Vector4(STYLE.BULLET_SIZE + 13, 1, 10, 1)
	for type in ["Button", "MenuItem", "SmallMenuItem"]:
		if type != "Button":
			theme.set_type_variation(type, "Button")
		var empty := _empty(margins)
		var lit := _flat(STYLE.SODIUM, margins)
		theme.set_stylebox("normal", type, empty)
		theme.set_stylebox("disabled", type, empty)
		theme.set_stylebox("hover", type, lit)
		theme.set_stylebox("pressed", type, lit)
		theme.set_stylebox("hover_pressed", type, lit)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, STYLE.TEXT)
		theme.set_color("font_disabled_color", type, STYLE.FAINT)
		for state in ["hover", "focus", "pressed", "hover_pressed"]:
			theme.set_color("font_%s_color" % state, type, STYLE.INK)
		theme.set_font("font", type, _font(STYLE.FONT_DISPLAY, STYLE.SPACING_ITEM))
	theme.set_font_size("font_size", "Button", STYLE.SIZE_SMALL_ITEM)
	theme.set_font_size("font_size", "MenuItem", STYLE.SIZE_ITEM)
	theme.set_font_size("font_size", "SmallMenuItem", STYLE.SIZE_SMALL_ITEM)


static func _labels(theme: Theme) -> void:
	var labels := {
		"TitleLabel": [STYLE.FONT_DISPLAY_BOLD, STYLE.SPACING_TITLE, STYLE.SIZE_TITLE, STYLE.CREAM],
		"HeadingLabel":
		[STYLE.FONT_DISPLAY_BOLD, STYLE.SPACING_HEADING, STYLE.SIZE_HEADING, STYLE.CREAM],
		"SubLabel": [STYLE.FONT_BODY_BOLD, STYLE.SPACING_LABEL * 2, STYLE.SIZE_HINT, STYLE.SODIUM],
		"BodyLabel": [STYLE.FONT_BODY, 0, STYLE.SIZE_BODY, STYLE.TEXT],
		"HintLabel": [STYLE.FONT_BODY, 0, STYLE.SIZE_HINT, STYLE.MUTED],
		"FootLabel": [STYLE.FONT_BODY, STYLE.SPACING_LABEL, STYLE.SIZE_FOOT, STYLE.FAINT],
		"PlateLabel": [STYLE.FONT_BODY_BOLD, STYLE.SPACING_LABEL, STYLE.SIZE_FOOT, STYLE.INK],
		"KeyLabel": [STYLE.FONT_DISPLAY, STYLE.SPACING_ITEM, STYLE.SIZE_BODY + 1, STYLE.CREAM],
		"CodeLabel": [STYLE.FONT_DISPLAY_BOLD, STYLE.SPACING_CODE, STYLE.SIZE_CODE, STYLE.SODIUM],
		"LcdLabel": [STYLE.FONT_DISPLAY_LCD, STYLE.SPACING_CODE / 2, STYLE.SIZE_LCD, STYLE.SODIUM],
	}
	for type: String in labels:
		var spec: Array = labels[type]
		theme.set_type_variation(type, "Label")
		theme.set_font("font", type, _font(spec[0], spec[1]))
		theme.set_font_size("font_size", type, spec[2])
		theme.set_color("font_color", type, spec[3])


static func _panels(theme: Theme) -> void:
	var band := _flat(STYLE.PANEL, Vector4(STYLE.MARGIN, 16, STYLE.MARGIN, 16))
	band.border_color = STYLE.SODIUM
	band.border_width_top = 1
	band.border_width_bottom = 1
	theme.set_type_variation("Band", "PanelContainer")
	theme.set_stylebox("panel", "Band", band)
	theme.set_type_variation("Plate", "PanelContainer")
	theme.set_stylebox("panel", "Plate", _flat(STYLE.TAG.darkened(0.12), Vector4(7, 2, 7, 2)))
	var info := _flat(STYLE.PANEL, Vector4(12, 10, 12, 10))
	info.border_color = STYLE.SODIUM
	info.border_width_left = 2
	theme.set_type_variation("InfoPanel", "PanelContainer")
	theme.set_stylebox("panel", "InfoPanel", info)
	var metal := _flat(STYLE.METAL, Vector4(10, 10, 10, 8))
	metal.border_color = STYLE.METAL_EDGE
	metal.set_border_width_all(1)
	metal.shadow_color = Color(0, 0, 0, 0.6)
	metal.shadow_size = 8
	metal.shadow_offset = Vector2(0, 4)
	theme.set_type_variation("MetalPanel", "PanelContainer")
	theme.set_stylebox("panel", "MetalPanel", metal)


static func _digicode_and_intercom(theme: Theme) -> void:
	theme.set_type_variation("DigicodeKey", "Button")
	var key := _flat(STYLE.KEY, Vector4(0, 1, 0, 1))
	key.border_color = STYLE.KEY_EDGE
	key.set_border_width_all(1)
	var lit := _flat(STYLE.SODIUM, Vector4(0, 1, 0, 1))
	lit.border_color = STYLE.SODIUM
	lit.set_border_width_all(1)
	theme.set_stylebox("normal", "DigicodeKey", key)
	theme.set_stylebox("disabled", "DigicodeKey", key)
	theme.set_stylebox("focus", "DigicodeKey", StyleBoxEmpty.new())
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "DigicodeKey", lit)
		theme.set_color("font_%s_color" % state, "DigicodeKey", STYLE.INK)
	theme.set_color("font_color", "DigicodeKey", STYLE.TEXT)
	theme.set_font("font", "DigicodeKey", _font(STYLE.FONT_DISPLAY, 0))
	theme.set_font_size("font_size", "DigicodeKey", STYLE.SIZE_BODY + 1)
	var lcd := _flat(STYLE.LCD, Vector4(6, 0, 6, 0))
	lcd.border_color = STYLE.INK
	lcd.set_border_width_all(1)
	theme.set_type_variation("LcdPanel", "PanelContainer")
	theme.set_stylebox("panel", "LcdPanel", lcd)
	theme.set_type_variation("OptionRow", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "OptionRow", StyleBoxEmpty.new())
	theme.set_type_variation("IntercomRow", "Button")
	var row := _empty(Vector4(0, 0, 0, 0))
	var row_lit := _flat(Color(STYLE.SODIUM, 0.18), Vector4(0, 0, 0, 0))
	theme.set_stylebox("normal", "IntercomRow", row)
	theme.set_stylebox("disabled", "IntercomRow", row)
	theme.set_stylebox("focus", "IntercomRow", StyleBoxEmpty.new())
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "IntercomRow", row_lit)
	for type in ["NameTag", "NameTagAi"]:
		var tag := _flat(STYLE.TAG if type == "NameTag" else STYLE.TAG_AI, Vector4(6, 1, 6, 1))
		tag.border_color = STYLE.TAG_EDGE
		tag.set_border_width_all(1)
		theme.set_type_variation(type, "PanelContainer")
		theme.set_stylebox("panel", type, tag)
	theme.set_type_variation("TagLabel", "Label")
	theme.set_font("font", "TagLabel", _font(STYLE.FONT_DISPLAY, 0))
	theme.set_font_size("font_size", "TagLabel", STYLE.SIZE_BODY + 2)
	theme.set_color("font_color", "TagLabel", STYLE.INK)


## The HUD in game (T-165): labels outlined in warm black, and the green text
## of the terminals' screens.
static func _hud(theme: Theme) -> void:
	var labels := {
		"HudLabel": [STYLE.FONT_DISPLAY, STYLE.SPACING_ITEM, STYLE.SIZE_HUD, STYLE.TEXT],
		"HudValue": [STYLE.FONT_DISPLAY, STYLE.SPACING_ITEM, STYLE.SIZE_HUD, STYLE.SODIUM],
		"HudPrompt": [STYLE.FONT_BODY_BOLD, 0, STYLE.SIZE_HUD_PROMPT, STYLE.CREAM],
		"HudBig": [STYLE.FONT_DISPLAY_BOLD, STYLE.SPACING_HEADING, STYLE.SIZE_HUD_BIG, STYLE.CREAM],
		"ScreenLabel": [STYLE.FONT_DISPLAY_LCD, 0, STYLE.SIZE_SCREEN, STYLE.SCREEN],
	}
	for type: String in labels:
		var spec: Array = labels[type]
		theme.set_type_variation(type, "Label")
		theme.set_font("font", type, _font(spec[0], spec[1]))
		theme.set_font_size("font_size", type, spec[2])
		theme.set_color("font_color", type, spec[3])
		if type != "ScreenLabel":
			theme.set_color("font_outline_color", type, STYLE.INK)
			theme.set_constant("outline_size", type, STYLE.OUTLINE_HUD)
	var screen := _flat(Color(0.0, 0.05, 0.02, 0.85), Vector4(8, 6, 8, 6))
	screen.border_color = STYLE.SCREEN_DIM
	screen.set_border_width_all(1)
	theme.set_type_variation("ScreenPanel", "PanelContainer")
	theme.set_stylebox("panel", "ScreenPanel", screen)


## The vertical scroll bar of the credits (T-167): a thin dark rail and a
## sodium grabber, no buttons.
static func _scroll_bars(theme: Theme) -> void:
	var rail := _flat(Color(STYLE.FAINT, 0.35), Vector4(2, 0, 2, 0))
	var grabber := _flat(Color(STYLE.SODIUM, 0.7), Vector4(2, 0, 2, 0))
	var grabber_lit := _flat(STYLE.SODIUM, Vector4(2, 0, 2, 0))
	theme.set_stylebox("scroll", "VScrollBar", rail)
	theme.set_stylebox("scroll_focus", "VScrollBar", rail)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_lit)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_lit)
