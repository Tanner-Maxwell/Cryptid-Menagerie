extends Control

# Mouse tracking variables
var mouse_position = Vector2.ZERO
var screen_center = Vector2.ZERO
var parallax_strength = 300  # How strongly the background responds to mouse movement

# References to parallax layers
@onready var parallax_bg = $ParallaxBackground
@onready var layer1 = $ParallaxBackground/ParallaxLayer1
@onready var layer2 = $ParallaxBackground/ParallaxLayer2
@onready var layer3 = $ParallaxBackground/ParallaxLayer3

func _ready():
	# Connect button signals to their respective functions
	$PanelContainer/VBoxContainer/PlayButton.connect("pressed", Callable(self, "_on_play_button_pressed"))
	$PanelContainer/VBoxContainer/OptionsButton.connect("pressed", Callable(self, "_on_options_button_pressed"))
	$PanelContainer/VBoxContainer/QuitButton.connect("pressed", Callable(self, "_on_quit_button_pressed"))
	
	# Set game title to match your game's name
	$TitleLabel.text = "Cryptid Menagerie"
	
	# Set motion scale for each parallax layer programmatically
	if layer1:
		layer1.motion_scale = Vector2(0.02, 0.02)  # Slowest (farthest layer)
	if layer2:
		layer2.motion_scale = Vector2(0.05, 0.05)  # Medium speed (middle layer)
	if layer3:
		layer3.motion_scale = Vector2(0.08, 0.08)  # Fastest (closest layer)
	
	# Store the center of the screen for parallax calculations
	screen_center = get_viewport_rect().size / 2
	
	# Set initial mouse position to center to avoid jumps on start
	mouse_position = screen_center
	
	# Optional: Add animation to make the title more appealing
	var title_tween = create_tween()
	title_tween.tween_property($TitleLabel, "modulate", Color(1, 1, 0.8, 1), 1.0)
	title_tween.tween_property($TitleLabel, "modulate", Color(1, 1, 1, 1), 1.0)
	title_tween.set_loops()

func _process(delta):
	# Calculate offset from screen center as a ratio (-1 to 1 range)
	var offset_ratio = (mouse_position - screen_center) / screen_center
	
	# Apply to parallax background
	if parallax_bg:
		parallax_bg.scroll_offset = -offset_ratio * parallax_strength

func _input(event):
	# Track mouse movement for parallax effect
	if event is InputEventMouseMotion:
		mouse_position = event.position

func _on_play_button_pressed():
	print("Play button pressed - starting game")
	
	# First try to load the starter selection scene
	var starter_scene_path = "res://starter_selection_scene.tscn"
	if FileAccess.file_exists(starter_scene_path):
		# Initialize GameState if needed
		if "initialize_player_team" in GameState:
			GameState.initialize_player_team()
		get_tree().change_scene_to_file(starter_scene_path)
		return
	
	# If starter selection scene is not available, try the overworld scene
	var overworld_scene_path = "res://Cryptid-Menagerie/scenes/overworld_map.tscn"
	if FileAccess.file_exists(overworld_scene_path):
		get_tree().change_scene_to_file(overworld_scene_path)
		return
		
	# If not available, try loading the battle scene directly
	var battle_scene_path = "res://Cryptid-Menagerie/scenes/battle_scene.tscn"
	if FileAccess.file_exists(battle_scene_path):
		# Initialize GameState if needed
		if "initialize_player_team_with_test_cryptids" in GameState:
			GameState.initialize_player_team_with_test_cryptids()
		get_tree().change_scene_to_file(battle_scene_path)
		return
		
	# Fallback in case scenes aren't found
	print("ERROR: Could not find game start scene")
	$ErrorLabel.text = "Error: Could not find game start scene"
	$ErrorLabel.show()

func _on_options_button_pressed():
	print("Options button pressed")
	
	# Check if options menu exists
	if has_node("OptionsMenu"):
		$OptionsMenu.show()
	else:
		# Create a simple options panel
		var options_panel = PanelContainer.new()
		options_panel.name = "OptionsMenu"
		options_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		options_panel.position = Vector2(50, 50)
		options_panel.custom_minimum_size = Vector2(400, 300)
		
		# Add a background style
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.2, 0.9)
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		options_panel.add_theme_stylebox_override("panel", style_box)
		
		# Add a margin container
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		options_panel.add_child(margin)
		
		# Add a VBox for content
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 15)
		margin.add_child(vbox)
		
		# Add a title
		var title = Label.new()
		title.text = "Options"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)
		vbox.add_child(title)
		
		# Add a separator
		var separator = HSeparator.new()
		vbox.add_child(separator)
		
		# Add some placeholder options
		var volume_label = Label.new()
		volume_label.text = "Volume"
		vbox.add_child(volume_label)
		
		var volume_slider = HSlider.new()
		volume_slider.min_value = 0
		volume_slider.max_value = 100
		volume_slider.value = 80
		vbox.add_child(volume_slider)
		
		# Add a close button
		var close_button = Button.new()
		close_button.text = "Close"
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		close_button.connect("pressed", Callable(self, "_on_options_close_pressed"))
		vbox.add_child(close_button)
		
		# Add to scene
		add_child(options_panel)

func _on_options_close_pressed():
	$OptionsMenu.hide()

func _on_quit_button_pressed():
	print("Quit button pressed - exiting game")
	get_tree().quit()
