class_name StatusEffectDisplay
extends Control

@export var icon_size: Vector2 = Vector2(32, 32)
@export var icon_spacing: int = 4
@export var max_icons_per_row: int = 5

# Export variables for status effect icons
@export_group("Status Effect Icons")
@export var default_icon: Texture2D  # Fallback icon if none specified
@export var stun_icon: Texture2D
@export var vulnerable_icon: Texture2D
@export var shielded_icon: Texture2D
@export var poison_icon: Texture2D
@export var paralyze_icon: Texture2D
@export var immobilize_icon: Texture2D
@export var burn_icon: Texture2D
@export var dazed_icon: Texture2D

var status_effect_manager: StatusEffectManager
var icon_container: HBoxContainer  # Changed to HBoxContainer for better layout
var effect_icons: Dictionary = {}  # Key: EffectType, Value: TextureRect

func _ready():
	# Position this display above the cryptid
	position = Vector2(-icon_size.x * max_icons_per_row / 2, -10)  # Adjust Y offset as needed
	
	custom_minimum_size = Vector2(
		(icon_size.x + icon_spacing) * max_icons_per_row, 
		icon_size.y
	)
	
	# Create horizontal container for icons
	icon_container = HBoxContainer.new()
	icon_container.add_theme_constant_override("separation", icon_spacing)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(icon_container)

# Initialize with reference to status effect manager
func initialize(manager: StatusEffectManager) -> void:
	status_effect_manager = manager
	
	# Connect to manager signals
	status_effect_manager.status_effect_added.connect(_on_status_effect_added)
	status_effect_manager.status_effect_removed.connect(_on_status_effect_removed)
	
	# Initialize display with any existing effects
	refresh_display()

# Refresh the entire display
func refresh_display() -> void:
	# Clear existing icons
	for child in icon_container.get_children():
		child.queue_free()
	effect_icons.clear()
	
	# Add icons for all active effects
	var effects = status_effect_manager.get_all_effects()
	for effect in effects:
		_add_effect_icon(effect)

# Get the appropriate icon for an effect type
func _get_effect_icon(effect_type: StatusEffect.EffectType) -> Texture2D:
	match effect_type:
		StatusEffect.EffectType.STUN:
			return stun_icon if stun_icon else default_icon
		StatusEffect.EffectType.VULNERABLE:
			return vulnerable_icon if vulnerable_icon else default_icon
		StatusEffect.EffectType.SHIELDED:
			return shielded_icon if shielded_icon else default_icon
		StatusEffect.EffectType.POISON:
			return poison_icon if poison_icon else default_icon
		StatusEffect.EffectType.PARALYZE:
			return paralyze_icon if paralyze_icon else default_icon
		StatusEffect.EffectType.IMMOBILIZE:
			return immobilize_icon if immobilize_icon else default_icon
		StatusEffect.EffectType.BURN:
			return burn_icon if burn_icon else default_icon
		StatusEffect.EffectType.DAZED:
			return dazed_icon if dazed_icon else default_icon
		_:
			return default_icon

# Add an icon for a status effect
func _add_effect_icon(effect: StatusEffect) -> void:
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Get the appropriate icon texture
	var icon_texture = _get_effect_icon(effect.effect_type)
	
	# Set icon texture if available
	if effect.icon:
		# Use the effect's specific icon if it has one
		icon_rect.texture = effect.icon
	elif icon_texture:
		# Use the exported icon for this effect type
		icon_rect.texture = icon_texture
	else:
		# Create a colored placeholder if no icon available
		var placeholder = preload("res://Cryptid-Menagerie/assets/icon.svg")  # Using default Godot icon as fallback
		if placeholder:
			icon_rect.texture = placeholder
		icon_rect.modulate = _get_effect_color(effect.effect_type)
	
	# Create a container for the icon and stack count
	var icon_wrapper = Control.new()
	icon_wrapper.custom_minimum_size = icon_size
	icon_wrapper.add_child(icon_rect)
	
	# Add stack count label if more than 1 stack
	if effect.stack_count > 1:
		var stack_label = Label.new()
		stack_label.text = str(effect.stack_count)
		stack_label.add_theme_font_size_override("font_size", 14)
		stack_label.add_theme_color_override("font_color", Color.WHITE)
		stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		stack_label.add_theme_constant_override("shadow_offset_x", 1)
		stack_label.add_theme_constant_override("shadow_offset_y", 1)
		stack_label.position = Vector2(icon_size.x - 16, icon_size.y - 18)
		icon_wrapper.add_child(stack_label)
	
	# Add tooltip on hover
	icon_rect.tooltip_text = effect.effect_name + ": " + effect.description
	
	icon_container.add_child(icon_wrapper)
	effect_icons[effect.effect_type] = icon_wrapper

# Signal callbacks
func _on_status_effect_added(effect: StatusEffect) -> void:
	refresh_display()  # Refresh entire display to maintain order

func _on_status_effect_removed(effect_type: StatusEffect.EffectType) -> void:
	refresh_display()  # Refresh entire display to maintain order

# Get color for effect type (for placeholder icons)
func _get_effect_color(effect_type: StatusEffect.EffectType) -> Color:
	match effect_type:
		StatusEffect.EffectType.STUN:
			return Color.YELLOW
		StatusEffect.EffectType.VULNERABLE:
			return Color.ORANGE
		StatusEffect.EffectType.POISON:
			return Color.PURPLE
		StatusEffect.EffectType.SHIELDED:
			return Color.CYAN
		StatusEffect.EffectType.BURN:
			return Color.RED
		StatusEffect.EffectType.DAZED:
			return Color.DIM_GRAY
		StatusEffect.EffectType.PARALYZE:
			return Color.BLUE
		StatusEffect.EffectType.IMMOBILIZE:
			return Color.BROWN
		_:
			return Color.WHITE
