extends BaseAnimal

func _ready():
	await super._ready()


# ============================================================
# wolf.gd — Example HOSTILE animal
# Wolves gain a "pack bonus": if another wolf is nearby when
# they detect the player, they move 20% faster. This shows how
# child scripts add flavor on top of the base hostile loop.
# ============================================================
# extends BaseAnimal
#
# var pack_speed_bonus: float = 0.2  # 20% faster near other wolves
# var pack_detection_radius: float = 15.0
#
# func _ready():
#     await super._ready()
#
# # Override chase to apply pack bonus
# func _chase_behavior(delta):
#     _apply_pack_bonus()
#     super._chase_behavior(delta)
#
# func _apply_pack_bonus():
#     var nearby_wolves = get_tree().get_nodes_in_group("animals")
#     var wolf_count = 0
#     for animal in nearby_wolves:
#         if animal != self and animal.animal_key == "wolf":
#             if global_position.distance_to(animal.global_position) < pack_detection_radius:
#                 wolf_count += 1
#     # Temporarily boost move_speed if wolves are nearby
#     move_speed = animal_definition.get("move_speed", 3.0) * (1.0 + pack_speed_bonus * wolf_count)


# ============================================================
# cow.gd — Example FARMABLE animal
# Farmable animals share the same flee/wander loop as wild ones
# for now. The "leadable" behavior (following player back to a
# pen) will be added later — this script is where that logic
# will live when it's ready.
# ============================================================
# extends BaseAnimal
#
# var is_being_led: bool = false  # Future: player can lead this animal
#
# func _ready():
#     await super._ready()
#
# # Future: override _check_player_proximity to allow leading
# # instead of fleeing once the player has the right item equipped.
