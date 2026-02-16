# CameraShakeManager.gd
# Autoload singleton - now with HIT FLASH + SHAKE!

extends Node

# Shake settings
@export var max_shake_pixels: float = 8.0
@export var decay_rate: float = 14.0

# Flash settings (for damage hits)
@export var flash_color: Color = Color(1, 1, 1, 1)  # Red-ish, semi-transparent
@export var flash_duration: float = 0.12                    # Super quick
@export var flash_intensity: float = 1.0                    # Scale alpha (0.5=dim, 2.0=bright)

var current_camera: Camera3D = null
var active_tween: Tween = null

# Flash overlay
var flash_canvas: CanvasLayer
var flash_rect: ColorRect

func _ready() -> void:
	await get_tree().process_frame
	_find_camera()
	_setup_flash_overlay()

func _setup_flash_overlay() -> void:
	flash_canvas = CanvasLayer.new()
	flash_canvas.layer = 128  # On top of everything
	get_tree().root.add_child(flash_canvas)
	
	flash_rect = ColorRect.new()
	flash_rect.anchors_preset = Control.PRESET_FULL_RECT  # ← FIXED: added the dot
	flash_rect.color = Color.TRANSPARENT
	flash_canvas.add_child(flash_rect)

func _find_camera() -> void:
	current_camera = get_viewport().get_camera_3d()
	if not current_camera:
		push_warning("CameraShakeManager: No active Camera3D")

# Original shake (unchanged)
func shake(
	intensity: float = 0.35,
	duration: float = 0.18,
	max_offset: float = -1.0
) -> void:
	if not current_camera:
		_find_camera()
		if not current_camera: return
	
	if active_tween:
		active_tween.kill()
	
	var use_duration = duration if duration > 0 else 0.18
	var use_max = max_offset if max_offset > 0 else max_shake_pixels
	var target_strength = intensity * use_max * 0.18
	
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.set_trans(Tween.TRANS_SINE)
	
	# Horizontal wobble
	active_tween.tween_property(current_camera, "h_offset", 0.0, use_duration * 1.1).from(target_strength)
	active_tween.tween_property(current_camera, "h_offset", 0.0, use_duration * 0.9).from(target_strength * -0.6).set_delay(use_duration * 0.25)
	
	# Vertical (smaller)
	active_tween.tween_property(current_camera, "v_offset", 0.0, use_duration * 1.0).from(target_strength * 0.4)
	active_tween.tween_property(current_camera, "v_offset", 0.0, use_duration * 0.8).from(target_strength * -0.3).set_delay(use_duration * 0.35)
	
	active_tween.tween_callback(func():
		current_camera.h_offset = 0.0
		current_camera.v_offset = 0.0
		active_tween = null
	).set_delay(use_duration * 1.2)

# NEW: Quick screen flash (red overlay)
func flash(color: Color = Color.TRANSPARENT, duration: float = -1.0) -> void:
	var use_duration = duration if duration > 0 else flash_duration
	var use_color = color if color.a > 0 else flash_color
	
	# Scale alpha by intensity
	use_color.a *= flash_intensity
	
	var flash_tween = create_tween()
	flash_rect.color = use_color  # Instant on
	
	# Fade out smoothly
	flash_tween.tween_property(flash_rect, "color:a", 0.0, use_duration).from(use_color.a)
	flash_tween.tween_property(flash_rect, "color", Color.TRANSPARENT, use_duration * 0.8)

# COMBO: Shake + Flash (perfect for hits!)
func hit_feedback(intensity: float = 0.35, damage_scale: bool = true) -> void:
	var dmg_intensity = 1.0
	if damage_scale:
		dmg_intensity = clampf(intensity, 0.2, 1.2)  # Scale by damage
	
	shake(dmg_intensity * 0.8, 0.15)  # Subtle shake
	flash(flash_color * dmg_intensity, 0.10)  # Quick red flash

# Usage examples (call from take_damage):
# CameraShakeManager.hit_feedback(damage)          # Auto-scales
# CameraShakeManager.flash(Color.WHITE, 0.08)     # Custom white flash
# CameraShakeManager.shake(0.5) + flash()         # Manual combo
