extends PanelContainer

@onready var gold_label = $MarginContainer/HBoxContainer/GoldLabel
@onready var gold_icon = $MarginContainer/HBoxContainer/GoldIcon
@onready var animation_label = $MarginContainer/HBoxContainer/AnimationLabel

var current_display_gold: int = 0
var target_gold: int = 0
var tween: Tween

func _ready():
	# Set up the display
	setup_display()
	
	# Connect to GoldManager if it exists
	if GoldManager:
		GoldManager.connect("gold_changed", Callable(self, "_on_gold_changed"))
		GoldManager.connect("gold_earned", Callable(self, "_on_gold_earned"))
		GoldManager.connect("gold_spent", Callable(self, "_on_gold_spent"))
		
		# Initialize with current gold
		current_display_gold = GoldManager.get_gold()
		target_gold = current_display_gold
		update_gold_display()

func setup_display():
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.7, 0.2, 1)  # Gold border
	add_theme_stylebox_override("panel", style)
	
	# Position in top-right corner
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -220
	offset_right = -20
	offset_top = 20
	offset_bottom = 70
	
	# Set up the gold icon
	if gold_icon:
		gold_icon.custom_minimum_size = Vector2(32, 32)
		gold_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Load the icon texture (using icon.svg as placeholder)
		var icon_texture = load("res://icon.svg")
		if icon_texture:
			gold_icon.texture = icon_texture
			gold_icon.modulate = Color(1.0, 0.85, 0.0, 1.0)  # Gold tint
	
	# Style the gold label
	if gold_label:
		gold_label.add_theme_font_size_override("font_size", 24)
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		
	# Hide animation label initially
	if animation_label:
		animation_label.visible = false
		animation_label.add_theme_font_size_override("font_size", 20)

func _on_gold_changed(new_amount: int):
	target_gold = new_amount
	animate_gold_change()

func _on_gold_earned(amount: int):
	show_gold_animation("+" + str(amount), Color(0.0, 1.0, 0.0, 1.0))

func _on_gold_spent(amount: int):
	show_gold_animation("-" + str(amount), Color(1.0, 0.0, 0.0, 1.0))

func animate_gold_change():
	# Kill existing tween if any
	if tween and tween.is_running():
		tween.kill()
	
	# Create smooth number animation
	tween = create_tween()
	tween.tween_method(Callable(self, "set_display_gold"), current_display_gold, target_gold, 0.5)
	tween.tween_callback(Callable(self, "_on_tween_completed"))

func set_display_gold(value: int):
	current_display_gold = value
	update_gold_display()

func update_gold_display():
	if gold_label:
		gold_label.text = str(current_display_gold)

func _on_tween_completed():
	current_display_gold = target_gold

func show_gold_animation(text: String, color: Color):
	if not animation_label:
		return
		
	# Set up the animation label
	animation_label.text = text
	animation_label.add_theme_color_override("font_color", color)
	animation_label.visible = true
	animation_label.position = Vector2.ZERO
	animation_label.modulate = Color(1, 1, 1, 1)
	
	# Create animation
	var anim_tween = create_tween()
	anim_tween.set_parallel(true)
	
	# Move up and fade out
	anim_tween.tween_property(animation_label, "position", Vector2(0, -30), 1.0)
	anim_tween.tween_property(animation_label, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# Hide after animation
	anim_tween.chain().tween_callback(Callable(animation_label, "hide"))
