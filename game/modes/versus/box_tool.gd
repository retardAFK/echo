class_name BoxTool
extends RefCounted
## Builds meshes out of coloured boxes (spec S-024, T-372, T-377): the
## prototype first-person arms (ViewModel) and the chests (VersusChest), one
## mesh each with the colours in the vertices. The real models replace them
## with T-385.


static func start() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## Adds a box at center, of size, turned yaw then pitch (radians).
static func box(
	tool: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw := 0.0, pitch := 0.0
) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var half := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var up: Vector3 = face[1]
		var side: Vector3 = face[2]
		var corners: Array[Vector3] = []
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local := normal + side * corner.x + up * corner.y
			corners.append(center + basis * (local * half))
		tool.set_color(color)
		tool.set_normal(basis * normal)
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_color(color)
			tool.set_normal(basis * normal)
			tool.add_vertex(corners[index])
