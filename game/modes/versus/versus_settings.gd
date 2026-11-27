class_name VersusSettings
extends Resource
## Tunable values of the Versus mode (spec S-024, T-371): the boss's health,
## phases, poise and rage, the hunted's health, stamina and guns (their own numbers in
## data/weapons/, VersusWeapon),
## and the clock. Starting values from the spec, to tune by simulation.

@export_group("Boss")
## Size of the boss's model (S-025, Q8), and of the hitbox the shots meet
## (BossLook); its collision with the map stays the monster's.
@export_range(1.0, 2.0, 0.05) var boss_scale: float = 1.3
## Boss health for each hunted at the start (Q7).
## 250 after the simulations (T-384, flares); 500 with the hitscan guns
## (T-408, the boss melted in a minute at 250).
@export_range(50.0, 2000.0, 10.0) var boss_health_per_hunted: float = 500.0
## That health scaled by the number of hunted: entry n - 1 for n hunted, 1
## past the end. Tuned by the simulations (T-408 and T-411, 12 games each):
## with 2, 3 and 4 AI hunted the AI boss then wins 58 % of the games.
@export var boss_health_scales: PackedFloat32Array = [1.0, 0.8, 0.75, 0.45]
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

@export_group("View")
## The camera behind the shoulder (S-025, Q1): its distance behind the head,
## for a hunted and for the bigger boss; how far the crosshair's ray looks.
@export_range(1.0, 10.0, 0.1, "suffix:m") var view_distance: float = 3.0
@export_range(1.0, 15.0, 0.1, "suffix:m") var boss_view_distance: float = 4.5
@export_range(10.0, 500.0, 5.0, "suffix:m") var aim_reach: float = 150.0

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
## How close a teammate must be to revive, and the boss to finish (Q5).
@export_range(0.5, 5.0, 0.1, "suffix:m") var revive_reach: float = 2.0
@export_range(0.5, 5.0, 0.1, "suffix:m") var finish_reach: float = 2.5
## The noise of a revive (Q5).
@export_range(0.0, 30.0, 1.0, "suffix:m") var revive_noise_range: float = 8.0
## How fast a downed hunted crawls (Q5).
@export_range(0.0, 3.0, 0.1, "suffix:m/s") var crawl_speed: float = 0.8
## A medkit in a tool slot shortens a revive to this share of its time,
## and is spent (Q13).
@export_range(0.1, 1.0, 0.05) var medkit_revive_factor: float = 0.5

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

@export_group("Flares")
## A Flare: a shot that flies (S-024; S-025 keeps it for the precision
## rifle of T-404). Damage of a flare on the body (Q13).
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

@export_group("Clock")
## Length of a Versus game, in seconds (Q3).
@export_range(30.0, 3600.0, 10.0, "suffix:s") var match_time: float = 480.0
## Seconds before the end when its last minutes are announced (Q3; called
## "dawn" in the code since S-024): a siren, the boss's last phase.
@export_range(0.0, 600.0, 5.0, "suffix:s") var dawn_warning: float = 60.0

@export_group("Zone")
## The zone (S-025, Q6, VersusZone): when each step starts shrinking, in
## seconds of play, and the share of the start radius it shrinks to.
@export var zone_step_times := PackedFloat32Array([120.0, 240.0, 360.0])
@export var zone_step_ratios := PackedFloat32Array([0.65, 0.4, 0.18])
## Seconds a step takes to shrink.
@export_range(1.0, 120.0, 1.0, "suffix:s") var zone_shrink_time: float = 30.0
## Outside: a hunted loses a point every zone_hunted_tick seconds, the boss
## this share of its health each second.
@export_range(0.5, 30.0, 0.5, "suffix:s") var zone_hunted_tick: float = 4.0
@export_range(0.0, 0.2, 0.005) var zone_boss_share: float = 0.02
## Seconds before a step when the banner warns of it.
@export_range(0.0, 60.0, 1.0, "suffix:s") var zone_warning: float = 20.0
## Seconds without attacking before the boss is shown to the hunted (Q4).
@export_range(5.0, 300.0, 1.0, "suffix:s") var hunted_boss_time: float = 45.0

@export_group("Hits")
## Distance from the boss's eyes within which a flare is in the face (Q13).
@export_range(0.1, 1.5, 0.05, "suffix:m") var face_radius: float = 0.45
## Flares that light the scene for real at once (budget of 4 lights, plan).
@export_range(0, 4) var flare_lights: int = 2
## Range of a flare's light, in meters.
@export_range(1.0, 30.0, 0.5, "suffix:m") var flare_light_range: float = 9.0
## Seconds the hit marker stays on the crosshair (Q21).
@export_range(0.05, 1.0, 0.05, "suffix:s") var hit_marker_time: float = 0.25
## Seconds a damage number floats over the boss (S-025, Q4).
@export_range(0.1, 3.0, 0.05, "suffix:s") var damage_number_time: float = 0.8

@export_group("Boss blows")
## Claw reach, half angle and height (Q9).
@export_range(0.5, 6.0, 0.1, "suffix:m") var claw_reach: float = 2.5
@export_range(5.0, 180.0, 5.0, "suffix:°") var claw_half_angle: float = 45.0
@export_range(0.2, 4.0, 0.1, "suffix:m") var claw_height: float = 1.5
## Seconds of the raised arm before the claw lands (Q9, the signal).
@export_range(0.0, 2.0, 0.05, "suffix:s") var claw_windup: float = 0.35
@export_range(0.1, 5.0, 0.05, "suffix:s") var claw_cooldown: float = 0.8
@export_range(1, 5) var claw_damage: int = 1
## Seconds the boss crouches and roars before charging (Q9, the signal).
@export_range(0.0, 3.0, 0.05, "suffix:s") var charge_windup: float = 0.6
@export_range(2.0, 40.0, 0.5, "suffix:m") var charge_distance: float = 14.0
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var charge_speed: float = 16.0
## Nearest target the AI boss charges, in meters.
@export_range(0.0, 20.0, 0.5, "suffix:m") var charge_min_distance: float = 6.0
@export_range(0.5, 60.0, 0.5, "suffix:s") var charge_cooldown: float = 8.0
@export_range(1, 5) var charge_damage: int = 2
## Distance at which the charge hits a hunted, in meters.
@export_range(0.3, 3.0, 0.1, "suffix:m") var charge_hit_radius: float = 1.2
## Seconds the boss is stunned after charging into a wall (Q9).
@export_range(0.0, 10.0, 0.1, "suffix:s") var charge_stun: float = 2.0
## The leap (Q9, phase 2+): onto a noise heard lately, between these
## distances, aimed within this cosine of the noise (a played boss).
@export_range(0.0, 20.0, 0.5, "suffix:m") var leap_min_distance: float = 5.0
@export_range(5.0, 60.0, 1.0, "suffix:m") var leap_range: float = 25.0
@export_range(0.5, 1.0, 0.01) var leap_aim_cos: float = 0.95
## Seconds a noise stays a leap target.
@export_range(0.5, 20.0, 0.5, "suffix:s") var leap_noise_memory: float = 4.0
## Seconds in the air (its shadow shows that long) and the arc's height.
@export_range(0.3, 3.0, 0.05, "suffix:s") var leap_time: float = 1.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var leap_height: float = 3.5
## The shock wave at the landing: radius, hit points, how far it throws.
@export_range(0.5, 10.0, 0.1, "suffix:m") var leap_radius: float = 3.0
@export_range(0, 3) var leap_damage: int = 1
@export_range(0.0, 10.0, 0.5, "suffix:m") var leap_knock: float = 3.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var leap_cooldown: float = 12.0
## Seconds between the two blows of the double claw (phase 3, Q8).
@export_range(0.1, 1.0, 0.05, "suffix:s") var double_claw_delay: float = 0.3
## Share of the ambient light left when the arena lights go out (Q8).
@export_range(0.0, 1.0, 0.05) var lights_out_ambient: float = 0.5

@export_group("End")
## Time scale of the slow motion on the killing blow, and its real length (Q1).
@export_range(0.05, 1.0, 0.05) var kill_slowmo_scale: float = 0.25
@export_range(0.0, 5.0, 0.1, "suffix:s") var kill_slowmo_time: float = 1.5
## Seconds the result stays on screen before the end screen (the test
## room starts again instead).
@export_range(0.0, 20.0, 0.5, "suffix:s") var end_delay: float = 4.0
## The camera turning around the fallen boss (Q1): distance, height, and
## turns per second.
@export_range(1.0, 20.0, 0.5, "suffix:m") var orbit_distance: float = 6.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var orbit_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var orbit_turns: float = 0.08
## The best player (Q28): points per revive and per hit in the face, on top
## of the damage dealt.
@export_range(0.0, 500.0, 5.0) var mvp_revive_points: float = 100.0
@export_range(0.0, 100.0, 1.0) var mvp_face_points: float = 10.0
## The siren of dawn near (Q3).
@export_range(0.0, 200.0, 5.0, "suffix:m") var dawn_siren_range: float = 100.0

@export_group("AI boss")
## The AI boss's choices (Q12, BossBrain): how much farther a hunted that
## hurt it more may be than the nearest and still be its target; how far
## from its teammates a shooter is alone (a leap target); how near the heard
## noise must be to that shooter.
@export_range(0.0, 30.0, 0.5, "suffix:m") var brain_grudge_margin: float = 6.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var brain_lone_distance: float = 8.0
@export_range(0.5, 10.0, 0.5, "suffix:m") var brain_leap_near: float = 4.0
## It backs off for brain_retreat_time once its poise reaches this share of
## poise_max, before it would kneel.
@export_range(0.0, 1.0, 0.05) var brain_retreat_poise: float = 0.8
@export_range(0.0, 10.0, 0.5, "suffix:s") var brain_retreat_time: float = 3.0

@export_group("AI hunted")
## Farthest the AI hunted shoots at the boss; it fires in bursts of
## ai_burst_time (holding fire), ai_fire_interval apart (S-025).
@export_range(1.0, 60.0, 1.0, "suffix:m") var ai_fire_range: float = 25.0
@export_range(0.2, 10.0, 0.1, "suffix:s") var ai_fire_interval: float = 1.4
@export_range(0.1, 5.0, 0.1, "suffix:s") var ai_burst_time: float = 1.0
## Its aim misses the boss's chest by up to this angle, drawn per burst: an
## AI hunted is not a perfect gun (T-408).
@export_range(0.0, 20.0, 0.5, "suffix:°") var ai_aim_error: float = 5.0
## Where it goes (Q17, PreyFighter), chosen every ai_think_interval: a
## downed teammate when the boss is at least ai_revive_safe from it; a chest
## (any when unarmed, else within ai_chest_detour with the boss at least
## ai_chest_safe from it). A goal not reached in ai_goal_time is given up.
@export_range(0.1, 5.0, 0.1, "suffix:s") var ai_think_interval: float = 0.5
@export_range(0.0, 50.0, 1.0, "suffix:m") var ai_revive_safe: float = 12.0
@export_range(0.0, 100.0, 1.0, "suffix:m") var ai_chest_detour: float = 25.0
@export_range(0.0, 50.0, 1.0, "suffix:m") var ai_chest_safe: float = 8.0
@export_range(1.0, 120.0, 1.0, "suffix:s") var ai_goal_time: float = 20.0
## Armed, the boss alarms it (it flees) only within ai_keep_distance; and
## it joins its nearest teammate once farther than ai_regroup_distance.
@export_range(0.0, 50.0, 1.0, "suffix:m") var ai_keep_distance: float = 10.0
@export_range(0.0, 100.0, 1.0, "suffix:m") var ai_regroup_distance: float = 10.0
## It rolls away from a claw wound up within claw_reach plus this.
@export_range(0.0, 5.0, 0.1, "suffix:m") var ai_dodge_margin: float = 1.0

@export_group("Arenas")
## The arenas (Q24): a game in a map listed here takes place in its arena;
## elsewhere (the test room), on the whole map.
@export var arenas: Array[VersusArena] = []

@export_group("Falls")
## A fall shorter than this does nothing, in meters (Q34).
@export_range(0.0, 20.0, 0.5, "suffix:m") var fall_safe_height: float = 4.0
## From fall_safe_height to this, a hunted loses 1 point; beyond, 2 (Q34).
@export_range(0.0, 30.0, 0.5, "suffix:m") var fall_hurt_height: float = 7.0
## A fall longer than this puts a hunted down at once (Q34).
@export_range(0.0, 60.0, 0.5, "suffix:m") var fall_down_height: float = 10.0
## Share of its full health the boss loses past fall_hurt_height (Q34).
@export_range(0.0, 0.5, 0.01) var boss_fall_ratio: float = 0.05
## Seconds the boss is stunned after such a fall (Q34).
@export_range(0.0, 5.0, 0.1, "suffix:s") var boss_fall_stun: float = 1.0
## Range of the noise of a fall past fall_safe_height (Q34).
@export_range(0.0, 60.0, 1.0, "suffix:m") var fall_noise_range: float = 15.0
## Points a dodge roll at the landing takes off a hunted's fall (Q34).
@export_range(0, 3) var fall_roll_saving: int = 1

@export_group("Chests")
## Every weapon and tool (Q13); chests draw among them (Q31).
@export var items: Array[VersusItem] = []
## The weapon in each hunted's first chest (Q29), always common.
@export var first_weapon: VersusItem
## The rarities of the guns (S-025, Q3), common first; a chest's gun draws
## one by its weights.
@export var rarities: Array[VersusRarity] = []
## Seconds to hold interact to open a chest, then to take from an open one (Q30).
@export_range(0.0, 10.0, 0.1, "suffix:s") var chest_open_time: float = 2.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var chest_take_time: float = 0.5
## How close a hunted opens a chest, and the range of the lid's noise (Q30).
@export_range(0.5, 5.0, 0.1, "suffix:m") var chest_reach: float = 2.5
@export_range(0.0, 60.0, 1.0, "suffix:m") var chest_noise_range: float = 10.0
## Chests of the arena at the start, and new ones at each phase (Q32).
@export_range(0, 20) var arena_chests: int = 4
@export_range(0, 20) var phase_chests: int = 3
## Spare shots a hunted has when it gets its first gun.
@export_range(0, 300) var start_spare_ammo: int = 90

@export_group("UV laser")
## The lance-laser UV (Q13): reach, damage per second (twice in the face),
## how much it slows the boss, its battery and its recharge, its hum.
@export_range(1.0, 100.0, 1.0, "suffix:m") var laser_range: float = 30.0
@export_range(0.0, 100.0, 1.0) var laser_damage_per_second: float = 15.0
@export_range(0.0, 1.0, 0.05) var laser_slow: float = 0.3
@export_range(0.1, 30.0, 0.5, "suffix:s") var laser_battery: float = 6.0
@export_range(0.1, 60.0, 0.5, "suffix:s") var laser_recharge: float = 10.0
@export_range(0.0, 60.0, 1.0, "suffix:m") var laser_noise_range: float = 6.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var laser_noise_interval: float = 1.0

@export_group("Tools")
## Seconds a push takes (the sonic shotgun's, S-025: its distance is the
## gun's push).
@export_range(0.05, 2.0, 0.05, "suffix:s") var sonic_push_time: float = 0.3
## Flash grenade (S-025, Q2): thrown up to flash_throw along the aim (or
## against what it meets), it stuns the boss within flash_radius of where it
## goes off for flash_stun, breaking its blow; heard to flash_noise_range.
@export_range(1.0, 40.0, 0.5, "suffix:m") var flash_throw: float = 14.0
@export_range(0.5, 20.0, 0.5, "suffix:m") var flash_radius: float = 6.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var flash_stun: float = 1.5
@export_range(0.0, 60.0, 1.0, "suffix:m") var flash_noise_range: float = 25.0
## Medkit (Q13): points it gives back, and its noise.
@export_range(1, 3) var medkit_heal: int = 1
@export_range(0.0, 30.0, 1.0, "suffix:m") var medkit_noise_range: float = 4.0
## A firecracker going off within this of the boss hurts it (Q13).
@export_range(0.0, 10.0, 0.1, "suffix:m") var firecracker_radius: float = 2.5
@export_range(0.0, 200.0, 5.0) var firecracker_damage: float = 40.0
@export_range(0.0, 200.0, 5.0) var firecracker_poise: float = 35.0
