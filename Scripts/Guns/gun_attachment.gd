extends Resource
class_name GunAttachment

@export var attachment_name: String = ""
@export var attachment_id: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export_enum("barrel", "sight", "magazine", "grip", "special") var slot_type: String = "barrel"

@export var damage_mult_add: float = 0.0
@export var fire_rate_mult_add: float = 0.0
@export var spread_mult_add: float = 0.0
@export var mag_size_add: int = 0
@export var bullet_speed_mult_add: float = 0.0
@export var bullets_per_shot_add: int = 0
@export var shot_spread_add: float = 0.0
@export var pierce_add: int = 0
@export var reload_speed_mult_add: float = 0.0

@export var elemental_type: String = ""
@export var elemental_damage: float = 0.0
@export var elemental_chance: float = 0.0

@export var camera_shake: float = 0.0  # extra shake from this attachment
