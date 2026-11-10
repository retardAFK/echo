extends RefCounted
## Building blocks for generated maps (spec S-006, T-039).
##
## Coordinates follow the paper plan: x to the east, y to the south, in meters,
## from the north-west corner. Heights are world heights (0 = ground).
## A plan point (x, y) at height h becomes the world point (x - origin.x, h, y - origin.y).
##
## Blocks are gathered by structure (a building, a fence, a ground tile). Each
## structure becomes one Node3D with one merged mesh per material (one draw call
## each) and one box collision shape per block, on the "walls" layer for walls
## (they muffle noise, S-002) and on the "world" layer for floors and ramps.

enum Kind { WALL, FLOOR, GHOST }

const WORLD_LAYER := 1 << 0
const WALLS_LAYER := 1 << 1


class Block:
	var transform: Transform3D
	var size: Vector3
	var material: Material
	var kind: int


class Structure:
	var name: String
	var blocks: Array[Block] = []
	var parent_path := ""

	func _init(p_name: String, p_parent := "Structures") -> void:
		name = p_name
		parent_path = p_parent


var origin := Vector2(110, 110)
var structures: Array[Structure] = []


## A new structure, built under the node at parent_path.
func structure(p_name: String, parent_path := "Structures") -> Structure:
	var s := Structure.new(p_name, parent_path)
	structures.append(s)
	return s


## World position of a plan point at a height.
func world(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x - origin.x, h, y - origin.y)


## An axis-aligned box spanning a plan rectangle, from height h0 to h1.
func box(
	s: Structure, x0: float, y0: float, x1: float, y1: float, h0: float, h1: float,
	material: Material, kind := Kind.WALL
) -> void:
	var size := Vector3(absf(x1 - x0), absf(h1 - h0), absf(y1 - y0))
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var center := world((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h0 + h1) / 2.0)
	_add(s, Transform3D(Basis.IDENTITY, center), size, material, kind)


## A sloped slab whose top goes from h_start on the x0 (or y0) side of the
## rectangle to h_end on the other side. along_x picks the slope direction.
func ramp(
	s: Structure, x0: float, y0: float, x1: float, y1: float, h_start: float, h_end: float,
	along_x: bool, material: Material, thickness := 0.3
) -> void:
	var run := absf(x1 - x0) if along_x else absf(y1 - y0)
	var width := absf(y1 - y0) if along_x else absf(x1 - x0)
	var rise := h_end - h_start
	# The slope goes from the x0/y0 side to the other one, whatever their order.
	var sign_dir := signf(x1 - x0) if along_x else signf(y1 - y0)
	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var basis: Basis
	var size: Vector3
	if along_x:
		basis = Basis(Vector3.BACK, angle * sign_dir)
		size = Vector3(length, thickness, width)
	else:
		basis = Basis(Vector3.RIGHT, -angle * sign_dir)
		size = Vector3(width, thickness, length)
	var top := world((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h_start + h_end) / 2.0)
	var center := top - basis.y * thickness / 2.0
	_add(s, Transform3D(basis, center), size, material, Kind.FLOOR)


## A wall along x at plan y, from x0 to x1, with openings.
## Each gap is [from_x, to_x, top]: open from the floor h0 up to top, wall above.
func wall_x(
	s: Structure, x0: float, x1: float, y: float, h0: float, h1: float, thickness: float,
	material: Material, gaps: Array = []
) -> void:
	var a := minf(x0, x1)
	var b := maxf(x0, x1)
	var cursor := a
	for gap: Array in _sorted(gaps):
		box(s, cursor, y - thickness / 2.0, gap[0], y + thickness / 2.0, h0, h1, material)
		box(s, gap[0], y - thickness / 2.0, gap[1], y + thickness / 2.0, gap[2], h1, material)
		cursor = gap[1]
	box(s, cursor, y - thickness / 2.0, b, y + thickness / 2.0, h0, h1, material)


## A wall along y at plan x, from y0 to y1, with openings [from_y, to_y, top].
func wall_y(
	s: Structure, y0: float, y1: float, x: float, h0: float, h1: float, thickness: float,
	material: Material, gaps: Array = []
) -> void:
	var a := minf(y0, y1)
	var b := maxf(y0, y1)
	var cursor := a
	for gap: Array in _sorted(gaps):
		box(s, x - thickness / 2.0, cursor, x + thickness / 2.0, gap[0], h0, h1, material)
		box(s, x - thickness / 2.0, gap[0], x + thickness / 2.0, gap[1], gap[2], h1, material)
		cursor = gap[1]
	box(s, x - thickness / 2.0, cursor, x + thickness / 2.0, b, h0, h1, material)


## A horizontal slab covering a rectangle minus holes ([x0, y0, x1, y1] each),
## cut in square tiles of tile meters, one structure per tile.
func slab_tiles(
	prefix: String, rect: Rect2, holes: Array[Rect2], h0: float, h1: float,
	material: Material, tile: float, parent_path := "Ground"
) -> void:
	var pieces: Array[Rect2] = [rect]
	for hole in holes:
		var next: Array[Rect2] = []
		for piece in pieces:
			next.append_array(subtract(piece, hole))
		pieces = next
	var tiles := {}
	for piece in pieces:
		var gx0 := floori(piece.position.x / tile)
		var gx1 := ceili(piece.end.x / tile)
		var gy0 := floori(piece.position.y / tile)
		var gy1 := ceili(piece.end.y / tile)
		for gx in range(gx0, gx1):
			for gy in range(gy0, gy1):
				var cell := Rect2(gx * tile, gy * tile, tile, tile).intersection(piece)
				if cell.get_area() < 0.0001:
					continue
				var key := "%s_%d_%d" % [prefix, gx, gy]
				if not tiles.has(key):
					tiles[key] = structure(key, parent_path)
				box(
					tiles[key], cell.position.x, cell.position.y, cell.end.x, cell.end.y,
					h0, h1, material, Kind.FLOOR
				)


## Parts of a rectangle outside a hole (up to four rectangles).
static func subtract(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var cut := rect.intersection(hole)
	if cut.get_area() < 0.0001:
		return [rect]
	var parts: Array[Rect2] = []
	# North and south bands, full width.
	if cut.position.y > rect.position.y:
		parts.append(Rect2(rect.position, Vector2(rect.size.x, cut.position.y - rect.position.y)))
	if cut.end.y < rect.end.y:
		parts.append(
			Rect2(rect.position.x, cut.end.y, rect.size.x, rect.end.y - cut.end.y)
		)
	# West and east bands, beside the hole.
	if cut.position.x > rect.position.x:
		parts.append(
			Rect2(rect.position.x, cut.position.y, cut.position.x - rect.position.x, cut.size.y)
		)
	if cut.end.x < rect.end.x:
		parts.append(Rect2(cut.end.x, cut.position.y, rect.end.x - cut.end.x, cut.size.y))
	return parts


## Builds every structure under root; nodes are owned by root so they get saved.
func build(root: Node) -> void:
	for s in structures:
		var parent := _ensure_path(root, s.parent_path)
		var node := Node3D.new()
		node.name = s.name
		parent.add_child(node)
		node.owner = root
		_build_meshes(s, node, root)
		_build_bodies(s, node, root)


func _build_meshes(s: Structure, node: Node3D, root: Node) -> void:
	var tools := {}
	for block in s.blocks:
		if not tools.has(block.material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[block.material] = tool
		var cube := BoxMesh.new()
		cube.size = block.size
		tools[block.material].append_from(cube, 0, block.transform)
	var mesh := ArrayMesh.new()
	for material: Material in tools:
		var tool: SurfaceTool = tools[material]
		tool.set_material(material)
		tool.commit(mesh)
	if mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	node.add_child(instance)
	instance.owner = root


func _build_bodies(s: Structure, node: Node3D, root: Node) -> void:
	var bodies := {}
	for block in s.blocks:
		if block.kind == Kind.GHOST:
			continue
		if not bodies.has(block.kind):
			var body := StaticBody3D.new()
			body.name = "Walls" if block.kind == Kind.WALL else "Floors"
			body.collision_layer = WALLS_LAYER if block.kind == Kind.WALL else WORLD_LAYER
			body.collision_mask = 0
			node.add_child(body)
			body.owner = root
			bodies[block.kind] = body
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = block.size
		shape.shape = box_shape
		shape.transform = block.transform
		bodies[block.kind].add_child(shape)
		shape.owner = root


func _add(s: Structure, xform: Transform3D, size: Vector3, material: Material, kind: int) -> void:
	var block := Block.new()
	block.transform = xform
	block.size = size
	block.material = material
	block.kind = kind
	s.blocks.append(block)


func _sorted(gaps: Array) -> Array:
	var copy := gaps.duplicate()
	copy.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return copy


func _ensure_path(root: Node, path: String) -> Node:
	var node := root
	for part in path.split("/", false):
		var child := node.get_node_or_null(part)
		if child == null:
			child = Node3D.new()
			child.name = part
			node.add_child(child)
			child.owner = root
			if node == root:
				child.add_to_group("navigation_source", true)
		node = child
	return node
