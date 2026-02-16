extends Node3D

@onready var camera = get_tree().get_first_node_in_group("camera")
@onready var chest_spot = $house_small/chest_spot
@onready var couch_spot = $house_small/couch_spot
@onready var doormat_spot = $house_small/doormat_spot
@onready var drawer_1_spot = $house_small/drawer_1_spot
@onready var drawer_2_spot = $house_small/drawer_2_spot
@onready var rug_spot = $house_small/rug_spot

const FURNITURE = {
	"chest": [
		preload("res://Scenes/City/Furniture/chest_1.tscn"),
		preload("res://Scenes/City/Furniture/chest_2.tscn"),
		preload("res://Scenes/City/Furniture/chest_3.tscn"),
		preload("res://Scenes/City/Furniture/chest_4.tscn"),
	],
	"couch": [
		preload("res://Scenes/City/Furniture/couch_1.tscn"),
		preload("res://Scenes/City/Furniture/couch_2.tscn"),
		preload("res://Scenes/City/Furniture/couch_3.tscn"),
	],
	#"doormat": [
		#preload("res://Scenes/City/Furniture/doormat_1.tscn"),
		#preload("res://Scenes/City/Furniture/doormat_2.tscn"),
	#],
	"drawer": [
		preload("res://Scenes/City/Furniture/drawer_1.tscn"),
		preload("res://Scenes/City/Furniture/drawer_2.tscn"),
		preload("res://Scenes/City/Furniture/drawer_3.tscn"),
		preload("res://Scenes/City/Furniture/drawer_4.tscn"),
	],
	"rug": [
		preload("res://Scenes/City/Furniture/rug_1.tscn"),
		preload("res://Scenes/City/Furniture/rug_2.tscn"),
		preload("res://Scenes/City/Furniture/rug_3.tscn"),
		preload("res://Scenes/City/Furniture/rug_4.tscn"),
		preload("res://Scenes/City/Furniture/rug_5.tscn"),
	],
}

func _ready():
	furnish_house()

func furnish_house():
	place_random("chest", chest_spot, 0.0, PI, 0.4)
	place_random("couch", couch_spot, PI, 0.5)
	place_random("drawer", drawer_1_spot, 0.0, 0.0, 0.3)
	place_random("drawer", drawer_2_spot, PI / 2, 0.0, 0.3)
	place_random("rug", rug_spot, 0.0, 0.4)

func place_random(category: String, spot: Node3D, extra_rotation_y: float = 0.0, y_offset: float = 0.0, skip_chance: float = 0.0):
	if randf() < skip_chance:
		return
	if not spot or not FURNITURE.has(category):
		return
	var options = FURNITURE[category]
	if options.size() == 0:
		return
	var piece = options[randi() % options.size()].instantiate()
	spot.add_child(piece)
	piece.position = Vector3(0, y_offset, 0)
	piece.rotation = Vector3.ZERO
	piece.rotation.y = extra_rotation_y

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		print("person entered small house")
		camera.enter_house()
	if body.is_in_group("trees"):
		print("HEHEHEHEHEHEHEHTREETHEEHEHHE")

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		camera.exit_house()
