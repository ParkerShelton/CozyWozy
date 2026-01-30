extends Node

var plants: Dictionary = {}

func _ready():
	load_all_plants()

func load_all_plants():
	var dir = DirAccess.open("res://Resources/Plants/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var plant = load("res://Resources/Plants/" + file_name)
				if plant is Plant:
					plants[plant.plant_name] = plant
			file_name = dir.get_next()
	else:
		print("Failed to open Plants directory")

func get_plant(plant_name: String) -> Plant:
	return plants.get(plant_name)
