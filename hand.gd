extends Control

@export var hand_radius: int = 100
@export var card_angle: float = 0
@export var angle_limit: float = 25
@export var highlight_offset: float = 15
@export var max_card_spread_angle: float = 5
@export var current_highlighted_container = null
@onready var tile_map_layer = %TileMapLayer
@onready var cryptids_cards = %"Cryptids Cards"
@onready var discard_cards_node = %DiscardCards
@onready var enemy_ai = get_node("/root/VitaChrome/EnemyAIController")
@onready var selected_cryptid

var current_highlighted_card: CardDialog = null

# Variables to track discard state
var in_discard_mode = false
var cards_to_discard = []
var discard_count_required = 0
var confirm_button = null
var in_discard_selection_mode
var selected_for_discard
@onready var card_dialog = preload("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")

var hand: Array = []
var highlighted_cards: Array = []
var max_highlighted_cards = 2

var selected_top_card: CardDialog = null
var selected_bottom_card: CardDialog = null

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			clear_card_selections()

func _ready():
	selected_cryptid = tile_map_layer.player_cryptids_in_play[0].cryptid
	switch_cryptid_deck(selected_cryptid)

func add_card(card):
	hand.push_back(card)
	add_child(card)
	reposition_cards()

func remove_card(card):
	hand.erase(card)

func reposition_cards():
	var card_spread = min(angle_limit / hand.size(), max_card_spread_angle)
	var current_angle = 0
	if hand.size() > 1:	
		current_angle = -(card_spread * (hand.size()-1))/2 - 92
	else:
		current_angle = -(card_spread * (hand.size()-1))/2 - 90
	for card in hand:
		card_transform_update(card, current_angle)
		current_angle += card_spread
		pass

func get_card_position(angle: float) -> Vector2:
	var x: float = hand_radius * cos(deg_to_rad(angle))
	var y: float = hand_radius * sin(deg_to_rad(angle))
	
	return Vector2(x, y)

func card_transform_update(card, angle_in_drag: float):
	card.set_position(get_card_position(angle_in_drag))
	card.set_rotation(deg_to_rad(angle_in_drag + 90))
	if card in highlighted_cards:
		card.position.y -= highlight_offset

# Function to highlight the selected card
func highlight_card(new_card: CardDialog):
	if new_card in highlighted_cards:
		unhighlight_card(new_card)
		return

	# If two cards are already highlighted, don't allow selecting a third
	if highlighted_cards.size() < max_highlighted_cards:
		highlighted_cards.append(new_card)
		new_card.highlight()
		new_card.position.y -= highlight_offset
		new_card.z_index += 1

# Function to unhighlight the current card
func unhighlight_card(card: CardDialog):
	if card in highlighted_cards:
		highlighted_cards.erase(card)
		card.unhighlight()
		card.position.y += highlight_offset
		card.z_index -= 1

# Ensure no more than two cards are highlighted
func can_highlight_more() -> bool:
	return highlighted_cards.size() < max_highlighted_cards
	
func cards_selected(selected_cards: Array):
	print("DEBUG: cards_selected called with " + str(selected_cards.size()) + " cards")
	
	for cards_picked in selected_cards:
		print("DEBUG: Processing card: " + cards_picked.card_resource.to_string())
		
		# First check if we have an original card reference
		if cards_picked.card_resource.original_card != null:
			# Update the original card's state to IN_DISCARD
			cards_picked.card_resource.original_card.current_state = Card.CardState.IN_DISCARD
			print("DEBUG: Updated original card state to IN_DISCARD")
			
			# Make sure the original card is in the discard pile if not already there
			if not selected_cryptid.discard.has(cards_picked.card_resource.original_card):
				selected_cryptid.discard.push_back(cards_picked.card_resource.original_card)
				print("DEBUG: Added original card to discard")
		else:
			# If no original reference, update this card's state directly
			cards_picked.card_resource.current_state = Card.CardState.IN_DISCARD
			print("DEBUG: Updated direct card state to IN_DISCARD")
			
			# Make sure the card is in the discard pile if not already there
			if not selected_cryptid.discard.has(cards_picked.card_resource):
				selected_cryptid.discard.push_back(cards_picked.card_resource)
				print("DEBUG: Added card to discard")
	
	print("DEBUG: After cards_selected - deck size: " + str(selected_cryptid.deck.size()) + 
		  ", discard size: " + str(selected_cryptid.discard.size()))
	
	# Print contents of discard pile for debugging
	print("DEBUG: Discard pile contents:")
	for i in range(selected_cryptid.discard.size()):
		print("  [" + str(i) + "] " + selected_cryptid.discard[i].to_string())
	
	# Make sure to update card availability after modifying card states
	update_card_availability()
	
	return selected_cryptid

# Add a new debug function to help troubleshoot card state
func debug_print_all_cards():
	print("\n----- DEBUG: ALL CARDS FOR " + selected_cryptid.name + " -----")
	
	print("DECK CARDS:")
	for card in selected_cryptid.deck:
		print("  Card: " + card.to_string() + ", State: " + str(card.current_state))
	
	print("DISCARD CARDS:")
	for card in selected_cryptid.discard:
		print("  Card: " + card.to_string() + ", State: " + str(card.current_state))
	
	print("HAND DISPLAY:")
	var child_count = 0
	for child in get_children():
		if child is CardDialog and child.card_resource:
			child_count += 1
			print("  Display card " + str(child_count) + ": " + child.card_resource.to_string())
	
	print("----- END DEBUG CARDS -----\n")

# Add a function to completely clear the hand
func clear_hand():
	print("Clearing hand completely")
	
	# Clear any selected cards
	selected_top_card = null
	selected_bottom_card = null
	highlighted_cards.clear()
	
	# Remove and free all child nodes
	for child in get_children():
		if child is CardDialog:
			remove_child(child)
			child.queue_free()
	
	# Clear the hand array
	hand.clear()
	
	# Reset any discard mode
	in_discard_mode = false
	cards_to_discard.clear()
	discard_count_required = 0

func switch_cryptid_deck(cryptid: Cryptid):
	print("Switching deck to cryptid: ", cryptid.name)
	
	# Clear existing hand first
	clear_hand()
	
	# Debug: Print state of all cards before filtering
	print("DEBUG: All cards state before building hand:")
	for i in range(cryptid.deck.size()):
		var card = cryptid.deck[i]
		print("DEBUG: Card " + str(i) + " - state: " + str(card.current_state))
	
	# Count how many cards are in the deck state
	var available_cards = 0
	for card in cryptid.deck:
		if card.current_state == Card.CardState.IN_DECK:
			available_cards += 1
	
	print("DEBUG: Total available cards in deck: " + str(available_cards))
	
	# Create unique instances of each card
	var base_card
	var cards_added = 0
	var single_card_warning = false
	
	# Flag to track if we only have one card
	if available_cards == 1:
		single_card_warning = true
		print("WARNING: Only one card available - actions will be disabled")
	
	for card_resource in cryptid.deck:
		# Only display cards that are in the deck state
		if card_resource.current_state == Card.CardState.IN_DECK:
			print("DEBUG: Adding card to hand - index: " + str(cards_added))
			
			# Create a unique copy of the card resource
			var unique_card_resource = create_unique_card_instance(card_resource)
			
			# Instantiate the card dialog
			base_card = card_dialog.instantiate()
			base_card.card_resource = unique_card_resource
			
			# If only one card, mark it as disabled using metadata
			if single_card_warning:
				base_card.set_meta("disabled_for_action", true)
			
			add_card(base_card)
			cards_added += 1
	
	print("DEBUG: Total cards added to hand: " + str(cards_added))
	
	# Update the selected cryptid
	if selected_cryptid and selected_cryptid != cryptid:
		selected_cryptid.currently_selected = false
	
	selected_cryptid = cryptid
	selected_cryptid.currently_selected = true
	
	# Update card availability based on the new cryptid's state
	update_card_availability()
	
	# Show warning if only one card available
	if single_card_warning:
		var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
		if game_instructions:
			game_instructions.text = "Only one card available! Use Rest action to recover cards."
	
	# Make sure the hand is visible
	show()
	
	# Force redraw to ensure everything is updated
	queue_redraw()
		
func switch_cryptid_discard_cards(cryptid: Cryptid):
	selected_cryptid = cryptid
	highlighted_cards.clear()
	for child in discard_cards_node.get_children():
		discard_cards_node.remove_child(child)
	
	print("DEBUG: Building discard pile display:")
	var base_card
	var cards_added = 0
	for card_resource in cryptid.deck:
		# Only display cards that are in the discard state
		if card_resource.current_state == Card.CardState.IN_DISCARD:
			print("DEBUG: Adding card to discard display - index: " + str(cards_added))
			
			base_card = card_dialog.instantiate()
			base_card.card_resource = card_resource
			discard_cards_node.add_child(base_card)
			cards_added += 1
	
	print("DEBUG: Total cards added to discard display: " + str(cards_added))
	
	selected_cryptid.currently_selected = false
	selected_cryptid = cryptid

func _on_button_pressed():
	var card_template = preload("res://Cryptid-Menagerie/data/cryptids/Moves/test_card.tres")
	var unique_card_resource = create_unique_card_instance(card_template)
	
	var base_card = card_dialog.instantiate()
	base_card.card_resource = unique_card_resource
	add_card(base_card)
	
	# Add the unique card resource to the cryptid's deck
	selected_cryptid.deck.push_back(unique_card_resource)

func set_selected_top_card(card: CardDialog):
	# Check if a top action has already been used this turn
	if selected_cryptid.top_card_played:
		print("Already used a top action this turn")
		return
		
	selected_top_card = card
	check_if_turn_complete()

func set_selected_bottom_card(card: CardDialog):
	# Check if a bottom action has already been used this turn
	if selected_cryptid.bottom_card_played:
		print("Already used a bottom action this turn")
		return
		
	selected_bottom_card = card
	check_if_turn_complete()

# Modify check_if_turn_complete to not auto-advance
func check_if_turn_complete():
	print("DEBUG: check_if_turn_complete called")
	print("DEBUG: selected_top_card = " + str(selected_top_card))
	print("DEBUG: selected_bottom_card = " + str(selected_bottom_card))
	
	if selected_top_card != null and selected_bottom_card != null:
		print("DEBUG: Both cards selected")
		
		# Both top and bottom actions have been selected
		# Make sure they're from different cards
		if selected_top_card.card_resource != selected_bottom_card.card_resource:
			print("DEBUG: Cards are different, completing actions")
			selected_cryptid.top_card_played = true
			selected_cryptid.bottom_card_played = true
			
			# Add the used cards to the discard pile
			var cards_to_discard = [selected_top_card, selected_bottom_card]
			print("DEBUG: Sending " + str(cards_to_discard.size()) + " cards to discard")
			cards_selected(cards_to_discard)
			
			# Reset selections
			selected_top_card = null
			selected_bottom_card = null
			
			# Mark cryptid's turn as completed - BUT DON'T ADVANCE TURNS
			selected_cryptid.completed_turn = true
			
			# Update the menu to show only the End Turn button
			var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
			if action_menu and action_menu.has_method("show_end_turn_only"):
				action_menu.show_end_turn_only()
			
			# Update instructions to tell player to press End Turn
			var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
			if game_instructions:
				game_instructions.text = "Turn complete. Press End Turn to continue."
		else:
			print("DEBUG: Same card selected for both actions")
	else:
		print("DEBUG: Not all cards selected yet")

# Update the next_cryptid_turn function to prevent automatic switching
func next_cryptid_turn():
	print("next_cryptid_turn called but will NOT automatically advance")
	
	# DO NOTHING - this function should no longer do anything
	# All turn changes must now go through the End Turn button
	# This function is kept as a stub for compatibility with existing code
	pass
	
func check_turn_completion():
	if selected_cryptid.top_card_played and selected_cryptid.bottom_card_played:
		# Both actions have been used, mark turn as complete
		selected_cryptid.completed_turn = true
		
		# Check if there are more cryptids that need to take their turn
		if tile_map_layer.any_cryptid_not_completed():
			next_cryptid_turn()
		else:
			# All cryptids have taken their turn, move to battle phase
			get_node("/root/Main/GameController").battle_phase()
			
# Update this function in hand.gd

func update_card_availability():
	print("DEBUG: Updating card availability")
	
	# Ensure we're working with the selected cryptid
	if not selected_cryptid:
		print("DEBUG: No selected cryptid!")
		return
	
	print("DEBUG: Top card played: " + str(selected_cryptid.top_card_played))
	print("DEBUG: Bottom card played: " + str(selected_cryptid.bottom_card_played))
	
	# Check if we only have one card in hand
	var single_card_warning = (get_child_count() == 1)
	if single_card_warning:
		print("WARNING: Only one card in hand - disabling card actions")
	
	# Process all cards in the hand
	for card in get_children():
		if not is_instance_valid(card):
			print("WARNING: Invalid card instance, skipping")
			continue
			
		if card is CardDialog:
			# Check if this specific card has been fully disabled
			var fully_disabled = card.has_meta("fully_disabled") and card.get_meta("fully_disabled") == true
			
			# Also disable if we only have one card in hand
			if single_card_warning:
				card.set_meta("disabled_for_action", true)
				# Visually indicate it's disabled
				card.modulate = Color(0.8, 0.8, 0.8, 1)  # Slightly grayed out
			else:
				card.set_meta("disabled_for_action", false)
				
			# Get the card containers
			var vbox = card.get_node_or_null("VBoxContainer")
			if not vbox:
				continue
				
			var top_half_container = vbox.get_node_or_null("TopHalfContainer")
			var bottom_half_container = vbox.get_node_or_null("BottomHalfContainer")
			
			if not top_half_container or not bottom_half_container:
				continue
			
			# Handle top half availability
			if selected_cryptid.top_card_played or fully_disabled or single_card_warning:
				top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				top_half_container.disabled = true
			else:
				top_half_container.modulate = Color(1, 1, 1, 1)
				top_half_container.disabled = false
			
			# Handle bottom half availability
			if selected_cryptid.bottom_card_played or fully_disabled or single_card_warning:
				bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				bottom_half_container.disabled = true
			else:
				bottom_half_container.modulate = Color(1, 1, 1, 1)
				bottom_half_container.disabled = false
				
	# If both actions have been used, check if turn is complete
	if selected_cryptid.top_card_played and selected_cryptid.bottom_card_played:
		selected_cryptid.completed_turn = true
		print("DEBUG: Marked cryptid's turn as complete")
		
	# Update action menu to show Rest as the primary option when only one card
	if single_card_warning:
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu and action_menu.has_method("update_menu_visibility"):
			action_menu.update_menu_visibility(selected_cryptid)


func create_unique_card_instance(card_template):
	# Create a new card resource
	var new_card = Card.new()
	
	# Store reference to original card
	new_card.original_card = card_template
	
	# Store original movement values explicitly for both top and bottom moves
	if card_template.top_move:
		for action in card_template.top_move.actions:
			if action.action_types == [0]:  # Move action
				new_card.set_meta("original_top_move_amount", action.amount)
				print("Storing original top move amount: " + str(action.amount))
	
	if card_template.bottom_move:
		for action in card_template.bottom_move.actions:
			if action.action_types == [0]:  # Move action
				new_card.set_meta("original_bottom_move_amount", action.amount)
				print("Storing original bottom move amount: " + str(action.amount))
	
	# Copy the state
	new_card.current_state = card_template.current_state
	
	# Duplicate the top move
	var new_top_move = Move.new()
	new_top_move.name_prefix = card_template.top_move.name_prefix
	new_top_move.name_suffix = card_template.top_move.name_suffix
	new_top_move.card_side = card_template.top_move.card_side
	new_top_move.elemental_type = card_template.top_move.elemental_type.duplicate()
	
	# Duplicate top move actions
	for action in card_template.top_move.actions:
		var new_action = Action.new()
		new_action.action_types = action.action_types.duplicate()
		new_action.range = action.range
		new_action.amount = action.amount #This is the value that needs to be unique per card instance!
		new_action.area_of_effect = action.area_of_effect.duplicate()
		new_action.disabled = action.disabled
		new_top_move.add_action(new_action)
	
	# Duplicate the bottom move (similar to top move)
	var new_bottom_move = Move.new()
	new_bottom_move.name_prefix = card_template.bottom_move.name_prefix
	new_bottom_move.name_suffix = card_template.bottom_move.name_suffix
	new_bottom_move.card_side = card_template.bottom_move.card_side
	new_bottom_move.elemental_type = card_template.bottom_move.elemental_type.duplicate()
	
	# Duplicate bottom move actions
	for action in card_template.bottom_move.actions:
		var new_action = Action.new()
		new_action.action_types = action.action_types.duplicate()
		new_action.range = action.range
		new_action.amount = action.amount  # This is the value that needs to be unique per card instance!
		new_action.area_of_effect = action.area_of_effect.duplicate()
		new_action.disabled = action.disabled
		new_bottom_move.add_action(new_action)
	
	# Assign the duplicated moves to the new card
	new_card.top_move = new_top_move
	new_card.bottom_move = new_bottom_move
	
	return new_card

# Add this to hand.gd or wherever your rest action is handled
func rest_action():
	print("Performing rest action for", selected_cryptid.name)
	
	# Reset all card states from IN_DISCARD to IN_DECK
	var cards_recovered = 0
	
	# First, report the state before rest
	print("Before rest - Deck size:", selected_cryptid.deck.size())
	print("Before rest - Discard size:", selected_cryptid.discard.size())
	
	# Create an array to store cards being moved
	var cards_to_recover = selected_cryptid.discard.duplicate()
	
	# Process each card in the discard pile
	for card in cards_to_recover:
		# Verify the card state before changing it
		print("Processing card:", card, "Current state:", card.current_state)
		
		# Only change state if it's actually in discard
		if card.current_state == Card.CardState.IN_DISCARD:
			# Change the card state to IN_DECK
			card.current_state = Card.CardState.IN_DECK
			cards_recovered += 1
			print("Recovered card from discard:", card, "New state:", card.current_state)
		else:
			print("WARN: Card in discard pile had unexpected state:", card.current_state)
	
	# Clear the discard pile after moving all cards to deck
	selected_cryptid.discard.clear()
	
	print("Cards recovered from discard:", cards_recovered)
	
	# Verify all cards in deck are properly marked
	print("Verifying deck card states:")
	for i in range(selected_cryptid.deck.size()):
		var card = selected_cryptid.deck[i]
		print("Deck card", i, ":", card, "State:", card.current_state)
		
		# Ensure all cards are marked as IN_DECK
		if card.current_state != Card.CardState.IN_DECK:
			print("FIXING incorrect card state for card", i)
			card.current_state = Card.CardState.IN_DECK
	
	# Then refresh the hand with all IN_DECK cards
	switch_cryptid_deck(selected_cryptid)
	
	# Double-check that our discard pile is truly empty
	if selected_cryptid.discard.size() > 0:
		print("ERROR: Discard pile not empty after rest! Size:", selected_cryptid.discard.size())
		# Force clear it again
		selected_cryptid.discard.clear()
	
	# Update the game instructions
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions:
		game_instructions.text = "Rested: recovered " + str(cards_recovered) + " cards from discard pile!"
	
	# Mark the cryptid's turn as completed
	selected_cryptid.top_card_played = true
	selected_cryptid.bottom_card_played = true
	selected_cryptid.completed_turn = true
	
	# Show only the End Turn button
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.has_method("show_end_turn_only"):
		action_menu.show_end_turn_only()
	
func clear_card_selections():
	print("Clearing all card selections")
	
	# Reset the selected cards
	
	# Reset all card highlighting
	for child in self.get_children():
		if child is CardDialog:
			# Reset modulate for non-disabled cards
			if not child.top_half_container.disabled:
				child.top_half_container.modulate = Color(1, 1, 1, 1)
			if not child.bottom_half_container.disabled:
				child.bottom_half_container.modulate = Color(1, 1, 1, 1)
	
	# Reset any action booleans in the tile map
	if tile_map_layer:
		tile_map_layer.move_action_bool = false
		tile_map_layer.attack_action_bool = false
		tile_map_layer.delete_all_lines()
		tile_map_layer.delete_all_indicators()
	
	# Show the action menu again
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		action_menu.show()

# Function to enter discard selection mode
func enter_discard_selection_mode(count_required):
	var in_discard_selection_mode = true
	discard_count_required = count_required
	var selected_for_discard = []
	
	# Add/update a visible label to show discard mode is active
	var discard_mode_label = Label.new()
	discard_mode_label.name = "DiscardModeLabel"
	discard_mode_label.text = "SELECT " + str(count_required) + " CARD(S) TO DISCARD"
	discard_mode_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # Red color
	discard_mode_label.add_theme_font_size_override("font_size", 24)  # Larger font
	add_child(discard_mode_label)
	
	# Position the label at the top of the screen
	discard_mode_label.anchor_left = 0.5
	discard_mode_label.anchor_right = 0.5
	discard_mode_label.anchor_top = 0.1
	discard_mode_label.anchor_bottom = 0.1
	discard_mode_label.offset_left = -200
	discard_mode_label.offset_right = 200
	
	# Add a separate click detector to each card for discard mode
	for card in get_children():
		if card is CardDialog:
			# Add a new button that covers the whole card but is invisible
			var click_detector = Button.new()
			click_detector.name = "DiscardClickDetector"
			click_detector.flat = true
			click_detector.modulate = Color(1, 1, 1, 0)  # Invisible
			
			# Size it to cover the entire card
			click_detector.size = card.size
			click_detector.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass events through
			
			# Connect the pressed signal
			click_detector.connect("pressed", Callable(self, "_on_card_clicked_for_discard").bind(card))
			
			# Add it to the card
			card.add_child(click_detector)
			
			# Add a highlight effect to show it's selectable
			var highlight = ColorRect.new()
			highlight.name = "DiscardHighlight"
			highlight.size = card.size
			highlight.color = Color(1, 0.8, 0.8, 0.3)  # Light red, semi-transparent
			highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept events
			highlight.visible = false  # Start invisible
			card.add_child(highlight)

# Modify _on_card_clicked_for_discard to work with the new detectors
func _on_card_clicked_for_discard(card):
	if !in_discard_selection_mode:
		return
	
	# Toggle selection state
	if selected_for_discard.has(card):
		# Deselect the card
		selected_for_discard.erase(card)
		
		# Update highlight
		var highlight = card.get_node_or_null("DiscardHighlight")
		if highlight:
			highlight.visible = false
	else:
		# Check if we've already selected enough cards
		if selected_for_discard.size() >= discard_count_required:
			return
		
		# Select the card
		selected_for_discard.append(card)
		
		# Update highlight
		var highlight = card.get_node_or_null("DiscardHighlight")
		if highlight:
			highlight.visible = true
	
	# Update instruction text
	var discard_mode_label = get_node_or_null("DiscardModeLabel")
	if discard_mode_label:
		var remaining = discard_count_required - selected_for_discard.size()
		if remaining > 0:
			discard_mode_label.text = "SELECT " + str(remaining) + " MORE CARD(S) TO DISCARD"
		else:
			discard_mode_label.text = "PRESS CONFIRM TO DISCARD SELECTED CARDS"
			# Show confirm button
			show_confirm_discard_button()

# Add a function to show confirm button
func show_confirm_discard_button():
	var confirm_button = Button.new()
	confirm_button.text = "Confirm Discard"
	confirm_button.name = "ConfirmDiscardButton"
	confirm_button.connect("pressed", Callable(self, "_on_confirm_discard_pressed"))
	add_child(confirm_button)
	
	# Position the button at the bottom of the screen
	confirm_button.anchor_left = 0.5
	confirm_button.anchor_top = 1.0
	confirm_button.anchor_right = 0.5
	confirm_button.anchor_bottom = 1.0
	confirm_button.offset_left = -100
	confirm_button.offset_top = -50
	confirm_button.offset_right = 100
	confirm_button.offset_bottom = -10

func _on_confirm_discard_pressed():
	print("Confirm discard pressed with", cards_to_discard.size(), "cards selected")
	
	# Verify we have selected the required number of cards
	if cards_to_discard.size() != discard_count_required:
		print("ERROR: Not enough cards selected for discard")
		return
	
	# Get the game controller
	var game_controller = get_node_or_null("/root/VitaChrome/TileMapLayer/GameController")
	if not game_controller:
		print("ERROR: Game controller not found")
		return
	
	# Process the selected cards
	var selected_cards = cards_to_discard.duplicate()
	
	# Reset discard mode
	in_discard_mode = false
	cards_to_discard.clear()
	discard_count_required = 0
	
	# Reset card visuals
	for card in get_children():
		if card is CardDialog:
			card.modulate = Color(1, 1, 1, 1)
	
	# Hide the discard confirmation button
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		action_menu.show_discard_confirmation(false)
	
	# Notify the game controller
	game_controller.on_discard_complete(selected_cards)


# Add function to exit discard mode and clean up
func exit_discard_selection_mode():
	in_discard_selection_mode = false
	
	# Remove the discard mode label
	var discard_mode_label = get_node_or_null("DiscardModeLabel")
	if discard_mode_label:
		remove_child(discard_mode_label)
		discard_mode_label.queue_free()
	
	# Remove all click detectors and highlights
	for card in get_children():
		if card is CardDialog:
			var click_detector = card.get_node_or_null("DiscardClickDetector")
			if click_detector:
				card.remove_child(click_detector)
				click_detector.queue_free()
			
			var highlight = card.get_node_or_null("DiscardHighlight")
			if highlight:
				card.remove_child(highlight)
				highlight.queue_free()
	
	# Remove confirm button if it exists
	var confirm_button = get_node_or_null("ConfirmDiscardButton")
	if confirm_button:
		remove_child(confirm_button)
		confirm_button.queue_free()

# Replace the start_discard_mode function with this improved version
func start_discard_mode(count_required):
	in_discard_mode = true
	discard_count_required = count_required
	cards_to_discard = []
	
	print("Starting discard mode, cards needed: ", count_required)
	
	# Block all card activation functionality during discard mode
	# by removing any active card state and highlighting
	clear_card_selections()
	
	# Connect all cards to the discard selection function
	for card in get_children():
		if card is CardDialog:
			# Check if the card was already used this turn
			# The card should be grayed out and not selectable if it was used
			var already_used = false
			
			# Check if the card's resource is already in the discard pile
			for discard_card in selected_cryptid.discard:
				if card.card_resource == discard_card or (card.card_resource.original_card != null and card.card_resource.original_card == discard_card):
					already_used = true
					break
			
			# Skip cards that were already used this turn
			if already_used:
				card.modulate = Color(0.5, 0.5, 0.5, 1)  # Gray out
				continue
				
			# Make the card visually indicate it's selectable
			card.modulate = Color(1, 1, 1, 1)  # Full brightness
			
			# Connect the input event if not already connected
			if not card.is_connected("gui_input", Callable(self, "_on_card_input")):
				card.connect("gui_input", Callable(self, "_on_card_input").bind(card))

# Function to handle card input
func _on_card_input(event, card):
	# Only process clicks in discard mode
	if not in_discard_mode:
		return
	
	# Check for left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Block any other handling of the event
		get_viewport().set_input_as_handled()
		
		# Toggle card selection
		toggle_card_selection(card)

func toggle_card_selection(card):
	print("Toggling card selection in discard mode")
	
	# Prevent toggling cards that were already used (grayed out)
	if card.modulate.r < 0.6:  # Check if the card is grayed out
		print("Card already used or in discard, cannot select")
		return
	
	if cards_to_discard.has(card):
		# Deselect the card
		cards_to_discard.erase(card)
		card.modulate = Color(1, 1, 1, 1)  # Reset color
		print("Card deselected, remaining:", cards_to_discard.size(), "/", discard_count_required)
	else:
		# Only allow selection if we haven't reached the required count
		if cards_to_discard.size() < discard_count_required:
			# Select the card
			cards_to_discard.append(card)
			card.modulate = Color(1, 0.5, 0.5, 1)  # Red tint
			print("Card selected, now have:", cards_to_discard.size(), "/", discard_count_required)
	
	# Update the confirm button state in the action menu
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.confirm_discard_button:
		# Enable the button only if we have exactly the required number of cards
		var enable_button = cards_to_discard.size() == discard_count_required
		action_menu.confirm_discard_button.disabled = !enable_button
		
		# Update button appearance
		if enable_button:
			action_menu.confirm_discard_button.modulate = Color(1, 1, 1, 1)
			print("Discard confirmation button enabled - ready to advance turn")
		else:
			action_menu.confirm_discard_button.modulate = Color(0.7, 0.7, 0.7, 1)
			print("Discard confirmation button disabled - need more cards")
	
	# Update the instruction text
	var game_controller = get_node("/root/VitaChrome/GameController")
	if game_controller:
		var remaining = discard_count_required - cards_to_discard.size()
		if remaining > 0:
			game_controller.game_instructions.text = "Select " + str(remaining) + " more card(s) to discard"
		else:
			game_controller.game_instructions.text = "Press Confirm to discard selected cards and proceed to next cryptid"
