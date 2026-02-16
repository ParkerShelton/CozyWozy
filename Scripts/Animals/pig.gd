extends BaseAnimal

@onready var pig = $pig

var baby_pig_scene = preload("res://Scenes/Animals/pig.tscn")

func _ready():
	var rand_size = randf_range(0.7, 1.2)
	pig.scale = Vector3(rand_size, rand_size, rand_size)
	
	if rand_size > 0.9:
		pass
		#spawn_babies()
	
	super._ready()


func spawn_babies():
	var spawn_size = randf_range(0.3, 0.5)
	var baby_amount = randi_range(1, 3)
	
	for i in baby_amount:
		var baby =  baby_pig_scene.instantiate()
		get_tree().root.add_child(baby)
		baby.position = position + Vector3(3 + baby_amount, 0, 3 + baby_amount)
		baby.scale = Vector3(spawn_size, spawn_size, spawn_size)
