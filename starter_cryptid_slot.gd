extends PanelContainer

# Signals
signal selected
signal hovered
signal unhovered

# UI Elements
@onready var icon_rect = $VBoxContainer/IconContainer/CryptidIcon
@onready var name_label = $VBoxContainer/NameLabel
@onready var type_label = $VBoxContainer/TypeLabel
@onready var stats_container = $VBoxContainer/StatsContainer

# Properties
var cryptid: Cryptid = null
var is_selected: bool = false

func _ready():
	# Connect hover detection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Add a background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", style)
	
	# Set minimum size
	custom_minimum_size = Vector2(120, 150)

func setup(new_cryptid: Cryptid):
	cryptid = new_cryptid
	
	# Update visuals
	name_label.text = cryptid.name
	
	if cryptid.icon:
		icon_rect.texture = cryptid.icon
	
	# Get elemental types
	var type_text = ""
	if "elemental_types" in cryptid and cryptid.elemental_types.size() > 0:
		var types = []
		for type_id in cryptid.elemental_types:
			if type_id >= 0 and type_id < Cryptid.ELEMENTAL_TYPE.size():
				types.append(Cryptid.ELEMENTAL_TYPE.keys()[type_id])
		
		type_text = " / ".join(types)
	
	type_label.text = type_text if type_text else "Neutral"
	
	# Update stat labels
	var health_label = stats_container.get_node("HealthLabel")
	var speed_label = stats_container.get_node("SpeedLabel")
	var deck_label = stats_container.get_node("DeckLabel")
	
	health_label.text = "HP: " + str(cryptid.health)
	speed_label.text = "SPD: " + str(cryptid.speed)
	deck_label.text = "Deck: " + str(cryptid.max_hand_size)
	
	# Set color based on primary elemental type (first in the array)
	if "elemental_types" in cryptid and cryptid.elemental_types.size() > 0:
		var primary_color = get_type_color(cryptid.elemental_types[0])
		
		# Apply color to the type label
		type_label.add_theme_color_override("font_color", primary_color)
		
		# Create or update the panel style
		var style = get_theme_stylebox("panel", "PanelContainer").duplicate()
		if style is StyleBoxFlat:
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = primary_color.lightened(0.2)
			
			# If there's a second type, use it for a gradient or accent
			if cryptid.elemental_types.size() > 1:
				var secondary_color = get_type_color(cryptid.elemental_types[1])
				# Add the secondary color as a bottom border that's slightly thicker
				style.border_width_bottom = 4
				style.border_color = primary_color.lightened(0.2)
				style.border_blend = true # Enable blending for a gradient effect
			
			add_theme_stylebox_override("panel", style)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("selected")
		get_viewport().set_input_as_handled()

func _on_mouse_entered():
	if not is_selected:
		var style = get_theme_stylebox("panel", "PanelContainer").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Lighten when hovered
			add_theme_stylebox_override("panel", style)
	
	emit_signal("hovered")

func _on_mouse_exited():
	if not is_selected:
		var style = get_theme_stylebox("panel", "PanelContainer").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Normal color
			add_theme_stylebox_override("panel", style)
	
	emit_signal("unhovered")

func set_selected(selected: bool):
	is_selected = selected
	
	# Update visual appearance
	if is_selected:
		var style = get_theme_stylebox("panel", "PanelContainer").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = Color(0.4, 0.4, 0.2, 1.0)  # Gold color for selected
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.9, 0.9, 0.3, 1.0)  # Gold border
			add_theme_stylebox_override("panel", style)
	else:
		var style = get_theme_stylebox("panel", "PanelContainer").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Normal color
			
			# Keep type-colored border if available
			if "elemental_types" in cryptid:
				var color = get_type_color(cryptid.elemental_types[0])
				style.border_width_top = 2
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				style.border_color = color.lightened(0.2)
				
			add_theme_stylebox_override("panel", style)

# Get color based on elemental type
func get_type_color(type_id: int) -> Color:
	# Colors inspired by elemental types
	match type_id:
		Cryptid.ELEMENTAL_TYPE.NEUTRAL: return Color(0.7, 0.7, 0.7)  # Gray
		Cryptid.ELEMENTAL_TYPE.FIRE: return Color(1.0, 0.3, 0.0)  # Red-orange
		Cryptid.ELEMENTAL_TYPE.WATER: return Color(0.0, 0.5, 1.0)  # Blue
		Cryptid.ELEMENTAL_TYPE.GROVE: return Color(0.0, 0.8, 0.2)  # Green
		Cryptid.ELEMENTAL_TYPE.ELECTRIC: return Color(1.0, 0.8, 0.0)  # Yellow
		Cryptid.ELEMENTAL_TYPE.AETHER: return Color(0.8, 0.4, 1.0)  # Purple
		Cryptid.ELEMENTAL_TYPE.ICE: return Color(0.6, 0.9, 1.0)  # Light blue
		Cryptid.ELEMENTAL_TYPE.GLOOM: return Color(0.4, 0.0, 0.5)  # Dark purple
		Cryptid.ELEMENTAL_TYPE.GLIMMER: return Color(1.0, 0.8, 0.9)  # Pink
		Cryptid.ELEMENTAL_TYPE.OOZE: return Color(0.5, 0.8, 0.2)  # Slime green
		Cryptid.ELEMENTAL_TYPE.ROCK: return Color(0.6, 0.4, 0.2)  # Brown
		Cryptid.ELEMENTAL_TYPE.SPECTRE: return Color(0.5, 0.5, 0.8)  # Pale blue
		Cryptid.ELEMENTAL_TYPE.AIR: return Color(0.9, 0.9, 1.0)  # White
		_: return Color(0.7, 0.7, 0.7)  # Default gray
