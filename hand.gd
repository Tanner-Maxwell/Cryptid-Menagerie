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
		print("DEBUG: Removing card from deck: " + cards_picked.card_resource.to_string())
		selected_cryptid.deck.erase(cards_picked.card_resource)
		print("DEBUG: Adding card to discard: " + cards_picked.card_resource.to_string())
		selected_cryptid.discard.push_back(cards_picked.card_resource)
	print("DEBUG: After cards_selected - deck size: " + str(selected_cryptid.deck.size()) + ", discard size: " + str(selected_cryptid.discard.size()))
	return selected_cryptid

func switch_cryptid_deck(cryptid: Cryptid):
	print("Switching deck to cryptid: ", cryptid.name)
	
	# Clear existing hand
	hand.clear()
	highlighted_cards.clear()
	for child in self.get_children():
		remove_child(child)
		child.queue_free()
	
	# Debug: Print state of all cards before filtering
	print("DEBUG: All cards state before building hand:")
	for i in range(cryptid.deck.size()):
		var card = cryptid.deck[i]
		print("DEBUG: Card " + str(i) + " - state: " + str(card.current_state))
	
	# Create unique instances of each card
	var base_card
	var cards_added = 0
	for card_resource in cryptid.deck:
		# Only display cards that are in the deck state
		if card_resource.current_state == Card.CardState.IN_DECK:
			print("DEBUG: Adding card to hand - index: " + str(cards_added))
			
			# Create a unique copy of the card resource
			var unique_card_resource = create_unique_card_instance(card_resource)
			
			# Instantiate the card dialog
			base_card = card_dialog.instantiate()
			base_card.card_resource = unique_card_resource
			add_card(base_card)
			cards_added += 1
	
	print("DEBUG: Total cards added to hand: " + str(cards_added))
	
	# Update the selected cryptid
	if selected_cryptid:
		selected_cryptid.currently_selected = false
	selected_cryptid = cryptid
	selected_cryptid.currently_selected = true
	
	# Update card availability based on the new cryptid's state
	update_card_availability()
		
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

func check_if_turn_complete():
	print("DEBUG: check_if_turn_complete called")
	print("DEBUG: selected_top_card = " + str(selected_top_card))
	print("DEBUG: selected_bottom_card = " + str(selected_bottom_card))
	
	if selected_top_card != null and selected_bottom_card != null:
		print("DEBUG: Both cards selected")
		
		# Both top and bottom actions have been selected
		# Make sure they're from different cards
		if selected_top_card.card_resource != selected_bottom_card.card_resource:
			print("DEBUG: Cards are different, completing turn")
			selected_cryptid.top_card_played = true
			selected_cryptid.bottom_card_played = true
			
			# Add the used cards to the discard pile
			var cards_to_discard = [selected_top_card, selected_bottom_card]
			print("DEBUG: Sending " + str(cards_to_discard.size()) + " cards to discard")
			cards_selected(cards_to_discard)
			
			# Reset selections
			selected_top_card = null
			selected_bottom_card = null
			
			# Mark cryptid's turn as completed
			selected_cryptid.completed_turn = true
			
			# Get next cryptid in turn order
			next_cryptid_turn()
		else:
			print("DEBUG: Same card selected for both actions")
	else:
		print("DEBUG: Not all cards selected yet")

func next_cryptid_turn():
	print("Switching to next cryptid's turn")
	
	# First ensure that player_cryptids_in_play are sorted by speed
	tile_map_layer.sort_cryptids_by_speed(tile_map_layer.all_cryptids_in_play)
	
	# Log the current speed order for debugging
	print("Current cryptid speed order:")
	for cryptid in tile_map_layer.all_cryptids_in_play:
		print(cryptid.cryptid.name, " - Speed: ", cryptid.cryptid.speed)
	
	# Find the index of the current cryptid in player_cryptids_in_play
	var current_index = -1
	for i in range(tile_map_layer.all_cryptids_in_play.size()):
		if tile_map_layer.all_cryptids_in_play[i].cryptid == selected_cryptid:
			current_index = i
			break
	
	print("Current cryptid index: ", current_index)
	
	# Set the current cryptid as not selected
	if selected_cryptid:
		selected_cryptid.currently_selected = false
	
	# Find the next cryptid that hasn't completed their turn
	# Start from the next index and loop around if necessary
	var checked_count = 0
	var next_index = (current_index + 1) % tile_map_layer.all_cryptids_in_play.size()
	var next_cryptid = null
	
	# Loop through all cryptids starting from the next one and going in order
	while checked_count < tile_map_layer.all_cryptids_in_play.size():
		var candidate = tile_map_layer.all_cryptids_in_play[next_index].cryptid
		
		if not candidate.completed_turn:
			next_cryptid = candidate
			break
			
		# Move to the next index, wrapping around if necessary
		next_index = (next_index + 1) % tile_map_layer.all_cryptids_in_play.size()
		checked_count += 1
	
	if next_cryptid == null:
		print("All cryptids have taken their turn, moving to battle phase")
		# All cryptids have taken their turn, transition to the next phase
		var game_controller = %GameController
		game_controller.battle_phase()
		return
	
	# Set the new cryptid as selected
	selected_cryptid = next_cryptid
	selected_cryptid.currently_selected = true
	
	# Check if this is an enemy cryptid
	var is_enemy = false
	var enemy_cryptid_node = null
	for enemy_cryptid in tile_map_layer.enemy_cryptids_in_play:
		if enemy_cryptid.cryptid == selected_cryptid:
			is_enemy = true
			enemy_cryptid_node = enemy_cryptid
			break
	
	if is_enemy:
		print("Enemy cryptid's turn: ", selected_cryptid.name)
		# Trigger the enemy AI
		enemy_ai.take_enemy_turn(enemy_cryptid_node)
	else:
		print("Player cryptid's turn: ", selected_cryptid.name)
		# Regular player turn setup
		tile_map_layer.reset_for_new_cryptid()
		
		# DEBUG: Print deck and discard contents
		print("DEBUG: " + selected_cryptid.name + " deck size: " + str(selected_cryptid.deck.size()))
		print("DEBUG: " + selected_cryptid.name + " discard size: " + str(selected_cryptid.discard.size()))
		for i in range(selected_cryptid.deck.size()):
			print("   Deck card " + str(i) + ": " + selected_cryptid.deck[i].to_string())
		for i in range(selected_cryptid.discard.size()):
			print("   Discard card " + str(i) + ": " + selected_cryptid.discard[i].to_string())
		
		switch_cryptid_deck(selected_cryptid)
		
		# Force update action menu button state for the new cryptid
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu:
			# First ensure it's visible
			action_menu.show()
			
			# Get direct references to the buttons
			var swap_button = action_menu.get_node("VBoxContainer/SwapButton")
			var rest_button = action_menu.get_node("VBoxContainer/RestButton")
			var catch_button = action_menu.get_node("VBoxContainer/CatchButton")
			var end_turn_button = action_menu.get_node("VBoxContainer/EndTurnButton")
			
			# Check if this cryptid has already used a card action
			if selected_cryptid.top_card_played or selected_cryptid.bottom_card_played:
				print("NEW TURN - Cryptid has used card action, hiding action buttons")
				
				# Hide action buttons, show only end turn
				if swap_button: swap_button.hide()
				if rest_button: rest_button.hide()
				if catch_button: catch_button.hide()
				if end_turn_button: end_turn_button.show()
			else:
				print("NEW TURN - Cryptid has not used card action, showing all buttons")
				
				# Show all buttons
				if swap_button: swap_button.show()
				if rest_button: rest_button.show()
				if catch_button: catch_button.show()
				if end_turn_button: end_turn_button.show()
	
	switch_cryptid_deck(selected_cryptid)
		# Force update action menu button state for the new cryptid
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		# First ensure it's visible
		action_menu.show()
		
		# Get direct references to the buttons
		var swap_button = action_menu.get_node("VBoxContainer/SwapButton")
		var rest_button = action_menu.get_node("VBoxContainer/RestButton")
		var catch_button = action_menu.get_node("VBoxContainer/CatchButton")
		var end_turn_button = action_menu.get_node("VBoxContainer/EndTurnButton")
		
		# Check if this cryptid has already used a card action
		if selected_cryptid.top_card_played or selected_cryptid.bottom_card_played:
			print("NEW TURN - Cryptid has used card action, hiding action buttons")
			
			# Hide action buttons, show only end turn
			if swap_button: swap_button.hide()
			if rest_button: rest_button.hide()
			if catch_button: catch_button.hide()
			if end_turn_button: end_turn_button.show()
		else:
			print("NEW TURN - Cryptid has not used card action, showing all buttons")
			
			# Show all buttons
			if swap_button: swap_button.show()
			if rest_button: rest_button.show()
			if catch_button: catch_button.show()
			if end_turn_button: end_turn_button.show()
	
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
			
func update_card_availability():
	# Gray out all top halves if a top action has been used
	if selected_cryptid.top_card_played:
		for card in get_children():
			if card is CardDialog:
				card.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				card.top_half_container.disabled = true
	
	# Gray out all bottom halves if a bottom action has been used
	if selected_cryptid.bottom_card_played:
		for card in get_children():
			if card is CardDialog:
				card.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				card.bottom_half_container.disabled = true
				
	# If both actions have been used, check if turn is complete
	if selected_cryptid.top_card_played and selected_cryptid.bottom_card_played:
		selected_cryptid.completed_turn = true
		

func create_unique_card_instance(card_template):
	# Create a new card resource
	var new_card = Card.new()
	
	# Store reference to original card
	new_card.original_card = card_template
	
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
		new_action.amount = action.amount
		new_action.area_of_effect = action.area_of_effect.duplicate()
		new_action.disabled = action.disabled
		new_top_move.add_action(new_action)
	
	# Duplicate the bottom move
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
		new_action.amount = action.amount
		new_action.area_of_effect = action.area_of_effect.duplicate()
		new_action.disabled = action.disabled
		new_bottom_move.add_action(new_action)
	
	# Assign the duplicated moves to the new card
	new_card.top_move = new_top_move
	new_card.bottom_move = new_bottom_move
	
	return new_card

# Add this to hand.gd or wherever your rest action is handled
func rest_action():
	# Reset all card states to IN_DECK
	for card in selected_cryptid.deck:
		card.current_state = Card.CardState.IN_DECK
	
	# Then refresh the hand
	switch_cryptid_deck(selected_cryptid)
	
	# Mark the cryptid's turn as completed
	selected_cryptid.completed_turn = true
	
	# Move to next cryptid's turn
	next_cryptid_turn()
	
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
