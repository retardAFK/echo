class_name ArenaPiece
extends Resource
## One block of a Versus arena (spec S-024, Q24, T-376): a box, placed by its
## transform (its centre; a ramp is a tilted box), of a look. Written by
## tools/godot/build_versus_arena.gd into the arena's file.

## What it looks like: concrete (low walls, closed doors), metal (stairs up
## to the roofs), boards (doors and windows nailed shut), fence (the
## building-site barriers around the arena).
enum Look { CONCRETE, METAL, BOARDS, FENCE }

@export var transform := Transform3D.IDENTITY
@export var size := Vector3.ONE
@export var look := Look.CONCRETE


static func make(p_transform: Transform3D, p_size: Vector3, p_look: Look) -> ArenaPiece:
	var piece := ArenaPiece.new()
	piece.transform = p_transform
	piece.size = p_size
	piece.look = p_look
	return piece
