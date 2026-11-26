class_name VersusSettings
extends Resource
## Tunable values of the Versus mode (spec S-024, T-371): the boss's health,
## phases, poise and rage, the hunted's health, stamina and flare launcher,
## and the clock. Starting values from the spec, to tune by simulation.

@export_group("Boss")
## Boss health for each hunted at the start (Q7).
@export_range(50.0, 2000.0, 10.0) var boss_health_per_hunted: float = 400.0
## Phases, highest start_ratio first (Q8).
@export var phases: Array[VersusPhase] = []
## Seconds the boss cannot be hurt when a phase starts (Q8, its cry).
@export_range(0.0, 10.0, 0.1, "suffix:s") var phase_shield_time: float = 2.0
## Poise points before the boss falls to its knees (Q11).
@export_range(10.0, 1000.0, 5.0) var poise_max: float = 100.0
## Poise points lost per second when nothing hits it.
@export_range(0.0, 100.0, 0.5) var poise_decay: float = 8.0
## Seconds on its knees (Q11).
@export_range(0.0, 10.0, 0.1, "suffix:s") var kneel_time: float = 3.0
## Damage multiplier while on its knees (Q11).
@export_range(1.0, 4.0, 0.1) var kneel_damage_scale: float = 2.0
## Seconds after getting up before it can be knocked down again (Q11).
@export_range(0.0, 60.0, 0.5, "suffix:s") var kneel_immunity: float = 15.0
## Rage gained per point of damage taken, in percent (Q10).
@export_range(0.0, 1.0, 0.01) var rage_per_damage: float = 0.1
## Rage gained per hit landed on a hunted, in percent (Q10).
@export_range(0.0, 50.0, 0.5) var rage_per_hit: float = 5.0
## Rage lost per second without attacking, in percent (Q10).
@export_range(0.0, 10.0, 0.1) var rage_decay: float = 1.0
## Seconds without attacking before the rage starts to drain.
@export_range(0.0, 30.0, 0.5, "suffix:s") var rage_decay_delay: float = 5.0
## Length of the Fury, in seconds (Q9).
@export_range(1.0, 30.0, 0.5, "suffix:s") var fury_time: float = 10.0
## Speed multiplier during the Fury (Q9).
@export_range(1.0, 2.0, 0.05) var fury_speed_scale: float = 1.25

@export_group("Hunted")
## Hit points of a hunted (Q14).
@export_range(1, 10) var hunted_health: int = 3
## Seconds a downed hunted lasts before being out (Q5).
@export_range(5.0, 120.0, 1.0, "suffix:s") var down_time: float = 30.0
## Times a hunted can be revived (Q5).
@export_range(0, 5) var revives: int = 2
## Hit points after a revive (Q5).
@export_range(1, 10) var revive_health: int = 2
## Seconds of holding E to revive (Q5).
@export_range(0.5, 10.0, 0.1, "suffix:s") var revive_time: float = 3.0
## Seconds of holding E for the boss to finish a downed hunted (Q5).
@export_range(0.5, 10.0, 0.1, "suffix:s") var finish_time: float = 2.0

@export_group("Stamina and dodge")
## Seconds of stamina refill from empty to full (Q15).
@export_range(0.5, 20.0, 0.1, "suffix:s") var stamina_refill_time: float = 3.0
## Share of the stamina a dodge costs (Q15).
@export_range(0.0, 1.0, 0.01) var dodge_cost: float = 0.35
## Seconds without spending before the stamina refills.
@export_range(0.0, 5.0, 0.1, "suffix:s") var stamina_refill_delay: float = 0.6
## Share of the stamina a second of running costs.
@export_range(0.0, 1.0, 0.01) var run_cost: float = 0.12
## Length of the dodge roll, in meters (Q15).
@export_range(0.5, 10.0, 0.1, "suffix:m") var dodge_distance: float = 3.0
## Duration of the dodge roll, in seconds (Q15).
@export_range(0.1, 2.0, 0.05, "suffix:s") var dodge_time: float = 0.4
## Seconds of the roll during which nothing hurts (Q15).
@export_range(0.0, 2.0, 0.05, "suffix:s") var dodge_shield_time: float = 0.25
## Range of the roll's noise, in meters (Q15).
@export_range(0.0, 50.0, 0.5, "suffix:m") var dodge_noise_range: float = 6.0

@export_group("Flare launcher")
## Damage of a flare on the body (Q13).
@export_range(0.0, 500.0, 1.0) var flare_damage: float = 30.0
## Damage of a flare in the face (Q13).
@export_range(0.0, 500.0, 1.0) var flare_face_damage: float = 60.0
## Poise a flare in the face adds (Q11).
@export_range(0.0, 200.0, 1.0) var flare_face_poise: float = 35.0
## Poise a flare on the body adds.
@export_range(0.0, 200.0, 1.0) var flare_poise: float = 6.0
## Speed of a flare, in meters per second (Q13).
@export_range(5.0, 200.0, 1.0, "suffix:m/s") var flare_speed: float = 45.0
## Gravity on a flare, in meters per second squared: it drops a little after
## about 25 m (Q23).
@export_range(0.0, 30.0, 0.1, "suffix:m/s²") var flare_gravity: float = 4.0
## Seconds a flare flies before it goes out.
@export_range(0.5, 10.0, 0.1, "suffix:s") var flare_life: float = 2.0
## Seconds a flare burns on the ground (Q13).
@export_range(0.0, 30.0, 0.5, "suffix:s") var flare_ground_time: float = 8.0
## Flares in the launcher (Q13).
@export_range(1, 20) var flare_clip: int = 6
## Seconds between two shots.
@export_range(0.05, 3.0, 0.05, "suffix:s") var flare_cooldown: float = 0.45
## Seconds to reload (Q13).
@export_range(0.1, 10.0, 0.1, "suffix:s") var reload_time: float = 2.0
## Range of a shot's noise, in meters (Q13).
@export_range(0.0, 60.0, 0.5, "suffix:m") var shot_noise_range: float = 20.0

@export_group("Clock")
## Length of a Versus game, in seconds (Q3).
@export_range(30.0, 3600.0, 10.0, "suffix:s") var match_time: float = 600.0
## Seconds before the end when dawn is announced (Q3).
@export_range(0.0, 600.0, 5.0, "suffix:s") var dawn_warning: float = 120.0
## Seconds without attacking before the boss is shown to the hunted (Q4).
@export_range(5.0, 300.0, 1.0, "suffix:s") var hunted_boss_time: float = 45.0
