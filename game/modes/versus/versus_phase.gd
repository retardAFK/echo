class_name VersusPhase
extends Resource
## One phase of the Versus boss (spec S-024, Q8, T-371): it starts when the
## boss's health falls to start_ratio. Listed, highest first, in
## VersusSettings.phases. To add a phase: a new .tres in data/phases/ and a
## line in versus_settings.tres (docs/MODULES.md, "Le mode Versus").

## Text key of its name, shown under the boss bar.
@export var name_key := ""
## Health ratio at which the phase starts (1.0 for the first one).
@export_range(0.0, 1.0, 0.01) var start_ratio: float = 1.0
## Boss speed multiplier during the phase.
@export_range(0.5, 2.0, 0.05) var speed_scale: float = 1.0
## Multiplier of the damage the boss takes during the phase.
@export_range(0.5, 2.0, 0.05) var damage_taken_scale: float = 1.0
## Whether the boss may leap on a noise during the phase (Q9).
@export var can_leap := false
## Whether entering the phase puts the arena lights out (Q8, phase 2).
@export var lights_out := false
## Whether its claw strikes twice during the phase (Q8, phase 3).
@export var double_claw := false
