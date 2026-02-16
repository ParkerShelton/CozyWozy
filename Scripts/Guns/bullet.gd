extends RigidBody3D
class_name Bullet

var damage: float = 10.0
var max_range: float = 100.0
var pierce_remaining: int = 0
var distance_traveled: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var speed: float = 80.0

var elemental_type: String = ""
var elemental_damage: float = 0.0
var elemental_chance: float = 0.0

var hit_targets: Array = []
var start_position: Vector3

func setup(dir: Vector3, dmg: float, spd: float, rng: float, pierce: int, elem_type: String = "", elem_dmg: float = 0.0, elem_chance: float = 0.0):
	direction = dir.normalized()
	damage = dmg
	speed = spd
	max_range = rng
	pierce_remaining = pierce
	elemental_type = elem_type
	elemental_damage = elem_dmg
	elemental_chance = elem_chance
	call_deferred("_launch")

func _launch():
	start_position = global_position
	linear_velocity = direction * speed
	look_at(global_position + direction)

func _ready():
	gravity_scale = 0
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	if start_position != Vector3.ZERO:
		distance_traveled = global_position.distance_to(start_position)
		if distance_traveled >= max_range:
			queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	
	if body in hit_targets:
		return
	
	hit_targets.append(body)
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
		if elemental_type != "" and randf() < elemental_chance:
			if body.has_method("apply_status_effect"):
				body.apply_status_effect(elemental_type, elemental_damage)
	
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()
