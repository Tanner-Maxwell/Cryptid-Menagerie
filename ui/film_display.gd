extends PanelContainer

@onready var film_label = $MarginContainer/HBoxContainer/FilmLabel
@onready var film_icon = $MarginContainer/HBoxContainer/FilmIcon
@onready var animation_label = $MarginContainer/HBoxContainer/AnimationLabel

var current_display_film: int = 0
var target_film: int = 0
var tween: Tween

func _ready():
	# Set up the display
	setup_display()
	
	# Connect to FilmManager if it exists
	if FilmManager:
		FilmManager.connect("film_changed", Callable(self, "_on_film_changed"))
		FilmManager.connect("film_added", Callable(self, "_on_film_added"))
		FilmManager.connect("film_used", Callable(self, "_on_film_used"))
		
		# Initialize with current film
		current_display_film = FilmManager.get_film()
		target_film = current_display_film
		update_film_display()

func setup_display():
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.8, 1.0, 1)  # Light blue border for film
	add_theme_stylebox_override("panel", style)
	
	# Position below the gold display (top-right corner)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -220
	offset_right = -20
	offset_top = 100  # Position below gold display
	offset_bottom = 150
	
	# Set up the film icon
	if film_icon:
		film_icon.custom_minimum_size = Vector2(32, 32)
		film_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		film_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# You can create a custom film icon or use a placeholder
		var icon_texture = load("res://icon.svg")  # Replace with actual film icon
		if icon_texture:
			film_icon.texture = icon_texture
			film_icon.modulate = Color(0.7, 0.85, 1.0, 1.0)  # Light blue tint
	
	# Style the film label
	if film_label:
		film_label.add_theme_font_size_override("font_size", 24)
		film_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
		
	# Hide animation label initially
	if animation_label:
		animation_label.visible = false
		animation_label.add_theme_font_size_override("font_size", 20)

func _on_film_changed(new_amount: int):
	target_film = new_amount
	animate_film_change()

func _on_film_added(amount: int):
	show_film_animation("+" + str(amount), Color(0.0, 1.0, 0.0, 1.0))

func _on_film_used(amount: int):
	show_film_animation("-" + str(amount), Color(1.0, 0.5, 0.0, 1.0))

func animate_film_change():
	# Kill existing tween if any
	if tween and tween.is_running():
		tween.kill()
	
	# Create smooth number animation
	tween = create_tween()
	tween.tween_method(Callable(self, "set_display_film"), current_display_film, target_film, 0.5)
	tween.tween_callback(Callable(self, "_on_tween_completed"))

func set_display_film(value: int):
	current_display_film = value
	update_film_display()

func update_film_display():
	if film_label:
		film_label.text = str(current_display_film)

func _on_tween_completed():
	current_display_film = target_film

func show_film_animation(text: String, color: Color):
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
