extends Node

# Reference to key game objects
var tile_map_layer
var game_controller
var hand

# Called when the node enters the scene tree for the first time.
func _ready():
	# Wait until the scene is fully loaded before getting references
	await get_tree().process_frame
	
	# Get references to key game objects
	tile_map_layer = get_tree().get_nodes_in_group("map")[0]
	game_controller = get_node("/root/VitaChrome/TileMapLayer/GameController")
	hand = get_node("/root/VitaChrome/UIRoot/Hand")

# Main function to handle an enemy cryptid's turn
# Main function to handle an enemy cryptid's turn
# Main function to handle an enemy cryptid's turn
func take_enemy_turn(enemy_cryptid):
	print("AI: Taking turn for enemy cryptid: ", enemy_cryptid.cryptid.name)
	
	# Set the selected cryptid in the hand and tile map layer
	var previous_selected = tile_map_layer.selected_cryptid
	tile_map_layer.selected_cryptid = enemy_cryptid
	
	# IMPORTANT: Enable the hex occupied by this cryptid on the grid
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var point = tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos, true)
	tile_map_layer.a_star_hex_grid.set_point_disabled(point, false)
	print("AI: Enabled hex at", enemy_pos, "for movement")
	
	# Check if this cryptid has already completed its turn
	if enemy_cryptid.cryptid.completed_turn:
		print("AI: Cryptid already completed turn, skipping")
		return
	
	# Basic decision tree based on prioritization rules
	
	# 1. Check if we can attack a player cryptid
	var attack_target = find_attack_target(enemy_cryptid)
	if attack_target:
		print("AI: Found attack target:", attack_target.target.cryptid.name)
		perform_attack(enemy_cryptid, attack_target)
		
		# After attacking, check if we can move (retreat)
		if !enemy_cryptid.cryptid.completed_turn:
			var retreat_target = find_retreat_position(enemy_cryptid)
			if retreat_target:
				print("AI: Retreating after attack")
				perform_move(enemy_cryptid, retreat_target)
		
		# Mark actions as used but don't end turn - let player press the button
		enemy_cryptid.cryptid.top_card_played = true
		enemy_cryptid.cryptid.bottom_card_played = true
		
		# Show end turn button
		show_end_turn_button_for_enemy()
		return
	
	# 2. Check if we can move to attack range
	var move_attack_result = find_move_to_attack(enemy_cryptid)
	if move_attack_result:
		print("AI: Moving to attack position")
		perform_move(enemy_cryptid, move_attack_result.move_target)
		
		# If we can attack after moving, do so
		if move_attack_result.can_attack_after_move and !enemy_cryptid.cryptid.completed_turn:
			print("AI: Attacking after move")
			perform_attack(enemy_cryptid, move_attack_result.attack_info)
		
		# Mark actions as used but don't end turn - let player press the button
		enemy_cryptid.cryptid.top_card_played = true
		enemy_cryptid.cryptid.bottom_card_played = true
		
		# Show end turn button
		show_end_turn_button_for_enemy()
		return
	
	# 3. If no good attack options, rest to restore cards
	print("AI: No good options, resting")
	game_controller.perform_rest()
	
	# Mark actions as used but don't end turn - let player press the button
	enemy_cryptid.cryptid.top_card_played = true
	enemy_cryptid.cryptid.bottom_card_played = true
	
	# Show end turn button
	show_end_turn_button_for_enemy()

# Show the end turn button and wait for player to press it
func show_end_turn_button_for_enemy():
	print("AI: Showing end turn button for enemy")
	
	# Get the action menu
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		# Hide all other buttons
		for child in action_menu.get_node("VBoxContainer").get_children():
			if child.name != "EndTurnButton":
				child.hide()
		
		# Show only the end turn button
		var end_turn_button = action_menu.get_node("VBoxContainer/EndTurnButton")
		if end_turn_button:
			end_turn_button.show()
			action_menu.show()
	
	# Add a label or instruction for clarity
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions:
		game_instructions.text = "AI has completed its actions. Press End Turn to continue."
# Find closest player cryptid that can be attacked
func find_attack_target(enemy_cryptid):
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var closest_target = null
	var closest_distance = 999
	
	# Check if top action already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	# Check if bottom action already used
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played
	
	# If both actions used, can't attack
	if top_used and bottom_used:
		return null
	
	# Temporarily store original values
	var original_attack_bool = tile_map_layer.attack_action_bool
	var original_move_bool = tile_map_layer.move_action_bool
	var original_attack_range = tile_map_layer.attack_range
	
	# Examine each player cryptid
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		
		print("AI: Checking attack options from", enemy_pos, "to", player_pos)
		
		# Check cards for attacks
		for card in enemy_cryptid.cryptid.deck:
			# Skip cards that aren't in the deck
			if card.current_state != Card.CardState.IN_DECK:
				continue
				
			# Check top of card for attacks if top action not used yet
			if !top_used:
				for action in card.top_move.actions:
					if action.action_types.has(1):  # Attack action
						var attack_range = action.range
						
						# Set up the attack mode and calculate path
						tile_map_layer.attack_action_bool = true
						tile_map_layer.move_action_bool = false
						tile_map_layer.attack_range = attack_range
						
						# Get attack path
						var attack_path = tile_map_layer.a_star_hex_attack_grid.get_id_path(
							tile_map_layer.a_star_hex_attack_grid.get_closest_point(enemy_pos),
							tile_map_layer.a_star_hex_attack_grid.get_closest_point(player_pos)
						)
						
						# Calculate distance
						var attack_distance = attack_path.size() - 1
						
						print("AI: Card", card.top_move.name_prefix, "attack range:", attack_range, "actual distance:", attack_distance)
						
						if attack_distance <= attack_range:
							# Found a valid attack target in range
							if attack_distance < closest_distance:
								closest_distance = attack_distance
								closest_target = {
									"target": player_cryptid,
									"card": card,
									"is_top": true,
									"range": attack_range,
									"damage": action.amount,
									"attack_distance": attack_distance,
									"target_pos": player_pos
								}
			
			# Check bottom of card for attacks if bottom action not used yet
			if !bottom_used:
				for action in card.bottom_move.actions:
					if action.action_types.has(1):  # Attack action
						var attack_range = action.range
						
						# Set up the attack mode and calculate path
						tile_map_layer.attack_action_bool = true
						tile_map_layer.move_action_bool = false
						tile_map_layer.attack_range = attack_range
						
						# Get attack path
						var attack_path = tile_map_layer.a_star_hex_attack_grid.get_id_path(
							tile_map_layer.a_star_hex_attack_grid.get_closest_point(enemy_pos),
							tile_map_layer.a_star_hex_attack_grid.get_closest_point(player_pos)
						)
						
						# Calculate distance
						var attack_distance = attack_path.size() - 1
						
						print("AI: Card", card.bottom_move.name_suffix, "attack range:", attack_range, "actual distance:", attack_distance)
						
						if attack_distance <= attack_range:
							# Found a valid attack target in range
							if attack_distance < closest_distance:
								closest_distance = attack_distance
								closest_target = {
									"target": player_cryptid,
									"card": card,
									"is_top": false,
									"range": attack_range,
									"damage": action.amount,
									"attack_distance": attack_distance,
									"target_pos": player_pos
								}
	
	# Restore original values
	tile_map_layer.attack_action_bool = original_attack_bool
	tile_map_layer.move_action_bool = original_move_bool
	tile_map_layer.attack_range = original_attack_range
	
	return closest_target

# Find a move that gets us in range to attack
func find_move_to_attack(enemy_cryptid):
	# At the beginning of find_move_to_attack
	var enemy_world_pos = enemy_cryptid.position
	var enemy_pos = tile_map_layer.local_to_map(enemy_world_pos)
	print("AI: Enemy cryptid:", enemy_cryptid.cryptid.name)
	print("AI: Enemy world position:", enemy_world_pos)
	print("AI: Enemy grid position:", enemy_pos)

	# Second set of debug lines - check grid positions
	print("AI: Checking grid positions:")
	print("AI: Enemy at", enemy_pos, "- walkable:", enemy_pos in tile_map_layer.walkable_hexes)
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		print("AI:", player_cryptid.cryptid.name, "at", player_pos, "- walkable:", player_pos in tile_map_layer.walkable_hexes)
	
	# Rest of the function continues here...
	print("AI: Enemy position is", enemy_pos)
	# Check if actions already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played

	# If both actions used, can't move
	if top_used and bottom_used:
		return null
	
	# Find move cards
	var move_cards = []
	for card in enemy_cryptid.cryptid.deck:
		# Skip cards that aren't in the deck
		if card.current_state != Card.CardState.IN_DECK:
			continue
			
		# Check top of card for moves if top action not used yet
		if !top_used:
			for action in card.top_move.actions:
				if action.action_types.has(0):  # Move action
					move_cards.append({
						"card": card,
						"is_top": true,
						"range": action.amount
					})
		
		# Check bottom of card for moves if bottom action not used yet
		if !bottom_used:
			for action in card.bottom_move.actions:
				if action.action_types.has(0):  # Move action
					move_cards.append({
						"card": card,
						"is_top": false,
						"range": action.amount
					})
	
	print("AI: Found", move_cards.size(), "available move cards")
	if move_cards.size() == 0:
		return null
	
	# Find the closest player cryptid
	var closest_player = null
	var closest_player_distance = 999
	
	# Debug: print all player cryptids first
	print("AI: All player cryptids:")
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		print("AI: Player:", player_cryptid.cryptid.name, "at position:", player_pos)
	
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		
		# Use cube distance - more reliable for hex grids
		var enemy_cube = tile_map_layer.axial_to_cube(enemy_pos)
		var player_cube = tile_map_layer.axial_to_cube(player_pos)
		var distance = tile_map_layer.cube_distance(enemy_cube, player_cube)
		
		# Calculate our own cube distance directly
		var direct_distance = (abs(enemy_cube.x - player_cube.x) + 
							   abs(enemy_cube.y - player_cube.y) + 
							   abs(enemy_cube.z - player_cube.z)) / 2
							   
		# Also calculate Manhattan distance as a sanity check
		var manhattan_distance = abs(enemy_pos.x - player_pos.x) + abs(enemy_pos.y - player_pos.y)
		
		print("AI: Distance to", player_cryptid.cryptid.name, "at", player_pos, 
			  "from", enemy_pos, "is cube:", distance, 
			  "direct:", direct_distance, 
			  "manhattan:", manhattan_distance,
			  "enemy_cube:", enemy_cube,
			  "player_cube:", player_cube)
		
		if direct_distance < closest_player_distance:  # Using direct calculation for reliability
			closest_player_distance = direct_distance
			closest_player = player_cryptid
			print("AI: New closest player:", player_cryptid.cryptid.name, "at distance", direct_distance)
	
	if closest_player:
		print("AI: Final closest player is", closest_player.cryptid.name, 
			  "at position", tile_map_layer.local_to_map(closest_player.position), 
			  "with distance", closest_player_distance)
	else:
		print("AI: No player cryptids found!")
		return null
	
	if closest_player:
		var player_pos = tile_map_layer.local_to_map(closest_player.position)
		var best_move = null
		var best_distance_to_player = closest_player_distance
		
		# Sort move cards by range to try the furthest moves first
		move_cards.sort_custom(Callable(self, "sort_by_move_range"))
		
		# For each move card
		for move_info in move_cards:
			print("AI: Testing move card with range", move_info.range)
			
			# CRITICAL: Use a much smaller search radius to guarantee we only find truly reachable positions
			var max_range = move_info.range
			
			# For each possible distance
			for distance in range(1, max_range + 1):
				# Get all hexes at exactly this distance from the enemy
				var move_targets = get_hexes_at_distance(enemy_pos, distance)
				
				# Sort them by distance to player (closest first)
				for target in move_targets:
					# Skip if occupied
					var occupied = false
					for cryptid in tile_map_layer.all_cryptids_in_play:
						if tile_map_layer.local_to_map(cryptid.position) == target:
							occupied = true
							break
					
					if occupied or target == player_pos:
						continue
					
					# Double-check that this target is actually reachable
					var move_path = tile_map_layer.a_star_hex_grid.get_id_path(
						tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
						tile_map_layer.a_star_hex_grid.get_closest_point(target)
					)
					
					var actual_move_distance = move_path.size() - 1
					
					# If it's reachable, check how close it gets us to the player
					if actual_move_distance <= max_range:
						var target_cube = tile_map_layer.axial_to_cube(target)
						var player_cube = tile_map_layer.axial_to_cube(player_pos)
						var distance_to_player = (abs(target_cube.x - player_cube.x) + 
												 abs(target_cube.y - player_cube.y) + 
												 abs(target_cube.z - player_cube.z)) / 2
						
						print("AI: Position", target, "is", actual_move_distance, "moves away, distance to player:", distance_to_player)
						
						# If this is better than our current best
						if distance_to_player < best_distance_to_player:
							best_distance_to_player = distance_to_player
							best_move = {
								"position": target,
								"card": move_info.card,
								"is_top": move_info.is_top,
								"range": move_info.range,
								"move_distance": actual_move_distance
							}
							
							print("AI: New best move to", target, "with distance to player", distance_to_player)
		
		# If we found a better move
		if best_move and best_distance_to_player < closest_player_distance:
			print("AI: Final best move to", best_move.position, 
				"reduces distance from", closest_player_distance, 
				"to", best_distance_to_player)
			
			return {
				"move_target": best_move,
				"can_attack_after_move": false
			}
	
	return null

# Helper to sort move cards by range
func sort_by_move_range(a, b):
	return a.range > b.range

# Get all hexes at a specific distance from a center hex
func get_hexes_at_distance(center, distance):
	var result = []
	var center_cube = tile_map_layer.axial_to_cube(center)
	
	# For each walkable hex, check if it's at the right distance
	for hex in tile_map_layer.walkable_hexes:
		var hex_cube = tile_map_layer.axial_to_cube(hex)
		var hex_distance = (abs(center_cube.x - hex_cube.x) + 
						   abs(center_cube.y - hex_cube.y) + 
						   abs(center_cube.z - hex_cube.z)) / 2
		
		if hex_distance == distance:
			result.append(hex)
	
	return result


# Find the closest player cryptid - fixed version
func find_closest_player_cryptid(enemy_pos):
	var closest_player = null
	var closest_player_distance = 999
	
	print("AI: Looking for closest player from position", enemy_pos)
	
	# Find the closest player cryptid
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		
		# First calculate direct cube distance for simplicity
		var enemy_cube = tile_map_layer.axial_to_cube(enemy_pos)
		var player_cube = tile_map_layer.axial_to_cube(player_pos)
		var cube_distance = tile_map_layer.cube_distance(enemy_cube, player_cube)
		
		print("AI: Player", player_cryptid.cryptid.name, "at position", player_pos, "- cube distance:", cube_distance)
		
		# Now calculate path distance for accuracy
		var path = tile_map_layer.a_star_hex_grid.get_id_path(
			tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
			tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
		)
		
		# Print path details
		var path_positions = []
		for point_id in path:
			path_positions.append(tile_map_layer.a_star_hex_grid.get_point_position(point_id))
		print("AI: Path:", path_positions)
		
		var path_distance = path.size() - 1
		print("AI: Path distance:", path_distance)
		
		# Use path distance for determining closest
		if path_distance < closest_player_distance:
			closest_player_distance = path_distance
			closest_player = player_cryptid
	
	if closest_player:
		print("AI: Found closest player:", closest_player.cryptid.name, 
			  "at position", tile_map_layer.local_to_map(closest_player.position), 
			  "with distance", closest_player_distance)
	else:
		print("AI: No player cryptids found!")
	
	return {
		"cryptid": closest_player,
		"distance": closest_player_distance
	}

# Find a position to retreat to after attacking
func find_retreat_position(enemy_cryptid):
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var best_retreat_pos = null
	var best_safety_score = -999
	
	# Check if top action already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	# Check if bottom action already used
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played
	
	# If both actions used, can't move
	if top_used and bottom_used:
		return null
	
	# Find move cards
	var move_cards = []
	for card in enemy_cryptid.cryptid.deck:
		# Skip cards that aren't in the deck
		if card.current_state != Card.CardState.IN_DECK:
			continue
			
		# Check top of card for moves if top action not used yet
		if !top_used:
			for action in card.top_move.actions:
				if action.action_types.has(0):  # Move action
					move_cards.append({
						"card": card,
						"is_top": true,
						"range": action.amount
					})
		
		# Check bottom of card for moves if bottom action not used yet
		if !bottom_used:
			for action in card.bottom_move.actions:
				if action.action_types.has(0):  # Move action
					move_cards.append({
						"card": card,
						"is_top": false,
						"range": action.amount
					})
	
	# If no move cards available, can't retreat
	if move_cards.size() == 0:
		return null
	
	# Choose the move card with the highest range
	var best_move_card = null
	var best_move_range = 0
	for move_info in move_cards:
		if move_info.range > best_move_range:
			best_move_range = move_info.range
			best_move_card = move_info
	
	# For each walkable hex within move range
	for walkable_hex in tile_map_layer.walkable_hexes:
		# Skip hexes that are already occupied
		var occupied = false
		for cryptid in tile_map_layer.all_cryptids_in_play:
			if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
				occupied = true
				break
		
		if occupied:
			continue
			
		# Calculate if we can move to this hex
		var move_path_result = tile_map_layer.calculate_path(enemy_pos, walkable_hex)
		if move_path_result.path_length <= best_move_range and move_path_result.is_valid_move:
			# Calculate safety score (distance from player cryptids)
			var safety_score = 0
			for player_cryptid in tile_map_layer.player_cryptids_in_play:
				var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
				var player_path_result = tile_map_layer.calculate_path(walkable_hex, player_pos)
				safety_score += player_path_result.path_length
			
			# Prefer positions farther from players
			if safety_score > best_safety_score:
				best_safety_score = safety_score
				best_retreat_pos = {
					"position": walkable_hex,
					"card": best_move_card.card,
					"is_top": best_move_card.is_top,
					"range": best_move_card.range,
					"path_result": move_path_result
				}
	
	return best_retreat_pos

# Perform an attack action
func perform_attack(enemy_cryptid, attack_info):
	print("AI: Performing attack with card:", 
		  attack_info.card.top_move.name_prefix if attack_info.is_top else attack_info.card.bottom_move.name_suffix, 
		  "at range:", attack_info.range, 
		  "against target:", attack_info.target.cryptid.name,
		  "at distance:", attack_info.attack_distance)
	
	# Record the card usage before any operation that might free it
	var card = attack_info.card
	var is_top = attack_info.is_top
	var target_pos = attack_info.target_pos
	var attack_range = attack_info.range
	var attack_distance = attack_info.attack_distance
	
	# Important: Save the currently selected cryptid to restore later
	var previously_selected = tile_map_layer.selected_cryptid
	
	# Explicitly set the target enemy cryptid as the selected one
	print("AI: Setting selected cryptid to", enemy_cryptid.cryptid.name)
	tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Double check the target is in range
	if attack_distance > attack_range:
		print("AI: ERROR - Target out of range, skipping attack")
		# Restore selected cryptid
		tile_map_layer.selected_cryptid = previously_selected
		return
	
	# Create a card dialog instance to use for the attack
	var card_dialog_scene = load("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")
	var card_dialog_instance = card_dialog_scene.instantiate()
	
	# Set the card resource
	card_dialog_instance.card_resource = card
	
	# Set the parent to be the hand (needed for some reference checks)
	hand.add_child(card_dialog_instance)
	
	# Set up the card dialog
	card_dialog_instance.display(card)
	
	# Mark the appropriate half as selected
	if is_top:
		card_dialog_instance.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		card_dialog_instance.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Set the tile map's card_dialog reference to our instance
	tile_map_layer.card_dialog = card_dialog_instance
	
	# Start the attack action
	tile_map_layer.attack_action_bool = true
	tile_map_layer.attack_range = attack_range
	tile_map_layer.attack_action_selected(card_dialog_instance)
	
	# Wait a moment to make sure action is set up
	await get_tree().create_timer(0.3).timeout
	
	# Double-check we're still attacking with the right cryptid
	if tile_map_layer.selected_cryptid != enemy_cryptid:
		print("AI: ERROR - Selected cryptid changed! Restoring correct cryptid.")
		tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Perform the attack
	print("AI: Initiating attack action to position:", target_pos)
	tile_map_layer.handle_attack_action(target_pos)
	
	# Wait for animation to complete
	await get_tree().create_timer(1.0).timeout
	
	# Mark the card as used - use our stored references instead of possibly freed objects
	if is_top:
		enemy_cryptid.cryptid.top_card_played = true
	else:
		enemy_cryptid.cryptid.bottom_card_played = true
	
	# Update card state
	card.current_state = Card.CardState.IN_DISCARD
	
	# Make sure the card is in the discard pile (if not already)
	if not enemy_cryptid.cryptid.discard.has(card):
		enemy_cryptid.cryptid.discard.push_back(card)
	
	print("AI: Attack action completed")
	
	# Restore the previously selected cryptid
	tile_map_layer.selected_cryptid = previously_selected
	print("AI: Restored previously selected cryptid")


# Perform a move action
func perform_move(enemy_cryptid, move_info):
	print("AI: Performing move with card:", 
		move_info.card.top_move.name_prefix if move_info.is_top else move_info.card.bottom_move.name_suffix,
		"to position:", move_info.position)
	
	# Record the card usage before any operation that might free it
	var card = move_info.card
	var is_top = move_info.is_top
	var target_pos = move_info.position
	
	# Important: Save the currently selected cryptid to restore later
	var previously_selected = tile_map_layer.selected_cryptid
	
	# Explicitly set the target enemy cryptid as the selected one
	print("AI: Setting selected cryptid to", enemy_cryptid.cryptid.name)
	tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Ensure move action is reset
	tile_map_layer.move_action_bool = false
	tile_map_layer.attack_action_bool = false
	
	# Wait for a bit to ensure any previous actions are complete
	await get_tree().create_timer(0.2).timeout
	
	# Create a card dialog instance to use for the move
	var card_dialog_scene = load("res://Cryptid-Menagerie/data/cryptids/Cards/card_dialog.tscn")
	var card_dialog_instance = card_dialog_scene.instantiate()
	
	# Set the card resource
	card_dialog_instance.card_resource = card
	
	# Set the parent to be the hand (needed for some reference checks)
	hand.add_child(card_dialog_instance)
	
	# Set up the card dialog
	card_dialog_instance.display(card)
	
	# Mark the appropriate half as selected
	if is_top:
		card_dialog_instance.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		card_dialog_instance.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Set the tile map's card_dialog reference to our instance
	tile_map_layer.card_dialog = card_dialog_instance
	
	# Set up the move action parameters first
	tile_map_layer.move_leftover = move_info.range
	print("AI: Set move_leftover to", move_info.range)
	
	# Force enable the move action explicitly
	tile_map_layer.move_action_bool = true
	tile_map_layer.attack_action_bool = false
	print("AI: Set move_action_bool to true")
	
	# Start the move action
	print("AI: Calling move_action_selected")
	tile_map_layer.move_action_selected(card_dialog_instance)
	
	# Wait a moment to make sure action is set up
	await get_tree().create_timer(0.3).timeout
	
	# Debug action state before move
	print("AI: Pre-move state: move_action_bool =", tile_map_layer.move_action_bool, 
		"move_leftover =", tile_map_layer.move_leftover, 
		"selected_cryptid =", tile_map_layer.selected_cryptid.cryptid.name)
	
	# Double-check we're still moving the right cryptid
	if tile_map_layer.selected_cryptid != enemy_cryptid:
		print("AI: ERROR - Selected cryptid changed! Restoring correct cryptid.")
		tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Perform the move - force calculation of path first
	print("AI: Calculating path from", tile_map_layer.local_to_map(enemy_cryptid.position), "to", target_pos)
	tile_map_layer.calculate_path(tile_map_layer.local_to_map(enemy_cryptid.position), target_pos)
	
	print("AI: Initiating move action to position:", target_pos)
	tile_map_layer.handle_move_action(target_pos)
	
	# Wait for movement animation to complete
	await get_tree().create_timer(1.0).timeout
	
	# Debug position after move attempt
	print("AI: Cryptid position after move:", tile_map_layer.local_to_map(enemy_cryptid.position))
	
	# Mark the card as used - use our stored references instead of possibly freed objects
	if is_top:
		enemy_cryptid.cryptid.top_card_played = true
	else:
		enemy_cryptid.cryptid.bottom_card_played = true
	
	# Update card state
	card.current_state = Card.CardState.IN_DISCARD
	
	# Make sure the card is in the discard pile (if not already)
	if not enemy_cryptid.cryptid.discard.has(card):
		enemy_cryptid.cryptid.discard.push_back(card)
	
	print("AI: Move action completed")
	
	# Restore the previously selected cryptid
	tile_map_layer.selected_cryptid = previously_selected
	print("AI: Restored previously selected cryptid")


# End the current turn
func end_turn(enemy_cryptid):
	print("AI: Ending turn for cryptid:", enemy_cryptid.cryptid.name)
	
	# Mark the cryptid's turn as completed
	enemy_cryptid.cryptid.completed_turn = true
	
	# Move to next cryptid
	hand.next_cryptid_turn()
