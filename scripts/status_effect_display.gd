class_name StatusEffectDisplay
extends Control

@export var icon_size: Vector2 = Vector2(32, 32)
@export var icon_spacing: int = 4
@export var max_icons_per_row: int = 5

var status_effect_manager: StatusEffectManager
var icon_container: GridContainer
var effect_icons: Dictionary = {}  # Key: EffectType, Value: TextureRect

func _ready():
	custom_minimum_size = Vector2(
		(icon_size.x + icon_spacing) * max_icons_per_row, 
		icon_size.y
	)
	
	# Create grid container for icons
	icon_container = GridContainer.new()
	icon_container.columns = max_icons_per_row
	icon_container.add_theme_constant_override("h_separation", icon_spacing)
	icon_container.add_theme_constant_override("v_separation", icon_spacing)
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

# Add an icon for a status effect
func _add_effect_icon(effect: StatusEffect) -> void:
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set icon texture if available, otherwise use a placeholder
	if effect.icon:
		icon_rect.texture = effect.icon
	else:
		# Create a colored placeholder based on effect type
		icon_rect.modulate = _get_effect_color(effect.effect_type)
		# You can set a default icon texture here
	
	# Add stack count label if more than 1 stack
	if effect.stack_count > 1:
		var stack_label = Label.new()
		stack_label.text = str(effect.stack_count)
		stack_label.add_theme_font_size_override("font_size", 12)
		stack_label.add_theme_color_override("font_color", Color.WHITE)
		stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		stack_label.add_theme_constant_override("shadow_offset_x", 1)
		stack_label.add_theme_constant_override("shadow_offset_y", 1)
		stack_label.position = Vector2(icon_size.x - 12, icon_size.y - 16)
		icon_rect.add_child(stack_label)
	
	icon_container.add_child(icon_rect)
	effect_icons[effect.effect_type] = icon_rect

# Signal callbacks
func _on_status_effect_added(effect: StatusEffect) -> void:
	_add_effect_icon(effect)

func _on_status_effect_removed(effect_type: StatusEffect.EffectType) -> void:
	if effect_type in effect_icons:
		effect_icons[effect_type].queue_free()
		effect_icons.erase(effect_type)

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
