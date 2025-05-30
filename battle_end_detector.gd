extends Node

# Reference to important components
@onready var tile_map_layer = %TileMapLayer
@onready var game_controller = $"../GameController"

func _ready():
	# Wait a short time to ensure all references are properly set up
	await get_tree().create_timer(0.1).timeout
	
	# Verify we have the required references
	if !tile_map_layer:
		push_error("battle_end_detector: Missing tile_map_layer reference")
	if !game_controller:
		push_error("battle_end_detector: Missing game_controller reference")

func _process(_delta):
	# Check if we have valid game controller and tile map layer
	if game_controller and tile_map_layer:
		check_battle_end_conditions()
		
	if game_controller and tile_map_layer:
		# Check if all player cryptids are defeated
		var living_player_cryptids = 0
		for cryptid_node in tile_map_layer.player_cryptids_in_play:
			var health_bar = cryptid_node.get_node_or_null("HealthBar")
			if health_bar and health_bar.value > 0:
				living_player_cryptids += 1
		
		if living_player_cryptids == 0 and tile_map_layer.player_cryptids_in_play.size() > 0:
			# Call game over on the game controller
			if game_controller.has_method("trigger_game_over"):
				game_controller.trigger_game_over()

# Check if battle has ended
func check_battle_end_conditions():
	# Check if all player cryptids are defeated
	if tile_map_layer.player_cryptids_in_play.size() == 0:
		# Only transition if we're not already in game over state
		if game_controller.current_state != game_controller.GameState.GAMEOVER:
			game_controller.transition(game_controller.GameState.GAMEOVER)
	
	# Check if all enemy cryptids are defeated
	if tile_map_layer.enemy_cryptids_in_play.size() == 0:
		# Only transition if we're not already in victory state
		if game_controller.current_state != game_controller.GameState.VICTORY:
			game_controller.transition(game_controller.GameState.VICTORY)
