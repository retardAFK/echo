class_name FloorSurface
extends RefCounted
## What a foot lands on (spec S-012, T-143): it picks the sound of a footstep
## and, for metal and puddles, how far it carries (NoiseMath.range_for_gait).

enum Kind { CONCRETE, EARTH, METAL, TILE, WOOD, PUDDLE }

## Names of the kinds, as in the sound files (step_<name>_N.wav).
const NAMES := ["concrete", "earth", "metal", "tile", "wood", "puddle"]


## The floor under a position: a metal floor (S-016, Q9) first, then the
## map's SurfaceMap (FloorSurfaces node), else concrete.
static func at(tree: SceneTree, position: Vector3) -> Kind:
	if tree == null:
		return Kind.CONCRETE
	if MetalFloor.under(tree, position):
		return Kind.METAL
	for node in tree.get_nodes_in_group(FloorSurfaces.GROUP):
		var surfaces := (node as FloorSurfaces).surfaces
		if surfaces != null:
			return surfaces.kind_at(position) as Kind
	return Kind.CONCRETE
