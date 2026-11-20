class_name TrainSettings
extends Resource
## Tunable values of the passing train (spec S-020, T-332, piste S3): while it
## roars by, the noises near the railway are lost for the monster, like in a
## ventilation zone (NoiseEvent.masked). The room decides it; online, the
## clients hear the train when the room says so. Starting points.

## Seconds the train covers the noises, in the middle of its pass (the sound
## lasts longer: it comes and goes).
@export_range(0.0, 30.0, 0.5, "suffix:s") var cover_time: float = 8.0
## Noises closer to the railway than this, in meters, are covered.
@export_range(0.0, 100.0, 1.0, "suffix:m") var cover_distance: float = 25.0
