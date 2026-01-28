extends MeshInstance3D

func _ready():
	# Get the material
	var mat = get_surface_override_material(0)
	if mat:
		# Get the viewport texture parameter
		var viewport_tex = mat.get_shader_parameter("layer_mask_texture")
		if viewport_tex:
			# Set the viewport path - adjust this to your actual path
			viewport_tex.viewport_path = "/root/main/SubViewportContainer/SubViewport/hide_grass_viewport"
