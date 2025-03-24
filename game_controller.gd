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
@onready var enemy_ai_controller = %EnemyAIController

var discard_mode = false
var discard_count_needed = 0
var end_turn_after_discard = false
var current_round = 1

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
	
	# Explicitly prompt for action to ensure menu is visible
	await get_tree().create_timer(0.2).timeout
	action_selection_menu.prompt_player_for_action()

func transition(next_state: GameState):
	match current_state:
		GameState.PLAYER_TURN:
			start_player_turn()
		GameState.ENEMY_TURN:
			start_enemy_turn()
		# Handle other states (GAMEOVER, VICTORY)
	
	current_state = next_state

func start_player_turn():
	print("Starting player turn")
	
	# Display the action selection menu
	action_selection_menu.prompt_player_for_action()
	
	# Explicitly ensure the menu is visible with the right buttons
	action_selection_menu.show()
	
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
			# This is now the only way to advance to the next cryptid
			advance_to_next_cryptid()
		action_selection_menu.ActionType.BATTLE_PHASE:
			battle_phase()

# Also update the advance_to_next_cryptid function to properly set up the next cryptid
func advance_to_next_cryptid():
	print("Advancing to next cryptid")
	
	# First, ensure the current cryptid's turn is properly ended
	end_current_turn()
	
	# The end_current_turn function will handle any necessary discards
	# If it returns early for discard, we should not proceed with advancing
	
	# Check if we're in discard mode
	if discard_mode:
		print("In discard mode, not advancing to next cryptid yet")
		return
	
	# After that, we manually advance to the next cryptid
	var next_cryptid = find_next_cryptid()
	
	if next_cryptid:
		# Set up the next cryptid's turn
		setup_cryptid_turn(next_cryptid)
	else:
		# If no more cryptids to process, trigger battle phase
		battle_phase()

# Function to find the next cryptid that hasn't completed their turn
func find_next_cryptid():
	# Get the current cryptid
	var current_cryptid = hand.selected_cryptid
	if not current_cryptid:
		print("ERROR: No current cryptid selected")
		return null
	
	# Find the index of the current cryptid in all_cryptids_in_play
	var current_index = -1
	for i in range(tile_map_layer.all_cryptids_in_play.size()):
		if tile_map_layer.all_cryptids_in_play[i].cryptid == current_cryptid:
			current_index = i
			break
	
	if current_index == -1:
		print("ERROR: Current cryptid not found in all_cryptids_in_play")
		return null
	
	# Find the next cryptid that hasn't completed their turn
	var checked_count = 0
	var next_index = (current_index + 1) % tile_map_layer.all_cryptids_in_play.size()
	
	while checked_count < tile_map_layer.all_cryptids_in_play.size():
		var candidate = tile_map_layer.all_cryptids_in_play[next_index].cryptid
		
		if not candidate.completed_turn:
			return candidate
			
		# Move to the next index, wrapping around if necessary
		next_index = (next_index + 1) % tile_map_layer.all_cryptids_in_play.size()
		checked_count += 1
	
	# If we've checked all cryptids and found none, return null
	return null

# Update the setup_cryptid_turn function to properly clear and rebuild the hand
func setup_cryptid_turn(cryptid):
	print("Setting up turn for cryptid:", cryptid.name)
	
	# Current cryptid is no longer selected
	if hand.selected_cryptid:
		hand.selected_cryptid.currently_selected = false
	
	# Set the new cryptid as selected
	hand.selected_cryptid = cryptid
	cryptid.currently_selected = true
	
	# Reset card action values for the newly selected cryptid
	if tile_map_layer:
		tile_map_layer.reset_card_action_values(cryptid)
	
	# Check if this is an enemy cryptid
	var is_enemy = false
	var enemy_cryptid_node = null
	for enemy_cryptid in tile_map_layer.enemy_cryptids_in_play:
		if enemy_cryptid.cryptid == cryptid:
			is_enemy = true
			enemy_cryptid_node = enemy_cryptid
			break
	
	# Clear the hand before switching to prevent holding old cards
	hand.clear_hand()
	
	if is_enemy:
		print("Enemy cryptid's turn: ", cryptid.name)
		# Trigger the enemy AI
		tile_map_layer.reset_for_new_cryptid()
		enemy_ai_controller.take_enemy_turn(enemy_cryptid_node)
	else:
		print("Player cryptid's turn: ", cryptid.name)
		# Regular player turn setup
		tile_map_layer.reset_for_new_cryptid()
		
		# Update the UI
		hand.switch_cryptid_deck(cryptid)
		game_instructions.text = "Now controlling: " + cryptid.name
		
		# Show the action menu for the new cryptid
		action_selection_menu.prompt_player_for_action()

# Update prompt_swap_cryptid function to update menu
func prompt_swap_cryptid():
	print("Prompting player to swap cryptid")
	game_instructions.text = "Select a cryptid to swap to"
	
	# Mark top and bottom card played to prevent confusion
	if hand.selected_cryptid:
		hand.selected_cryptid.top_card_played = true
		hand.selected_cryptid.bottom_card_played = true
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()


# Update perform_rest function to properly update menu state
func perform_rest():
	print("Player is resting")
	game_instructions.text = "Player is resting"
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		# Mark both top and bottom actions as used to prevent soft-locks
		hand.selected_cryptid.top_card_played = true
		hand.selected_cryptid.bottom_card_played = true
		hand.selected_cryptid.completed_turn = true
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()
	
	# Refresh the cards in hand for clarity
	hand.rest_action()



# Update prompt_catch_cryptid function to update menu
func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	game_instructions.text = "Select a cryptid to catch"
	
	# Mark top and bottom card played to prevent confusion
	if hand.selected_cryptid:
		hand.selected_cryptid.top_card_played = true
		hand.selected_cryptid.bottom_card_played = true
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()
	
# Fix the end_current_turn function to properly check if discard is needed
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
		print("Checking if discard needed for", current_cryptid.name)
		print("top_card_played =", current_cryptid.top_card_played, ", bottom_card_played =", current_cryptid.bottom_card_played)
		
		if !current_cryptid.top_card_played or !current_cryptid.bottom_card_played:
			# Calculate how many cards need to be discarded
			discard_count_needed = 0
			if !current_cryptid.top_card_played:
				discard_count_needed += 1
				print("Top action not used, need to discard", discard_count_needed, "card(s)")
			if !current_cryptid.bottom_card_played:
				discard_count_needed += 1
				print("Bottom action not used, need to discard", discard_count_needed, "card(s)")
			
			if discard_count_needed > 0:
				print("Starting discard phase, need to discard", discard_count_needed, "card(s)")
				
				# Enter discard mode
				discard_mode = true
				end_turn_after_discard = true
				
				# Update instruction text
				game_instructions.text = "Select " + str(discard_count_needed) + " card(s) to discard"
				
				# Start discard mode in the hand
				hand.start_discard_mode(discard_count_needed)
				
				# Show the discard confirmation button
				action_selection_menu.show_discard_confirmation(true)
				
				return  # Return early, will complete turn after discard
			else:
				print("No cards need to be discarded")
		else:
			print("Both card actions were used, no discard needed")
		
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

# that doesn't automatically advance to the next cryptid
func complete_turn():
	var current_cryptid = hand.selected_cryptid
	
	# Mark current cryptid's turn as completed
	if current_cryptid:
		current_cryptid.completed_turn = true
		current_cryptid.currently_selected = true  # Keep it selected
	
	# Check if all cryptids have completed their turns
	if not tile_map_layer.any_cryptid_not_completed():
		battle_phase()
	else:
		# Do NOT move to the next cryptid's turn automatically
		# Just update the UI to reflect the current state
		# The player must press End Turn to proceed
		
		# Update the UI to show the current cryptid's hand
		if hand.selected_cryptid:
			hand.switch_cryptid_deck(hand.selected_cryptid)
			game_instructions.text = "Turn complete. Press End Turn to continue."
		
		# Show the action menu with only the End Turn button
		action_selection_menu.show_end_turn_only()

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
		
		# Mark the cryptid's turn as completed - this is important!
		current_cryptid.completed_turn = true
		
		print("Cryptid turn completed after discard, advancing to next cryptid")
	
	# Reset discard-related flags
	end_turn_after_discard = false
	discard_count_needed = 0
	
	# Advanced to the next cryptid
	advance_to_next_cryptid_after_discard()

# Function specifically for advancing after discard to avoid recursive issues
func advance_to_next_cryptid_after_discard():
	print("Advancing to next cryptid after discard")
	
	# After discard, we manually advance to the next cryptid
	var next_cryptid = find_next_cryptid()
	
	if next_cryptid:
		# Set up the next cryptid's turn
		setup_cryptid_turn(next_cryptid)
	else:
		# If no more cryptids to process, trigger battle phase
		battle_phase()

# Then replace the battle_phase function with this corrected version:
func battle_phase():
	print("Entering battle phase")
	
	game_instructions.text = "Round " + str(current_round) + " complete!"
	
	action_selection_menu.hide()
	discarded_cards.show()
	
	# Check if all player cryptids have completed their turns
	var all_completed = true
	for cryptid in tile_map_layer.all_cryptids_in_play:
		if cryptid.cryptid.completed_turn == false:
			all_completed = false
			break
	
	if all_completed:
		# Process the end of round
		process_end_of_round()
		
		# Increment the round
		current_round += 1
		
		# Show the round button
		action_selection_menu.show_round_button(current_round)
		
		# Wait for player to click the round button to continue
		game_instructions.text = "Click 'Start Round " + str(current_round) + "' to continue"
	else:
		# Not all cryptids have completed their turns
		game_instructions.text = "Not all cryptids have completed their turns"
		action_selection_menu.prompt_player_for_action()

# Make sure process_end_of_round is also defined:
func process_end_of_round():
	# Reset all cryptid turns
	reset_all_cryptid_turns()
	
	# This is where you would add any end of round effects or scoring
	print("Processing end of round " + str(current_round))
	
	# Here you could add code for:
	# - Adding score points
	# - Applying end of round damage or healing
	# - Spawning new cryptids or items
	# - Anything else that happens at round end
	
	# For now, just transition to a new round state
	current_state = GameState.PLAYER_TURN
	hand.show()

	
# Modified reset_all_cryptid_turns function
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


