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
	
	# Initialize action flags
	var top_action_used = enemy_cryptid.cryptid.top_card_played
	var bottom_action_used = enemy_cryptid.cryptid.bottom_card_played
	
	# First phase: See if we can attack without moving
	if !top_action_used or !bottom_action_used:
		print("AI: Looking for immediate attack opportunities")
		var attack_target = find_attack_target(enemy_cryptid)
		
		if attack_target:
			print("AI: Found immediate attack target:", attack_target.target.cryptid.name)
			perform_attack(enemy_cryptid, attack_target)
			
			# Update which action we used
			if attack_target.is_top:
				top_action_used = true
			else:
				bottom_action_used = true
				
			# Wait for animations to complete
			await get_tree().create_timer(1.0).timeout
		else:
			print("AI: No immediate attack targets found")
	
	# Second phase: See if we can move to attack range
	if !top_action_used or !bottom_action_used:
		print("AI: Looking for move-to-attack opportunities")
		var move_attack_result = find_move_to_attack(enemy_cryptid)
		
		if move_attack_result:
			print("AI: Found move to attack position")
			perform_move(enemy_cryptid, move_attack_result.move_target)
			
			# Update which action we used
			if move_attack_result.move_target.is_top:
				top_action_used = true
			else:
				bottom_action_used = true
				
			# Wait for animations to complete
			await get_tree().create_timer(1.0).timeout
			
			# If we can attack after moving, and we have an action left, do so
			if move_attack_result.can_attack_after_move and (!top_action_used or !bottom_action_used):
				print("AI: Attempting attack after move")
				# Find new attack targets from our new position
				var post_move_attack = find_attack_target(enemy_cryptid)
				if post_move_attack:
					# Make sure we're not trying to use the same half twice
					if (post_move_attack.is_top and !top_action_used) or (!post_move_attack.is_top and !bottom_action_used):
						print("AI: Attacking after move")
						perform_attack(enemy_cryptid, post_move_attack)
						
						# Update which action we used
						if post_move_attack.is_top:
							top_action_used = true
						else:
							bottom_action_used = true
							
						# Wait for animations to complete
						await get_tree().create_timer(1.0).timeout
				else:
					print("AI: No valid attack targets after moving")
		else:
			print("AI: No viable move-to-attack options found")
	
	# Third phase: If we've attacked but not moved, consider retreat
	if (top_action_used or bottom_action_used) and (!top_action_used or !bottom_action_used):
		print("AI: Considering retreat after attack")
		var retreat_target = find_retreat_position(enemy_cryptid)
		if retreat_target:
			# Check if we have the right action type available
			if (retreat_target.is_top and !top_action_used) or (!retreat_target.is_top and !bottom_action_used):
				print("AI: Retreating after attack")
				perform_move(enemy_cryptid, retreat_target)
				
				# Update which action we used
				if retreat_target.is_top:
					top_action_used = true
				else:
					bottom_action_used = true
					
				# Wait for animations to complete
				await get_tree().create_timer(1.0).timeout
	
	# Fourth phase: If we still have actions left and haven't found a good move,
	# consider resting to restore cards
	if !top_action_used and !bottom_action_used:
		print("AI: No good options, resting to restore cards")
		game_controller.perform_rest(enemy_cryptid)
		top_action_used = true
		bottom_action_used = true
	elif !top_action_used or !bottom_action_used:
		print("AI: Still have an unused action, but no good options")
		# We have one action left but nothing good to do with it
		# Just mark it as used so we end the turn
		top_action_used = true
		bottom_action_used = true
	
	# Mark the cryptid's turn as completed
	enemy_cryptid.cryptid.top_card_played = top_action_used
	enemy_cryptid.cryptid.bottom_card_played = bottom_action_used
	enemy_cryptid.cryptid.completed_turn = true
	
	print("AI: Ending turn for cryptid:", enemy_cryptid.cryptid.name)
	
	# Show end turn button
	show_end_turn_button_for_enemy()
	
	# Restore the previously selected cryptid
	tile_map_layer.selected_cryptid = previous_selected

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

func find_move_to_attack(enemy_cryptid):
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	print("AI: Enemy position is", enemy_pos)
	
	# IMPORTANT: Enable the hex occupied by this cryptid on the grid
	var point = tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos, true)
	tile_map_layer.a_star_hex_grid.set_point_disabled(point, false)
	print("AI: Enabled hex at", enemy_pos, "for movement")
	
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
	
	# Store original action state
	var original_move_bool = tile_map_layer.move_action_bool
	var original_attack_bool = tile_map_layer.attack_action_bool
	
	# Set up for path calculation
	tile_map_layer.move_action_bool = true
	tile_map_layer.attack_action_bool = false
	
	# Find the closest player cryptid using A* path distance
	var closest_player = null
	var closest_player_distance = 999
	
	# Debug: print all player cryptids first
	print("AI: All player cryptids:")
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		print("AI: Player:", player_cryptid.cryptid.name, "at position:", player_pos)
	
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		
		# Get the actual path through the A* grid
		var path = tile_map_layer.a_star_hex_grid.get_id_path(
			tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
			tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
		)
		
		# Calculate the actual path distance
		var path_distance = path.size() - 1
		
		print("AI: Path distance to", player_cryptid.cryptid.name, "at", player_pos, "is", path_distance)
		
		if path_distance < closest_player_distance:
			closest_player_distance = path_distance
			closest_player = player_cryptid
			print("AI: New closest player:", player_cryptid.cryptid.name, "at distance", path_distance)
	
	if closest_player:
		print("AI: Final closest player is", closest_player.cryptid.name, 
			  "at position", tile_map_layer.local_to_map(closest_player.position), 
			  "with distance", closest_player_distance)
		
		var player_pos = tile_map_layer.local_to_map(closest_player.position)
		var best_move = null
		var best_distance_to_player = closest_player_distance
		
		# Sort move cards by range to try the furthest moves first
		move_cards.sort_custom(Callable(self, "sort_by_move_range"))
		
		# For each move card
		for move_info in move_cards:
			print("AI: Testing move card with range", move_info.range)
			
			# Set up for movement calculation
			tile_map_layer.move_action_bool = true
			tile_map_layer.attack_action_bool = false
			tile_map_layer.move_leftover = move_info.range
			
			# Get all walkable hexes
			var potential_targets = []
			for walkable_hex in tile_map_layer.walkable_hexes:
				# Skip hexes that are already occupied
				var occupied = false
				for cryptid in tile_map_layer.all_cryptids_in_play:
					if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
						occupied = true
						break
				
				if occupied or walkable_hex == player_pos:
					continue
				
				# Calculate if we can reach this position
				var move_path = tile_map_layer.a_star_hex_grid.get_id_path(
					tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
					tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex)
				)
				
				var move_distance = move_path.size() - 1
				
				# Only consider positions we can actually reach
				if move_distance <= move_info.range:
					# Calculate distance from this hex to the player
					var approach_path = tile_map_layer.a_star_hex_grid.get_id_path(
						tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex),
						tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
					)
					
					var approach_distance = approach_path.size() - 1
					
					print("AI: Position", walkable_hex, "is", move_distance, "moves away, distance to player:", approach_distance)
					
					potential_targets.append({
						"position": walkable_hex,
						"move_distance": move_distance,
						"player_distance": approach_distance
					})
			
			# Sort potential targets by closest to player
			potential_targets.sort_custom(Callable(self, "sort_by_player_distance"))
			
			# Check the best positions
			for target in potential_targets:
				if target.player_distance < best_distance_to_player:
					best_distance_to_player = target.player_distance
					best_move = {
						"position": target.position,
						"card": move_info.card,
						"is_top": move_info.is_top,
						"range": move_info.range,
						"move_distance": target.move_distance
					}
					
					print("AI: New best move to", target.position, "with distance to player", target.player_distance)
					
					# If we found a position that gets us right next to the player, we're done
					if target.player_distance == 1:
						break
			
			# If we found a position that gets us right next to the player, we're done
			if best_distance_to_player == 1:
				break
		
		# Restore original movement state
		tile_map_layer.move_action_bool = original_move_bool
		tile_map_layer.attack_action_bool = original_attack_bool
		
		# If we found a better move
		if best_move and best_distance_to_player < closest_player_distance:
			print("AI: Final best move to", best_move.position, 
				"reduces distance from", closest_player_distance, 
				"to", best_distance_to_player)
			
			return {
				"move_target": best_move,
				"can_attack_after_move": false
			}
	else:
		print("AI: No player cryptids found!")
		# Restore original movement state
		tile_map_layer.move_action_bool = original_move_bool
		tile_map_layer.attack_action_bool = original_attack_bool
	
	return null

# Helper to sort move cards by range
func sort_by_move_range(a, b):
	return a.range > b.range

# Helper to sort positions by distance to player
func sort_by_player_distance(a, b):
	return a.player_distance < b.player_distance


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

# Find a position to retreat to after attacking
func find_retreat_position(enemy_cryptid):
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	print("AI: Calculating retreat from position", enemy_pos)
	
	# Check if top/bottom actions already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played
	
	# Find move cards that we can use for retreat
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
	
	print("AI: Found", move_cards.size(), "available move cards for retreat")
	if move_cards.size() == 0:
		return null
		
	# Find all player cryptids and their positions
	var player_positions = []
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		player_positions.append(tile_map_layer.local_to_map(player_cryptid.position))
	
	print("AI: Player positions for retreat calculation:", player_positions)
	
	# Store original movement state
	var original_move_bool = tile_map_layer.move_action_bool
	var original_attack_bool = tile_map_layer.attack_action_bool
	
	# Set up for movement calculation
	tile_map_layer.move_action_bool = true
	tile_map_layer.attack_action_bool = false
	
	# Find the best retreat position
	var best_retreat_pos = null
	var best_retreat_score = -999
	var best_retreat_move = null
	
	# Sort move cards by range (longer range first)
	move_cards.sort_custom(Callable(self, "sort_by_move_range"))
	
	# For each move card
	for move_info in move_cards:
		print("AI: Testing retreat card with range", move_info.range)
		tile_map_layer.move_leftover = move_info.range
		
		# Get all potential retreat hexes
		var retreat_options = []
		for walkable_hex in tile_map_layer.walkable_hexes:
			# Skip hexes that are already occupied
			var occupied = false
			for cryptid in tile_map_layer.all_cryptids_in_play:
				if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
					occupied = true
					break
			
			if occupied or walkable_hex in player_positions:
				continue
			
			# Check if we can reach this hex
			var move_path = tile_map_layer.a_star_hex_grid.get_id_path(
				tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
				tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex)
			)
			
			var move_distance = move_path.size() - 1
			
			# Only consider positions we can actually reach
			if move_distance <= move_info.range:
				# Calculate safety score - the farther from all players, the better
				var safety_score = 0
				for player_pos in player_positions:
					var approach_path = tile_map_layer.a_star_hex_grid.get_id_path(
						tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex),
						tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
					)
					
					var distance_to_player = approach_path.size() - 1
					safety_score += distance_to_player  # Higher is better
				
				print("AI: Retreat position", walkable_hex, "has safety score", safety_score)
				
				retreat_options.append({
					"position": walkable_hex,
					"safety_score": safety_score,
					"move_distance": move_distance
				})
		
		# Find the best retreat option for this card
		for option in retreat_options:
			if option.safety_score > best_retreat_score:
				best_retreat_score = option.safety_score
				best_retreat_pos = option.position
				best_retreat_move = {
					"position": option.position,
					"card": move_info.card,
					"is_top": move_info.is_top,
					"range": move_info.range,
					"move_distance": option.move_distance
				}
				
				print("AI: New best retreat at", option.position, "with safety score", option.safety_score)
	
	# Restore original movement state
	tile_map_layer.move_action_bool = original_move_bool
	tile_map_layer.attack_action_bool = original_attack_bool
	
	if best_retreat_move:
		print("AI: Final retreat position is", best_retreat_move.position, "with safety score", best_retreat_score)
	else:
		print("AI: No viable retreat positions found")
		
	return best_retreat_move
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
