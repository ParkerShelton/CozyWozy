extends Resource
class_name GunStats

@export var gun_name: String = "Pistol"
@export var gun_id: String = "pistol"
@export var icon: Texture2D

@export var damage: float = 10.0
@export var fire_rate: float = 0.3
@export var reload_time: float = 1.5
@export var mag_size: int = 12
@export var bullet_speed: float = 80.0
@export var bullet_range: float = 100.0
@export var spread: float = 0.0

@export_enum("semi_auto", "full_auto", "burst") var fire_mode: String = "semi_auto"
@export var burst_count: int = 3
@export var burst_delay: float = 0.05

@export var bullets_per_shot: int = 1
@export var shot_spread: float = 0.0
@export var pierce_count: int = 0

@export var barrel_slot: bool = true
@export var sight_slot: bool = true
@export var magazine_slot: bool = true
@export var grip_slot: bool = true
@export var special_slot: bool = true
