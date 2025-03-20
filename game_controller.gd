class_name GameController
extends Node2D

@onready var action_selection_menu = %ActionSelectMenu
@onready var game_instructions = %GameInstructions
@onready var swap_button = %SwapButton
@onready var rest_button = %RestButton
@onready var catch_button = %CatchButton
@onready var hand = %Hand
@onready var turn_order = %"Turn Order"
@onready var tile_map_layer = %TileMapLayer
@onready var discarded_cards = %DiscardCards
@onready var enemy_ai_controller = %EnemyAIController  # New reference to the AI controller

enum GameState {
	PLAYER_TURN,
	ENEMY_TURN,
	GAMEOVER,
	VICTORY
}

@onready var current_state: GameState = GameState.PLAYER_TURN

func _ready():
	# Start with the player's turn when the game begins
	transition(GameState.PLAYER_TURN)

func transition(next_state: GameState):
	# Log transition for debugging
	print("Game state transitioning from " + str(current_state) + " to " + str(next_state))
	
	# Handle exit actions for current state
	match current_state:
		GameState.PLAYER_TURN:
			# Clean up any UI elements specific to player turn
			pass
		GameState.ENEMY_TURN:
			# Clean up any enemy turn specific state
			pass
			
	# Set the new state
	current_state = next_state
	
	# Handle enter actions for new state
	match current_state:
		GameState.PLAYER_TURN:
			start_player_turn()
		GameState.ENEMY_TURN:
			start_enemy_turn()
		GameState.GAMEOVER:
			handle_game_over()
		GameState.VICTORY:
			handle_victory()

# Function that starts the player's turn
func start_player_turn():
	print("Starting player turn")
	
	# Display the action selection menu
	action_selection_menu.show()
	action_selection_menu.prompt_player_for_action()
	
	# Connect to the menu's signal if not already connected
	if not action_selection_menu.is_connected("action_selected", Callable(self, "_on_action_selected")):
		action_selection_menu.connect("action_selected", Callable(self, "_on_action_selected"))
	
	# Update instructions
	var current_cryptid = hand.selected_cryptid
	if current_cryptid:
		game_instructions.text = "Player's turn - Controlling: " + current_cryptid.name
	else:
		game_instructions.text = "Player's turn"

# Function to start the enemy turn
func start_enemy_turn():
	print("Starting enemy turn")
	
	# Hide the player UI during enemy turn
	action_selection_menu.hide()
	
	# Update instructions
	game_instructions.text = "Enemy's turn..."
	
	# Get current enemy cryptid that should take its turn
	var current_cryptid = hand.selected_cryptid
	if current_cryptid:
		print("Current cryptid for enemy turn: " + current_cryptid.name)
		
		# Find the cryptid node on the map
		var enemy_cryptid = null
		for cryptid in tile_map_layer.enemy_cryptids_in_play:
			if cryptid.cryptid == current_cryptid:
				enemy_cryptid = cryptid
				break
		
		if enemy_cryptid:
			# Delegate to the AI controller to handle the enemy's turn
			enemy_ai_controller.perform_enemy_turn(enemy_cryptid)
		else:
			print("ERROR: Could not find enemy cryptid node for " + current_cryptid.name)
			# Move to next cryptid
			hand.next_cryptid_turn()
	else:
		print("ERROR: No selected cryptid for enemy turn")
		# Move to next cryptid
		hand.next_cryptid_turn()

# Function to handle the selected action from the ActionSelectionMenu
func _on_action_selected(action_type: int):
	match action_type:
		action_selection_menu.ActionType.SWAP:
			prompt_swap_cryptid()
		action_selection_menu.ActionType.REST:
			perform_rest()
		action_selection_menu.ActionType.CATCH:
			prompt_catch_cryptid()
		action_selection_menu.ActionType.END_TURN:
			end_current_turn()
		action_selection_menu.ActionType.BATTLE_PHASE:
			round_phase()  # Renamed from battle_phase for clarity

# Functions to handle each action
func prompt_swap_cryptid():
	print("Prompting player to swap cryptid")
	game_instructions.text = "Select a cryptid to swap to"

func perform_rest():
	print("Player is resting")
	game_instructions.text = "Player is resting"
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		hand.selected_cryptid.completed_turn = true
		
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		round_phase()  # Renamed from battle_phase
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		
		# Check if the next cryptid is an enemy or player
		if hand.selected_cryptid and is_enemy_cryptid(hand.selected_cryptid):
			transition(GameState.ENEMY_TURN)
		else:
			action_selection_menu.prompt_player_for_action()

func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	game_instructions.text = "Select a cryptid to catch"
	
func end_current_turn():
	print("Ending current cryptid's turn")
	game_instructions.text = "Turn ended"
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		hand.selected_cryptid.completed_turn = true
		hand.selected_cryptid.currently_selected = false
	
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		round_phase()  # Renamed from battle_phase
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		
		# Update the UI to show the new selected cryptid's hand
		if hand.selected_cryptid:
			hand.switch_cryptid_deck(hand.selected_cryptid)
			game_instructions.text = "Now controlling: " + hand.selected_cryptid.name
			
			# If it's an enemy cryptid, transition to enemy turn
			if is_enemy_cryptid(hand.selected_cryptid):
				transition(GameState.ENEMY_TURN)
			else:
				# Show the action menu for the next player cryptid
				action_selection_menu.prompt_player_for_action()
				transition(GameState.PLAYER_TURN)

# Changed from battle_phase to round_phase for clarity
func round_phase():
	print("Entering round phase")
	game_instructions.text = "Round complete - preparing next round"
	
	action_selection_menu.hide()
	discarded_cards.show()
	
	# Check if all player cryptids have completed their turns
	var all_completed = true
	for cryptid in tile_map_layer.all_cryptids_in_play:
		if cryptid.cryptid.completed_turn == false:
			all_completed = false
			break
	
	if all_completed:
		# Reset all turns and start a new round
		reset_all_cryptid_turns()
		
		# Find the cryptid with the highest speed to start the next round
		tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
		
		# Update turn order display
		turn_order.clear_turn_order()
		for cryptid in tile_map_layer.all_cryptids_in_play:
			turn_order._add_picked_cards_to_turn_order(cryptid.cryptid.name)
		
		# Set the fastest cryptid as selected
		if tile_map_layer.all_cryptids_in_play.size() > 0:
			var fastest_cryptid = tile_map_layer.all_cryptids_in_play[0].cryptid
			hand.selected_cryptid = fastest_cryptid
			fastest_cryptid.currently_selected = true
			hand.switch_cryptid_deck(fastest_cryptid)
			
			# Determine if enemy or player should go first
			if is_enemy_cryptid(fastest_cryptid):
				transition(GameState.ENEMY_TURN)
			else:
				transition(GameState.PLAYER_TURN)
		else:
			print("ERROR: No cryptids in play after round reset")
			transition(GameState.PLAYER_TURN)  # Default to player turn if something goes wrong
	
# Reset all cryptid turns at the end of a round
func reset_all_cryptid_turns():
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		cryptid_in_play.cryptid.completed_turn = false
		cryptid_in_play.cryptid.top_card_played = false
		cryptid_in_play.cryptid.bottom_card_played = false

# Helper function to determine if a cryptid belongs to the enemy
func is_enemy_cryptid(cryptid):
	for enemy in tile_map_layer.enemy_cryptids_in_play:
		if enemy.cryptid == cryptid:
			return true
	return false

# Handle game over state
func handle_game_over():
	game_instructions.text = "Game Over - You Lost!"
	action_selection_menu.hide()
	# Additional game over UI/effects would go here

# Handle victory state
func handle_victory():
	game_instructions.text = "Victory - You Won!"
	action_selection_menu.hide()
	# Additional victory UI/effects would go here
