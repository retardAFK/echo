class_name MenuStyle
extends RefCounted
## The menu look chosen by Maxime (spec S-013, Q1): style A, "Sodium et
## digicode". Colors, fonts and sizes live here only; the theme file
## game/ui/theme/echo_theme.tres is generated from them by
## tools/godot/build_menu_theme.gd. Never the noise orange (rule 2.3).

const THEME_PATH := "res://game/ui/theme/echo_theme.tres"

## Warm black of the panels and of the text on a selection.
const INK := Color("0b0a08")
## Cream of the titles.
const CREAM := Color("efe6cc")
## Beige of the menu entries and of the texts.
const TEXT := Color("d8d0bb")
## Warm grey of the hints and of the disabled entries.
const MUTED := Color("8c8572")
## Darker warm grey of the bullets and of the footer.
const FAINT := Color("6e685a")
## Sodium ocher of the street lamps: selection, code, lamps.
const SODIUM := Color("ddb45a")
## Panel behind a group (pause band, tabs), almost black, a bit see-through.
const PANEL := Color(0.04, 0.035, 0.03, 0.88)
## Metal of the digicode and of the intercom.
const METAL := Color("3e3d38")
const METAL_EDGE := Color("6a6860")
## Name tag of the intercom, and the tag of a seat played by an AI.
const TAG := Color("e7e1cf")
const TAG_AI := Color("8f8a7b")
const TAG_EDGE := Color("9a9483")
## Keys and display of the digicode.
const KEY := Color("1d1c1a")
const KEY_EDGE := Color("55534c")
const LCD := Color("2c2a17")

const FONT_DISPLAY_BOLD := "res://assets/fonts/BarlowCondensed-ExtraBold.ttf"
const FONT_DISPLAY := "res://assets/fonts/BarlowCondensed-SemiBold.ttf"
const FONT_BODY := "res://assets/fonts/Barlow-Medium.ttf"
const FONT_BODY_BOLD := "res://assets/fonts/Barlow-SemiBold.ttf"
const FONT_DISPLAY_LCD := "res://assets/fonts/VT323-Regular.ttf"

## Font sizes on the 640 x 360 base (D-011).
const SIZE_TITLE := 64
const SIZE_HEADING := 26
const SIZE_ITEM := 17
const SIZE_SMALL_ITEM := 13
const SIZE_BODY := 9
const SIZE_HINT := 8
const SIZE_FOOT := 7
const SIZE_CODE := 46
const SIZE_LCD := 26

## The HUD in game (T-165), on the same base: small condensed capitals with
## a dark outline, readable over any scene.
const SIZE_HUD := 11
const SIZE_HUD_PROMPT := 10
const SIZE_HUD_BIG := 30
const OUTLINE_HUD := 3
## The old terminals' screens and the camera feed: green VT323 text.
const SIZE_SCREEN := 12
const SCREEN := Color(0.55, 1.0, 0.6)
const SCREEN_DIM := Color(0.3, 0.6, 0.35)

## Extra space between letters, in pixels of the 640 x 360 base.
const SPACING_TITLE := 9
const SPACING_HEADING := 3
const SPACING_ITEM := 1
const SPACING_LABEL := 2
const SPACING_CODE := 12

## Left margin of every menu screen.
const MARGIN := 34
## Bullet square in front of a menu entry.
const BULLET_SIZE := 5
