class_name ArenaBuilder
extends Node3D
## Puts a Versus arena (VersusArena, spec S-024, Q24, T-376) in its map: one
## mesh per look (so 4 draw calls for every barrier, wall, board and stair)
## and one static body with a box per piece; ramps and landings are floors
## (layer "world"), the rest walls (layer "walls"), as in the cité. It also
## gives the map's navigation region the arena's navigation mesh, so the AI
## goes up the stairs and not through the nailed doors.

const WORLD_LAYER := 1 << 0
const WALLS_LAYER := 1 << 1
## The material of each look, in ArenaPiece.Look order.
const MATERIALS: Array[Material] = [
	preload("res://game/fx/materials/concrete_obstacle.tres"),
	preload("res://game/modes/versus/data/arenas/arena_metal.tres"),
	preload("res://game/modes/versus/data/arenas/arena_boards.tres"),
	preload("res://game/modes/versus/data/arenas/arena_fence.tres"),
]

var arena: VersusArena


func _init(p_arena: VersusArena) -> void:
	arena = p_arena
	name = "VersusArena"


func _ready() -> void:
	build()


## Builds the meshes and the bodies; also called by the generator, out of a
## game, to bake the navigation mesh.
func build() -> void:
	var tools: Array[SurfaceTool] = []
	for look in ArenaPiece.Look.size():
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(tool)
	var floors := StaticBody3D.new()
	floors.name = "Floors"
	floors.collision_layer = WORLD_LAYER
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = WALLS_LAYER
	for piece in arena.pieces:
		var box := BoxMesh.new()
		box.size = piece.size
		tools[piece.look].append_from(box, 0, piece.transform)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = piece.size
		shape.shape = box_shape
		shape.transform = piece.transform
		(floors if piece.look == ArenaPiece.Look.METAL else walls).add_child(shape)
	add_child(floors)
	add_child(walls)
	for look in tools.size():
		if arena.pieces.any(func(piece: ArenaPiece) -> bool: return piece.look == look):
			var mesh := MeshInstance3D.new()
			mesh.name = ArenaPiece.Look.keys()[look].capitalize()
			tools[look].generate_normals()
			mesh.mesh = tools[look].commit()
			mesh.material_override = MATERIALS[look]
			add_child(mesh)


## Gives the map's navigation region the arena's mesh.
func use_navigation(map: Node) -> void:
	if arena.navigation_mesh == null:
		return
	for region: NavigationRegion3D in map.find_children("*", "NavigationRegion3D", true, false):
		region.navigation_mesh = arena.navigation_mesh
