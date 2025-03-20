class_name EnemyAIController
extends Node

# References to key game components
var tile_map_layer
var hand
var game_controller

# Settings for AI behavior
@export var attack_priority_weight: float = 2.0
@export var move_priority_weight: float = 1.5 
@export var rest_priority_weight: float = 1.0
@export var retreat_priority_weight: float = 1.2
@export var attack_after_move_weight: float = 1.8
@export var retreat_after_attack_weight: float = 1.6

# Current enemy cryptid being controlled
var current_enemy_cryptid = null

func _ready():
	# Get references to necessary nodes
	tile_map_layer = get_node("%TileMapLayer")
	hand = get_node("%Hand")
	game_controller = get_node("%GameController")

# Calculate hexagon distance (using cube coordinates for hexes)
func calculate_hex_distance(hex1, hex2):
	# Convert to cube coordinates
	var cube1 = tile_map_layer.axial_to_cube(hex1)
	var cube2 = tile_map_layer.axial_to_cube(hex2)
	
	# Calculate distance using cube coordinates
	return tile_map_layer.cube_distance(cube1, cube2)

# Calculate the best position to move to when approaching a player
func calculate_best_move_position(enemy_pos, player_pos, move_amount):
	# First convert to cube coordinates
	var enemy_cube = tile_map_layer.axial_to_cube(enemy_pos)
	var player_cube = tile_map_layer.axial_to_cube(player_pos)
	
	# Calculate vector from enemy to player
	var dir_cube = Vector3i(
		player_cube.x - enemy_cube.x,
		player_cube.y - enemy_cube.y,
		player_cube.z - enemy_cube.z
	)
	
	# Normalize the direction vector to unit length in cube space
	var length = tile_map_layer.cube_distance(Vector3i(0,0,0), dir_cube)
	if length == 0:
		return enemy_pos  # Already at player position
	
	# Calculate ideal distance (try to stay at range 2 if possible)
	var target_distance = 2
	var current_distance = tile_map_layer.cube_distance(enemy_cube, player_cube)
	
	# If we're further than move_amount + target_distance, move as close as possible
	if current_distance > move_amount + target_distance:
		# Move full amount toward player
		var move_pct = float(move_amount) / length
		var new_cube = Vector3i(
			enemy_cube.x + int(dir_cube.x * move_pct),
			enemy_cube.y + int(dir_cube.y * move_pct),
			enemy_cube.z + int(dir_cube.z * move_pct)
		)
		
		# Convert back to axial coordinates
		var new_pos = tile_map_layer.cube_to_axial(new_cube)
		
		# Check if the position is walkable
		if new_pos in tile_map_layer.walkable_hexes:
			return new_pos
	# If we can reach target_distance, do that
	elif current_distance > target_distance:
		var move_pct = float(current_distance - target_distance) / length
		var new_cube = Vector3i(
			enemy_cube.x + int(dir_cube.x * move_pct),
			enemy_cube.y + int(dir_cube.y * move_pct),
			enemy_cube.z + int(dir_cube.z * move_pct)
		)
		
		# Convert back to axial coordinates
		var new_pos = tile_map_layer.cube_to_axial(new_cube)
		
		# Check if the position is walkable
		if new_pos in tile_map_layer.walkable_hexes:
			return new_pos
	
	# If the ideal position isn't walkable or other logic failed, 
	# find the best walkable hex within move range
	var best_pos = enemy_pos
	var best_score = -999
	
	# Check all walkable hexes within range
	for walkable_hex in tile_map_layer.walkable_hexes:
		var hex_cube = tile_map_layer.axial_to_cube(walkable_hex)
		var distance_from_enemy = tile_map_layer.cube_distance(enemy_cube, hex_cube)
		
		# Skip if out of move range
		if distance_from_enemy > move_amount:
			continue
			
		# Skip if occupied by another cryptid
		var is_occupied = false
		for cryptid in tile_map_layer.all_cryptids_in_play:
			if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
				is_occupied = true
				break
		
		if is_occupied:
			continue
			
		# Score this position
		var distance_to_player = tile_map_layer.cube_distance(hex_cube, player_cube)
		var score = 0
		
		# Prefer positions closer to target_distance from player
		score -= abs(distance_to_player - target_distance)
		
		# Tie-breaker: prefer positions that use more of our movement
		score += 0.1 * distance_from_enemy
		
		if score > best_score:
			best_score = score
			best_pos = walkable_hex
	
	return best_pos

# Calculate position for moving into attack range
func calculate_move_position_for_attack(enemy_pos, player_pos, move_amount, attack_range):
	# First convert to cube coordinates
	var enemy_cube = tile_map_layer.axial_to_cube(enemy_pos)
	var player_cube = tile_map_layer.axial_to_cube(player_pos)
	
	# Current distance to player
	var current_distance = tile_map_layer.cube_distance(enemy_cube, player_cube)
	
	# If already in range, don't move
	if current_distance <= attack_range:
		return enemy_pos
	
	# Calculate vector from enemy to player
	var dir_cube = Vector3i(
		player_cube.x - enemy_cube.x,
		player_cube.y - enemy_cube.y,
		player_cube.z - enemy_cube.z
	)
	
	# Normalize the direction vector to unit length in cube space
	var length = tile_map_layer.cube_distance(Vector3i(0,0,0), dir_cube)
	if length == 0:
		return enemy_pos  # Already at player position
	
	# Try to move just enough to get within attack range
	var target_distance = attack_range
	
	# If we can reach target_distance, do that
	if current_distance - move_amount <= target_distance:
		var move_pct = float(current_distance - target_distance) / length
		var new_cube = Vector3i(
			enemy_cube.x + int(dir_cube.x * move_pct),
			enemy_cube.y + int(dir_cube.y * move_pct),
			enemy_cube.z + int(dir_cube.z * move_pct)
		)
		
		# Convert back to axial coordinates
		var new_pos = tile_map_layer.cube_to_axial(new_cube)
		
		# Check if the position is walkable
		if new_pos in tile_map_layer.walkable_hexes:
			return new_pos
	
	# If the ideal position isn't walkable or we can't reach target distance,
	# find the best walkable hex within move range
	var best_pos = enemy_pos
	var best_score = -999
	
	# Check all walkable hexes within range
	for walkable_hex in tile_map_layer.walkable_hexes:
		var hex_cube = tile_map_layer.axial_to_cube(walkable_hex)
		var distance_from_enemy = tile_map_layer.cube_distance(enemy_cube, hex_cube)
		
		# Skip if out of move range
		if distance_from_enemy > move_amount:
			continue
			
		# Skip if occupied by another cryptid
		var is_occupied = false
		for cryptid in tile_map_layer.all_cryptids_in_play:
			if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
				is_occupied = true
				break
		
		if is_occupied:
			continue
			
		# Score this position
		var distance_to_player = tile_map_layer.cube_distance(hex_cube, player_cube)
		var score = 0
		
		# Best if just within attack range
		if distance_to_player <= attack_range:
			score += 10
			# Prefer being at max attack range for safety
			score -= (attack_range - distance_to_player)
		else:
			# If can't get in range, get as close as possible
			score -= (distance_to_player - attack_range)
		
		if score > best_score:
			best_score = score
			best_pos = walkable_hex
	
	return best_pos

# Calculate position for retreating from player
func calculate_retreat_position(enemy_pos, player_pos, move_amount):
	# First convert to cube coordinates
	var enemy_cube = tile_map_layer.axial_to_cube(enemy_pos)
	var player_cube = tile_map_layer.axial_to_cube(player_pos)
	
	# Calculate vector from player to enemy (opposite of approach)
	var dir_cube = Vector3i(
		enemy_cube.x - player_cube.x,
		enemy_cube.y - player_cube.y,
		enemy_cube.z - player_cube.z
	)
	
	# Normalize the direction vector to unit length in cube space
	var length = tile_map_layer.cube_distance(Vector3i(0,0,0), dir_cube)
	if length == 0:
		# If somehow at same position, pick any direction
		dir_cube = Vector3i(1, 0, -1)
	
	# Try to move full amount away
	var move_pct = float(move_amount) / max(1, length)
	var new_cube = Vector3i(
		enemy_cube.x + int(dir_cube.x * move_pct),
		enemy_cube.y + int(dir_cube.y * move_pct),
		enemy_cube.z + int(dir_cube.z * move_pct)
	)
	
	# Convert back to axial coordinates
	var new_pos = tile_map_layer.cube_to_axial(new_cube)
	
	# Check if the position is walkable
	if new_pos in tile_map_layer.walkable_hexes:
		# Check if occupied
		var is_occupied = false
		for cryptid in tile_map_layer.all_cryptids_in_play:
			if tile_map_layer.local_to_map(cryptid.position) == new_pos:
				is_occupied = true
				break
		
		if not is_occupied:
			return new_pos
	
	# If the ideal position isn't walkable, find the best walkable hex
	var best_pos = enemy_pos
	var best_score = -999
	
	# Check all walkable hexes within range
	for walkable_hex in tile_map_layer.walkable_hexes:
		var hex_cube = tile_map_layer.axial_to_cube(walkable_hex)
		var distance_from_enemy = tile_map_layer.cube_distance(enemy_cube, hex_cube)
		
		# Skip if out of move range
		if distance_from_enemy > move_amount:
			continue
			
		# Skip if occupied by another cryptid
		var is_occupied = false
		for cryptid in tile_map_layer.all_cryptids_in_play:
			if tile_map_layer.local_to_map(cryptid.position) == walkable_hex:
				is_occupied = true
				break
		
		if is_occupied:
			continue
			
		# Score this position
		var distance_to_player = tile_map_layer.cube_distance(hex_cube, player_cube)
		var current_distance = tile_map_layer.cube_distance(enemy_cube, player_cube)
		
		# Prefer positions that increase distance from player
		var score = distance_to_player - current_distance
		
		if score > best_score:
			best_score = score
			best_pos = walkable_hex
	
	return best_pos

# End enemy turn without performing any actions
func end_enemy_turn():
	if current_enemy_cryptid == null:
		print("AI: No current enemy cryptid to end turn for")
		return
		
	print("AI: Ending turn for " + current_enemy_cryptid.cryptid.name)
	
	# Mark turn as completed
	current_enemy_cryptid.cryptid.completed_turn = true
	
	# Tell hand to move to next cryptid
	hand.next_cryptid_turn()

# Check if turn is complete and trigger next cryptid if needed
func check_turn_completed(enemy_cryptid):
	# Give a small delay to let animations complete
	await get_tree().create_timer(0.5).timeout
	
	# Check if both actions used
	if enemy_cryptid.cryptid.top_card_played and enemy_cryptid.cryptid.bottom_card_played:
		print("AI: Both actions used, ending turn")
		enemy_cryptid.cryptid.completed_turn = true
		hand.next_cryptid_turn()
	else:
		# If only one action used, look for another action to perform
		print("AI: Only one action used, looking for another")
		perform_enemy_turn(enemy_cryptid)

# Find the closest player cryptid on the map
func find_closest_player_cryptid(enemy_cryptid):
	var closest_player = null
	var shortest_distance = 9999
	
	# Get enemy position
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	
	# Check each player cryptid
	for player_cryptid in tile_map_layer.player_cryptids_in_play:
		var player_pos = tile_map_layer.local_to_map(player_cryptid.position)
		var distance = calculate_hex_distance(enemy_pos, player_pos)
		
		if distance < shortest_distance:
			shortest_distance = distance
			closest_player = player_cryptid
	
	return closest_player

# Analyze the cards available to the enemy
func analyze_available_cards(enemy_cryptid):
	# First ensure we have the enemy's cards loaded
	hand.switch_cryptid_deck(enemy_cryptid.cryptid)
	
	# Organize by action location (top/bottom) and type
	var top_attacks = []
	var top_moves = []
	var bottom_attacks = []
	var bottom_moves = []
	var all_cards = []
	
	# Go through each card in hand
	for card_node in hand.get_children():
		if not card_node is CardDialog:
			continue
			
		all_cards.append(card_node)
		var card = card_node.card_resource
		
		# Analyze top action
		if card.top_move.actions.size() > 0 and card.top_move.actions[0].action_types.size() > 0:
			var action_type = card.top_move.actions[0].action_types[0]
			var action_info = {
				"card_node": card_node,
				"action": card.top_move.actions[0],
				"type": action_type,
				"range": card.top_move.actions[0].range,
				"amount": card.top_move.actions[0].amount
			}
			
			if action_type == 0:  # Move
				top_moves.append(action_info)
			elif action_type == 1:  # Attack
				top_attacks.append(action_info)
		
		# Analyze bottom action
		if card.bottom_move.actions.size() > 0 and card.bottom_move.actions[0].action_types.size() > 0:
			var action_type = card.bottom_move.actions[0].action_types[0]
			var action_info = {
				"card_node": card_node,
				"action": card.bottom_move.actions[0],
				"type": action_type,
				"range": card.bottom_move.actions[0].range,
				"amount": card.bottom_move.actions[0].amount
			}
			
			if action_type == 0:  # Move
				bottom_moves.append(action_info)
			elif action_type == 1:  # Attack
				bottom_attacks.append(action_info)
	
	return {
		"top_attacks": top_attacks,
		"top_moves": top_moves,
		"bottom_attacks": bottom_attacks,
		"bottom_moves": bottom_moves,
		"all_cards": all_cards
	}

# Score all possible actions based on game state
func score_possible_actions(enemy_cryptid, available_cards, closest_player, distance_to_player):
	var scores = {}
	
	# Score rest option
	scores["rest"] = score_rest_option(enemy_cryptid)
	
	# Score attack options
	scores["direct_attack"] = score_direct_attack_options(
		enemy_cryptid, available_cards, closest_player, distance_to_player
	)
	
	# Score move options
	scores["move"] = score_move_options(
		enemy_cryptid, available_cards, closest_player, distance_to_player
	)
	
	# Score attack after move options
	scores["attack_after_move"] = score_attack_after_move_options(
		enemy_cryptid, available_cards, closest_player, distance_to_player
	)
	
	# Score retreat after attack
	scores["retreat_after_attack"] = score_retreat_after_attack(
		enemy_cryptid, available_cards, closest_player, distance_to_player
	)
	
	# Debug output
	print("AI: Action scores:")
	for action in scores:
		print("  " + action + ": " + str(scores[action].score) + " - " + scores[action].reason)
	
	return scores

# Score the option to rest and recover cards
func score_rest_option(enemy_cryptid):
	# Base score for resting
	var score = rest_priority_weight
	var reason = "Basic rest option"
	
	# Check how many cards are in discard
	var discard_count = enemy_cryptid.cryptid.discard.size()
	if discard_count > 0:
		score += 0.5 * discard_count
		reason = "Rest to recover " + str(discard_count) + " cards"
	
	# Check if any cards left in hand
	var cards_in_hand = hand.get_children().filter(func(node): return node is CardDialog)
	if cards_in_hand.size() <= 1:
		score += 2.0
		reason = "Almost out of cards, need to rest"
	
	return {
		"score": score,
		"action_type": "rest",
		"reason": reason
	}

# Score direct attack options (without moving first)
func score_direct_attack_options(enemy_cryptid, available_cards, closest_player, distance_to_player):
	var best_score = 0
	var best_attack_action = null
	var reason = "No direct attack possible"
	
	# Check if a top attack action is available and the enemy hasn't used a top action yet
	if not enemy_cryptid.cryptid.top_card_played:
		for attack in available_cards.top_attacks:
			var attack_range = attack.range
			
			# Can we reach the player?
			if attack_range >= distance_to_player:
				var score = attack_priority_weight
				
				# Bonus for higher damage
				score += 0.3 * attack.amount
				
				# Bonus for using range efficiently (not wasting it)
				var range_efficiency = 1.0 - (attack_range - distance_to_player) / float(attack_range)
				score += 0.5 * range_efficiency
				
				if score > best_score:
					best_score = score
					best_attack_action = attack
					reason = "Direct top attack, damage: " + str(attack.amount) + ", range: " + str(attack_range)
	
	# Check if a bottom attack action is available and the enemy hasn't used a bottom action yet
	if not enemy_cryptid.cryptid.bottom_card_played:
		for attack in available_cards.bottom_attacks:
			var attack_range = attack.range
			
			# Can we reach the player?
			if attack_range >= distance_to_player:
				var score = attack_priority_weight
				
				# Bonus for higher damage
				score += 0.3 * attack.amount
				
				# Bonus for using range efficiently (not wasting it)
				var range_efficiency = 1.0 - (attack_range - distance_to_player) / float(attack_range)
				score += 0.5 * range_efficiency
				
				if score > best_score:
					best_score = score
					best_attack_action = attack
					reason = "Direct bottom attack, damage: " + str(attack.amount) + ", range: " + str(attack_range)
	
	return {
		"score": best_score,
		"action_type": "direct_attack",
		"action": best_attack_action,
		"reason": reason
	}

# Score move options
func score_move_options(enemy_cryptid, available_cards, closest_player, distance_to_player):
	var best_score = 0
	var best_move_action = null
	var reason = "No move possible"
	
	# Check if a top move action is available and the enemy hasn't used a top action yet
	if not enemy_cryptid.cryptid.top_card_played:
		for move in available_cards.top_moves:
			var move_amount = move.amount
			
			# Score based on how much it helps close distance to attack
			var score = move_priority_weight
			
			# Better if it helps us get closer but maintain some range
			if distance_to_player > 1:
				var new_distance = max(1, distance_to_player - move_amount)
				var distance_improvement = distance_to_player - new_distance
				score += 0.4 * distance_improvement
				
				# Prefer to stay at range 2 if possible
				if new_distance == 2:
					score += 0.5
				
				if score > best_score:
					best_score = score
					best_move_action = move
					reason = "Top move to get closer, amount: " + str(move_amount)
			# If we're already adjacent, maybe we want to move away
			elif distance_to_player <= 1:
				score += 0.3 * move_amount  # Some credit for having movement
				if score > best_score:
					best_score = score
					best_move_action = move
					reason = "Top move to reposition, amount: " + str(move_amount)
	
	# Check if a bottom move action is available and the enemy hasn't used a bottom action yet
	if not enemy_cryptid.cryptid.bottom_card_played:
		for move in available_cards.bottom_moves:
			var move_amount = move.amount
			
			# Score based on how much it helps close distance to attack
			var score = move_priority_weight
			
			# Better if it helps us get closer but maintain some range
			if distance_to_player > 1:
				var new_distance = max(1, distance_to_player - move_amount)
				var distance_improvement = distance_to_player - new_distance
				score += 0.4 * distance_improvement
				
				# Prefer to stay at range 2 if possible
				if new_distance == 2:
					score += 0.5
				
				if score > best_score:
					best_score = score
					best_move_action = move
					reason = "Bottom move to get closer, amount: " + str(move_amount)
			# If we're already adjacent, maybe we want to move away
			elif distance_to_player <= 1:
				score += 0.3 * move_amount  # Some credit for having movement
				if score > best_score:
					best_score = score
					best_move_action = move
					reason = "Bottom move to reposition, amount: " + str(move_amount)
	
	return {
		"score": best_score,
		"action_type": "move",
		"action": best_move_action,
		"reason": reason
	}

# Score the option to attack after moving
func score_attack_after_move_options(enemy_cryptid, available_cards, closest_player, distance_to_player):
	var best_score = 0
	var best_move_action = null
	var best_attack_action = null
	var reason = "No attack after move possible"
	
	# Check each possible move + attack combination
	# For this we need one from top and one from bottom, from different cards
	
	# Try top move + bottom attack
	if not enemy_cryptid.cryptid.top_card_played and not enemy_cryptid.cryptid.bottom_card_played:
		for move in available_cards.top_moves:
			for attack in available_cards.bottom_attacks:
				# Skip if they're from the same card
				if move.card_node == attack.card_node:
					continue
				
				var move_amount = move.amount
				var attack_range = attack.range
				var new_distance = max(0, distance_to_player - move_amount)
				
				# Can we reach with move + attack?
				if new_distance <= attack_range:
					var score = attack_after_move_weight
					
					# Bonus for higher damage
					score += 0.3 * attack.amount
					
					# Bonus for efficient movement (not wasting steps)
					var move_efficiency = move_amount / float(distance_to_player)
					if move_efficiency > 1.0:
						move_efficiency = 1.0
					score += 0.3 * move_efficiency
					
					# Bonus for range efficiency
					var range_efficiency = 1.0 - (attack_range - new_distance) / float(attack_range)
					score += 0.3 * range_efficiency
					
					if score > best_score:
						best_score = score
						best_move_action = move
						best_attack_action = attack
						reason = "Top move + bottom attack combo"
	
	# Try bottom move + top attack
	if not enemy_cryptid.cryptid.bottom_card_played and not enemy_cryptid.cryptid.top_card_played:
		for move in available_cards.bottom_moves:
			for attack in available_cards.top_attacks:
				# Skip if they're from the same card
				if move.card_node == attack.card_node:
					continue
				
				var move_amount = move.amount
				var attack_range = attack.range
				var new_distance = max(0, distance_to_player - move_amount)
				
				# Can we reach with move + attack?
				if new_distance <= attack_range:
					var score = attack_after_move_weight
					
					# Bonus for higher damage
					score += 0.3 * attack.amount
					
					# Bonus for efficient movement (not wasting steps)
					var move_efficiency = move_amount / float(distance_to_player)
					if move_efficiency > 1.0:
						move_efficiency = 1.0
					score += 0.3 * move_efficiency
					
					# Bonus for range efficiency
					var range_efficiency = 1.0 - (attack_range - new_distance) / float(attack_range)
					score += 0.3 * range_efficiency
					
					if score > best_score:
						best_score = score
						best_move_action = move
						best_attack_action = attack
						reason = "Bottom move + top attack combo"
	
	return {
		"score": best_score,
		"action_type": "attack_after_move",
		"move_action": best_move_action,
		"attack_action": best_attack_action,
		"reason": reason
	}

# Score the option to retreat after attacking
func score_retreat_after_attack(enemy_cryptid, available_cards, closest_player, distance_to_player):
	var best_score = 0
	var best_move_action = null
	var best_attack_action = null
	var reason = "No retreat after attack possible"
	
	# Only consider retreat if we're at close range (1-2 hexes)
	if distance_to_player <= 2:
		# Try top attack + bottom move (retreat)
		if not enemy_cryptid.cryptid.top_card_played and not enemy_cryptid.cryptid.bottom_card_played:
			for attack in available_cards.top_attacks:
				for move in available_cards.bottom_moves:
					# Skip if they're from the same card
					if attack.card_node == move.card_node:
						continue
					
					var attack_range = attack.range
					
					# Can we attack from current position?
					if attack_range >= distance_to_player:
						var score = retreat_after_attack_weight
						
						# Bonus for higher damage
						score += 0.3 * attack.amount
						
						# Bonus for higher movement (better retreat)
						score += 0.3 * move.amount
						
						if score > best_score:
							best_score = score
							best_attack_action = attack
							best_move_action = move
							reason = "Top attack + bottom move (retreat)"
		
		# Try bottom attack + top move (retreat)
		if not enemy_cryptid.cryptid.bottom_card_played and not enemy_cryptid.cryptid.top_card_played:
			for attack in available_cards.bottom_attacks:
				for move in available_cards.top_moves:
					# Skip if they're from the same card
					if attack.card_node == move.card_node:
						continue
					
					var attack_range = attack.range
					
					# Can we attack from current position?
					if attack_range >= distance_to_player:
						var score = retreat_after_attack_weight
						
						# Bonus for higher damage
						score += 0.3 * attack.amount
						
						# Bonus for higher movement (better retreat)
						score += 0.3 * move.amount
						
						if score > best_score:
							best_score = score
							best_attack_action = attack
							best_move_action = move
							reason = "Bottom attack + top move (retreat)"
	
	return {
		"score": best_score,
		"action_type": "retreat_after_attack",
		"attack_action": best_attack_action,
		"move_action": best_move_action,
		"reason": reason
	}

# Main function to perform an enemy turn
func perform_enemy_turn(enemy_cryptid):
	print("AI: Starting turn for " + enemy_cryptid.cryptid.name)
	current_enemy_cryptid = enemy_cryptid
	
	# Check if actions already performed (top or bottom card already played)
	if enemy_cryptid.cryptid.top_card_played and enemy_cryptid.cryptid.bottom_card_played:
		print("AI: Both actions already used, ending turn")
		end_enemy_turn()
		return
		
	# Get available cards
	var available_cards = analyze_available_cards(enemy_cryptid)
	
	# Find closest player cryptid
	var closest_player = find_closest_player_cryptid(enemy_cryptid)
	if not closest_player:
		print("AI: No player cryptids found")
		end_enemy_turn()
		return
	
	# Calculate distance to closest player
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var player_pos = tile_map_layer.local_to_map(closest_player.position)
	var distance = calculate_hex_distance(enemy_pos, player_pos)
	
	print("AI: Closest player is " + closest_player.cryptid.name + " at distance " + str(distance))
	
	# Score all possible actions
	var action_scores = score_possible_actions(enemy_cryptid, available_cards, closest_player, distance)
	
	# THIS IS THE CRUCIAL LINE THAT SHOULD BE ADDED:
	execute_best_action(enemy_cryptid, action_scores, available_cards, closest_player)
	
	# Execute best action
# Execute the best action based on the scores
func execute_best_action(enemy_cryptid, action_scores, available_cards, closest_player):
	# Find the action with the highest score
	var best_action = "rest"
	var highest_score = action_scores["rest"].score
	
	for action_type in action_scores:
		if action_scores[action_type].score > highest_score:
			highest_score = action_scores[action_type].score
			best_action = action_type
	
	print("AI: Selected best action: " + best_action + " with score " + str(highest_score))
	
	# Execute the selected action
	match best_action:
		"rest":
			execute_rest(enemy_cryptid)
			print("resting")
		"direct_attack":
			execute_direct_attack(enemy_cryptid, action_scores["direct_attack"], closest_player)
			print("attacking")
		"move":
			execute_move(enemy_cryptid, action_scores["move"], closest_player)
			print("moving")
		"attack_after_move":
			execute_attack_after_move(enemy_cryptid, action_scores["attack_after_move"], closest_player)
		"retreat_after_attack":
			execute_retreat_after_attack(enemy_cryptid, action_scores["retreat_after_attack"], closest_player)


# Execute a rest action to recover cards
func execute_rest(enemy_cryptid):
	print("AI: Executing rest action for " + enemy_cryptid.cryptid.name)
	
	# Rest is handled by the hand.gd script
	# We need to mark the cryptid as selected and then call rest_action
	hand.selected_cryptid = enemy_cryptid.cryptid
	hand.rest_action()
	
	# Rest automatically ends the turn

# Execute a direct attack without moving
func execute_direct_attack(enemy_cryptid, action_data, target_cryptid):
	print("AI: Executing direct attack for " + enemy_cryptid.cryptid.name)
	
	if action_data.action == null:
		print("AI: No valid attack action found, ending turn")
		end_enemy_turn()
		return
	
	var card_node = action_data.action.card_node
	
	# Set the card as selected
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if we're using top or bottom of the card
	var is_top_action = false
	for top_attack in analyze_available_cards(enemy_cryptid).top_attacks:
		if top_attack.card_node == card_node:
			is_top_action = true
			break
	
	# Highlight the appropriate half of the card
	if is_top_action:
		card_node.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		card_node.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the attack action
	tile_map_layer.attack_action_selected(card_node)
	
	# Find position of target cryptid
	var target_pos = tile_map_layer.local_to_map(target_cryptid.position)
	
	# DIRECTLY call the handle_attack_action method instead of simulating a click
	tile_map_layer.handle_attack_action(target_pos)
	
	# Check if turn is completed
	check_turn_completed(enemy_cryptid)

# Execute a move action without attacking
func execute_move(enemy_cryptid, action_data, target_cryptid):
	print("AI: Executing move for " + enemy_cryptid.cryptid.name)
	
	if action_data.action == null:
		print("AI: No valid move action found, ending turn")
		end_enemy_turn()
		return
	
	var card_node = action_data.action.card_node
	
	# Set the card as selected
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if we're using top or bottom of the card
	var is_top_action = false
	for top_move in analyze_available_cards(enemy_cryptid).top_moves:
		if top_move.card_node == card_node:
			is_top_action = true
			break
	
	# Highlight the appropriate half of the card
	if is_top_action:
		card_node.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		card_node.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the move action
	tile_map_layer.move_action_selected(card_node)
	
	# Calculate best move position (toward player but keeping some distance)
	var move_amount = action_data.action.amount
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var player_pos = tile_map_layer.local_to_map(target_cryptid.position)
	var target_pos = calculate_best_move_position(enemy_pos, player_pos, move_amount)
	
	# Directly call the handle_move_action function with the target position
	tile_map_layer.handle_move_action(target_pos)
	print("helllooo?????")
	# Check if turn is completed
	check_turn_completed(enemy_cryptid)

# Execute attack after move combo
func execute_attack_after_move(enemy_cryptid, action_data, target_cryptid):
	print("AI: Executing attack after move for " + enemy_cryptid.cryptid.name)
	
	if action_data.move_action == null or action_data.attack_action == null:
		print("AI: Invalid attack after move combo, ending turn")
		end_enemy_turn()
		return
	
	# First execute the move
	var move_card = action_data.move_action.card_node
	
	# Set the card as selected
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if move is top or bottom
	var move_is_top = false
	for top_move in analyze_available_cards(enemy_cryptid).top_moves:
		if top_move.card_node == move_card:
			move_is_top = true
			break
	
	# Highlight the appropriate half of the card
	if move_is_top:
		move_card.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		move_card.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the move action
	tile_map_layer.move_action_selected(move_card)
	
	# Calculate position that brings us within attack range
	var move_amount = action_data.move_action.amount
	var attack_range = action_data.attack_action.range
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var player_pos = tile_map_layer.local_to_map(target_cryptid.position)
	var target_pos = calculate_move_position_for_attack(enemy_pos, player_pos, move_amount, attack_range)
	
	# Directly call the handle_move_action function
	tile_map_layer.handle_move_action(target_pos)
	
	# Give a small delay for movement to complete
	await get_tree().create_timer(0.8).timeout
	
	# Now execute the attack
	var attack_card = action_data.attack_action.card_node
	
	# Refresh state after move
	if !is_instance_valid(enemy_cryptid) or !is_instance_valid(target_cryptid):
		print("AI: Target or enemy is no longer valid after move")
		check_turn_completed(enemy_cryptid)
		return
	
	# Set the card as selected (might have changed after move)
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if attack is top or bottom
	var attack_is_top = false
	for top_attack in analyze_available_cards(enemy_cryptid).top_attacks:
		if top_attack.card_node == attack_card:
			attack_is_top = true
			break
	
	# Highlight the appropriate half of the card
	if attack_is_top:
		attack_card.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		attack_card.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the attack action
	tile_map_layer.attack_action_selected(attack_card)
	
	# Find updated position of target cryptid
	var updated_target_pos = tile_map_layer.local_to_map(target_cryptid.position)
	
	# Directly call the handle_attack_action function
	tile_map_layer.handle_attack_action(updated_target_pos)
	
	# Check if turn is completed
	check_turn_completed(enemy_cryptid)


# Execute retreat after attack combo
func execute_retreat_after_attack(enemy_cryptid, action_data, target_cryptid):
	print("AI: Executing retreat after attack for " + enemy_cryptid.cryptid.name)
	
	if action_data.attack_action == null or action_data.move_action == null:
		print("AI: Invalid retreat after attack combo, ending turn")
		end_enemy_turn()
		return
	
	# First execute the attack
	var attack_card = action_data.attack_action.card_node
	
	# Set the card as selected
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if attack is top or bottom
	var attack_is_top = false
	for top_attack in analyze_available_cards(enemy_cryptid).top_attacks:
		if top_attack.card_node == attack_card:
			attack_is_top = true
			break
	
	## Highlight the appropriate half of the card
	#if attack_is_top:
		#attack_card.top_half_container.modulate = Color(1, 1, 0, 1)
	#else:
		#attack_card.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the attack action
	tile_map_layer.attack_action_selected(attack_card)
	
	# Find position of target cryptid
	var target_pos = tile_map_layer.local_to_map(target_cryptid.position)
	
	# Directly call the handle_attack_action function
	tile_map_layer.handle_attack_action(target_pos)
	
	# Give a small delay for attack to complete
	await get_tree().create_timer(0.8).timeout
	
	# Now execute the move (retreat)
	var move_card = action_data.move_action.card_node
	
	# Refresh state after attack
	if !is_instance_valid(enemy_cryptid) or !is_instance_valid(target_cryptid):
		print("AI: Target or enemy is no longer valid after attack")
		check_turn_completed(enemy_cryptid)
		return
	
	# Set the card as selected (might have changed after attack)
	hand.selected_cryptid = enemy_cryptid.cryptid
	
	# Determine if move is top or bottom
	var move_is_top = false
	for top_move in analyze_available_cards(enemy_cryptid).top_moves:
		if top_move.card_node == move_card:
			move_is_top = true
			break
	
	# Highlight the appropriate half of the card
	if move_is_top:
		move_card.top_half_container.modulate = Color(1, 1, 0, 1)
	else:
		move_card.bottom_half_container.modulate = Color(1, 1, 0, 1)
	
	# Trigger the move action
	tile_map_layer.move_action_selected(move_card)
	
	# Calculate retreat position away from player
	var move_amount = action_data.move_action.amount
	var enemy_pos = tile_map_layer.local_to_map(enemy_cryptid.position)
	var player_pos = tile_map_layer.local_to_map(target_cryptid.position)
	var retreat_pos = calculate_retreat_position(enemy_pos, player_pos, move_amount)
	
	# Directly call the handle_move_action function
	tile_map_layer.handle_move_action(retreat_pos)
	
	# Check if turn is completed
	check_turn_completed(enemy_cryptid)
