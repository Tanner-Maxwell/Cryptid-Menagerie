# Game Over Scene Script
extends Control

# Called when the node enters the scene tree
func _ready():
	# Find buttons and connect their signals
	var restart_button = $CenterContainer/VBoxContainer/RestartButton
	var main_menu_button = $CenterContainer/VBoxContainer/MainMenuButton
	
	if restart_button:
		restart_button.connect("pressed", Callable(self, "_on_restart_pressed"))
	
	if main_menu_button:
		main_menu_button.connect("pressed", Callable(self, "_on_main_menu_pressed"))
	
	# Animate the game over text if needed
	animate_game_over_text()

func _on_restart_pressed():
	print("Restarting game...")
	# Reset game state for a new run
	reset_game_state()
	# Load the game scene (adjust path as needed)
	get_tree().change_scene_to_file("res://starter_selection_scene.tscn")

func _on_main_menu_pressed():
	print("Returning to main menu...")
	# Load the main menu scene (adjust path as needed)
	get_tree().change_scene_to_file("res://main_menu.tscn")

func reset_game_state():
	# Reset GameState variables
	if GameState:
		GameState.current_floor = 1
		GameState.current_biome = "Forest"
		GameState.current_encounter = null
		GameState.last_battle_result = null
		GameState._current_node_id = ""
		
		# Reinitialize player team with starter cryptids
		GameState.initialize_player_team_with_test_cryptids()
	
	# Reset any defeated cryptids trackers
	var tracker = Engine.get_singleton("DefeatedCryptidsTracker")
	if tracker:
		tracker._defeated_list.clear()
	
	# Clear globally defeated cryptids
	if GameController and "globally_defeated_cryptids" in GameController:
		GameController.globally_defeated_cryptids.clear()
	
	# Clear SwapCryptidDialog's static list
	var swap_dialog = preload("res://Cryptid-Menagerie/swap_cryptid_dialog.gd")
	if swap_dialog and "all_defeated_cryptids" in swap_dialog:
		swap_dialog.all_defeated_cryptids.clear()

func animate_game_over_text():
	var game_over_label = $CenterContainer/VBoxContainer/GameOverLabel
	if game_over_label:
		# Create a pulse animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(game_over_label, "modulate", Color(1, 0.5, 0.5, 1), 0.5)
		tween.tween_property(game_over_label, "modulate", Color(1, 1, 1, 1), 0.5)
