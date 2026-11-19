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
## Render layer of the meshes whose light is baked (T-049): the baked lights
## leave them out of their cull mask, so they are not lit twice.
const BAKED_LAYER := 1 << 1
## Size of the cells a face is cut in where a baked light reaches it, in meters.
const BAKE_CELL := 1.0
## The renderer's lights fall off more softly than their formula once drawn:
## the baked intensity is raised to this power to look the same (measured
## against a real light, T-049).
const BAKE_GAMMA := 0.4
const BAKE_SCALE := 0.82
## Cells of the lined interiors (S-019): their lights are small and many, so
## coarser cells keep the triangle count down (constitution 2.2).
const LINING_BAKE_CELL := 1.5
## Shadow rays start this far in front of the face.
const BAKE_OFFSET := 0.05


class Block:
	var transform: Transform3D
	var size: Vector3
	var material: Material
	var kind: int


## A room lined by the interior atlas (S-019): the faces of the source
## blocks that look into its box take its wall, floor and ceiling tiles.
class Zone:
	var box: AABB
	var wall: int
	var floor: int
	var ceiling: int


## One face of a block, or the part of it inside one zone.
class FacePart:
	var corner: Vector3
	var u_axis: Vector3
	var v_axis: Vector3
	var u_len: float
	var v_len: float
	var normal: Vector3
	var material: Material
	## Atlas tile, or -1 for the block's own material.
	var tile := -1


class Structure:
	var name: String
	var blocks: Array[Block] = []
	var parent_path := ""
	var node: Node3D

	func _init(p_name: String, p_parent := "Structures") -> void:
		name = p_name
		parent_path = p_parent


var origin := Vector2(110, 110)
var structures: Array[Structure] = []
## Interior linings (S-019): the rooms, the atlas material their faces take,
## and the block materials that get lined (the others, grilles or metal, keep
## their own look).
var zones: Array[Zone] = []
var lining: Material
var lined_materials: Array[Material] = []


## A new structure, built under the node at parent_path.
func structure(p_name: String, parent_path := "Structures") -> Structure:
	var s := Structure.new(p_name, parent_path)
	structures.append(s)
	return s


## World position of a plan point at a height.
func world(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x - origin.x, h, y - origin.y)


## A lined room (S-019): a plan rectangle from height h0 to h1, measured
## from the middle of its walls, and its atlas tiles (-1 leaves that side
## alone). The first zone added wins where two overlap.
func zone(rect: Rect2, h0: float, h1: float, wall: int, floor_tile: int, ceiling: int) -> void:
	var z := Zone.new()
	z.box = AABB(
		world(rect.position.x, rect.position.y, h0), Vector3(rect.size.x, h1 - h0, rect.size.y)
	)
	z.wall = wall
	z.floor = floor_tile
	z.ceiling = ceiling
	zones.append(z)


## An axis-aligned box spanning a plan rectangle, from height h0 to h1.
func box(
	s: Structure,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	h0: float,
	h1: float,
	material: Material,
	kind := Kind.WALL
) -> void:
	var size := Vector3(absf(x1 - x0), absf(h1 - h0), absf(y1 - y0))
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var center := world((x0 + x1) / 2.0, (y0 + y1) / 2.0, (h0 + h1) / 2.0)
	_add(s, Transform3D(Basis.IDENTITY, center), size, material, kind)


## A sloped slab whose top goes from h_start on the x0 (or y0) side of the
## rectangle to h_end on the other side. along_x picks the slope direction.
func ramp(
	s: Structure,
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	h_start: float,
	h_end: float,
	along_x: bool,
	material: Material,
	thickness := 0.3
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
## Each gap is [from_x, to_x, top] (a door: open from the floor h0 up to top,
## wall above) or [from_x, to_x, top, sill] (a window: wall below sill too).
func wall_x(
	s: Structure,
	x0: float,
	x1: float,
	y: float,
	h0: float,
	h1: float,
	thickness: float,
	material: Material,
	gaps: Array = []
) -> void:
	var a := minf(x0, x1)
	var b := maxf(x0, x1)
	var cursor := a
	for gap: Array in _sorted(gaps):
		box(s, cursor, y - thickness / 2.0, gap[0], y + thickness / 2.0, h0, h1, material)
		box(s, gap[0], y - thickness / 2.0, gap[1], y + thickness / 2.0, gap[2], h1, material)
		if gap.size() > 3:
			box(s, gap[0], y - thickness / 2.0, gap[1], y + thickness / 2.0, h0, gap[3], material)
		cursor = gap[1]
	box(s, cursor, y - thickness / 2.0, b, y + thickness / 2.0, h0, h1, material)


## A wall along y at plan x, from y0 to y1, with openings [from_y, to_y, top(, sill)].
func wall_y(
	s: Structure,
	y0: float,
	y1: float,
	x: float,
	h0: float,
	h1: float,
	thickness: float,
	material: Material,
	gaps: Array = []
) -> void:
	var a := minf(y0, y1)
	var b := maxf(y0, y1)
	var cursor := a
	for gap: Array in _sorted(gaps):
		box(s, x - thickness / 2.0, cursor, x + thickness / 2.0, gap[0], h0, h1, material)
		box(s, x - thickness / 2.0, gap[0], x + thickness / 2.0, gap[1], gap[2], h1, material)
		if gap.size() > 3:
			box(s, x - thickness / 2.0, gap[0], x + thickness / 2.0, gap[1], h0, gap[3], material)
		cursor = gap[1]
	box(s, x - thickness / 2.0, cursor, x + thickness / 2.0, b, h0, h1, material)


## A horizontal slab covering a rectangle minus holes (plan rectangles),
## cut in square tiles of tile meters, one structure per tile.
func slab_tiles(
	prefix: String,
	rect: Rect2,
	holes: Array[Rect2],
	h0: float,
	h1: float,
	material: Material,
	tile: float,
	parent_path := "Ground"
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
					tiles[key],
					cell.position.x,
					cell.position.y,
					cell.end.x,
					cell.end.y,
					h0,
					h1,
					material,
					Kind.FLOOR
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
		parts.append(Rect2(rect.position.x, cut.end.y, rect.size.x, rect.end.y - cut.end.y))
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
		s.node = node
		_build_meshes(s, node, root)
		_build_bodies(s, node, root)


func _build_meshes(s: Structure, node: Node3D, root: Node) -> void:
	var lined := _is_lined(s)
	var tools := {}
	for block in s.blocks:
		if block.material == null:
			continue  # Collision only: a model dresses it (S-006, T-046).
		if not lined:
			_tool(tools, block.material, false)
			var cube := BoxMesh.new()
			cube.size = block.size
			tools[block.material].append_from(cube, 0, block.transform)
			continue
		for part in _faces(block):
			_emit_face(
				_tool(tools, part.material, false), part, [0.0, part.u_len], [0.0, part.v_len], []
			)
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


func _tool(tools: Dictionary, material: Material, baked: bool) -> SurfaceTool:
	if not tools.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if baked:
			tool.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
		tools[material] = tool
	return tools[material]


## Whether a face of the structure looks into a lined room.
func _is_lined(s: Structure) -> bool:
	if zones.is_empty() or lining == null:
		return false
	for block in s.blocks:
		if block.material == null or not lined_materials.has(block.material):
			continue
		var bounds := block.transform * AABB(-block.size / 2.0, block.size)
		for z in zones:
			if z.box.grow(0.1).intersects(bounds):
				return true
	return false


## The six faces of a block, each cut where lined rooms begin and end, and
## the lining tile of each part.
func _faces(block: Block) -> Array[FacePart]:
	var parts: Array[FacePart] = []
	var b := block.transform.basis
	var lined := lined_materials.has(block.material) and lining != null
	var straight := b.is_equal_approx(Basis.IDENTITY)
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var face := FacePart.new()
			face.normal = b[axis].normalized() * side
			face.u_axis = b[(axis + 1) % 3].normalized()
			face.v_axis = b[(axis + 2) % 3].normalized()
			face.u_len = block.size[(axis + 1) % 3]
			face.v_len = block.size[(axis + 2) % 3]
			face.corner = (
				block.transform.origin
				+ face.normal * block.size[axis] / 2.0
				- face.u_axis * face.u_len / 2.0
				- face.v_axis * face.v_len / 2.0
			)
			face.material = block.material
			if not lined:
				parts.append(face)
				continue
			var us := PackedFloat32Array([0.0, face.u_len])
			var vs := PackedFloat32Array([0.0, face.v_len])
			if straight:
				for z in zones:
					var slab := AABB(
						face.corner, face.u_axis * face.u_len + face.v_axis * face.v_len
					)
					slab = slab.abs().grow(0.1)
					if not z.box.intersects(slab):
						continue
					for edge: Vector3 in [z.box.position, z.box.end]:
						us = _cut(us, (edge - face.corner).dot(face.u_axis), face.u_len)
						vs = _cut(vs, (edge - face.corner).dot(face.v_axis), face.v_len)
			us.sort()
			vs.sort()
			for j in vs.size() - 1:
				for i in us.size() - 1:
					var part := FacePart.new()
					part.normal = face.normal
					part.u_axis = face.u_axis
					part.v_axis = face.v_axis
					part.u_len = us[i + 1] - us[i]
					part.v_len = vs[j + 1] - vs[j]
					part.corner = face.corner + face.u_axis * us[i] + face.v_axis * vs[j]
					part.material = block.material
					var probe := (
						part.corner
						+ part.u_axis * part.u_len / 2.0
						+ part.v_axis * part.v_len / 2.0
						+ part.normal * 0.05
					)
					var tile := _tile_at(probe, part.normal)
					if tile >= 0:
						part.material = lining
						part.tile = tile
					parts.append(part)
	return parts


static func _cut(cuts: PackedFloat32Array, at: float, length: float) -> PackedFloat32Array:
	if at > 0.001 and at < length - 0.001 and not _has_cut(cuts, at):
		cuts.append(at)
	return cuts


## The lining tile a face with this normal takes at a point, or -1.
func _tile_at(p: Vector3, normal: Vector3) -> int:
	for z in zones:
		if z.box.has_point(p):
			if normal.y > 0.5:
				return z.floor
			if normal.y < -0.5:
				return z.ceiling
			return z.wall
	return -1


## Adds a face cut along us and vs; colors holds the baked light of each
## corner (rows along vs), or is empty. The vertex color carries the tile.
func _emit_face(tool: SurfaceTool, part: FacePart, us: Array, vs: Array, colors: Array) -> void:
	# Godot draws clockwise faces: flip the quads whose u x v points inward.
	var flip := part.u_axis.cross(part.v_axis).dot(part.normal) > 0.0
	var tint := Color(maxf(part.tile, 0) / 15.0, 0, 0) if part.tile >= 0 else Color.WHITE
	tool.set_normal(part.normal)
	for j in vs.size() - 1:
		for i in us.size() - 1:
			var quad := [
				Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
			]
			if flip:
				quad.reverse()
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2i = quad[k]
				tool.set_color(tint)
				if not colors.is_empty():
					tool.set_custom(0, colors[c.y][c.x])
				tool.add_vertex(part.corner + part.u_axis * us[c.x] + part.v_axis * vs[c.y])


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


# --- Baked light (T-049) ------------------------------------------------------


## Bakes the light of the given omni lights into the meshes of the structures,
## as a per-vertex color (CUSTOM0, added by the retro surface shader). Faces are
## cut in BAKE_CELL cells only where a light reaches them; shadows come from rays
## against the collision shapes of space (mask). Every structure mesh moves to
## BAKED_LAYER. Needs the structures in the tree, with their bodies in space.
## Returns the number of baked vertices.
func bake_light(lights: Array[OmniLight3D], space: PhysicsDirectSpaceState3D, mask: int) -> int:
	var count := 0
	for s in structures:
		var instance := s.node.get_node_or_null("Mesh") as MeshInstance3D if s.node else null
		if instance == null:
			continue
		instance.layers = BAKED_LAYER
		var near: Array[OmniLight3D] = []
		var bounds := instance.mesh.get_aabb()
		for light in lights:
			if bounds.grow(light.omni_range).has_point(light.global_position):
				near.append(light)
		if near.is_empty():
			continue
		var tools := {}
		for block in s.blocks:
			if block.material == null:
				continue
			for part in _faces(block):
				count += _bake_face(_tool(tools, part.material, true), part, near, space, mask)
		var mesh := ArrayMesh.new()
		for material: Material in tools:
			var tool: SurfaceTool = tools[material]
			tool.set_material(material)
			tool.commit(mesh)
		instance.mesh = mesh
	return count


## One face part, cut along the cells of the lights in front of it.
func _bake_face(
	tool: SurfaceTool,
	part: FacePart,
	lights: Array[OmniLight3D],
	space: PhysicsDirectSpaceState3D,
	mask: int
) -> int:
	var normal := part.normal
	var u_axis := part.u_axis
	var v_axis := part.v_axis
	var u_len := part.u_len
	var v_len := part.v_len
	var corner := part.corner
	var us := PackedFloat32Array([0.0, u_len])
	var vs := PackedFloat32Array([0.0, v_len])
	var lit: Array[OmniLight3D] = []
	var cell := LINING_BAKE_CELL if part.tile >= 0 else BAKE_CELL
	for light in lights:
		var to_light := light.global_position - corner
		var depth := to_light.dot(normal)
		var r := light.omni_range
		var lu := to_light.dot(u_axis)
		var lv := to_light.dot(v_axis)
		if depth <= 0.0 or depth >= r or lu < -r or lu > u_len + r or lv < -r or lv > v_len + r:
			continue
		lit.append(light)
		us = _add_cuts(us, lu - r, lu + r, u_len, cell)
		vs = _add_cuts(vs, lv - r, lv + r, v_len, cell)
	us.sort()
	vs.sort()
	var colors := []
	for v in vs:
		var row := []
		for u in us:
			var p := corner + u_axis * u + v_axis * v
			row.append(_light_at(p, normal, lit, space, mask))
		colors.append(row)
	_emit_face(tool, part, Array(us), Array(vs), colors)
	return us.size() * vs.size()


## Adds the cell lines from a to b (one per cell) inside (0, length).
static func _add_cuts(
	cuts: PackedFloat32Array, a: float, b: float, length: float, cell := BAKE_CELL
) -> PackedFloat32Array:
	var x := a
	while x <= b + 0.0001:
		if x > 0.0001 and x < length - 0.0001 and not _has_cut(cuts, x):
			cuts.append(x)
		x += cell
	return cuts


static func _has_cut(cuts: PackedFloat32Array, x: float) -> bool:
	for c in cuts:
		if absf(c - x) < 0.05:
			return true
	return false


## Light received at a point of a face, as the renderer's omni lights would
## give it (same falloff), with hard shadows from the collision shapes.
static func _light_at(
	p: Vector3,
	normal: Vector3,
	lights: Array[OmniLight3D],
	space: PhysicsDirectSpaceState3D,
	mask: int
) -> Color:
	var sum := Color(0, 0, 0, 1)
	for light in lights:
		var to_light := light.global_position - p
		var distance := to_light.length()
		var facing := normal.dot(to_light / maxf(distance, 0.0001))
		if distance >= light.omni_range or facing <= 0.0:
			continue
		var ray := PhysicsRayQueryParameters3D.create(
			p + normal * BAKE_OFFSET, light.global_position, mask
		)
		if not space.intersect_ray(ray).is_empty():
			continue
		var nd := pow(distance / light.omni_range, 4.0)
		var falloff := (
			pow(maxf(1.0 - nd, 0.0), 2.0) * pow(maxf(distance, 0.0001), -light.omni_attenuation)
		)
		var strength := pow(falloff * facing * light.light_energy, BAKE_GAMMA) * BAKE_SCALE
		sum.r += light.light_color.r * strength
		sum.g += light.light_color.g * strength
		sum.b += light.light_color.b * strength
	return sum
