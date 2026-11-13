class_name RoomCode
extends RefCounted
## Four-letter game codes (S-010, Q3 and Q6), easy to read out and type:
## no letter that looks like a digit or another letter (I, L, O, S).

const LETTERS := "ABCDEFGHJKMNPQRTUVWXYZ"
const LENGTH := 4


## A new code, different from those in taken.
static func generate(rng: RandomNumberGenerator, taken: Array = []) -> String:
	while true:
		var code := ""
		for i in LENGTH:
			code += LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
		if not taken.has(code):
			return code
	return ""


## What the player typed, as a code: spaces removed, upper case.
static func normalize(text: String) -> String:
	return text.strip_edges().replace(" ", "").to_upper()


## Whether a normalized text can be a code.
static func is_valid(code: String) -> bool:
	if code.length() != LENGTH:
		return false
	for letter in code:
		if not LETTERS.contains(letter):
			return false
	return true
