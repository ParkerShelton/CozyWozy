extends Node3D
class_name Gun

@export var stats: GunStats

var current_ammo: int = 0
var is_reloading: bool = false
var can_fire: bool = true
var burst_remaining: int = 0

var mod_damage_mult: float = 1.0
var mod_fire_rate_mult: float = 1.0
var mod_spread_mult: float = 1.0
var mod_mag_size_add: int = 0
var mod_bullet_speed_mult: float = 1.0
var mod_bullets_per_shot_add: int = 0
var mod_shot_spread_add: float = 0.0
var mod_pierce_add: int = 0
var mod_reload_speed_mult: float = 1.0

var elemental_type: String = ""
var elemental_damage: float = 0.0
var elemental_chance: float = 0.0

var attachments: Dictionary = {
	"barrel": null,
	"sight": null,
	"magazine": null,
	"grip": null,
	"special": null,
}

@onready var fire_point: Marker3D = $FirePoint
@onready var fire_timer: Timer = $FireTimer
@onready var reload_timer: Timer = $ReloadTimer
var muzzle_flash_scene: PackedScene = preload("res://Scenes/Guns/muzzle_flash.tscn")

var bullet_scene: PackedScene = preload("res://Scenes/Guns/pistol_bullet.tscn")

signal ammo_changed(current: int, max_ammo: int)
signal reload_started(duration: float)
signal reload_finished
signal gun_fired(shake_amount: float)

func _ready():
	current_ammo = get_mag_size()
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)
	ammo_changed.emit(current_ammo, get_mag_size())

func get_damage() -> float:
	return stats.damage * mod_damage_mult

func get_fire_rate() -> float:
	return stats.fire_rate * mod_fire_rate_mult

func get_spread() -> float:
	return stats.spread * mod_spread_mult

func get_mag_size() -> int:
	return stats.mag_size + mod_mag_size_add

func get_bullet_speed() -> float:
	return stats.bullet_speed * mod_bullet_speed_mult

func get_bullets_per_shot() -> int:
	return stats.bullets_per_shot + mod_bullets_per_shot_add

func get_shot_spread() -> float:
	return stats.shot_spread + mod_shot_spread_add

func get_pierce() -> int:
	return stats.pierce_count + mod_pierce_add

func get_reload_time() -> float:
	return stats.reload_time * mod_reload_speed_mult

func get_camera_shake() -> float:
	var base_shake = get_damage() * 0.05
	for slot in attachments:
		if attachments[slot] != null:
			base_shake += attachments[slot].camera_shake
	return base_shake

# ========== SHOOTING ==========

func try_fire():
	if is_reloading or not can_fire:
		return
	if current_ammo <= 0:
		return  # just don't fire, wait for manual reload
	
	match stats.fire_mode:
		"semi_auto":
			fire_once()
		"full_auto":
			fire_once()
		"burst":
			start_burst()
			
			
func spawn_muzzle_flash():
	var flash = muzzle_flash_scene.instantiate()
	get_tree().root.add_child(flash)
	flash.global_position = fire_point.global_position
	flash.global_rotation = fire_point.global_rotation
	
	
func fire_once():
	can_fire = false
	current_ammo -= 1
	
	var num_bullets = get_bullets_per_shot()
	var total_spread = get_shot_spread()
	
	for i in range(num_bullets):
		var spread_angle = 0.0
		if num_bullets > 1:
			spread_angle = lerp(-total_spread / 2.0, total_spread / 2.0, float(i) / max(num_bullets - 1, 1))
		spread_angle += randf_range(-get_spread(), get_spread())
		spawn_bullet(spread_angle)
	
	spawn_muzzle_flash()
	
	fire_timer.wait_time = get_fire_rate()
	fire_timer.start()
	
	ammo_changed.emit(current_ammo, get_mag_size())
	gun_fired.emit(get_camera_shake())

func start_burst():
	burst_remaining = stats.burst_count
	fire_burst_bullet()

func fire_burst_bullet():
	if burst_remaining <= 0 or current_ammo <= 0:
		can_fire = false
		fire_timer.wait_time = get_fire_rate()
		fire_timer.start()
		return
	
	current_ammo -= 1
	burst_remaining -= 1
	
	spawn_bullet(randf_range(-get_spread(), get_spread()))
	
	ammo_changed.emit(current_ammo, get_mag_size())
	gun_fired.emit(get_camera_shake())
	
	if burst_remaining > 0 and current_ammo > 0:
		get_tree().create_timer(stats.burst_delay).timeout.connect(fire_burst_bullet)
	else:
		can_fire = false
		fire_timer.wait_time = get_fire_rate()
		fire_timer.start()

func spawn_bullet(spread_angle: float):
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	bullet.global_position = fire_point.global_position
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_mouse_world_position"):
		var mouse_pos = player.get_mouse_world_position()
		var forward = (mouse_pos - bullet.global_position)
		forward.y = 0
		forward = forward.normalized()
		
		var spread_basis = Basis(Vector3.UP, spread_angle)
		var direction = spread_basis * forward
		
		bullet.setup(
			direction, get_damage(), get_bullet_speed(),
			stats.bullet_range, get_pierce(),
			elemental_type, elemental_damage, elemental_chance
		)

# ========== RELOADING ==========

func reload():
	if is_reloading or current_ammo >= get_mag_size():
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_ammo_for_gun(player.Hotbar.get_selected_item()["item_name"]):
		return
	
	is_reloading = true
	reload_timer.wait_time = get_reload_time()
	reload_timer.start()
	reload_started.emit(get_reload_time())

func _on_reload_finished():
	is_reloading = false
	
	# Pull ammo from inventory
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var gun_name = player.Hotbar.get_selected_item()["item_name"]
		var ammo_needed = get_mag_size() - current_ammo
		for i in range(ammo_needed):
			if player.has_ammo_for_gun(gun_name):
				player.consume_ammo(gun_name)
				current_ammo += 1
			else:
				break
	
	ammo_changed.emit(current_ammo, get_mag_size())
	reload_finished.emit()

func _on_fire_timer_timeout():
	can_fire = true

# ========== ATTACHMENTS ==========

func install_attachment(attachment: GunAttachment) -> bool:
	var slot = attachment.slot_type
	match slot:
		"barrel":
			if not stats.barrel_slot: return false
		"sight":
			if not stats.sight_slot: return false
		"magazine":
			if not stats.magazine_slot: return false
		"grip":
			if not stats.grip_slot: return false
		"special":
			if not stats.special_slot: return false
	
	if attachments[slot] != null:
		remove_attachment(slot)
	
	attachments[slot] = attachment
	apply_attachment_mods(attachment)
	return true

func remove_attachment(slot: String) -> GunAttachment:
	var attachment = attachments[slot]
	if attachment == null:
		return null
	remove_attachment_mods(attachment)
	attachments[slot] = null
	return attachment

func apply_attachment_mods(attachment: GunAttachment):
	mod_damage_mult += attachment.damage_mult_add
	mod_fire_rate_mult += attachment.fire_rate_mult_add
	mod_spread_mult += attachment.spread_mult_add
	mod_mag_size_add += attachment.mag_size_add
	mod_bullet_speed_mult += attachment.bullet_speed_mult_add
	mod_bullets_per_shot_add += attachment.bullets_per_shot_add
	mod_shot_spread_add += attachment.shot_spread_add
	mod_pierce_add += attachment.pierce_add
	mod_reload_speed_mult += attachment.reload_speed_mult_add
	
	if attachment.elemental_type != "":
		elemental_type = attachment.elemental_type
		elemental_damage = attachment.elemental_damage
		elemental_chance = attachment.elemental_chance
	
	current_ammo = min(current_ammo, get_mag_size())
	ammo_changed.emit(current_ammo, get_mag_size())

func remove_attachment_mods(attachment: GunAttachment):
	mod_damage_mult -= attachment.damage_mult_add
	mod_fire_rate_mult -= attachment.fire_rate_mult_add
	mod_spread_mult -= attachment.spread_mult_add
	mod_mag_size_add -= attachment.mag_size_add
	mod_bullet_speed_mult -= attachment.bullet_speed_mult_add
	mod_bullets_per_shot_add -= attachment.bullets_per_shot_add
	mod_shot_spread_add -= attachment.shot_spread_add
	mod_pierce_add -= attachment.pierce_add
	mod_reload_speed_mult -= attachment.reload_speed_mult_add
	
	if attachment.elemental_type != "" and elemental_type == attachment.elemental_type:
		elemental_type = ""
		elemental_damage = 0.0
		elemental_chance = 0.0
	
	current_ammo = min(current_ammo, get_mag_size())
	ammo_changed.emit(current_ammo, get_mag_size())
