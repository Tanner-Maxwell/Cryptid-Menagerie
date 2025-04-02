extends PanelContainer

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var content_container = $MarginContainer/VBoxContainer/ContentContainer

# Properties for the display
var cryptid: Cryptid = null

func _ready():
	# Initialize with default style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.3, 0.1, 1.0)  # Dark green background
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.8, 0.3, 1.0)  # Green border
	add_theme_stylebox_override("panel", style_box)
	
	# Set minimum size
	custom_minimum_size = Vector2(280, 220)

func set_title(text: String):
	title_label.text = text
	title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	title_label.add_theme_font_size_override("font_size", 24)

func clear_display():
	for child in content_container.get_children():
		content_container.remove_child(child)
		child.queue_free()

func set_cryptid(new_cryptid: Cryptid):
	cryptid = new_cryptid
	
	# Create a horizontal container for icon and details
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create icon
	var icon_container = CenterContainer.new()
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_rect.expand_mode = 3  # EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = 5  # STRETCH_KEEP_ASPECT_CENTERED
	if cryptid.icon:
		icon_rect.texture = cryptid.icon
	icon_container.add_child(icon_rect)
	hbox.add_child(icon_container)
	
	# Create details container
	var details_container = VBoxContainer.new()
	details_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Name label
	var name_label = Label.new()
	name_label.text = cryptid.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	details_container.add_child(name_label)
	
	# Health info
	var health_label = Label.new()
	var current_health = cryptid.health
	var max_health = cryptid.health
	
	# Check for stored health
	if cryptid.has_meta("current_health") and cryptid.get_meta("current_health") > 0:
		current_health = cryptid.get_meta("current_health")
	elif cryptid.get("current_health") != null and cryptid.current_health > 0:
		current_health = cryptid.current_health
	
	health_label.text = "HP: " + str(current_health) + "/" + str(max_health)
	details_container.add_child(health_label)
	
	# Stats info
	var stats_label = Label.new()
	stats_label.text = "STR: " + str(cryptid.strength) + "\n" + \
					  "DEX: " + str(cryptid.dexterity) + "\n" + \
					  "VIG: " + str(cryptid.vigor) + "\n" + \
					  "KNW: " + str(cryptid.knowledge) + "\n" + \
					  "WIL: " + str(cryptid.willpower)
	details_container.add_child(stats_label)
	
	# Add details to hbox
	hbox.add_child(details_container)
	
	# Add hbox to content container
	content_container.add_child(hbox)
	
	# Add a "Caught!" label with animation
	var caught_label = Label.new()
	caught_label.text = "CAUGHT!"
	caught_label.add_theme_font_size_override("font_size", 28)
	caught_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))
	caught_label.horizontal_alignment = 1  # CENTER = 1
	content_container.add_child(caught_label)
	
	# Create a pulsing animation
	var tween = create_tween()
	tween.set_loops()  # Infinite loops
	tween.tween_property(caught_label, "modulate", Color(1.0, 1.0, 0.0, 1.0), 0.5)
	tween.tween_property(caught_label, "modulate", Color(1.0, 0.5, 0.0, 1.0), 0.5)
