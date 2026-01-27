extends Node3D

@export var station_name : String = "workbench"

func _ready():
	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Add this station to player's available list
		if body.has_method("add_crafting_station"):
			body.add_crafting_station(station_name)
		print("Player entered workbench area")

func _on_body_exited(body):
	if body.is_in_group("player"):
		# Remove this station from player's available list
		if body.has_method("remove_crafting_station"):
			body.remove_crafting_station(station_name)
		print("Player left workbench area")
