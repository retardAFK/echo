class_name KitPrompts
extends RefCounted
## What holding interact does for a Versus kit, shown under the crosshair
## (spec S-024, Q5, Q30, T-381): [text key, value, progress], or [] for
## nothing. The value goes in the text: a String is a text key (translated),
## a number is shown as it is, null leaves the text alone; progress is from
## 0 to 1, or -1 for no bar. Worked out where the game is played (solo, or
## the room) and sent as it is to a client (VersusNet).


## A hunted's prompt: out, down (being revived?), a teammate to revive, a
## chest to open or take from.
static func of_hunter(kit: HunterKit) -> Array:
	var mode := kit.mode
	if kit.vitals.is_out():
		return ["VERSUS_OUT", null, -1.0]
	if kit.vitals.is_down():
		for other in mode.hunters:
			if other.revive.target == kit:
				return ["VERSUS_BEING_REVIVED", null, other.revive.ratio(other.revive_time())]
		return ["VERSUS_DOWN_TIME", ceili(kit.vitals.down_left), -1.0]
	var reach := mode.settings.revive_reach
	if DownedHold.nearest(mode.hunters, kit.body.global_position, reach, kit) != null:
		return ["VERSUS_REVIVE", null, kit.revive.ratio(kit.revive_time())]
	var chest := kit.chest if kit.chest != null else kit.chest_in_reach()
	if chest == null or (chest.is_open and chest.item == null):
		return []
	var ratio := kit.chest_held / chest.hold_time(mode.settings)
	if chest.is_open:
		return ["VERSUS_CHEST_TAKE", chest.item.name_key, ratio]
	return ["VERSUS_CHEST_OPEN", null, ratio]


## The boss's prompt: a downed hunted to finish.
static func of_boss(boss: BossKit) -> Array:
	var mode := boss.mode
	var reach := mode.settings.finish_reach
	if DownedHold.nearest(mode.hunters, boss.body.global_position, reach) == null:
		return []
	return ["VERSUS_FINISH", null, boss.finish.ratio(mode.settings.finish_time)]


## The text of a prompt, keys of the controls filled in.
static func text_of(prompt: Array) -> String:
	if prompt.size() < 2:
		return ""
	var value: Variant = prompt[1]
	if value is String or value is StringName:
		value = Text.t(String(value))
	return Text.with_keys(String(prompt[0]), value)
