extends Node3D

@onready var empty_rack = $tannning_rack_empty
@onready var leather_rack = $tannning_rack_leather
var is_tanning = false


func set_is_tanning(tanning: bool):
	is_tanning = tanning
	print("TANNINGGGGGG")

# Called when the node enters the scene tree for the first time.
func _ready():
	leather_rack.visible = is_tanning
	empty_rack.visible = !is_tanning


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	leather_rack.visible = is_tanning
	empty_rack.visible = !is_tanning
