# plant.gd
class_name Plant
extends Resource

@export var plant_name: String = ""
@export var icon: Texture2D = null  # Seed icon (for inventory/shop)
@export var seed_model_path: String = ""  # Shows when first planted
@export var growing_model_path: String = ""  # Shows at 50% growth (optional)
@export var grown_model_path: String = ""  # Shows when ready to harvest
@export var growth_time: float = 60.0  # Seconds to grow

# Simple harvest - just the crop item
@export var harvest_item: String = ""  # e.g. "plant_fiber"
@export var harvest_amount: int = 3
@export var harvest_icon: Texture2D = null

# Seeds returned when harvesting
@export var seed_return_amount: int = 2  # How many seeds you get back
