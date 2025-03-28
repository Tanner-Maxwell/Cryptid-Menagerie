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
	
	# Initialize action flags - this is key to tracking usage properly
	var top_action_used = enemy_cryptid.cryptid.top_card_played
	var bottom_action_used = enemy_cryptid.cryptid.bottom_card_played
	
	print("AI: Starting turn with top_action_used =", top_action_used, ", bottom_action_used =", bottom_action_used)
	
	# First phase: See if we can attack without moving
	if !top_action_used or !bottom_action_used:
		print("AI: Looking for immediate attack opportunities")
		var attack_target = find_attack_target(enemy_cryptid)
		
		if attack_target:
			print("AI: Found immediate attack target:", attack_target.target.cryptid.name)
			perform_attack(enemy_cryptid, attack_target)
			
			# Update which action we used and ensure cryptid state is updated
			if attack_target.is_top:
				top_action_used = true
				enemy_cryptid.cryptid.top_card_played = true
				print("AI: Used top attack action")
			else:
				bottom_action_used = true
				enemy_cryptid.cryptid.bottom_card_played = true
				print("AI: Used bottom attack action")
				
			# Wait for animations to complete
			await get_tree().create_timer(0.5).timeout
		else:
			print("AI: No immediate attack targets found")
	
	# Second phase: See if we can move to get closer
	if !top_action_used or !bottom_action_used:
		print("AI: Looking for move opportunities")
		var move_result = find_move_to_attack(enemy_cryptid)
		
		if move_result:
			print("AI: Found move to get closer to player")
			perform_move(enemy_cryptid, move_result.move_target)
			
			# Update which action we used and ensure cryptid state is updated
			if move_result.move_target.is_top:
				top_action_used = true
				enemy_cryptid.cryptid.top_card_played = true
				print("AI: Used top move action")
			else:
				bottom_action_used = true
				enemy_cryptid.cryptid.bottom_card_played = true
				print("AI: Used bottom move action")
				
			# Wait for movement animation to complete with proper polling
			print("AI: Waiting for movement animation to complete...")
			var timeout_counter = 0
			while tile_map_layer.movement_in_progress and timeout_counter < 50:
				await get_tree().process_frame
				timeout_counter += 1
				if timeout_counter % 10 == 0:
					print("AI: Still waiting for movement to finish...")

			# Add a safety delay to ensure any animation state is fully reset
			await get_tree().create_timer(1.0).timeout
			
			# After waiting for movement to complete
			print("AI: Movement finished, cryptid at position:", tile_map_layer.local_to_map(enemy_cryptid.position))

			# IMPORTANT: Re-get the enemy position AFTER movement
			enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
			print("AI: New position after move:", enemy_pos)
			
			# IMPORTANT: Check for attack opportunities AFTER moving
			if !top_action_used or !bottom_action_used:
				print("AI: Checking for attack opportunities after moving")
				var post_move_attack = find_attack_target(enemy_cryptid)
				
				if post_move_attack:
					# Check if we have the right action type available
					if (post_move_attack.is_top and !top_action_used) or (!post_move_attack.is_top and !bottom_action_used):
						print("AI: Found attack opportunity after moving!")
						perform_attack(enemy_cryptid, post_move_attack)
						
						# Update which action we used and ensure cryptid state is updated
						if post_move_attack.is_top:
							top_action_used = true
							enemy_cryptid.cryptid.top_card_played = true
							print("AI: Used top attack action after move")
						else:
							bottom_action_used = true
							enemy_cryptid.cryptid.bottom_card_played = true
							print("AI: Used bottom attack action after move")
							
						# Wait for animations to complete
						await get_tree().create_timer(1.0).timeout
				else:
					print("AI: No attack opportunities found after moving")
		else:
			print("AI: No viable move options found")
	
	# Third phase: If we've attacked but not moved, consider retreat
	if (top_action_used or bottom_action_used) and (!top_action_used or !bottom_action_used):
		print("AI: Considering retreat after attack")
		var retreat_target = find_retreat_position(enemy_cryptid)
		if retreat_target:
			# Reset any ongoing movement state before retreat
			tile_map_layer.move_action_bool = false
			tile_map_layer.attack_action_bool = false
			tile_map_layer.active_movement_card = null
			tile_map_layer.active_movement_card_part = ""
			tile_map_layer.move_leftover = 0
			
			# Check if we have the right action type available
			if (retreat_target.is_top and !top_action_used) or (!retreat_target.is_top and !bottom_action_used):
				print("AI: Retreating after attack")
				
				# Validate the target position is not disabled
				var target_point = tile_map_layer.a_star_hex_grid.get_closest_point(retreat_target.position, true)
				if tile_map_layer.a_star_hex_grid.is_point_disabled(target_point):
					print("AI: WARNING - Retreat target is disabled, enabling for movement attempt")
					tile_map_layer.set_point_disabled(target_point, false)
					
					# Force update debug display
					tile_map_layer.update_all_debug_indicators()
				
				# Delay to ensure everything is reset
				await get_tree().create_timer(0.5).timeout
			
			# Perform the retreat
			perform_move(enemy_cryptid, retreat_target)
			
			# Update which action we used and ensure cryptid state is updated
			if retreat_target.is_top:
				top_action_used = true
				enemy_cryptid.cryptid.top_card_played = true
				print("AI: Used top move action for retreat")
			else:
				bottom_action_used = true
				enemy_cryptid.cryptid.bottom_card_played = true
				print("AI: Used bottom move action for retreat")
				
			# Wait for animations to complete
			await get_tree().create_timer(1.0).timeout
					
	
	# Double-check that our local tracking vars match the cryptid state
	if top_action_used != enemy_cryptid.cryptid.top_card_played:
		print("AI: WARNING - Mismatch in top action tracking. Setting cryptid.top_card_played =", top_action_used)
		enemy_cryptid.cryptid.top_card_played = top_action_used
	
	if bottom_action_used != enemy_cryptid.cryptid.bottom_card_played:
		print("AI: WARNING - Mismatch in bottom action tracking. Setting cryptid.bottom_card_played =", bottom_action_used)
		enemy_cryptid.cryptid.bottom_card_played = bottom_action_used
	
	# Fourth phase: If we still have actions left and haven't found a good move,
	# consider resting to restore cards
	if !top_action_used and !bottom_action_used:
		print("AI: No good options, resting to restore cards")
		game_controller.perform_rest()
		top_action_used = true
		bottom_action_used = true
		enemy_cryptid.cryptid.top_card_played = true
		enemy_cryptid.cryptid.bottom_card_played = true
	elif !top_action_used or !bottom_action_used:
		print("AI: Still have an unused action, but no good options")
		# We have one action left but nothing good to do with it
		# Just mark it as used so we end the turn
		enemy_cryptid.cryptid.top_card_played = true
		enemy_cryptid.cryptid.bottom_card_played = true
		top_action_used = true
		bottom_action_used = true
	
	# Final check to ensure consistency
	print("AI: End of turn state - top_action_used =", top_action_used, 
		  "bottom_action_used =", bottom_action_used,
		  "cryptid.top_card_played =", enemy_cryptid.cryptid.top_card_played,
		  "cryptid.bottom_card_played =", enemy_cryptid.cryptid.bottom_card_played)
	
	# Mark the cryptid's turn as completed
	enemy_cryptid.cryptid.completed_turn = true
	
	# Reset card action values for this cryptid
	if tile_map_layer and tile_map_layer.has_method("reset_card_action_values"):
		print("AI: Resetting card action values at end of turn")
		tile_map_layer.reset_card_action_values(enemy_cryptid.cryptid)
	
	enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	point = tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos, false)
	var point_two = tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos, true)
	
	if point == point_two:
		tile_map_layer.a_star_hex_grid.set_point_disabled(point, true)
	
	# Show the End Turn button for the player to proceed
	show_end_turn_button_for_enemy()
	# Restore the previously selected cryptid
	tile_map_layer.selected_cryptid = previous_selected


# Show the end turn button and wait for player to press it
func show_end_turn_button_for_enemy():
	print("AI: Showing end turn button for enemy")
	
	# Get the action menu
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		# Use the new function to show only the End Turn button
		if action_menu.has_method("show_end_turn_only"):
			action_menu.show_end_turn_only()
		else:
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
# Find closest player cryptid that can be attacked
func find_attack_target(enemy_cryptid):
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	print("AI: Checking attack options from", enemy_pos)
	
	var closest_target = null
	var closest_distance = 999
	
	# Check if top action already used
	var top_used = enemy_cryptid.cryptid.top_card_played
	# Check if bottom action already used
	var bottom_used = enemy_cryptid.cryptid.bottom_card_played
	
	# If both actions used, can't attack
	if top_used and bottom_used:
		print("AI: Both actions already used, can't attack")
		return null
	
	# Determine appropriate targets based on team
	var valid_targets = []
	if enemy_cryptid in tile_map_layer.enemy_cryptids_in_play:
		# Enemy is attacking player cryptids
		valid_targets = tile_map_layer.player_cryptids_in_play
		print("AI: Enemy cryptid looking for player targets, found", valid_targets.size(), "potential targets")
	else:
		# Player is attacking enemy cryptids
		valid_targets = tile_map_layer.enemy_cryptids_in_play
		print("AI: Player cryptid looking for enemy targets, found", valid_targets.size(), "potential targets")
	
	# If no valid targets, return null
	if valid_targets.size() == 0:
		print("AI: No valid targets found")
		return null
	
	# Store original action state
	var original_move_bool = tile_map_layer.move_action_bool
	var original_attack_bool = tile_map_layer.attack_action_bool
	
	# Set up for attack calculation
	tile_map_layer.move_action_bool = false
	tile_map_layer.attack_action_bool = true
	
	# Examine each valid target
	for target_cryptid in valid_targets:
		var target_pos = tile_map_layer.local_to_map(target_cryptid.position)
		
		# Verify the target position is valid
		if not tile_map_layer.a_star_hex_attack_grid.has_point(
			tile_map_layer.a_star_hex_attack_grid.get_closest_point(target_pos)
		):
			print("AI: Target position not found in pathfinding grid, skipping")
			continue
		
		# Get the actual path through the A* grid
		var path = tile_map_layer.a_star_hex_attack_grid.get_id_path(
			tile_map_layer.a_star_hex_attack_grid.get_closest_point(enemy_pos),
			tile_map_layer.a_star_hex_attack_grid.get_closest_point(target_pos)
		)
		
		# If path is empty, skip this target
		if path.size() == 0:
			print("AI: No valid path to target at", target_pos, ", skipping")
			continue
		
		print("AI: Checking target", target_cryptid.cryptid.name, "at position", target_pos)
		
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
						print(path)
						# Calculate attack distance
						var attack_distance = path.size() - 1
						
						print("AI: Card", card.top_move.name_prefix, "attack range:", attack_range, "actual distance:", attack_distance)
						
						if attack_distance <= attack_range:
							# Found a valid attack target in range
							if attack_distance < closest_distance:
								closest_distance = attack_distance
								closest_target = {
									"target": target_cryptid,
									"card": card,
									"is_top": true,
									"range": attack_range,
									"damage": action.amount,
									"attack_distance": attack_distance,
									"target_pos": target_pos
								}
								print("AI: Found valid top attack at distance", attack_distance)
			
			# Check bottom of card for attacks if bottom action not used yet
			if !bottom_used:
				for action in card.bottom_move.actions:
					if action.action_types.has(1):  # Attack action
						var attack_range = action.range
						print(path)
						# Calculate attack distance
						var attack_distance = path.size() - 1
						
						print("AI: Card", card.bottom_move.name_suffix, "attack range:", attack_range, "actual distance:", attack_distance)
						
						if attack_distance <= attack_range:
							# Found a valid attack target in range
							if attack_distance < closest_distance:
								closest_distance = attack_distance
								closest_target = {
									"target": target_cryptid,
									"card": card,
									"is_top": false,
									"range": attack_range,
									"damage": action.amount,
									"attack_distance": attack_distance,
									"target_pos": target_pos
								}
								print("AI: Found valid bottom attack at distance", attack_distance)
	
	# Restore original state
	tile_map_layer.move_action_bool = original_move_bool
	tile_map_layer.attack_action_bool = original_attack_bool
	
	# Final validation before returning
	if closest_target != null:
		print("AI: Best attack target found:", closest_target.target.cryptid.name, 
			  "distance:", closest_target.attack_distance,
			  "using", "top" if closest_target.is_top else "bottom", "action")
		
		# Double check target still exists and is valid
		if closest_target.target in valid_targets:
			var final_check_pos = tile_map_layer.local_to_map(closest_target.target.position)
			if final_check_pos == closest_target.target_pos:
				return closest_target
			else:
				print("AI: ERROR - Target position changed, invalidating attack")
				return null
		else:
			print("AI: ERROR - Target no longer valid")
			return null
	else:
		print("AI: No valid attack targets found within range")
	
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
		
		# Before returning the best move, add this verification
		if best_move:
			# Verify the position is still walkable
			var is_target_walkable = best_move.position in tile_map_layer.walkable_hexes
			var is_target_disabled = false
			
			# Check if the point is disabled
			point = tile_map_layer.a_star_hex_grid.get_closest_point(best_move.position, true)
			is_target_disabled = tile_map_layer.a_star_hex_grid.is_point_disabled(point)
			
			# Debug output
			print("AI: Checking if target position", best_move.position, "is valid:")
			print("  In walkable_hexes:", is_target_walkable)
			print("  Point disabled:", is_target_disabled)
			
			# If the target point is disabled or not walkable, we can't move there
			if is_target_disabled or not is_target_walkable:
				print("AI: Target position is not valid, cannot move there")
				return null
			
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
			
			# Check if the point is disabled in the grid
			var hex_point = tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex, true)
			if tile_map_layer.a_star_hex_grid.is_point_disabled(hex_point):
				print("AI: Skipping disabled position", walkable_hex)
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
	
	# Final validation - check that the point is not disabled
	if best_retreat_move:
		var point = tile_map_layer.a_star_hex_grid.get_closest_point(best_retreat_move.position, true)
		if tile_map_layer.a_star_hex_grid.is_point_disabled(point):
			print("AI: WARNING - Selected retreat position is disabled! Trying to fix...")
			
			# Try to fix it
			tile_map_layer.set_point_disabled(point, false)
			
			# Double-check it was fixed
			if tile_map_layer.a_star_hex_grid.is_point_disabled(point):
				print("AI: ERROR - Could not enable retreat position, finding alternative")
				
				# Find the next best option that's not disabled
				var second_best = null
				var second_best_score = -999
				
				for move_info in move_cards:
					for walkable_hex in tile_map_layer.walkable_hexes:
						# Skip hexes that are already occupied
						var occupied = false
						for cryptid in tile_map_layer.all_cryptids_in_play:
							if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
								occupied = true
								break
						
						if occupied or walkable_hex in player_positions:
							continue
						
						# Skip the disabled best position
						if walkable_hex == best_retreat_pos:
							continue
						
						# Check if the point is disabled
						point = tile_map_layer.a_star_hex_grid.get_closest_point(walkable_hex, true)
						if tile_map_layer.a_star_hex_grid.is_point_disabled(point):
							continue
						
						# Only consider positions we can reach
						var path = tile_map_layer.a_star_hex_grid.get_id_path(
							tile_map_layer.a_star_hex_grid.get_closest_point(enemy_pos),
							point
						)
						
						if path.size() - 1 <= move_info.range:
							# Calculate safety score
							var safety_score = 0
							for player_pos in player_positions:
								var player_point = tile_map_layer.a_star_hex_grid.get_closest_point(player_pos)
								var distance = tile_map_layer.a_star_hex_grid.get_id_path(point, player_point).size() - 1
								safety_score += distance
							
							if safety_score > second_best_score:
								second_best_score = safety_score
								second_best = {
									"position": walkable_hex,
									"card": move_info.card,
									"is_top": move_info.is_top,
									"range": move_info.range,
									"move_distance": path.size() - 1
								}
				
				if second_best:
					print("AI: Using alternative retreat position with score", second_best_score)
					best_retreat_move = second_best
				else:
					print("AI: No viable retreat options found")
					return null
		
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
	
	# IMPORTANT: Verify the target exists before proceeding
	var target_cryptid = tile_map_layer.get_cryptid_at_position(target_pos)
	if target_cryptid == null:
		print("AI: ERROR - No valid target at position", target_pos, ", skipping attack")
		return
	
	# Check if target is valid (enemy attacking player or player attacking enemy)
	var is_valid_target = false
	if enemy_cryptid in tile_map_layer.enemy_cryptids_in_play and target_cryptid in tile_map_layer.player_cryptids_in_play:
		is_valid_target = true
	elif enemy_cryptid in tile_map_layer.player_cryptids_in_play and target_cryptid in tile_map_layer.enemy_cryptids_in_play:
		is_valid_target = true
		
	if not is_valid_target:
		print("AI: ERROR - Invalid target (cannot attack own team), skipping attack")
		return
	
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
	var attack_successful = tile_map_layer.handle_attack_action(target_pos)
	
	# Important: Check if the attack was actually performed before marking as used
	if attack_successful:
		print("AI: Attack was successful, marking card as used")
		# Mark the card as used - use our stored references instead of possibly freed objects
		if is_top:
			enemy_cryptid.cryptid.top_card_played = true
			print("AI: Marked top card as played")
		else:
			enemy_cryptid.cryptid.bottom_card_played = true
			print("AI: Marked bottom card as played")
	else:
		print("AI: Attack was not successful, not marking as used")
	
	# Wait for animation to complete
	await get_tree().create_timer(1.0).timeout
	
	# Update card state
	card.current_state = Card.CardState.IN_DISCARD
	
	# Make sure the card is in the discard pile (if not already)
	if not enemy_cryptid.cryptid.discard.has(card):
		enemy_cryptid.cryptid.discard.push_back(card)
	
	print("AI: Attack action completed")
	
	## Restore the previously selected cryptid
	#tile_map_layer.selected_cryptid = previously_selected
	#print("AI: Restored previously selected cryptid")



func perform_move(enemy_cryptid, move_info):
	print("AI: Performing move with card:", 
		move_info.card.top_move.name_prefix if move_info.is_top else move_info.card.bottom_move.name_suffix,
		"to position:", move_info.position)
	
	# Record the card usage before any operation that might free it
	var card = move_info.card
	var is_top = move_info.is_top
	var target_pos = move_info.position
	
	# Store original movement amount before any changes are made
	var original_amount = 0
	if is_top:
		for action in card.top_move.actions:
			if action.action_types == [0]:  # Move action
				original_amount = action.amount
				if not card.has_meta("original_move_amount"):
					card.set_meta("original_move_amount", action.amount)
					print("AI: Storing original top movement amount: " + str(action.amount))
	else:
		for action in card.bottom_move.actions:
			if action.action_types == [0]:  # Move action
				original_amount = action.amount
				if not card.has_meta("original_move_amount"):
					card.set_meta("original_move_amount", action.amount)
					print("AI: Storing original bottom movement amount: " + str(action.amount))
	
	# Important: Save the currently selected cryptid to restore later
	var previously_selected = tile_map_layer.selected_cryptid
	
	# Save original cryptid position to check if move was successful
	var original_position = enemy_cryptid.position
	
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
		"selected_cryptid =", tile_map_layer.selected_cryptid)
	
	# Double-check we're still moving the right cryptid
	if tile_map_layer.selected_cryptid != enemy_cryptid:
		print("AI: ERROR - Selected cryptid changed! Restoring correct cryptid.")
		tile_map_layer.selected_cryptid = enemy_cryptid
	
	# Perform the move - force calculation of path first
	print("AI: Calculating path from", tile_map_layer.local_to_map(enemy_cryptid.position), "to", target_pos)
	tile_map_layer.calculate_path(tile_map_layer.local_to_map(enemy_cryptid.position), target_pos)
	
	print("AI: Initiating move action to position:", target_pos)
	var move_success = tile_map_layer.handle_move_action(target_pos)
	
	# Wait for movement animation to complete
	await get_tree().create_timer(1.0).timeout
	
	# Check if the move was successful by comparing positions
	var new_position = enemy_cryptid.position
	var move_performed = original_position != new_position
	
	# Debug position after move attempt
	print("AI: Cryptid position after move:", tile_map_layer.local_to_map(enemy_cryptid.position))
	print("AI: Move successful:", move_performed)
	
	# IMPORTANT: If move was not successful, we need to clean up
	if !move_performed:
		print("AI: Move was not successful, cleaning up target position")
		# Re-enable the target position that was disabled
		var point = tile_map_layer.a_star_hex_grid.get_closest_point(target_pos, true)
		tile_map_layer.set_point_disabled(point, false)
		
		# Force update debug display
		tile_map_layer.update_all_debug_indicators()
	
	if move_performed:
		# Mark the card as used - use our stored references instead of possibly freed objects
		if is_top:
			enemy_cryptid.cryptid.top_card_played = true
			print("AI: Marked top card as played for movement")
		else:
			enemy_cryptid.cryptid.bottom_card_played = true
			print("AI: Marked bottom card as played for movement")
	else:
		print("AI: Move was not successful, not marking as used")
	
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
