extends GutTest
## Shader warm-up (S-009, T-085): one copy per different look, small copies.


func _mesh(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


func test_same_mesh_and_material_count_once() -> void:
	var root := Node3D.new()
	var box := BoxMesh.new()
	var red := StandardMaterial3D.new()
	root.add_child(_mesh(box, red))
	root.add_child(_mesh(box, red))
	root.add_child(_mesh(box))
	root.add_child(_mesh(SphereMesh.new(), red))
	root.add_child(MeshInstance3D.new())  # No mesh: skipped.
	assert_eq(ShaderWarmup.collect(root).size(), 3)
	root.free()


func test_multimesh_counts_once_per_mesh() -> void:
	var root := Node3D.new()
	var box := BoxMesh.new()
	for i in 2:
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = box
		root.add_child(batch)
	root.add_child(_mesh(box))
	assert_eq(ShaderWarmup.collect(root).size(), 2)
	root.free()


func test_copy_is_small_and_keeps_materials() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(4, 2, 1)
	var red := StandardMaterial3D.new()
	var source := _mesh(box, red)
	var copy := ShaderWarmup.make_copy(source, 0.02) as MeshInstance3D
	assert_eq(copy.mesh, box)
	assert_eq(copy.material_override, red)
	assert_almost_eq(copy.scale.x, 0.005, 0.0001)
	source.free()
	copy.free()


func test_multimesh_copy_draws_one_instance() -> void:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = BoxMesh.new()
	batch.multimesh.instance_count = 50
	var copy := ShaderWarmup.make_copy(batch, 0.02) as MultiMeshInstance3D
	assert_eq(copy.multimesh.instance_count, 1)
	assert_true(copy.multimesh.use_colors)
	assert_eq(copy.multimesh.mesh, batch.multimesh.mesh)
	batch.free()
	copy.free()
