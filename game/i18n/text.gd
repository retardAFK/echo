class_name Text
extends RefCounted
## The one door to the texts the player reads (internationalisation, T-450).
## Every text of the game is a key of game/i18n/strings.csv; the code never
## writes a sentence itself, it asks Text for the sentence of a key. Only
## this file talks to TranslationServer, so changing how texts are stored
## (CSV today, PO files if the game ships in English, Q-011) touches nothing
## else. How to add, rename or remove a text: game/i18n/README.md.

## Suffixes of the two forms of a counted text (see count()).
const ONE := "_ONE"
const MANY := "_MANY"
## Key of the decimal separator of the current language ("," in French).
const DECIMAL_KEY := "FORMAT_DECIMAL_POINT"


## The text of a key in the current language. With values, its %d / %s
## placeholders are filled: Text.t("HUD_DISTANCE", 12) gives "12 m".
## A key missing from the file comes back as is, which the key test
## (tests/test_i18n_keys.gd) catches before it reaches a player.
static func t(key: String, values: Variant = null) -> String:
	var text := String(TranslationServer.translate(key))
	if values == null:
		return text
	return text % values


## The form of a counted text that agrees with n: the key KEY_ONE for one
## thing, KEY_MANY for several, both filled with n. French puts 0 and 1 in
## the singular, other languages only 1.
static func count(key: String, n: int) -> String:
	return t(key + (ONE if is_singular(n) else MANY), n)


## Whether n takes the singular form in the current language.
static func is_singular(n: int) -> bool:
	if TranslationServer.get_locale().begins_with("fr"):
		return absi(n) < 2
	return absi(n) == 1


## The text of a key with its key tokens ({interact}, {move}...) replaced by
## the names of the keys the player chose, for the keyboard chosen.
static func with_keys(key: String, values: Variant = null) -> String:
	return Settings.fill(t(key, values))


## A decimal number written the way the current language writes it:
## Text.decimal(1.25) gives "1,25" in French.
static func decimal(value: float, digits := 2) -> String:
	return String.num(value, digits).pad_decimals(digits).replace(".", t(DECIMAL_KEY))
