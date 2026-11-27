class_name KitPrompts
extends RefCounted
## What holding interact does for a Versus kit, shown under the crosshair
## (spec S-024, Q5, Q30, T-381): [text key, value, progress], or [] for
## nothing. The value goes in the text: a String is a text key (translated),
## a number is shown as it is, null leaves the text alone; progress is from
## 0 to 1, or -1 for no bar. Worked out where the game is played (solo, or
## the room) and sent as it is to a client (VersusNet).


## A hunted's prompt: out (a terminal left?), down (being revived? a
## syringe?), a teammate to revive, a return terminal to work, a chest to
## open or take from.
static func of_hunter(kit: HunterKit) -> Array:
	var mode := kit.mode
	var terminals := mode.terminals
	if kit.vitals.is_out():
		if terminals != null and terminals.ready_count() > 0:
			return ["VERSUS_OUT_TERMINAL", null, -1.0]
		return ["VERSUS_OUT", null, -1.0]
	if kit.vitals.is_down():
		return _of_downed(kit)
	var reach := mode.settings.revive_reach
	if DownedHold.nearest(mode.hunters, kit.body.global_position, reach, kit) != null:
		return ["VERSUS_REVIVE", null, kit.revive.ratio(kit.revive_time())]
	if terminals != null and terminals.first_out() != null and terminals.in_reach(kit) != null:
		return ["VERSUS_TERMINAL", null, maxf(terminals.ratio_of(kit), 0.0)]
	var chest := kit.chest if kit.chest != null else kit.chest_in_reach()
	if chest == null or (chest.is_open and chest.item == null):
		return []
	var ratio := kit.chest_held / chest.hold_time(mode.settings)
	if chest.is_open:
		return ["VERSUS_CHEST_TAKE", chest.item.name_key, ratio]
	return ["VERSUS_CHEST_OPEN", null, ratio]


## A downed hunted's prompt: being revived, its syringe (T-414), the time
## it has left.
static func _of_downed(kit: HunterKit) -> Array:
	for other in kit.mode.hunters:
		if other.revive.target == kit:
			return ["VERSUS_BEING_REVIVED", null, other.revive.ratio(other.revive_time())]
	if kit.syringe.is_going():
		return ["VERSUS_SYRINGE_GOING", null, kit.syringe.ratio(kit.mode.settings)]
	var slot := SyringeShot.slot_of(kit)
	if slot >= 0:
		var key := "VERSUS_DOWN_SYRINGE_1" if slot == 0 else "VERSUS_DOWN_SYRINGE_2"
		return [key, ceili(kit.vitals.down_left), -1.0]
	return ["VERSUS_DOWN_TIME", ceili(kit.vitals.down_left), -1.0]


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
