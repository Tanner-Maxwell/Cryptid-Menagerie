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
	game_controller = get_node("/root/VitaChrome/GameController")
	hand = get_node("/root/VitaChrome/UIRoot/Hand")

# Main function to handle an enemy cryptid's turn
func take_enemy_turn(enemy_cryptid):
	print("AI: Taking turn for enemy cryptid: ", enemy_cryptid.cryptid.name)
	
	# Set the selected cryptid in the hand and tile map layer
	var previous_selected = tile_map_layer.selected_cryptid
	tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Check if this cryptid has already completed its turn
	if enemy_cryptid.cryptid.completed_turn:
		print("AI: Cryptid already completed turn, skipping")
		end_turn(enemy_cryptid)
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
		
		end_turn(enemy_cryptid)
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
		
		end_turn(enemy_cryptid)
		return
	
	# 3. If no good attack options, rest to restore cards
	print("AI: No good options, resting")
	perform_rest(enemy_cryptid)
	end_turn(enemy_cryptid)
	
	# Restore the previously selected cryptid
	tile_map_layer.selected_cryptid = previous_selected

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
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	print("AI: Enemy position is", enemy_pos)
	
	# Check if top action already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	# Check if bottom action already used
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played
	
	# If both actions used, can't move or attack
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
	
	# If no move cards, can't do this strategy
	if move_cards.size() == 0:
		print("AI: No move cards available")
		return null
	
	# Get the closest player cryptid using our helper function
	var closest_player_info = find_closest_player_cryptid(enemy_pos)
	var closest_player = closest_player_info.cryptid
	var closest_player_distance = closest_player_info.distance
	
	# If we found a player to approach
	if closest_player:
		var player_pos = tile_map_layer.local_to_map(closest_player.position)
		var best_approach_pos = null
		var best_approach_move = null
		var best_approach_distance = closest_player_distance  # Start with current distance
		
		# For each move card, find the best position to move closer
		for move_info in move_cards:
			print("AI: Checking move card with range", move_info.range)
			
			# Get all positions that are exactly within our movement range
			var positions_in_range = []
			
			# First, get all walkable hexes
			for walkable_hex in tile_map_layer.walkable_hexes:
				# Skip hexes that are already occupied
				var occupied = false
				for cryptid in tile_map_layer.all_cryptids_in_play:
					if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
						occupied = true
						break
				
				if occupied:
					continue
					
				# Skip if this is the same position as a player
				if walkable_hex == player_pos:
					continue
				
				# Calculate the exact path length from our position to this hex
				var move_path = tile_map_layer.a_star_hex_grid.get_id_path(
					tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
					tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex)
				)
				
				# Calculate actual distance using path length
				var actual_distance = move_path.size() - 1
				
				# Debug output for positions that are potentially in range
				if actual_distance <= move_info.range:
					print("AI: Position", walkable_hex, "is", actual_distance, "moves away (range:", move_info.range, ")")
					positions_in_range.append({
						"position": walkable_hex,
						"distance": actual_distance
					})
			
			# Now check each position in range to find the closest to a player
			for pos_data in positions_in_range:
				var pos = pos_data.position
				
				# Calculate distance from this hex to the player
				var approach_path = tile_map_layer.a_star_hex_grid.get_id_path(
					tile_map_layer.a_star_hex_grid.get_closest_point(pos),
					tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
				)
				
				# Print the full path for debugging
				var path_positions = []
				for point_id in approach_path:
					path_positions.append(tile_map_layer.a_star_hex_grid.get_point_position(point_id))
				
				print("AI: Path from", pos, "to player at", player_pos, ":", path_positions)
				
				var approach_distance = approach_path.size() - 1
				
				# Also calculate using cube distance for comparison
				var pos_cube = tile_map_layer.axial_to_cube(pos)
				var player_pos_cube = tile_map_layer.axial_to_cube(player_pos)
				var cube_dist = tile_map_layer.cube_distance(pos_cube, player_pos_cube)
				
				print("AI: Path distance:", approach_distance, "Cube distance:", cube_dist)
				
				# Use the cube distance as it's more reliable for hex grids
				approach_distance = cube_dist
				
				# If this gets us closer, it's a candidate
				if approach_distance < best_approach_distance:
					print("AI: Found better approach position at", pos, 
						"with distance", approach_distance, 
						"(current is", best_approach_distance, ")")
					
					best_approach_distance = approach_distance
					best_approach_pos = pos
					best_approach_move = {
						"position": pos,
						"card": move_info.card,
						"is_top": move_info.is_top,
						"range": move_info.range,
						"move_distance": pos_data.distance  # Actual distance calculated earlier
					}
		
		# If we found a better position
		if best_approach_move and best_approach_distance < closest_player_distance:
			print("AI: Found move to approach player from distance", 
				closest_player_distance, "to", best_approach_distance,
				"(moving to", best_approach_move.position, ")")
			
			return {
				"move_target": best_approach_move,
				"can_attack_after_move": false
			}
		else:
			print("AI: No better position found than current position")
	
	# No good moves found
	return null
	
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
	
	# Double check the target is in range
	if attack_distance > attack_range:
		print("AI: ERROR - Target out of range, skipping attack")
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
	await get_tree().process_frame
	
	# Perform the attack - after this point, card_dialog_instance might be freed
	print("AI: Initiating attack action to position:", target_pos)
	tile_map_layer.handle_attack_action(target_pos)
	
	# Wait a moment for any animations to finish
	await get_tree().create_timer(0.5).timeout
	
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


# Perform a move action
func perform_move(enemy_cryptid, move_info):
	print("AI: Performing move with card:", 
		move_info.card.top_move.name_prefix if move_info.is_top else move_info.card.bottom_move.name_suffix,
		"to position:", move_info.position)
	
	# Record the card usage before any operation that might free it
	var card = move_info.card
	var is_top = move_info.is_top
	var target_pos = move_info.position
	
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
		"move_leftover =", tile_map_layer.move_leftover)
	
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

# Perform rest action to recover cards
func perform_rest(enemy_cryptid):
	print("AI: Performing rest for cryptid:", enemy_cryptid.cryptid.name)
	
	# Reset all card states to IN_DECK
	for card in enemy_cryptid.cryptid.deck:
		card.current_state = Card.CardState.IN_DECK
	
	# Mark both actions as used
	enemy_cryptid.cryptid.top_card_played = true
	enemy_cryptid.cryptid.bottom_card_played = true
	
	# Mark turn as completed
	enemy_cryptid.cryptid.completed_turn = true


# End the current turn
func end_turn(enemy_cryptid):
	print("AI: Ending turn for cryptid:", enemy_cryptid.cryptid.name)
	
	# Mark the cryptid's turn as completed
	enemy_cryptid.cryptid.completed_turn = true
	
	# Move to next cryptid
	hand.next_cryptid_turn()
