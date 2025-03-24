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
@onready var enemy_ai_controller = $EnemyAIController

var discard_mode = false
var discard_count_needed = 0
var end_turn_after_discard = false

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
	match current_state:
		GameState.PLAYER_TURN:
			start_player_turn()
		GameState.ENEMY_TURN:
			start_enemy_turn()
		# Handle other states (GAMEOVER, VICTORY)
	
	current_state = next_state

# Function that starts the player's turn
func start_player_turn():
	# Display the action selection menu
	action_selection_menu.prompt_player_for_action()
	# Connect to the menu's signal if not already connected
	if not action_selection_menu.is_connected("action_selected", Callable(self, "_on_action_selected")):
		action_selection_menu.connect("action_selected", Callable(self, "_on_action_selected"))

# Function to start the enemy turn
func start_enemy_turn():
	pass

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
			battle_phase()

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
		battle_phase()
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		action_selection_menu.prompt_player_for_action()

func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	game_instructions.text = "Select a cryptid to catch"
	
# Update the end_current_turn function to properly handle discard
func end_current_turn():
	print("Ending current cryptid's turn")
	
	# First check if there's an active movement that needs to be finished
	if tile_map_layer and tile_map_layer.move_action_bool and tile_map_layer.move_leftover > 0:
		print("Finishing active movement before ending turn")
		tile_map_layer.finish_movement()
	
	# Get the current cryptid
	var current_cryptid = hand.selected_cryptid
	
	if current_cryptid:
		# Check if both card parts have been played
		if !current_cryptid.top_card_played or !current_cryptid.bottom_card_played:
			# Calculate how many cards need to be discarded
			discard_count_needed = 0
			if !current_cryptid.top_card_played:
				discard_count_needed += 1
			if !current_cryptid.bottom_card_played:
				discard_count_needed += 1
			
			if discard_count_needed > 0:
				# Enter discard mode
				discard_mode = true
				end_turn_after_discard = true
				
				# Update instruction text
				game_instructions.text = "Select " + str(discard_count_needed) + " card(s) to discard"
				
				# Start discard mode in the hand
				hand.start_discard_mode(discard_count_needed)
				
				# Show the discard confirmation button in the action menu
				action_selection_menu.show_discard_confirmation(true)
				
				# Make sure other card functionality is disabled
				action_selection_menu.enter_discard_mode()
				
				# Prevent any active card actions in the tile map
				tile_map_layer.reset_action_modes()
				
				return  # Return early, will complete turn after discard
		
		# If we get here, no discard needed or already handled
		complete_turn()
	else:
		print("WARNING: No selected cryptid found")
		# Try to end turn anyway
		complete_turn()

# Function to handle when discard selection is complete
func on_discard_selection_complete(selected_cards):
	discard_mode = false
	
	# Get the current cryptid
	var current_cryptid = hand.selected_cryptid
	
	if current_cryptid:
		# Process the selected cards
		hand.cards_selected(selected_cards)
		
		# Mark appropriate card parts as played based on how many were discarded
		if selected_cards.size() >= 1 and !current_cryptid.top_card_played:
			current_cryptid.top_card_played = true
		
		if selected_cards.size() >= 2 and !current_cryptid.bottom_card_played:
			current_cryptid.bottom_card_played = true
	
	# If this was triggered by end turn, complete the turn now
	if end_turn_after_discard:
		end_turn_after_discard = false
		complete_turn()

# Function to complete the turn
func complete_turn():
	var current_cryptid = hand.selected_cryptid
	
	# Mark current cryptid's turn as completed
	if current_cryptid:
		current_cryptid.completed_turn = true
		current_cryptid.currently_selected = false
	
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		battle_phase()
	else:
		# Move to the next cryptid's turn
		hand.next_cryptid_turn()
		
		# Update the UI to show the new selected cryptid's hand
		if hand.selected_cryptid:
			hand.switch_cryptid_deck(hand.selected_cryptid)
			game_instructions.text = "Now controlling: " + hand.selected_cryptid.name
		
		# Show the action menu for the next cryptid
		action_selection_menu.prompt_player_for_action()

# Update the on_discard_complete function to properly handle forced discards
func on_discard_complete(selected_cards):
	print("Discard complete with", selected_cards.size(), "cards")
	
	discard_mode = false
	
	# Get the current cryptid
	var current_cryptid = hand.selected_cryptid
	
	if current_cryptid:
		# Verify we have the right number of cards
		if selected_cards.size() < discard_count_needed:
			print("ERROR: Not enough cards discarded, needed", discard_count_needed, "got", selected_cards.size())
			# Force another discard attempt
			hand.start_discard_mode(discard_count_needed)
			action_selection_menu.show_discard_confirmation(true)
			return
		
		# Process the selected cards
		hand.cards_selected(selected_cards)
		
		# Mark appropriate card parts as played based on how many were discarded
		if selected_cards.size() >= 1 and !current_cryptid.top_card_played:
			current_cryptid.top_card_played = true
		
		if selected_cards.size() >= 2 and !current_cryptid.bottom_card_played:
			current_cryptid.bottom_card_played = true
	
	# If this was triggered by end turn, complete the turn now
	if end_turn_after_discard:
		end_turn_after_discard = false
		complete_turn()

func battle_phase():
	print("Entering battle phase")
	game_instructions.text = "Battle phase"
	
	action_selection_menu.hide()
	discarded_cards.show()
	
	# Check if all player cryptids have completed their turns
	var all_completed = true
	for cryptid in tile_map_layer.all_cryptids_in_play:
		if cryptid.cryptid.completed_turn == false:
			all_completed = false
			break
	
	if all_completed:
		# Enemy turn logic would go here
		# ...
		
		# After enemy turn, reset all turns and start a new round
		reset_all_cryptid_turns()
		transition(GameState.PLAYER_TURN)
		hand.show()
	
func reset_all_cryptid_turns():
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		cryptid_in_play.cryptid.completed_turn = false
		cryptid_in_play.cryptid.top_card_played = false
		cryptid_in_play.cryptid.bottom_card_played = false
		
		# Reset all card action values
		tile_map_layer.reset_card_action_values(cryptid_in_play.cryptid)
		
		# Make sure cards in discard pile have the correct state
		for card in cryptid_in_play.cryptid.discard:
			card.current_state = Card.CardState.IN_DISCARD
			
		# Make sure cards in deck have the correct state
		for card in cryptid_in_play.cryptid.deck:
			if card.current_state != Card.CardState.IN_DISCARD:
				card.current_state = Card.CardState.IN_DECK
