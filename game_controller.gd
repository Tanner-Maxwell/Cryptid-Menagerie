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
@onready var swap_dialog = %SwapCryptidDialog
@export var swap_cryptid_slot_scene: PackedScene

# Add this static class variable to ensure defeated cryptids are tracked globally
static var globally_defeated_cryptids = []

var defeated_cryptids = []
var emergency_swap_cryptid = null
var discard_mode = false
var discard_count_needed = 0
var end_turn_after_discard = false
var current_round = 1
var is_trainer_battle: bool = false  # Default to wild battle
var catch_dialog: PanelContainer = null


enum BattleState {
	PLAYER_TURN,
	ENEMY_TURN,
	GAMEOVER,
	VICTORY
}

@onready var current_state: BattleState = BattleState.PLAYER_TURN

func _ready():
	# Start with the player's turn when the game begins
	transition(BattleState.PLAYER_TURN)
	# Connect buttons to the respective functions
	swap_button.connect("pressed", Callable(self, "_on_swap_button_pressed"))
	rest_button.connect("pressed", Callable(self, "_on_rest_button_pressed"))
	catch_button.connect("pressed", Callable(self, "_on_catch_button_pressed"))
	#end_turn_button.connect("pressed", Callable(self, "_on_end_turn_button_pressed"))
	# Explicitly prompt for action to ensure menu is visible
	await get_tree().create_timer(0.2).timeout
	if Engine.has_singleton("DefeatedCryptidsTracker"):
		var tracker = Engine.get_singleton("DefeatedCryptidsTracker")
		defeated_cryptids = tracker.get_defeated_list()
		print("Loaded defeated_cryptids from global tracker:", defeated_cryptids)
	else:
		print("Initialized new defeated_cryptids list:", defeated_cryptids)
	
	catch_button.connect("pressed", Callable(self, "_on_catch_pressed"))
	
	initialize_catch_dialog()
	#catch_dialog = preload("res://path_to_catch_dialog.tscn").instantiate()
	#get_node("/root/VitaChrome/UIRoot").add_child(catch_dialog)
	#catch_dialog.hide()  # Hide until needed
	# Add this to your _ready function in game_controller.gd
	var test_button = Button.new()
	test_button.text = "Test Catch Dialog"
	test_button.position = Vector2(100, 100)
	test_button.connect("pressed", Callable(self, "_on_test_button_pressed"))
	get_node("/root/VitaChrome/UIRoot").add_child(test_button)
	
	
# Add this to the bottom of the file, make it accessible via a keystroke
func _input(event):
	# Press F8 to test emergency swap
	if event is InputEventKey and event.keycode == KEY_F8 and event.pressed:
		print("F8 pressed, testing emergency swap")
		test_emergency_swap()

func transition(next_state: BattleState):
	match current_state:
		BattleState.PLAYER_TURN:
			start_player_turn()
		BattleState.ENEMY_TURN:
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
	# But we need to be careful - when a cryptid is swapped in, it should already have both
	# card actions marked as used, so it shouldn't trigger discard
	var current_cryptid = hand.selected_cryptid
	if current_cryptid:
		# Mark the current cryptid's turn as completed if not already
		current_cryptid.completed_turn = true
		
		# Only call end_current_turn if both actions aren't already used
		# This prevents unnecessary discard prompts for swapped cryptids
		if !current_cryptid.top_card_played or !current_cryptid.bottom_card_played:
			end_current_turn()
			
			# If end_current_turn started discard mode, we should return early
			if discard_mode:
				print("In discard mode, not advancing to next cryptid yet")
				return
	
	tile_map_layer.verify_grid_state()
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

func setup_cryptid_turn(cryptid):
	print("Setting up turn for cryptid:", cryptid.name)
	
	# Before switching cryptids, verify card states for current cryptid
	if hand.selected_cryptid:
		verify_cryptid_card_states(hand.selected_cryptid)
	
	# Current cryptid is no longer selected
	if hand.selected_cryptid:
		hand.selected_cryptid.currently_selected = false
	
	# Set the new cryptid as selected
	hand.selected_cryptid = cryptid
	cryptid.currently_selected = true
	
	# Verify card states for the new cryptid
	verify_cryptid_card_states(cryptid)
	
	# Reset card action values for the newly selected cryptid
	if tile_map_layer:
		tile_map_layer.reset_card_action_values(cryptid)
	
	# Clear the hand before switching to prevent holding old cards
	hand.clear_hand()
	
	# If the cryptid has already completed its turn, we should
	# advance to the next cryptid based on the sorted order
	if cryptid.completed_turn:
		print("Cryptid", cryptid.name, "has already completed its turn, finding next cryptid...")
		
		# Find the next cryptid that hasn't completed its turn
		var next_cryptid = find_next_cryptid_in_order()
		
		if next_cryptid:
			print("Found next available cryptid:", next_cryptid.name)
			# Call setup_cryptid_turn for the next cryptid
			# Use call_deferred to avoid recursion issues
			call_deferred("setup_cryptid_turn", next_cryptid)
		else:
			print("No more cryptids available this round, entering battle phase")
			# Call battle phase if all cryptids have taken their turn
			call_deferred("battle_phase")
			
		return
	
	# Check if this is an enemy cryptid
	var is_enemy = false
	var enemy_cryptid_node = null
	for enemy_cryptid in tile_map_layer.enemy_cryptids_in_play:
		if enemy_cryptid.cryptid == cryptid:
			is_enemy = true
			enemy_cryptid_node = enemy_cryptid
			break
	
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

# Add this new helper function to verify card states
func verify_cryptid_card_states(cryptid):
	print("Verifying card states for", cryptid.name)
	
	# Track counts for reporting
	var fixed_deck_cards = 0
	var fixed_discard_cards = 0
	
	# First check deck cards
	for card in cryptid.deck:
		# Check if card is in discard pile
		var in_discard = false
		for discard_card in cryptid.discard:
			if discard_card == card:
				in_discard = true
				break
		
		# If card is in discard pile, it should be marked as IN_DISCARD
		if in_discard:
			if card.current_state != Card.CardState.IN_DISCARD:
				print("Found card in discard pile with wrong state - fixing")
				card.current_state = Card.CardState.IN_DISCARD
				fixed_discard_cards += 1
		# If card is NOT in discard pile, it should be marked as IN_DECK
		else:
			if card.current_state != Card.CardState.IN_DECK:
				print("Found card not in discard with wrong state - fixing")
				card.current_state = Card.CardState.IN_DECK
				fixed_deck_cards += 1
	
	# Report results
	if fixed_deck_cards > 0 or fixed_discard_cards > 0:
		print("Fixed card states:", fixed_deck_cards, "deck cards,", fixed_discard_cards, "discard cards")
	else:
		print("All card states verified correct")
		
func _on_swap_cryptid_selected(new_cryptid):
	print("Swapping to cryptid: ", new_cryptid.name)
	
	# Get the current cryptid and its node in the scene
	var current_cryptid = hand.selected_cryptid
	var current_cryptid_node = null
	
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if cryptid_node.cryptid == current_cryptid:
			current_cryptid_node = cryptid_node
			break
	
	if not current_cryptid_node:
		print("ERROR: Could not find current cryptid node")
		return
	
	# Get the position of the current cryptid
	var cryptid_position = current_cryptid_node.position
	var cryptid_map_pos = tile_map_layer.local_to_map(cryptid_position)
	
	# We'll disable this position at the end, after the new cryptid is placed
	var point = tile_map_layer.a_star_hex_grid.get_closest_point(cryptid_map_pos, true)
	
	# IMPORTANT: Save the current cryptid's health before removing it
	var health_bar = current_cryptid_node.get_node_or_null("HealthBar")
	if health_bar:
		print("Preserving health for " + current_cryptid.name + ": " + 
			  str(health_bar.value) + "/" + str(health_bar.max_value))
		
		# ALWAYS use metadata for health tracking for consistency
		current_cryptid.set_meta("current_health", health_bar.value)
		print("Set current_health metadata to " + str(current_cryptid.get_meta("current_health")))
	
	# Create a new cryptid node with the selected cryptid data
	var new_cryptid_node = tile_map_layer.blank_cryptid.instantiate()
	new_cryptid_node.cryptid = new_cryptid
	new_cryptid_node.hand = hand
	new_cryptid_node.position = cryptid_position
	
	# Mark the new cryptid's turn as completed
	new_cryptid.completed_turn = true
	new_cryptid.top_card_played = true
	new_cryptid.bottom_card_played = true
	
	# IMPORTANT: Use the cryptid's stored health if available
	var current_health = 0  # Start with 0, will be set properly below
	var max_health = new_cryptid.health
	
	# Check for metadata FIRST as our standard health storage method
	if new_cryptid.has_meta("current_health"):
		current_health = new_cryptid.get_meta("current_health")
		print("Found stored health metadata for " + new_cryptid.name + ": " + str(current_health))
	# Fallback to property for backward compatibility
	elif new_cryptid.get("current_health") != null:
		current_health = new_cryptid.current_health
		print("Found stored health property for " + new_cryptid.name + ": " + str(current_health))
		# Also set metadata for consistency going forward
		new_cryptid.set_meta("current_health", current_health)
	else:
		# If no health data found, use maximum health
		current_health = max_health
		print("No stored health found for " + new_cryptid.name + ", using max health: " + str(current_health))
		new_cryptid.set_meta("current_health", current_health)
	
	# CRITICAL: Now set health values to the stored value, not max health
	print("Setting health values to:", current_health, "/", max_health)
	new_cryptid_node.set_health_values(current_health, max_health)
	new_cryptid_node.update_health_bar()
	
	# Remove the current cryptid from player_cryptids_in_play
	var index = tile_map_layer.player_cryptids_in_play.find(current_cryptid_node)
	if index != -1:
		tile_map_layer.player_cryptids_in_play.remove_at(index)
	
	# Also remove from all_cryptids_in_play
	index = tile_map_layer.all_cryptids_in_play.find(current_cryptid_node)
	if index != -1:
		tile_map_layer.all_cryptids_in_play.remove_at(index)
	
	# Add the new cryptid to player_cryptids_in_play
	tile_map_layer.player_cryptids_in_play.append(new_cryptid_node)
	
	# Add to all_cryptids_in_play
	tile_map_layer.all_cryptids_in_play.append(new_cryptid_node)
	
	# Add the new cryptid to the scene tree
	tile_map_layer.get_node("PlayerTeam").add_child(new_cryptid_node)
	
	# Remove the old cryptid node (which also removes it from the scene tree)
	current_cryptid_node.queue_free()
	
	# Update the selected cryptid in the hand
	hand.selected_cryptid = new_cryptid
	hand.switch_cryptid_deck(new_cryptid)
	
	# Update the turn order display
	turn_order.initialize_cryptid_labels()
	
	# Update game instructions
	game_instructions.text = current_cryptid.name + " swapped out for " + new_cryptid.name
	
	# CRITICAL: Make sure the position is still marked as disabled
	# This is necessary because the old cryptid is gone but the new one
	# occupies the same position on the grid
	tile_map_layer.a_star_hex_grid.set_point_disabled(point, true)
	print("Ensuring position", cryptid_map_pos, "remains disabled after swap")
	
	# For debugging, check if it's actually disabled
	if !tile_map_layer.a_star_hex_grid.is_point_disabled(point):
		print("WARNING: Failed to disable position after swap, trying again")
		tile_map_layer.a_star_hex_grid.set_point_disabled(point, true)
	
	# End the current turn and advance to the next cryptid
	# We're bypassing the end_current_turn check for discards here
	# by directly calling advance_to_next_cryptid
	advance_to_next_cryptid()

# Update perform_rest function to properly update menu state
func perform_rest():
	print("Player is resting")
	game_instructions.text = "Player is resting - recovering cards from discard..."
	
	# Mark current cryptid's turn as completed
	if hand.selected_cryptid:
		# Mark both top and bottom actions as used to prevent soft-locks
		hand.selected_cryptid.top_card_played = true
		hand.selected_cryptid.bottom_card_played = true
		hand.selected_cryptid.completed_turn = true
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()
	
	# Refresh the cards in hand for clarity - adding debug output
	print("Before rest action - Discard count:", 
		  hand.selected_cryptid.discard.size() if hand.selected_cryptid else "No cryptid")
	
	# Call the proper rest action to recover cards
	hand.rest_action()
	
	print("After rest action - Discard count:", 
		  hand.selected_cryptid.discard.size() if hand.selected_cryptid else "No cryptid")
	print("After rest action - Deck/Hand count:", 
		  hand.get_child_count() - 1 if hand else "No hand")  # -1 for non-card children



# Update prompt_catch_cryptid function to update menu
func prompt_catch_cryptid():
	print("Prompting player to catch a cryptid")
	
	# Can't catch in trainer battles
	if is_trainer_battle:
		game_instructions.text = "You can't catch cryptids in trainer battles!"
		action_selection_menu.prompt_player_for_action()
		return
	
	# Check if there's only one enemy left
	if tile_map_layer.enemy_cryptids_in_play.size() != 1:
		game_instructions.text = "You can only catch the last remaining enemy cryptid!"
		action_selection_menu.prompt_player_for_action()
		return
	
	# Get the target cryptid
	var target_cryptid = tile_map_layer.enemy_cryptids_in_play[0]
	
	# Mark top and bottom card played to prevent confusion
	if hand.selected_cryptid:
		hand.selected_cryptid.top_card_played = true
		hand.selected_cryptid.bottom_card_played = true
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()
	
	# Calculate catch probability based on health
	var catch_chance = calculate_catch_probability(target_cryptid)
	
	# Attempt to catch
	var catch_successful = attempt_catch(target_cryptid, catch_chance)
	
	if catch_successful:
		handle_successful_catch(target_cryptid)
	else:
		handle_failed_catch(target_cryptid)
	
# Fix the end_current_turn function to properly check if discard is needed
func end_current_turn():
	print("Ending current cryptid's turn")
	
	# First check if there's an active movement that needs to be finished
	if tile_map_layer and tile_map_layer.move_action_bool and tile_map_layer.move_leftover > 0:
		print("Finishing active movement before ending turn")
		tile_map_layer.finish_movement()
	
	# Verify the grid state to ensure all hexes are correctly enabled/disabled
	tile_map_layer.verify_grid_state()
	
	# Get the current cryptid
	var current_cryptid = hand.selected_cryptid
	
	if current_cryptid:
		# Check if both card parts have been played
		print("Checking if discard needed for", current_cryptid.name)
		print("top_card_played =", current_cryptid.top_card_played, ", bottom_card_played =", current_cryptid.bottom_card_played)
		
		# IMPORTANT FIX: If both card actions are marked as played (such as after a swap),
		# we should skip the discard logic entirely and proceed directly to complete_turn
		if current_cryptid.top_card_played and current_cryptid.bottom_card_played:
			print("Both card actions were used, no discard needed")
			complete_turn()
			return
		
		# If we get here, at least one card action wasn't used and may need discard
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
	
	# Verify the grid state
	tile_map_layer.verify_grid_state()
	
	
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

func process_end_of_round():
	# Reset all cryptid turns
	reset_all_cryptid_turns()
	
	# This is where you would add any end of round effects or scoring
	print("Processing end of round " + str(current_round))
	
	# Use the existing sort function in tile_map_layer
	print("BEFORE SORTING - Cryptid order:")
	action_selection_menu.log_cryptid_order()
	
	# Sort cryptids by speed
	tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
	
	# Verify sorting worked by logging the sorted order
	print("AFTER SORTING - Cryptid order:")
	action_selection_menu.log_cryptid_order()
	
	# Update turn order display to reflect the new sort order
	if turn_order:
		turn_order.initialize_cryptid_labels()
	
	# Transition to a new round state
	current_state = BattleState.PLAYER_TURN
	hand.show()
	

	
# Modified reset_all_cryptid_turns function
func reset_all_cryptid_turns():
	print("Resetting turns for ALL cryptids")
	
	# Process all cryptids in play
	for cryptid_in_play in tile_map_layer.all_cryptids_in_play:
		var cryptid = cryptid_in_play.cryptid
		
		print("Resetting turn for cryptid:", cryptid.name)
		
		# CRITICAL: Reset the turn completion flag to false
		cryptid.completed_turn = false
		cryptid.top_card_played = false
		cryptid.bottom_card_played = false
		
		# Reset card action values
		tile_map_layer.reset_card_action_values(cryptid)
		
		# Check if this is a player cryptid (by checking if it's in player_cryptids_in_play)
		var is_player = false
		for player_cryptid_node in tile_map_layer.player_cryptids_in_play:
			if player_cryptid_node.cryptid == cryptid:
				is_player = true
				break
		
		# If this is a player cryptid, restore cards from discard to deck
		if is_player:
			restore_cards_from_discard(cryptid)
		
		# Verify all cards are in the correct state
		verify_card_states(cryptid)
	
	# Update turn order display
	if turn_order:
		turn_order.initialize_cryptid_labels()


func prompt_emergency_swap(defeated_cryptid):
	print("Prompting emergency swap for defeated cryptid:", defeated_cryptid.cryptid.name)
	game_instructions.text = "Your cryptid was defeated! Select a replacement."
	
	# Store the defeated cryptid for reference
	emergency_swap_cryptid = defeated_cryptid
	
	# Find the swap dialog
	var swap_dialog_node = get_node_or_null("SwapCryptidDialog")
	if not swap_dialog_node:
		swap_dialog_node = get_node_or_null("/root/VitaChrome/UIRoot/SwapCryptidDialog")
	if not swap_dialog_node:
		swap_dialog_node = get_node_or_null("/root/VitaChrome/SwapCryptidDialog")
	
	if not swap_dialog_node:
		print("ERROR: Could not find SwapCryptidDialog!")
		game_instructions.text = "Error: Swap dialog not found!"
		
		# If we can't find the dialog, just remove the cryptid
		tile_map_layer.remove_defeated_cryptid(defeated_cryptid)
		return
	
	# Create a filtered team for the swap dialog
	var filtered_team = Team.new()
	
	# Get all cryptids from GameState
	var all_cryptids = []
	if GameState.player_team:
		if GameState.player_team.has_method("get_cryptids"):
			all_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			all_cryptids = GameState.player_team._content
			
		print("Found", all_cryptids.size(), "cryptids in GameState")
	
	# Get names of cryptids in play
	var in_play_names = []
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if cryptid_node.cryptid and cryptid_node.cryptid != defeated_cryptid.cryptid:
			in_play_names.append(cryptid_node.cryptid.name)
			print("- In play:", cryptid_node.cryptid.name)
	
	# Add only bench cryptids to filtered team
	for cryptid in all_cryptids:
		if cryptid == null:
			continue
			
		# Skip the defeated cryptid
		if cryptid == defeated_cryptid.cryptid:
			print("EXCLUDING defeated cryptid from options:", cryptid.name)
			continue
			
		# Skip if already in play
		if cryptid.name in in_play_names:
			print("EXCLUDING in-play cryptid from options:", cryptid.name)
			continue
			
		# Add this cryptid to options
		filtered_team.add_cryptid(cryptid)
		print("Added to swap options:", cryptid.name)
	
	# Check if we have any cryptids left
	if filtered_team.get_cryptids().size() == 0:
		print("No cryptids available for emergency swap!")
		game_instructions.text = "No cryptids available for swap. Battle lost!"
		
		# Just remove the defeated cryptid
		tile_map_layer.remove_defeated_cryptid(defeated_cryptid)
		check_game_over_condition()
		return
	
	# We need to adapt our list of "in play" cryptids to exclude the defeated one
	var cryptids_in_play_except_defeated = []
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if cryptid_node != defeated_cryptid:
			cryptids_in_play_except_defeated.append(cryptid_node)
	
	# Open the swap dialog with emergency mode
	print("Opening emergency swap dialog with", filtered_team.get_cryptids().size(), "cryptids")
	
	swap_dialog_node.set_title("EMERGENCY: Select replacement cryptid") 
	swap_dialog_node.open(filtered_team, defeated_cryptid.cryptid, cryptids_in_play_except_defeated)
	
	# Connect to the dialog's signal for emergency swap
	if swap_dialog_node.is_connected("cryptid_selected", Callable(self, "_on_emergency_swap_selected")):
		swap_dialog_node.disconnect("cryptid_selected", Callable(self, "_on_emergency_swap_selected"))
	swap_dialog_node.connect("cryptid_selected", Callable(self, "_on_emergency_swap_selected"))

func _on_emergency_swap_selected(new_cryptid):
	print("Emergency swap selected:", new_cryptid.name)
	
	if not emergency_swap_cryptid:
		print("ERROR: No emergency swap cryptid found!")
		return
	
	# Get the position of the defeated cryptid
	var defeated_position = emergency_swap_cryptid.get_meta("defeated_position")
	var defeated_map_pos = emergency_swap_cryptid.get_meta("defeated_map_pos")
	
	print("Placing new cryptid at position:", defeated_map_pos)
	
	# Get the point for the position, we'll disable it again after placing the new cryptid
	var defeated_point = tile_map_layer.a_star_hex_grid.get_closest_point(defeated_map_pos, true)
	
	# Make sure the hex position is available for the new cryptid
	tile_map_layer.a_star_hex_grid.set_point_disabled(defeated_point, false)
	
	# Create a new cryptid node with the selected cryptid data
	var emergency_cryptid_node = tile_map_layer.blank_cryptid.instantiate()
	emergency_cryptid_node.cryptid = new_cryptid
	emergency_cryptid_node.hand = hand
	emergency_cryptid_node.position = defeated_position
	
	# The new cryptid should NOT act in the current turn
	new_cryptid.completed_turn = true
	new_cryptid.top_card_played = true
	new_cryptid.bottom_card_played = true
	
	# IMPORTANT: Use the cryptid's stored health if available
	var swap_current_health = 0
	var swap_max_health = new_cryptid.health
	
	# Check stored health using metadata FIRST
	if new_cryptid.has_meta("current_health"):
		swap_current_health = new_cryptid.get_meta("current_health")
		print("Using stored health metadata for " + new_cryptid.name + ": " + str(swap_current_health))
	# Fallback to property for backward compatibility
	elif new_cryptid.get("current_health") != null:
		swap_current_health = new_cryptid.current_health
		print("Using stored health property for " + new_cryptid.name + ": " + str(swap_current_health))
		# Also set metadata for consistency going forward
		new_cryptid.set_meta("current_health", swap_current_health)
	else:
		# If no health data found, use maximum health
		swap_current_health = swap_max_health
		print("No stored health found for " + new_cryptid.name + ", using max health: " + str(swap_current_health))
		new_cryptid.set_meta("current_health", swap_current_health)
	
	# Set health values to the stored value, not max health
	print("Setting health values to:", swap_current_health, "/", swap_max_health)
	emergency_cryptid_node.set_health_values(swap_current_health, swap_max_health)
	emergency_cryptid_node.update_health_bar()
	
	# Actually remove the defeated cryptid now
	tile_map_layer.remove_defeated_cryptid(emergency_swap_cryptid)
	emergency_swap_cryptid = null
	
	# Add the new cryptid to player_cryptids_in_play
	tile_map_layer.player_cryptids_in_play.append(emergency_cryptid_node)
	
	# Add to all_cryptids_in_play
	tile_map_layer.all_cryptids_in_play.append(emergency_cryptid_node)
	
	# Add the new cryptid to the scene tree
	tile_map_layer.get_node("PlayerTeam").add_child(emergency_cryptid_node)
	
	# Update the selected cryptid in the hand
	hand.selected_cryptid = new_cryptid
	hand.switch_cryptid_deck(new_cryptid)
	
	# Update the turn order display
	turn_order.initialize_cryptid_labels()
	
	# Update game instructions
	game_instructions.text = "Emergency swap complete! " + new_cryptid.name + " has joined the battle!"
	
	# CRITICAL: Disable the position again now that it's occupied by the new cryptid
	tile_map_layer.a_star_hex_grid.set_point_disabled(defeated_point, true)
	print("Ensuring position", defeated_map_pos, "is disabled after emergency swap")
	
	# For debugging, check if it's actually disabled
	if !tile_map_layer.a_star_hex_grid.is_point_disabled(defeated_point):
		print("WARNING: Failed to disable position after emergency swap, trying again")
		tile_map_layer.a_star_hex_grid.set_point_disabled(defeated_point, true)
	
	# Show some visual effect for the new cryptid
	# Create a flash effect
	var flash_color = Color(0, 1, 0, 0.5)  # Green flash
	emergency_cryptid_node.modulate = flash_color
	var tween = get_tree().create_tween()
	tween.tween_property(emergency_cryptid_node, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Advance to the next cryptid's turn
	advance_to_next_cryptid()
	
# Emergency test function - you can call this directly for testing
func test_emergency_swap():
	print("Testing emergency swap feature...")
	
	# Get the first player cryptid
	if tile_map_layer.player_cryptids_in_play.size() > 0:
		var test_cryptid = tile_map_layer.player_cryptids_in_play[0]
		print("Using test cryptid: " + test_cryptid.cryptid.name)
		
		# Store position data on the cryptid
		test_cryptid.set_meta("defeated_position", test_cryptid.position)
		test_cryptid.set_meta("defeated_map_pos", tile_map_layer.local_to_map(test_cryptid.position))
		
		# Apply emergency visual effect
		test_cryptid.modulate = Color(1, 0, 0, 0.5)  # Red fade
		
		# Trigger emergency swap
		prompt_emergency_swap(test_cryptid)
	else:
		print("ERROR: No player cryptids available for test!")

func emergency_swap_for_defeated_cryptid(defeated_cryptid):
	print("Prompting emergency swap for defeated cryptid:", defeated_cryptid.name)
	
	# CRITICAL: First, add the defeated cryptid to the defeated_cryptids lists
	if !defeated_cryptids.has(defeated_cryptid.name):
		defeated_cryptids.append(defeated_cryptid.name)
		print("ADDED to defeated_cryptids list:", defeated_cryptid.name)
	
	# Also add to the global static list for double-safety
	if !GameController.globally_defeated_cryptids.has(defeated_cryptid.name):
		GameController.globally_defeated_cryptids.append(defeated_cryptid.name)
		print("ADDED to global defeated list:", defeated_cryptid.name)
	
	# Create a temporary team with only available cryptids
	var temp_team = Team.new()
	
	# Process all player team cryptids for potential swap options
	var player_team_node = get_node_or_null("/root/VitaChrome/TileMapLayer/PlayerTeam")
	if player_team_node:
		# First add only non-defeated cryptids as swap options
		for child in player_team_node.get_children():
			if !child.has_property("cryptid") or !child.cryptid:
				continue
				
			# Skip the defeated cryptid
			if child.cryptid.name == defeated_cryptid.name:
				print("EXCLUDING defeated cryptid from options:", child.cryptid.name)
				continue
				
			# Also skip any cryptid in the defeated lists
			if defeated_cryptids.has(child.cryptid.name) or GameController.globally_defeated_cryptids.has(child.cryptid.name):
				print("EXCLUDING defeated cryptid from options:", child.cryptid.name)
				continue
				
			# Add to swap options
			temp_team.add_cryptid(child.cryptid)
			print("Adding cryptid to filtered team:", child.cryptid.name)
	
	# Add a few extra cryptids for dev/testing (if needed)
	if tile_map_layer.player_cryptids_in_play.size() > 0 && temp_team.get_cryptids().size() < 3:
		var first_cryptid = null
		
		# Find a non-defeated cryptid to use as template
		for cryptid_node in tile_map_layer.player_cryptids_in_play:
			if cryptid_node.cryptid and cryptid_node.cryptid.name != defeated_cryptid.name and !defeated_cryptids.has(cryptid_node.cryptid.name) and !GameController.globally_defeated_cryptids.has(cryptid_node.cryptid.name):
				first_cryptid = cryptid_node.cryptid
				break
		
		if first_cryptid:
			for i in range(1, 4):
				var new_name = "Backup " + first_cryptid.name + " " + str(i)
				
				# Skip if already in defeated lists
				if defeated_cryptids.has(new_name) or GameController.globally_defeated_cryptids.has(new_name):
					continue
					
				var new_cryptid = Cryptid.new()
				new_cryptid.name = new_name
				new_cryptid.scene = first_cryptid.scene
				new_cryptid.icon = first_cryptid.icon
				new_cryptid.health = 10  # Give it full health
				
				# Copy the deck
				for card in first_cryptid.deck:
					new_cryptid.deck.append(card.duplicate())
				
				temp_team.add_cryptid(new_cryptid)
				print("Adding extra cryptid to filtered team:", new_cryptid.name)
	
	print("Opening emergency swap dialog with", temp_team.get_cryptids().size(), "cryptids")
	
	# Find the swap dialog
	var swap_dialog_node = get_node_or_null("SwapCryptidDialog")
	if not swap_dialog_node:
		swap_dialog_node = get_node_or_null("/root/VitaChrome/UIRoot/SwapCryptidDialog")
	if not swap_dialog_node:
		swap_dialog_node = get_node_or_null("/root/VitaChrome/SwapCryptidDialog")
	
	if not swap_dialog_node:
		print("ERROR: Could not find SwapCryptidDialog for emergency swap!")
		return
	
	# Connect to the dialog's signal if not already connected
	if not swap_dialog_node.is_connected("cryptid_selected", Callable(self, "_on_emergency_swap_cryptid_selected")):
		swap_dialog_node.connect("cryptid_selected", Callable(self, "_on_emergency_swap_cryptid_selected"))
	
	# Open the dialog with the temporary team
	swap_dialog_node.open(temp_team, defeated_cryptid, tile_map_layer.player_cryptids_in_play)

func _on_emergency_swap_cryptid_selected(new_cryptid):
	print("Selected cryptid:", new_cryptid.name)
	
	# Get the defeated cryptid's position
	var position = Vector2.ZERO
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if defeated_cryptids.has(cryptid_node.cryptid.name):
			position = cryptid_node.position
			break
	
	# Create a new cryptid node
	var new_cryptid_node = tile_map_layer.blank_cryptid.instantiate()
	new_cryptid_node.cryptid = new_cryptid
	new_cryptid_node.hand = hand
	new_cryptid_node.position = position
	
	# Set cryptid state - CRITICAL FIX HERE
	# Mark both top and bottom card actions as used
	# This prevents the discard logic from triggering
	new_cryptid.completed_turn = true
	new_cryptid.top_card_played = true
	new_cryptid.bottom_card_played = true
	new_cryptid.currently_selected = true
	
	# Set health values
	new_cryptid_node.set_health_values(new_cryptid.health, new_cryptid.health)
	new_cryptid_node.update_health_bar()
	
	# Remove the defeated cryptid from player_cryptids_in_play
	for i in range(tile_map_layer.player_cryptids_in_play.size()-1, -1, -1):
		if defeated_cryptids.has(tile_map_layer.player_cryptids_in_play[i].cryptid.name):
			tile_map_layer.player_cryptids_in_play.remove_at(i)
	
	# Also remove from all_cryptids_in_play
	for i in range(tile_map_layer.all_cryptids_in_play.size()-1, -1, -1):
		if tile_map_layer.all_cryptids_in_play[i].cryptid and defeated_cryptids.has(tile_map_layer.all_cryptids_in_play[i].cryptid.name):
			tile_map_layer.all_cryptids_in_play.remove_at(i)
	
	# Add the new cryptid to player_cryptids_in_play
	tile_map_layer.player_cryptids_in_play.append(new_cryptid_node)
	
	# Add to all_cryptids_in_play
	tile_map_layer.all_cryptids_in_play.append(new_cryptid_node)
	
	# Add the new cryptid to the scene tree
	tile_map_layer.get_node("PlayerTeam").add_child(new_cryptid_node)
	
	# Update the selected cryptid in the hand
	hand.selected_cryptid = new_cryptid
	hand.switch_cryptid_deck(new_cryptid)
	
	# Update the turn order display
	turn_order.initialize_cryptid_labels()
	
	# After swapping cryptids, advance to the next cryptid's turn
	# This is the key addition - don't stay on the swapped-in cryptid's turn
	advance_to_next_cryptid()

func mark_cryptid_defeated(cryptid_name):
	if !defeated_cryptids.has(cryptid_name):
		defeated_cryptids.append(cryptid_name)
		print("MARKED AS PERMANENTLY DEFEATED:", cryptid_name)
		
		# Update the persistent tracker if it exists
		if Engine.has_singleton("DefeatedCryptidsTracker"):
			var tracker = Engine.get_singleton("DefeatedCryptidsTracker")
			tracker.add_defeated(cryptid_name)
		
		# Add to the static globally_defeated_cryptids list
		if !GameController.globally_defeated_cryptids.has(cryptid_name):
			GameController.globally_defeated_cryptids.append(cryptid_name)
			print("Added to global static list:", cryptid_name)
		
		# Also update SwapCryptidDialog's static list
		var swap_dialog = get_node_or_null("/root/VitaChrome/UIRoot/SwapCryptidDialog")
		if swap_dialog and "all_defeated_cryptids" in swap_dialog:
			if !swap_dialog.all_defeated_cryptids.has(cryptid_name):
				swap_dialog.all_defeated_cryptids.append(cryptid_name)
				print("Added to swap dialog static list:", cryptid_name)
		
		# CRITICAL FIX: Remove the cryptid from the player team directly
		var player_team_node = get_node_or_null("/root/VitaChrome/TileMapLayer/PlayerTeam")
		if player_team_node:
			if player_team_node.has_method("get_cryptids") and player_team_node.has_method("remove_cryptid"):
				# First find the cryptid object by name
				var cryptids = player_team_node.get_cryptids()
				for cryptid in cryptids:
					if cryptid.name == cryptid_name:
						print("REMOVING CRYPTID FROM PLAYER TEAM:", cryptid_name)
						player_team_node.remove_cryptid(cryptid)
						break
			elif player_team_node.get("_content") != null:
				# Direct access to _content array
				var cryptids = player_team_node._content
				for i in range(cryptids.size() - 1, -1, -1):
					if cryptids[i].name == cryptid_name:
						print("REMOVING CRYPTID FROM PLAYER TEAM _content:", cryptid_name)
						cryptids.remove_at(i)
						break
			
			# Also check if there's a cryptidTeam property
			if player_team_node.get("cryptidTeam") != null:
				var team = player_team_node.cryptidTeam
				if team.has_method("get_cryptids") and team.has_method("remove_cryptid"):
					var cryptids = team.get_cryptids()
					for cryptid in cryptids:
						if cryptid.name == cryptid_name:
							print("REMOVING CRYPTID FROM cryptidTeam:", cryptid_name)
							team.remove_cryptid(cryptid)
							break
				elif team.get("_content") != null:
					var cryptids = team._content
					for i in range(cryptids.size() - 1, -1, -1):
						if cryptids[i].name == cryptid_name:
							print("REMOVING CRYPTID FROM cryptidTeam _content:", cryptid_name)
							cryptids.remove_at(i)
							break
		
		# Also check for any standalone Player node
		var player = get_node_or_null("/root/VitaChrome/Player")
		if player and player.get("cryptidTeam") != null:
			var team = player.cryptidTeam
			if team.has_method("get_cryptids") and team.has_method("remove_cryptid"):
				var cryptids = team.get_cryptids()
				for cryptid in cryptids:
					if cryptid.name == cryptid_name:
						print("REMOVING CRYPTID FROM Player's cryptidTeam:", cryptid_name)
						team.remove_cryptid(cryptid)
						break
			elif team.get("_content") != null:
				var cryptids = team._content
				for i in range(cryptids.size() - 1, -1, -1):
					if cryptids[i].name == cryptid_name:
						print("REMOVING CRYPTID FROM Player's cryptidTeam _content:", cryptid_name)
						cryptids.remove_at(i)
						break
	else:
		print("Cryptid already marked as defeated:", cryptid_name)
	
	# Print the current list for debugging
	print("Current defeated cryptids list:", defeated_cryptids)

func find_and_setup_next_cryptid():
	var next_cryptid = find_next_cryptid()
	
	if next_cryptid:
		# Set up the next cryptid's turn
		setup_cryptid_turn(next_cryptid)
	else:
		# If no more cryptids to process, trigger battle phase
		battle_phase()

func prompt_swap_cryptid():
	print("Prompting player to swap cryptid")
	
	# CRITICAL: First check if we have any bench cryptids available
	if !has_bench_cryptids():
		print("No bench cryptids available - preventing swap")
		game_instructions.text = "No cryptids available for swap!"
		action_selection_menu.prompt_player_for_action()
		return
	
	game_instructions.text = "Select a cryptid to swap to"
	
	# Find the swap dialog
	var swap_dialog_node = get_node_or_null("/root/VitaChrome/UIRoot/SwapCryptidDialog")
	if not swap_dialog_node:
		print("ERROR: Could not find SwapCryptidDialog!")
		game_instructions.text = "Error: Swap dialog not found!"
		action_selection_menu.prompt_player_for_action()
		return
	
	# Get the tile_map_layer reference
	var tile_map_layer = get_node_or_null("/root/VitaChrome/TileMapLayer")
	if !tile_map_layer:
		print("ERROR: TileMapLayer not found!")
		game_instructions.text = "Error: TileMapLayer not found!"
		action_selection_menu.prompt_player_for_action()
		return
	
	# Track the current cryptid being swapped from
	var current_cryptid = hand.selected_cryptid
	
	# Mark cryptid as having used its actions
	if current_cryptid:
		current_cryptid.top_card_played = true
		current_cryptid.bottom_card_played = true
	
		# Create a filtered team for the swap dialog containing only bench cryptids
		var filtered_team = Team.new()
		
		# Get all cryptids from GameState
		var all_cryptids = []
		if GameState.player_team:
			if GameState.player_team.has_method("get_cryptids"):
				all_cryptids = GameState.player_team.get_cryptids()
			elif "_content" in GameState.player_team:
				all_cryptids = GameState.player_team._content
				
			print("Found", all_cryptids.size(), "cryptids in GameState")
		
		# Get names of cryptids in play
		var in_play_names = []
		for cryptid_node in tile_map_layer.player_cryptids_in_play:
			if cryptid_node.cryptid and cryptid_node != tile_map_layer.selected_cryptid:
				in_play_names.append(cryptid_node.cryptid.name)
				print("- In play:", cryptid_node.cryptid.name)
		
		# Add only bench cryptids to filtered team
		for cryptid in all_cryptids:
			if not cryptid.name in in_play_names or cryptid == current_cryptid:
				filtered_team.add_cryptid(cryptid)
				print("Added to swap options:", cryptid.name)
		
		# Open the swap dialog with the filtered team
		swap_dialog_node.open(filtered_team, current_cryptid, tile_map_layer.player_cryptids_in_play)
		
		# Connect to the dialog's signal if not already connected
		if not swap_dialog_node.is_connected("cryptid_selected", Callable(self, "_on_swap_cryptid_selected")):
			swap_dialog_node.connect("cryptid_selected", Callable(self, "_on_swap_cryptid_selected"))
		
		# Update the UI to show only end turn button
		action_selection_menu.show_end_turn_only()
	else:
		print("ERROR: No selected cryptid found")
		game_instructions.text = "Error: No selected cryptid!"
		action_selection_menu.prompt_player_for_action()

# Add the helper function to check if bench cryptids are available
func has_bench_cryptids():
	print("Checking for bench cryptids...")
	
	# Get the tile_map_layer reference
	var tile_map_layer = get_node_or_null("/root/VitaChrome/TileMapLayer")
	if !tile_map_layer:
		print("TileMapLayer not found!")
		return false
	
	# Get total cryptids from GameState
	var all_cryptids = []
	if GameState.player_team:
		if GameState.player_team.has_method("get_cryptids"):
			all_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			all_cryptids = GameState.player_team._content
		
		print("Total cryptids in GameState:", all_cryptids.size())
		for cryptid in all_cryptids:
			print("- Team cryptid:", cryptid.name)
	else:
		print("No player team in GameState")
		return false
	
	# Get cryptids currently in play
	var in_play_cryptids = []
	for cryptid_node in tile_map_layer.player_cryptids_in_play:
		if cryptid_node and cryptid_node.cryptid:
			in_play_cryptids.append(cryptid_node.cryptid)
			print("- In play:", cryptid_node.cryptid.name)
	
	# Find bench cryptids by name comparison (safer than object comparison)
	var bench_cryptids = []
	for team_cryptid in all_cryptids:
		var is_in_play = false
		for play_cryptid in in_play_cryptids:
			if team_cryptid.name == play_cryptid.name:
				is_in_play = true
				break
		
		if !is_in_play:
			bench_cryptids.append(team_cryptid)
			print("- Found bench cryptid:", team_cryptid.name)
	
	print("Total bench cryptids:", bench_cryptids.size())
	return bench_cryptids.size() > 0
		
func restore_cards_from_discard(cryptid: Cryptid):
	print("Restoring cards from discard for:", cryptid.name)
	
	# Check if there are any cards in discard
	if cryptid.discard.size() == 0:
		print("No cards in discard pile")
		return
	
	print("Moving", cryptid.discard.size(), "cards from discard to deck")
	
	# Move all cards from discard back to deck state
	for card in cryptid.discard:
		# Update the card state
		card.current_state = Card.CardState.IN_DECK
		print("Restored card to deck:", card)
	
	# Clear the discard pile - cards are already in deck array
	var cards_restored = cryptid.discard.size()
	cryptid.discard.clear()
	
	print("Restored", cards_restored, "cards to deck")

# Helper function to verify card states
func verify_card_states(cryptid: Cryptid):
	print("Verifying card states for", cryptid.name)
	
	# First check deck cards
	for card in cryptid.deck:
		# Check if card is in discard pile
		var in_discard = cryptid.discard.has(card)
		
		# If card is in discard pile, it should be marked as IN_DISCARD
		if in_discard:
			if card.current_state != Card.CardState.IN_DISCARD:
				print("Found card in discard pile with wrong state - fixing")
				card.current_state = Card.CardState.IN_DISCARD
		# If card is NOT in discard pile, it should be marked as IN_DECK
		else:
			if card.current_state != Card.CardState.IN_DECK:
				print("Found card not in discard with wrong state - fixing")
				card.current_state = Card.CardState.IN_DECK
	
	print("Card verification complete for", cryptid.name)

func find_next_cryptid_in_order():
	# Find the index of the current cryptid
	var current_index = -1
	for i in range(tile_map_layer.all_cryptids_in_play.size()):
		if tile_map_layer.all_cryptids_in_play[i].cryptid == hand.selected_cryptid:
			current_index = i
			break
	
	if current_index == -1:
		print("ERROR: Current cryptid not found in all_cryptids_in_play")
		return null
	
	# Start from the next index and look for a cryptid that hasn't completed its turn
	for i in range(1, tile_map_layer.all_cryptids_in_play.size()):
		var next_index = (current_index + i) % tile_map_layer.all_cryptids_in_play.size()
		var next_cryptid = tile_map_layer.all_cryptids_in_play[next_index].cryptid
		
		if not next_cryptid.completed_turn:
			return next_cryptid
	
	# If we get here, all cryptids have completed their turns
	return null

func _on_catch_pressed():
	prompt_catch_cryptid()

# Calculate catch probability based on health percentage
func calculate_catch_probability(target_cryptid):
	# Get health values
	var health_bar = target_cryptid.get_node("HealthBar")
	if not health_bar:
		return 0.5  # Default if no health bar found
	
	var current_health = health_bar.value
	var max_health = health_bar.max_value
	
	# Calculate health percentage
	var health_percentage = float(current_health) / max_health
	
	# Calculate catch probability: 50% at full health, 100% near 0 health
	var catch_probability = 1.0 - (health_percentage * 0.5)
	
	print("Cryptid health: ", current_health, "/", max_health, " (", health_percentage * 100, "%)")
	print("Calculated catch probability: ", catch_probability * 100, "%")
	
	return catch_probability

# Attempt to catch the cryptid based on probability
func attempt_catch(target_cryptid, catch_probability):
	# Generate a random number between 0 and 1
	var random_value = randf()
	
	# FOR TESTING: Force catch to succeed
	var is_successful = true  # Change this to force success
	
	# Normal code (commented out during testing)
	# var is_successful = random_value < catch_probability
	
	print("Catch attempt: random value = ", random_value, ", needed <= ", catch_probability)
	print("Catch ", "successful" if is_successful else "failed")
	
	return is_successful

# Handle a successful catch
func handle_successful_catch(target_cryptid):
	print("Successfully caught " + target_cryptid.cryptid.name + "!")
	game_instructions.text = "You caught " + target_cryptid.cryptid.name + "!"
	
	# Create a duplicate of the cryptid to add to player's team
	var caught_cryptid = target_cryptid.cryptid.duplicate()
	print("Created duplicate of caught cryptid:", caught_cryptid.name)
	
	# Store current health and other state in the cryptid
	preserve_cryptid_state(target_cryptid)
	
	# Add directly to GameState player team
	if GameState.player_team:
		if GameState.player_team.has_method("add_cryptid"):
			GameState.player_team.add_cryptid(caught_cryptid)
			print("DIRECT ADD: Added " + caught_cryptid.name + " to player team")
		elif "_content" in GameState.player_team:
			# Direct array access as fallback
			GameState.player_team._content.append(caught_cryptid)
			print("DIRECT ADD via _content: Added " + caught_cryptid.name + " to player team")
	else:
		print("ERROR: GameState.player_team is null")
		GameState.player_team = Team.new()
		GameState.player_team.add_cryptid(caught_cryptid)
		print("Created new team and added " + caught_cryptid.name)
	
	# Debug team after adding
	if GameState:
		GameState.debug_player_team()
	
	# Check if there's space in the team
	var has_space = true
	if GameState.player_team && GameState.player_team.has_method("has_space"):
		has_space = GameState.player_team.has_space()
	
	# If there's space, we're done
	if has_space:
		# Remove the caught cryptid from the enemy team
		remove_cryptid_from_enemy_team(target_cryptid)
		
		# End battle (since this was the last enemy)
		end_battle_with_victory()
	else:
		# Otherwise, open the replacement dialog
		prompt_replace_cryptid(caught_cryptid, target_cryptid)
	
	# Disable input to prevent actions during catch process
	set_process_input(false)
	
	# Play a success animation/effect
	animate_catch_success(target_cryptid)

func handle_failed_catch(target_cryptid):
	print("Failed to catch ", target_cryptid.cryptid.name)
	game_instructions.text = "The cryptid broke free!"
	
	# Update UI to show the end turn button
	action_selection_menu.show_end_turn_only()
	
	# Play a failure animation/effect
	animate_catch_failure(target_cryptid)
	
# Add cryptid directly to player team
func add_cryptid_to_team(cryptid):
	var player_team_node = get_node("/root/VitaChrome/TileMapLayer/PlayerTeam")
	if player_team_node:
		if player_team_node.has_method("add_cryptid"):
			player_team_node.add_cryptid(cryptid)
		elif player_team_node.get("cryptidTeam") != null:
			var team = player_team_node.cryptidTeam
			if team.has_method("add_cryptid"):
				team.add_cryptid(cryptid)
	
	print(cryptid.name, " added to player's team")

# Show dialog to replace an existing cryptid
func prompt_replace_cryptid(new_cryptid, original_cryptid_node):
	print("Team is full - showing replacement dialog")
	
	# Make sure catch dialog is initialized
	initialize_catch_dialog()
	
	if catch_dialog:
		# Build the player's team
		var player_team_node = get_node("/root/VitaChrome/TileMapLayer/PlayerTeam")
		var player_team = Team.new()
		
		if player_team_node:
			if player_team_node.has_method("get_cryptids"):
				var cryptids = player_team_node.get_cryptids()
				for cryptid in cryptids:
					player_team.add_cryptid(cryptid)
			elif player_team_node.get("_content") != null:
				for cryptid in player_team_node._content:
					player_team.add_cryptid(cryptid)
			elif player_team_node.get("cryptidTeam") != null:
				var team = player_team_node.cryptidTeam
				if team.has_method("get_cryptids"):
					var cryptids = team.get_cryptids()
					for cryptid in cryptids:
						player_team.add_cryptid(cryptid)
		
		# Store reference to original cryptid node for later
		catch_dialog.set_meta("original_cryptid_node", original_cryptid_node)
		
		# Open the dialog
		if catch_dialog.is_connected("cryptid_selected", Callable(self, "_on_replace_cryptid_selected")):
			catch_dialog.disconnect("cryptid_selected", Callable(self, "_on_replace_cryptid_selected"))
		catch_dialog.connect("cryptid_selected", Callable(self, "_on_replace_cryptid_selected"))
		catch_dialog.open(player_team, new_cryptid, tile_map_layer.player_cryptids_in_play)
		catch_dialog.show()
	else:
		print("ERROR: Could not find or create catch dialog")
		
		# Fall back to direct team add and end battle
		add_cryptid_to_team(new_cryptid)
		remove_cryptid_from_enemy_team(original_cryptid_node)
		end_battle_with_victory()

# Handle cryptid replacement selection
func _on_replace_cryptid_selected(replaced_cryptid, new_cryptid):
	print("Replacing ", replaced_cryptid.name, " with ", new_cryptid.name)
	
	# Make sure we're modifying the actual team in GameState
	if GameState.player_team:
		# First, remove the selected cryptid from the team
		print("Removing", replaced_cryptid.name, "from team")
		if GameState.player_team.has_method("remove_cryptid"):
			GameState.player_team.remove_cryptid(replaced_cryptid)
		else:
			print("ERROR: player_team doesn't have remove_cryptid method")
			
			# Fallback: try to remove directly from _content if available
			if "_content" in GameState.player_team:
				var index = -1
				for i in range(GameState.player_team._content.size()):
					if GameState.player_team._content[i] == replaced_cryptid:
						index = i
						break
				
				if index >= 0:
					GameState.player_team._content.remove_at(index)
					print("Manually removed cryptid from team._content")
		
		# Then add the new cryptid
		print("Adding", new_cryptid.name, "to team")
		if GameState.player_team.has_method("add_cryptid"):
			GameState.player_team.add_cryptid(new_cryptid)
		else:
			print("ERROR: player_team doesn't have add_cryptid method")
			
			# Fallback: try to add directly to _content if available
			if "_content" in GameState.player_team:
				GameState.player_team._content.append(new_cryptid)
				print("Manually added cryptid to team._content")
		
		# Debug: verify team contents
		var team_cryptids = []
		if GameState.player_team.has_method("get_cryptids"):
			team_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			team_cryptids = GameState.player_team._content
			
		print("Team now contains", team_cryptids.size(), "cryptids:")
		for cryptid in team_cryptids:
			print("- ", cryptid.name)
	else:
		print("ERROR: GameState.player_team is null - cannot update team")
		
		# Try to initialize the team if it doesn't exist
		GameState.player_team = Team.new()
		if GameState.player_team:
			print("Created new team in GameState")
			GameState.player_team.add_cryptid(new_cryptid)
			print("Added", new_cryptid.name, "to newly created team")
	
	# Clean up the catch dialog signal connection
	if catch_dialog and catch_dialog.is_connected("cryptid_selected", Callable(self, "_on_replace_cryptid_selected")):
		catch_dialog.disconnect("cryptid_selected", Callable(self, "_on_replace_cryptid_selected"))
	
	if GameState:
		GameState.debug_player_team()
	
	# End battle with victory
	end_battle_with_victory()

# Call this when all enemy cryptids are defeated/caught
func end_battle_with_victory():
	print("Victory! Battle has ended.")
	game_instructions.text = "Victory! Battle has ended."
	
	# Get the battle scene (parent of this script)
	var battle_scene = get_tree().current_scene
	
	# Call the end_battle function to return to the overworld
	if battle_scene and battle_scene.has_method("end_battle"):
		print("Calling end_battle on battle scene")
		battle_scene.end_battle(true)  # true means victory
	else:
		print("WARNING: Could not find battle scene's end_battle method")
		
		# Fallback - create a button to return to map
		var continue_button = Button.new()
		continue_button.text = "Return to Map"
		continue_button.custom_minimum_size = Vector2(150, 50)
		continue_button.position = Vector2(get_viewport_rect().size.x / 2 - 75, get_viewport_rect().size.y * 0.8)
		continue_button.connect("pressed", Callable(self, "_on_return_to_map_pressed"))
		get_node("/root/VitaChrome/UIRoot").add_child(continue_button)
	
# Return to map button handler
func _on_return_to_map():
	get_tree().change_scene_to_file("res://Cryptid-Menagerie/scenes/overworld_map.tscn")

func initialize_catch_dialog():
	# Only initialize once
	if catch_dialog != null:
		return
		
	# Try to find an existing dialog first
	catch_dialog = get_node_or_null("/root/VitaChrome/UIRoot/CatchDialog")
	
	if catch_dialog == null:
		# Try other paths
		catch_dialog = get_node_or_null("../UIRoot/CatchDialog")
	
	if catch_dialog == null:
		# Search entire scene tree if needed
		var dialogs = get_tree().get_nodes_in_group("catch_dialog")
		if dialogs.size() > 0:
			catch_dialog = dialogs[0]
	
	# Only instantiate if not found (you can comment this out if you added it to the scene)
	if catch_dialog == null:
		var catch_dialog_scene = load("res://catch_dialog.tscn")
		if catch_dialog_scene:
			catch_dialog = catch_dialog_scene.instantiate()
			get_node("/root/VitaChrome/UIRoot").add_child(catch_dialog)
			print("Initialized catch dialog")
		else:
			print("ERROR: Could not load catch dialog scene")
	else:
		print("Found existing catch dialog")
		
	# Ensure it starts hidden
	if catch_dialog:
		catch_dialog.hide()

func preserve_cryptid_state(cryptid_node):
	var health_bar = cryptid_node.get_node("HealthBar")
	if health_bar:
		var current_health = health_bar.value
		var max_health = health_bar.max_value
		
		# Store health using metadata for consistency
		cryptid_node.cryptid.set_meta("current_health", current_health)
		print("Preserved cryptid health:", current_health, "/", max_health)

func animate_catch_success(target_cryptid):
	# Create a flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 0, 0.7)  # Bright yellow, semitransparent
	flash.size = Vector2(2000, 2000)  # Make it large to cover the screen
	flash.position = Vector2(-1000, -1000)  # Center it
	flash.z_index = 100  # Make sure it appears above everything
	get_node("/root/VitaChrome").add_child(flash)
	
	# Create a tween to fade out the flash
	var tween = create_tween()
	tween.tween_property(flash, "color", Color(1, 1, 0, 0), 1.0)
	tween.tween_callback(Callable(flash, "queue_free"))
	
	# Add a short delay for the effect to be visible
	await get_tree().create_timer(1.2).timeout
	
	# Re-enable input
	set_process_input(true)

# Create catch failure animation
func animate_catch_failure(target_cryptid):
	# Create a flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.5)  # Red, semitransparent
	flash.size = Vector2(2000, 2000)  # Make it large to cover the screen
	flash.position = Vector2(-1000, -1000)  # Center it
	flash.z_index = 100  # Make sure it appears above everything
	get_node("/root/VitaChrome").add_child(flash)
	
	# Create a tween to fade out the flash
	var tween = create_tween()
	tween.tween_property(flash, "color", Color(1, 0, 0, 0), 0.5)
	tween.tween_callback(Callable(flash, "queue_free"))
	
	# Add a short delay for the effect to be visible
	await get_tree().create_timer(0.6).timeout


# Remove the cryptid from the enemy team
func remove_cryptid_from_enemy_team(cryptid_node):
	# Remove from enemy_cryptids_in_play
	if cryptid_node in tile_map_layer.enemy_cryptids_in_play:
		tile_map_layer.enemy_cryptids_in_play.erase(cryptid_node)
	
	# Remove from all_cryptids_in_play
	if cryptid_node in tile_map_layer.all_cryptids_in_play:
		tile_map_layer.all_cryptids_in_play.erase(cryptid_node)
	
	# Make its position walkable again
	var map_pos = tile_map_layer.local_to_map(cryptid_node.position)
	if not map_pos in tile_map_layer.walkable_hexes:
		tile_map_layer.walkable_hexes.append(map_pos)
	
	# Remove visual node from scene tree
	cryptid_node.queue_free()

# Add a continue button to return to the overworld/next scene
func add_continue_button():
	# Create a button
	var continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 50)
	
	# Position it in the center bottom of the screen
	continue_button.anchor_left = 0.5
	continue_button.anchor_top = 0.9
	continue_button.anchor_right = 0.5
	continue_button.anchor_bottom = 0.9
	continue_button.offset_left = -75
	continue_button.offset_top = -25
	continue_button.offset_right = 75
	continue_button.offset_bottom = 25
	
	# Connect its pressed signal
	continue_button.connect("pressed", Callable(self, "_on_continue_button_pressed"))
	
	# Add it to the UI
	get_node("/root/VitaChrome/UIRoot").add_child(continue_button)

# Handle continue button press
func _on_continue_button_pressed():
	# Hide the button
	get_node("/root/VitaChrome/UIRoot/Button").queue_free()
	
	# Implement transition to next scene or overworld
	# This would depend on your game's structure
	game_instructions.text = "Returning to overworld..."
	
	# For now, just reset the battle state
	reset_all_cryptid_turns()
	
	# Show action menu again
	action_selection_menu.show()
	action_selection_menu.prompt_player_for_action()

func _on_test_button_pressed():
	# Create a test cryptid
	var test_cryptid = Cryptid.new()
	test_cryptid.name = "Test Caught Cryptid"
	
	# Show the dialog directly
	initialize_catch_dialog()
	
	if catch_dialog:
		var player_team_node = get_node("/root/VitaChrome/TileMapLayer/PlayerTeam")
		var player_team = null
		
		if player_team_node:
			if player_team_node.has_method("get_cryptids"):
				player_team = player_team_node
		
		if player_team:
			catch_dialog.open(player_team, test_cryptid, tile_map_layer.player_cryptids_in_play)
			catch_dialog.show()
			print("TEST: Showed catch dialog directly")
		else:
			print("TEST: Failed to get player team")
	else:
		print("TEST: Failed to initialize catch dialog")


# Add this fallback function
func _on_return_to_map_pressed():
	get_tree().change_scene_to_file("res://Cryptid-Menagerie/scenes/overworld_map.tscn")

func check_game_over_condition():
	print("Checking if all player cryptids are defeated...")
	
	# Get the player team
	var player_team_alive = false
	
	# First check GameState.player_team
	if GameState.player_team:
		var all_cryptids = []
		
		# Get all cryptids in the player's team
		if GameState.player_team.has_method("get_cryptids"):
			all_cryptids = GameState.player_team.get_cryptids()
		elif "_content" in GameState.player_team:
			all_cryptids = GameState.player_team._content
			
		print("Found", all_cryptids.size(), "total cryptids in player team")
		
		# Check if any cryptid is not in the defeated lists
		for cryptid in all_cryptids:
			# Skip null entries
			if cryptid == null:
				continue
				
			# Check against all sources of defeated cryptids
			var is_defeated = false
			
			# Check the defeated_cryptids list
			if defeated_cryptids.has(cryptid.name):
				print("Cryptid", cryptid.name, "is in defeated_cryptids list")
				is_defeated = true
			
			# Check globally_defeated_cryptids list
			if globally_defeated_cryptids.has(cryptid.name):
				print("Cryptid", cryptid.name, "is in globally_defeated_cryptids list")
				is_defeated = true
				
			# Check DefeatedCryptidsTracker
			if Engine.has_singleton("DefeatedCryptidsTracker"):
				var tracker = Engine.get_singleton("DefeatedCryptidsTracker")
				if tracker.is_defeated(cryptid.name):
					print("Cryptid", cryptid.name, "is in DefeatedCryptidsTracker")
					is_defeated = true
			
			# If at least one cryptid is not defeated, the team is still alive
			if not is_defeated:
				print("Found living cryptid:", cryptid.name)
				player_team_alive = true
				break
	
	# If no living cryptids found, trigger game over
	if not player_team_alive:
		print("All player cryptids are defeated! GAME OVER")
		trigger_game_over()
		return true
	else:
		print("Player team still has living cryptids")
		return false

func trigger_game_over():
	print("GAME OVER! All cryptids defeated!")
	
	# Update game instructions
	game_instructions.text = "GAME OVER! All cryptids have been defeated!"
	
	# Wait a moment
	await get_tree().create_timer(2.0).timeout
	
	# Change to game over scene
	get_tree().change_scene_to_file("res://game_over.tscn")

func show_game_over_message():
	# Create a game over panel
	var game_over_panel = PanelContainer.new()
	game_over_panel.custom_minimum_size = Vector2(600, 200)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vbox)
	
	# Add game over text
	var game_over_label = Label.new()
	game_over_label.text = "DEFEAT"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	vbox.add_child(game_over_label)
	
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator)
	
	var details_label = Label.new()
	details_label.text = "All your cryptids have been defeated!"
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(details_label)
	
	var separator2 = HSeparator.new()
	separator2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator2)
	
	# Add continue button
	var continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(200, 50)
	continue_button.connect("pressed", Callable(self, "_on_game_over_continue_pressed"))
	vbox.add_child(continue_button)
	
	# Center the panel
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -300
	game_over_panel.offset_top = -100
	game_over_panel.offset_right = 300
	game_over_panel.offset_bottom = 100
	
	# Add to UI
	get_node("/root/VitaChrome/UIRoot").add_child(game_over_panel)
	
	# Hide other UI elements
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		action_menu.hide()

func _on_game_over_continue_pressed():
	# Load the game over scene
	get_tree().change_scene_to_file("res://Cryptid-Menagerie/scenes/game_over_scene.tscn")
