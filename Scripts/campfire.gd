extends Node3D

@export var light_radius: float = 0.8
@export var light_intensity: float = 1.5
@export var light_color: Color = Color(1.0, 0.7, 0.4)

func _ready():
	enable_light()

func enable_light():
	call_deferred("register_with_day_night")
	
	var day_night = get_node_or_null("/root/main/DayNightOverlay/ColorRect")
	if day_night and day_night.material:
		day_night.material.set_shader_parameter("falloff_power", 3.5)

func register_with_day_night():
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night and day_night.has_method("register_light"):
		day_night.register_light(self, light_radius, light_color, light_intensity)

func _exit_tree():
	var day_night = get_node_or_null("/root/main/day_night_overlay/ColorRect")
	if day_night and day_night.has_method("unregister_light"):
		day_night.unregister_light(self)


func _on_safe_zone_body_entered(body):
	if body.is_in_group("player"):
		body.heal_at_campfire()
		EnemyManager.enter_safe_zone()


func _on_safe_zone_body_exited(body):
	if body.is_in_group("player"):
		body.heal_at_campfire()
		EnemyManager.exit_safe_zone()
