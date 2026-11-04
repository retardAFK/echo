class_name RetroProp
extends Node3D
## A static prop made in Blender (spec S-005, T-033). Its textures are drawn
## with sharp pixels (constitution 2.3), whatever the glTF importer chose.


func _ready() -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
