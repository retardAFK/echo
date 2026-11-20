class_name EscalationList
extends Resource
## The stages of the monster's rise, in order (spec S-023, Q5, T-354): the
## first applies after the first objective done, and so on; objectives past
## the last stage add nothing. Adding or removing a stage is one
## EscalationStage .tres and its line in game/data/escalation/escalation.tres
## (docs/MODULES.md).

const PATH := "res://game/data/escalation/escalation.tres"

@export var stages: Array[EscalationStage] = []


static func default() -> EscalationList:
	return load(PATH)


## Gives settings every stage up to reached (excluded from), from stage from
## on: the stages already given are not given again.
func apply(settings: MonsterSettings, from: int, reached: int) -> void:
	for i in range(maxi(from, 0), mini(reached, stages.size())):
		stages[i].apply(settings)
