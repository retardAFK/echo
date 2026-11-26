extends GutTest
## Pure rules of the Versus mode (spec S-024, T-371): boss health, phases,
## poise, rage, hunted vitals, stamina, who wins, shot geometry.

const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")

var _settings: VersusSettings


func before_each() -> void:
	_settings = SETTINGS.duplicate()


func test_boss_health_scales_with_hunted() -> void:
	assert_eq(BossHealth.new(_settings, 2).max_health, 800.0)
	assert_eq(BossHealth.new(_settings, 4).max_health, 1600.0)


func test_phases_change_at_thresholds_with_a_shield() -> void:
	var boss := BossHealth.new(_settings, 1)
	watch_signals(boss)
	boss.take_hit(100.0)
	assert_eq(boss.phase, 0)
	boss.take_hit(40.0)  # 260 / 400 = 0.65
	assert_eq(boss.phase, 1)
	assert_signal_emitted_with_parameters(boss, "phase_changed", [1])
	assert_true(boss.is_shielded())
	assert_eq(boss.take_hit(50.0), 0.0, "no damage during the phase cry")
	boss.update(_settings.phase_shield_time + 0.1)
	assert_eq(boss.take_hit(50.0), 50.0)


func test_enraged_phase_takes_more_damage() -> void:
	var boss := BossHealth.new(_settings, 1)
	boss.take_hit(280.0)  # 0.3: phase 3
	assert_eq(boss.phase, 2)
	boss.update(5.0)
	assert_almost_eq(boss.take_hit(40.0), 50.0, 0.01)
	assert_gt(boss.speed_scale(), 1.0)


func test_poise_kneels_then_immunity() -> void:
	var boss := BossHealth.new(_settings, 4)
	watch_signals(boss)
	for i in 3:
		boss.take_hit(10.0, 35.0)
	assert_true(boss.is_kneeling())
	assert_signal_emitted(boss, "knelt")
	assert_almost_eq(boss.take_hit(10.0), 20.0, 0.01, "double damage on its knees")
	boss.update(_settings.kneel_time + 0.01)
	assert_false(boss.is_kneeling())
	for i in 5:
		boss.take_hit(1.0, 35.0)
	assert_false(boss.is_kneeling(), "cannot be knocked down again so soon")


func test_rage_fills_and_fury() -> void:
	var boss := BossHealth.new(_settings, 4)
	assert_false(boss.start_fury())
	for i in 20:
		boss.attacked(true)
	assert_eq(boss.rage, 100.0)
	assert_true(boss.start_fury())
	assert_true(boss.in_fury())
	assert_eq(boss.rage, 0.0)
	boss.update(_settings.fury_time + 0.1)
	assert_false(boss.in_fury())


func test_rage_drains_without_attacking() -> void:
	var boss := BossHealth.new(_settings, 4)
	boss.attacked(true)
	boss.update(_settings.rage_decay_delay + 2.0)
	assert_lt(boss.rage, _settings.rage_per_hit)


func test_hunted_down_revive_and_out() -> void:
	var vitals := HuntedVitals.new(_settings)
	assert_true(vitals.hurt(3))
	assert_true(vitals.is_down())
	assert_true(vitals.revive())
	assert_eq(vitals.health, _settings.revive_health)
	vitals.hurt(2)
	assert_true(vitals.revive())
	assert_eq(vitals.revives_left, 0)
	vitals.hurt(2)
	assert_true(vitals.is_out(), "its third fall: out at once")
	assert_false(vitals.revive())


func test_hunted_bleeds_out_and_finish() -> void:
	var vitals := HuntedVitals.new(_settings)
	vitals.hurt(3)
	vitals.update(_settings.down_time + 0.1)
	assert_true(vitals.is_out())
	var other := HuntedVitals.new(_settings)
	other.hurt(3)
	other.finish()
	assert_true(other.is_out())


func test_dodge_shield() -> void:
	var vitals := HuntedVitals.new(_settings)
	vitals.shield(0.25)
	assert_false(vitals.hurt(1))
	vitals.update(0.3)
	assert_true(vitals.hurt(1))


func test_stamina_dodge_and_refill() -> void:
	var stamina := Stamina.new(_settings)
	assert_true(stamina.spend(_settings.dodge_cost))
	assert_true(stamina.spend(_settings.dodge_cost))
	assert_false(stamina.spend(_settings.dodge_cost))
	stamina.update(_settings.stamina_refill_delay + 0.01)
	stamina.update(_settings.stamina_refill_time)
	assert_eq(stamina.value, 1.0)


func test_hunted_win_when_boss_dies_even_with_none_standing() -> void:
	var boss := BossHealth.new(_settings, 1)
	var rules := VersusRules.new(_settings, boss)
	var vitals := HuntedVitals.new(_settings)
	rules.hunted.append(vitals)
	assert_eq(rules.update(1.0), VersusRules.Winner.NONE)
	vitals.hurt(3)
	boss.take_hit(1000.0)
	assert_eq(rules.update(0.0), VersusRules.Winner.HUNTED)


func test_boss_wins_when_none_standing_or_at_dawn() -> void:
	var rules := VersusRules.new(_settings, BossHealth.new(_settings, 2))
	var a := HuntedVitals.new(_settings)
	var b := HuntedVitals.new(_settings)
	rules.hunted.append_array([a, b])
	a.hurt(3)
	assert_eq(rules.update(1.0), VersusRules.Winner.NONE)
	b.hurt(3)
	assert_eq(rules.update(1.0), VersusRules.Winner.BOSS)
	var dawn := VersusRules.new(_settings, BossHealth.new(_settings, 1))
	dawn.hunted.append(HuntedVitals.new(_settings))
	dawn.update(_settings.match_time - _settings.dawn_warning + 1.0)
	assert_true(dawn.dawn_near())
	assert_eq(dawn.update(_settings.match_time), VersusRules.Winner.BOSS)


func test_boss_tracked_after_idle() -> void:
	var boss := BossHealth.new(_settings, 1)
	var rules := VersusRules.new(_settings, boss)
	boss.update(_settings.hunted_boss_time + 1.0)
	assert_true(rules.boss_tracked())
	boss.attacked(false)
	assert_false(rules.boss_tracked())


func test_flare_arc_drops() -> void:
	var state := [Vector3.ZERO, Vector3(0, 0, -_settings.flare_speed)]
	for i in 60:
		state = ShotMath.step(state[0], state[1], _settings.flare_gravity, 1.0 / 60.0)
	assert_almost_eq((state[0] as Vector3).z, -_settings.flare_speed, 0.01)
	assert_lt((state[0] as Vector3).y, -1.0)


func test_claw_arc_and_lamp_cone() -> void:
	var facing := Vector3.FORWARD
	assert_true(ShotMath.in_arc(Vector3.ZERO, facing, Vector3(0, 0, -2), 2.5, 45.0, 1.5))
	assert_false(ShotMath.in_arc(Vector3.ZERO, facing, Vector3(0, 0, 2), 2.5, 45.0, 1.5))
	assert_false(ShotMath.in_arc(Vector3.ZERO, facing, Vector3(0, 0, -3), 2.5, 45.0, 1.5))
	assert_true(ShotMath.in_cone(Vector3.ZERO, facing, Vector3(0.5, 0, -6), 8.0, 20.0))
	assert_false(ShotMath.in_cone(Vector3.ZERO, facing, Vector3(5, 0, -6), 8.0, 20.0))
