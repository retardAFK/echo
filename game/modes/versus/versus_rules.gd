class_name VersusRules
extends RefCounted
## Who wins a Versus game, and when (spec S-024, Q1 to Q6, T-371). Pure: it
## reads the boss's BossHealth and each hunted's HuntedVitals.
## - The hunted win when the boss's health reaches 0 (Q1), even in the same
##   frame as their last one falls (Q6).
## - The boss wins when no hunted stands (all down or out), or at the end of
##   the clock: dawn (Q2, Q3).
## - Q4: a boss that has not attacked for hunted_boss_time is shown.

enum Winner { NONE, HUNTED, BOSS }

var settings: VersusSettings
var boss: BossHealth
var hunted: Array[HuntedVitals] = []
## Seconds played.
var clock := 0.0
var winner := Winner.NONE


func _init(versus: VersusSettings, boss_health: BossHealth) -> void:
	settings = versus
	boss = boss_health


## Seconds left on the clock.
func time_left() -> float:
	return maxf(settings.match_time - clock, 0.0)


## Whether dawn is near (Q3).
func dawn_near() -> bool:
	return time_left() <= settings.dawn_warning


## Whether the boss is shown to the hunted (Q4).
func boss_tracked() -> bool:
	return boss.since_attack() >= settings.hunted_boss_time


func standing_count() -> int:
	var count := 0
	for vitals in hunted:
		if vitals.is_standing():
			count += 1
	return count


## Counts delta seconds and decides; returns the winner (NONE while it goes on).
func update(delta: float) -> Winner:
	if winner != Winner.NONE:
		return winner
	clock += delta
	winner = decide()
	return winner


## The winner now, without counting time.
func decide() -> Winner:
	if boss.is_dead():
		return Winner.HUNTED
	if not hunted.is_empty() and standing_count() == 0:
		return Winner.BOSS
	if clock >= settings.match_time:
		return Winner.BOSS
	return Winner.NONE
