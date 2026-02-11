extends BaseAnimal

@onready var body_mesh = $rabbit2/rabbit

func _ready():
	await super._ready()

	if body_mesh:
		randomize_colors()



func randomize_colors():
	# Create instance-specific RNG for unique colors per horse
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())
	
	var body_color_index = rng.randi() % 7
	var hair_color_index = rng.randi() % 5
	
	if body_mesh:
		var body_shader = load("res://Shaders/Animals/rabbit_shader.gdshader")
		var body_material = ShaderMaterial.new()
		body_material.shader = body_shader
		body_material.set_shader_parameter("selected_color", body_color_index)
		body_mesh.material_override = body_material
