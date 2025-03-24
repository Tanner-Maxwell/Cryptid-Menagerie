# Updated action_select_menu.gd
extends Control

# Signal to notify the selected action type
signal action_selected(action_type: int)

# Enum for the action types
enum ActionType { SWAP, REST, CATCH, BATTLE_PHASE, END_TURN }

@onready var hand = %Hand
@onready var tile_map_layer = %TileMapLayer

# Direct references to buttons for more reliable access
@onready var swap_button = $VBoxContainer/SwapButton
@onready var rest_button = $VBoxContainer/RestButton
@onready var catch_button = $VBoxContainer/CatchButton
@onready var end_turn_button = $VBoxContainer/EndTurnButton
@onready var confirm_discard_button = $VBoxContainer/DiscardButton
@onready var round_button = $VBoxContainer/RoundButton

# Add a new variable to track the current round
var current_round = 1

func _ready():
	# Wait for the scene to be fully initialized before trying to get references
	await get_tree().process_frame
	
	# Ensure our @onready variables are properly set, or find them manually
	if not swap_button:
		swap_button = get_node_or_null("VBoxContainer/SwapButton")
	if not rest_button:
		rest_button = get_node_or_null("VBoxContainer/RestButton")
	if not catch_button:
		catch_button = get_node_or_null("VBoxContainer/CatchButton")
	if not end_turn_button:
		end_turn_button = get_node_or_null("VBoxContainer/EndTurnButton")
	
	# Print button references to verify we have the correct paths
	print("Button references in action_select_menu:")
	print("  swap_button =", swap_button != null)
	print("  rest_button =", rest_button != null)
	print("  catch_button =", catch_button != null)
	print("  end_turn_button =", end_turn_button != null)
	
	# Exit early if we're missing critical references
	if not swap_button or not rest_button or not catch_button or not end_turn_button:
		print("ERROR: Critical button references missing, check node structure!")
		return
	
	# Connecting button signals to the respective functions
	swap_button.connect("pressed", Callable(self, "_on_swap_pressed"))
	rest_button.connect("pressed", Callable(self, "_on_rest_pressed"))
	catch_button.connect("pressed", Callable(self, "_on_catch_pressed"))
	end_turn_button.connect("pressed", Callable(self, "_on_end_turn_pressed"))
	
	# Initialize the round button if it doesn't exist
	round_button = get_node_or_null("VBoxContainer/RoundButton")
	if not round_button:
		var new_round_button = Button.new()
		new_round_button.name = "RoundButton"
		new_round_button.text = "Start Round 1"
		new_round_button.connect("pressed", Callable(self, "_on_round_button_pressed"))
		$VBoxContainer.add_child(new_round_button)
		round_button = new_round_button
	
	# Hide all buttons first
	if round_button:
		round_button.hide()
		
	if end_turn_button:
		end_turn_button.hide()
	
	# Start with only the basic action buttons visible
	if swap_button:
		swap_button.show()
	if rest_button:
		rest_button.show()
	if catch_button:
		catch_button.show()
	
	# Make sure the menu itself is visible
	show()

func update_menu_visibility(cryptid: Cryptid):
	if cryptid == null:
		print("ERROR: Null cryptid passed to update_menu_visibility")
		return
		
	print("Updating menu for cryptid: ", cryptid.name)
	print("top_card_played: ", cryptid.top_card_played, ", bottom_card_played: ", cryptid.bottom_card_played)
	
	# Check if we have valid button references first
	if not swap_button or not rest_button or not catch_button or not end_turn_button:
		print("ERROR: Button references missing, trying to find them")
		
		# Try to find the buttons
		swap_button = get_node_or_null("VBoxContainer/SwapButton")
		rest_button = get_node_or_null("VBoxContainer/RestButton")
		catch_button = get_node_or_null("VBoxContainer/CatchButton")
		end_turn_button = get_node_or_null("VBoxContainer/EndTurnButton")
		
		# If still missing, we can't proceed
		if not swap_button or not rest_button or not catch_button or not end_turn_button:
			print("ERROR: Critical button references still missing, can't update menu")
			return
	
	# Hide all buttons first
	hide_all_buttons()
	
	# Check if the cryptid has used ANY card action this turn (top OR bottom)
	# This is an important change - we now check if EITHER action is used
	if cryptid.top_card_played or cryptid.bottom_card_played:
		print("Card action used - showing only End Turn button")
		if end_turn_button:
			end_turn_button.show()
	else:
		print("No card action used - showing action buttons")
		if swap_button:
			swap_button.show()
		if rest_button:
			rest_button.show()
		if catch_button:
			catch_button.show()
		if end_turn_button:
			end_turn_button.show()
			
	# Always ensure the menu itself is visible
	show()

# And update prompt_player_for_action to be more defensive
func prompt_player_for_action():
	print("MENU: prompt_player_for_action called")
	
	# Ensure we're visible first
	show()
	
	# Hide all buttons first to get a clean slate
	hide_all_buttons()
	
	# Show the basic buttons if they exist
	if swap_button:
		swap_button.show()
	if rest_button:
		rest_button.show()
	if catch_button:
		catch_button.show()
	
	# Update button visibility based on current cryptid
	var selected_cryptid = null
	if hand and hand.has_method("switch_cryptid_deck"):
		selected_cryptid = hand.selected_cryptid
		if selected_cryptid:
			update_menu_visibility(selected_cryptid)
		else:
			print("ERROR: No selected_cryptid found in hand!")
	else:
		print("ERROR: hand reference invalid or missing switch_cryptid_deck method!")

# Function to explicitly force-update the menu state
func force_update():
	if hand and hand.selected_cryptid:
		update_menu_visibility(hand.selected_cryptid)
	
# Functions for each action button
func _on_swap_pressed():
	hide()
	emit_signal("action_selected", ActionType.SWAP)

func _on_rest_pressed():
	hide()
	emit_signal("action_selected", ActionType.REST)

func _on_catch_pressed():
	hide()
	emit_signal("action_selected", ActionType.CATCH)

func _on_end_turn_pressed():
	hide()
	emit_signal("action_selected", ActionType.END_TURN)

# New function for round button
func _on_round_button_pressed():
	hide()
	# This will trigger the battle phase or new round
	emit_signal("action_selected", ActionType.BATTLE_PHASE)

# Called when all player cryptids have completed their turns
func trigger_battle_phase():
	emit_signal("action_selected", ActionType.BATTLE_PHASE)

# Also update the hide_all_buttons function to be more defensive
func hide_all_buttons():
	for child in $VBoxContainer.get_children():
		if child is Button:  # Ensure we're only hiding buttons
			child.hide()

# Show the round button with appropriate round number
func show_round_button(round_number: int):
	hide_all_buttons()
	
	if round_button:
		round_button.text = "Start Round " + str(round_number)
		round_button.show()
	
	show()

# Update/replace the show_discard_confirmation function
func show_discard_confirmation(visible = true):
	# Hide all buttons
	hide_all_buttons()
	
	# Create confirm button if it doesn't exist
	if not confirm_discard_button:
		confirm_discard_button = Button.new()
		confirm_discard_button.text = "Confirm Discard"
		confirm_discard_button.name = "DiscardButton"
		$VBoxContainer.add_child(confirm_discard_button)
		
		# Connect to signal
		confirm_discard_button.connect("pressed", Callable(self, "_on_confirm_discard_pressed"))
	
	# Show or hide the button
	confirm_discard_button.visible = visible
	
	# Start with the button disabled until required cards are selected
	confirm_discard_button.disabled = true
	confirm_discard_button.modulate = Color(0.7, 0.7, 0.7, 1)
	
	# Make sure the menu itself is visible
	self.visible = visible

func _on_confirm_discard_pressed():
	print("Confirm discard button pressed")
	
	# Get the hand and game controller
	var hand = get_node_or_null("/root/VitaChrome/UIRoot/Hand")
	var game_controller = get_node_or_null("/root/VitaChrome/GameController")
	
	if hand and game_controller:
		# Get the selected cards from hand
		var selected_cards = hand.cards_to_discard.duplicate()
		
		# Verify we have enough cards
		if selected_cards.size() < hand.discard_count_required:
			print("ERROR: Not enough cards selected for discard. Need", 
				  hand.discard_count_required, "but only have", selected_cards.size())
			return
		
		print("Selected", selected_cards.size(), "cards for discard")
		
		# Reset discard mode in hand
		hand.in_discard_mode = false
		hand.cards_to_discard.clear()
		
		# Reset card visuals
		for card in hand.get_children():
			if card is CardDialog:
				card.modulate = Color(1, 1, 1, 1)
		
		# Hide the discard confirmation
		show_discard_confirmation(false)
		
		# Hide entire menu until next turn
		hide()
		
		# Notify the game controller to process the discard and advance turn
		game_controller.on_discard_complete(selected_cards)

# Add a function to show only the End Turn button
func show_end_turn_only():
	# Hide all buttons first
	hide_all_buttons()
	
	# Show only the End Turn button
	if end_turn_button:
		end_turn_button.show()
	
	# Make sure the menu is visible
	show()
