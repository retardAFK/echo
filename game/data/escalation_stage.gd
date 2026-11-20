class_name EscalationStage
extends Resource
## One stage of the monster's rise (spec S-023, Q5, T-354): what changes in
## its MonsterSettings once the hunted have done one more objective. Stages
## add up: the second keeps what the first gave. One .tres per stage in
## game/data/escalation/, listed in escalation.tres (EscalationList).

## Key of the stage's short name in strings.csv (test room, guide, debug).
@export var name_key := ""
## MonsterSettings property name -> new value, such as
## {"scan_recharge_time": 35.0}. A test checks every name exists there.
@export var overrides := {}


## Gives settings the values of this stage.
func apply(settings: MonsterSettings) -> void:
	for property: String in overrides:
		settings.set(property, overrides[property])
