class_name VersusRarity
extends Resource
## A rarity of the Versus guns (spec S-025, Q3, T-404): its color (on the
## gun, the open chest and the light beam above it), what it multiplies
## damage by, and how likely a chest gives it. One .tres per rarity in
## data/rarities/, listed in order (common first) in rarities of
## versus_settings.tres; a VersusItem's rarity is its index there.

## Key of its name in strings.csv.
@export var name_key := ""
@export var color := Color.GRAY
@export_range(1.0, 3.0, 0.05) var damage_multiplier: float = 1.0
## How likely a gun of a chest of the start, then of a new phase, has it.
@export_range(0.0, 100.0, 0.5) var weight: float = 1.0
@export_range(0.0, 100.0, 0.5) var phase_weight: float = 1.0


## The rarity of item among rarities, or null (no item, no rarities).
static func of(item: VersusItem, rarities: Array[VersusRarity]) -> VersusRarity:
	if item == null or rarities.is_empty():
		return null
	return rarities[clampi(item.rarity, 0, rarities.size() - 1)]


## The index of a rarity drawn among rarities by weight (phase_weight for
## the chests of a new phase); 0 when none.
static func draw(rarities: Array[VersusRarity], rng: RandomNumberGenerator, phase := false) -> int:
	var total := 0.0
	for rarity in rarities:
		total += rarity.phase_weight if phase else rarity.weight
	if total <= 0.0:
		return 0
	var pick := rng.randf() * total
	for i in rarities.size():
		pick -= rarities[i].phase_weight if phase else rarities[i].weight
		if pick < 0.0:
			return i
	return rarities.size() - 1
