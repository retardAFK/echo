class_name VersusStats
extends RefCounted
## What each hunted did in a Versus game, for the end screen (spec S-024,
## Q28, T-380): damage dealt to the boss, hits in the face, teammates
## revived, and the best player (MVP). VersusMode tells it of each hit.

var settings: VersusSettings
## Damage dealt to the boss, by shooter (a hunted's body).
var damage := {}
## Hits in the face, by shooter.
var face_hits := {}


func _init(versus: VersusSettings) -> void:
	settings = versus


## A shot of shooter took taken from the boss's health.
func on_hit(shooter: Node, face: bool, taken: float) -> void:
	if shooter == null:
		return
	damage[shooter] = damage.get(shooter, 0.0) + taken
	if face:
		face_hits[shooter] = face_hits.get(shooter, 0) + 1


func damage_of(kit: HunterKit) -> float:
	return damage.get(kit.body, 0.0)


func faces_of(kit: HunterKit) -> int:
	return face_hits.get(kit.body, 0)


## Its MVP score: damage, plus points per revive and per face hit.
func score(kit: HunterKit) -> float:
	return (
		damage_of(kit)
		+ kit.revives_done * settings.mvp_revive_points
		+ faces_of(kit) * settings.mvp_face_points
	)


## The hunted with the best score, or null without any.
func mvp(hunters: Array[HunterKit]) -> HunterKit:
	var best: HunterKit
	for kit in hunters:
		if best == null or score(kit) > score(best):
			best = kit
	return best


## What the hunted is called on the end screen: "Vous" on its own machine,
## else "Chassé n" (n: its place, from 1).
static func name_of(hunters: Array[HunterKit], kit: HunterKit) -> String:
	if kit.is_local():
		return Text.t("VERSUS_YOU")
	return Text.t("VERSUS_HUNTED_N", hunters.find(kit) + 1)


## One line per hunted: damage, face hits, revives.
func lines(hunters: Array[HunterKit]) -> Array[String]:
	var result: Array[String] = []
	for kit in hunters:
		result.append(
			Text.t(
				"VERSUS_END_LINE",
				[name_of(hunters, kit), roundi(damage_of(kit)), faces_of(kit), kit.revives_done]
			)
		)
	return result


## Online (T-381): one row per hunted, [seat, damage, face hits, revives],
## seat_of giving each body's seat; the clients write their own lines.
func rows(hunters: Array[HunterKit], seat_of: Callable) -> Array:
	var result := []
	for kit in hunters:
		result.append(
			[seat_of.call(kit.body), roundi(damage_of(kit)), faces_of(kit), kit.revives_done]
		)
	return result


## The lines of rows, the hunted of own_seat called "Vous".
static func lines_of(rows: Array, own_seat: int) -> Array[String]:
	var result: Array[String] = []
	for row: Array in rows:
		if row.size() >= 4:
			result.append(
				Text.t("VERSUS_END_LINE", [seat_name(row[0], own_seat), row[1], row[2], row[3]])
			)
	return result


## "Vous" for own_seat, else "Chassé n".
static func seat_name(seat: int, own_seat: int) -> String:
	return Text.t("VERSUS_YOU") if seat == own_seat else Text.t("VERSUS_HUNTED_N", seat)
