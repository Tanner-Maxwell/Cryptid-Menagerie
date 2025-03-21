extends TileMapLayer

const MAIN_ATLAS_ID = 0

@onready var a_star_hex_grid = AStar2D.new()
@onready var a_star_hex_attack_grid = AStar2D.new()
@onready var line_container = $LineContainer
@onready var player_pos = map_to_local(Vector2i(-4, 1))
@onready var selected_cryptid = $"PlayerTeam/Grove Starter"
@onready var enemy_cryptid = $"EnemyTeam/Fire Starter"
@onready var walkable_hexes = []
@onready var card_dialog = $"../UIRoot/Hand/CardDialog"
@onready var hand = %Hand
@onready var turn_order = %"Turn Order"

@onready var player_team = %PlayerTeam
@onready var enemy_team = %EnemyTeam
@onready var player_starting_positions = [Vector2i(-4, 1), Vector2i(-2, 1), Vector2i(0, 1)]
@onready var enemy_starting_positions = [Vector2i(-4, -3), Vector2i(-2, -3), Vector2i(0, -3)]

var active_movement_card = null
var movement_in_progress = false
var current_tween = null

@onready var player_cryptids_in_play = []
@onready var enemy_cryptids_in_play = []

@onready var all_cryptids_in_play = []

@onready var blank_cryptid = preload("res://Cryptid-Menagerie/data/cryptids/blank_cryptid.tscn")
@onready var current_card

var original_move_amount = 0
var active_movement_card_part = ""
var move_action_bool = false
var attack_action_bool = false
var current_atlas_coords
var cur_position_cube
var move_leftover = 0
var attack_range = 2
var path
var attack_path
var vector_path = []
var point_path = []
var damage

func _ready():
	cur_position_cube = axial_to_cube(local_to_map(player_pos))
	var cur_position = Vector2i(-6, -1)
	create_hex_map_a_star(cur_position)
	show_coordinates_label(cur_position)
	
	#Place player and enemy teams on map
	player_cryptids_in_play = initialize_starting_positions(player_starting_positions, player_team)
	enemy_cryptids_in_play = initialize_starting_positions(enemy_starting_positions, enemy_team)
	all_cryptids_in_play.append_array(player_cryptids_in_play)
	all_cryptids_in_play.append_array(enemy_cryptids_in_play)
	print(all_cryptids_in_play)
	sort_cryptids_by_speed(all_cryptids_in_play)
	for cryptid in all_cryptids_in_play:
		print(cryptid.cryptid, cryptid.cryptid.speed)
		turn_order._add_picked_cards_to_turn_order(cryptid.cryptid.name)
	
	sort_cryptids_by_speed(player_cryptids_in_play)
	print(player_cryptids_in_play[0].cryptid.speed)
	selected_cryptid = player_cryptids_in_play[0].cryptid
	player_cryptids_in_play[0].cryptid.currently_selected = true
	for cryptid in player_cryptids_in_play:
		print(cryptid, cryptid.cryptid.speed, cryptid.cryptid.currently_selected)
	print(player_cryptids_in_play)
	
	

func _process(delta):
	if move_action_bool:
		handle_mouse_motion()

#Place player and enemy teams on map
func initialize_starting_positions(starting_positions : Array, team):
	var cryptids_in_play = []
	for positions in starting_positions:
		var cryptid
		cryptid = blank_cryptid.instantiate()
		cryptid.cryptid = team._content[cryptids_in_play.size()]
		team.add_child(cryptid)
		#if selected_cryptid == null:
			#selected_cryptid = cryptid.cryptid
			#print("hello??")
			#print(selected_cryptid)
			#print(cryptid.cryptid.currently_selected)
			#cryptid.cryptid.currently_selected = true
			
		
		cryptid.position = map_to_local(starting_positions[cryptids_in_play.size()])
		cryptid.hand = %Hand
		cryptids_in_play.append(cryptid)
		var point = a_star_hex_grid.get_closest_point(positions, true)
		a_star_hex_grid.set_point_disabled(point, true)
	return cryptids_in_play
	
func handle_right_click():
	print("Right-click detected - cancelling current action")
	
	# Clear action states
	move_action_bool = false
	attack_action_bool = false
	active_movement_card_part = ""
	active_movement_card = null
	
	# Clean up visual elements
	delete_all_lines()
	delete_all_indicators()
	remove_movement_indicator()
	
	# Re-enable eligible card halves
	enable_all_card_halves()
	
	# Show the action menu again
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		action_menu.show()

# New function that can be called programmatically
func calculate_path(current_pos: Vector2i, target_pos: Vector2i):
	# Calculate paths
	vector_path = []
	point_path = []
	var attack_vector_path = []
	var attack_point_path = []
	
	# Calculate appropriate path based on current action mode
	if move_action_bool:
		path = a_star_hex_grid.get_id_path(
			a_star_hex_grid.get_closest_point(current_pos),
			a_star_hex_grid.get_closest_point(target_pos)
		)
		
		for point in path:
			vector_path.append(map_to_local(a_star_hex_grid.get_point_position(point)))
			point_path.append(a_star_hex_grid.get_point_position(point))
	
	if attack_action_bool:
		var attack_path = a_star_hex_attack_grid.get_id_path(
			a_star_hex_attack_grid.get_closest_point(current_pos),
			a_star_hex_attack_grid.get_closest_point(target_pos)
		)
		
		for point in attack_path:
			attack_vector_path.append(map_to_local(a_star_hex_attack_grid.get_point_position(point)))
			attack_point_path.append(a_star_hex_attack_grid.get_point_position(point))
	
	delete_all_lines()
	
	# Handle move action visualization
	if move_action_bool:
		# Calculate if the target hex is within the remaining movement range
		var movement_distance = point_path.size() - 1
		
		# Check if the movement is valid (within range and to a walkable hex)
		var is_valid_move = movement_distance <= move_leftover && target_pos in walkable_hexes
		
		# If valid, show the path
		if is_valid_move:
			draw_lines_between_points(convert_vector2_array_to_vector2i_array(vector_path), movement_distance, Color(0, 1, 0))
	
	# Handle attack action visualization
	if attack_action_bool:
		var attack_distance = attack_point_path.size() - 1
		if attack_distance <= attack_range:
			var attack_color = Color(1, 0, 0)  # Red for attack
			draw_lines_between_points(convert_vector2_array_to_vector2i_array(attack_vector_path), attack_range, attack_color)
			
	# Return relevant data for the AI to use
	return {
		"vector_path": vector_path,
		"point_path": point_path,
		"path_length": point_path.size() - 1 if point_path.size() > 0 else 0,
		"is_valid_move": move_action_bool and point_path.size() > 0 and point_path.size() - 1 <= move_leftover and target_pos in walkable_hexes,
		"is_valid_attack": attack_action_bool and attack_point_path.size() > 0 and attack_point_path.size() - 1 <= attack_range
	}

# Update the original function to use the new one
func handle_mouse_motion():
	# Get the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	
	if selected_cryptid == null:
		selected_cryptid = player_cryptids_in_play[0]
	
	# Calculate paths using our new function
	var current_pos = local_to_map(selected_cryptid.position)
	var target_pos = local_to_map(get_local_mouse_position())
	
	calculate_path(current_pos, target_pos)
			
func handle_left_click(event):
	var global_clicked = event.position
	selected_cryptid = currently_selected_cryptid()
	var pos_clicked = local_to_map(to_local(global_clicked))
	
	# Debugging
	print("Left click detected!")
	print("move_action_bool = ", move_action_bool)
	print("attack_action_bool = ", attack_action_bool)
	
	if selected_cryptid == null:
		print("WARNING: No selected cryptid found, using first cryptid")
		selected_cryptid = player_cryptids_in_play[0]
	
	# Handle action based on what is active
	if move_action_bool:
		print("Handling move action")
		handle_move_action(pos_clicked)
	elif attack_action_bool:
		print("Handling attack action")
		handle_attack_action(pos_clicked) 
	else:
		print("No action type active")

	
func handle_move_action(pos_clicked):
	# Calculate the movement distance required for this move
	var movement_distance = point_path.size() - 1
	
	# Only process the move if the clicked position is walkable and within movement range
	if pos_clicked in walkable_hexes and movement_distance <= move_leftover:
		var move_performed = false  # Track if a move was actually performed
		
		# Store the original position for freeing up after movement
		var original_position = local_to_map(selected_cryptid.position)
		
		# Only subtract the actual distance moved, not the full allowed movement
		var remaining_movement = move_leftover - movement_distance
		
		# Safely check if card_dialog is still valid
		if is_instance_valid(card_dialog) and card_dialog.has_method("update_move_action_display"):
			# Check top half
			if card_dialog.top_half_container and card_dialog.top_half_container.modulate == Color(1, 1, 0, 1):
				for action in card_dialog.card_resource.top_move.actions:
					if action.action_types == [0]:
						# Verify the move is actually changing position
						var new_position = pos_clicked
						move_performed = (original_position != new_position)
						
						if move_performed:
							# Set active card part ONLY when a move is actually performed
							move_leftover = remaining_movement
							active_movement_card_part = "top"
							active_movement_card = card_dialog
							
							# Animate movement along the path
							animate_movement_along_path(selected_cryptid, original_position, new_position)
							
							# Mark top action as used only if we've used all movement
							if move_leftover <= 0:
								card_dialog.top_half_container.disabled = true
								card_dialog.bottom_half_container.disabled = true
								card_dialog.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								card_dialog.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								selected_cryptid.cryptid.top_card_played = true
								
								# Mark the original card as discarded
								if card_dialog.card_resource.original_card != null:
									print("DEBUG: Marking original card as discarded from move action")
									card_dialog.card_resource.original_card.current_state = Card.CardState.IN_DISCARD
								else:
									print("ERROR: No original card reference found for move action")
							else:
								# We have more movement left, disable other cards
								# Disable bottom half of this card 
								card_dialog.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								
								# Disable top half of all other cards
								disable_other_card_halves("top")
								
								# Update card display to show remaining movement
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("top", move_leftover)
			
			# Check bottom half
			elif card_dialog.bottom_half_container and card_dialog.bottom_half_container.modulate == Color(1, 1, 0, 1):
				for action in card_dialog.card_resource.bottom_move.actions:
					if action.action_types == [0]:
						# Verify the move is actually changing position
						var new_position = pos_clicked
						move_performed = (original_position != new_position)
						
						if move_performed:
							# Set active card part ONLY when a move is actually performed
							move_leftover = remaining_movement
							active_movement_card_part = "bottom"
							active_movement_card = card_dialog
							
							# Animate movement along the path
							animate_movement_along_path(selected_cryptid, original_position, new_position)
							
							# Mark bottom action as used only if we've used all movement
							if move_leftover <= 0:
								card_dialog.top_half_container.disabled = true
								card_dialog.bottom_half_container.disabled = true
								card_dialog.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								card_dialog.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								selected_cryptid.cryptid.bottom_card_played = true
								
								# Mark the original card as discarded
								if card_dialog.card_resource.original_card != null:
									print("DEBUG: Marking original card as discarded from move action")
									card_dialog.card_resource.original_card.current_state = Card.CardState.IN_DISCARD
								else:
									print("ERROR: No original card reference found for move action")
							else:
								# We have more movement left, disable other cards
								# Disable top half of this card
								card_dialog.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								
								# Disable bottom half of all other cards
								disable_other_card_halves("bottom")
								
								# Update card display to show remaining movement
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("bottom", move_leftover)
		# Handle the case where card_dialog is not valid - AI controlled cryptids
		else:
			print("Card dialog not valid - likely AI controlled move")
			
			# For AI moves, we still need to perform the movement
			var new_position = pos_clicked
			move_performed = (original_position != new_position)
			
			if move_performed:
				move_leftover = remaining_movement
				
				# Animate movement along the path
				animate_movement_along_path(selected_cryptid, original_position, new_position)
				
				# For AI, we'll rely on the AI to track card usage
		
		# Only update the game state if a move was actually performed
		if move_performed:
			# Now show the action menu again with updated button state
			var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
			if action_menu and action_menu.has_method("update_menu_visibility"):
				action_menu.update_menu_visibility(selected_cryptid.cryptid)
				action_menu.show()
			
			# Check if turn is complete
			if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
				selected_cryptid.cryptid.completed_turn = true
				
				# Check if the hand reference is valid before calling next_cryptid_turn
				var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
				if hand_node and hand_node.has_method("next_cryptid_turn"):
					hand_node.next_cryptid_turn()
	else:
		print("Invalid move: Clicked on a non-walkable hex or insufficient movement points")
		print("Required movement: ", movement_distance, ", Available movement: ", move_leftover)
	
	# Reset action state only if no movement left
	if move_leftover <= 0:
		move_action_bool = false
		active_movement_card_part = ""  # Reset active card part
		active_movement_card = null     # Reset active card
		remove_movement_indicator()
		
		# Re-enable all cards if card_dialog is valid
		if is_instance_valid(card_dialog):
			enable_all_card_halves()
	else:
		# Show remaining movement indicator
		update_movement_indicator(selected_cryptid, move_leftover)
		
	delete_all_lines()


func attack_action_selected(current_card):
	card_dialog = current_card
	
	# Important: Reset ALL action booleans first
	move_action_bool = false  # Explicitly disable movement
	attack_action_bool = false
	
	# Make sure we have the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	
	if selected_cryptid == null:
		print("ERROR: No selected cryptid found when selecting attack action")
		return
		
	delete_all_lines()
	
	# Only check active movement after the first attack has been made
	if active_movement_card != null:
		# If already in segmented movement, only allow continuing with the same card
		if active_movement_card != current_card:
			print("Cannot use a different card during active movement")
			return
		
		# If already in a segmented movement, only allow continuing with the same card part
		if (active_movement_card_part == "top" and 
			card_dialog.top_half_container.modulate != Color(1, 1, 0, 1)):
			print("Cannot use bottom part during active top movement")
			return
		elif (active_movement_card_part == "bottom" and 
			card_dialog.bottom_half_container.modulate != Color(1, 1, 0, 1)):
			print("Cannot use top part during active bottom movement")
			return
	
	# Check for attack action in the card
	if card_dialog.top_half_container.modulate == Color(1, 1, 0, 1):
		for action in card_dialog.card_resource.top_move.actions:
			if action.action_types == [1]:  # Attack action type
				attack_range = action.range
				damage = action.amount
				attack_action_bool = true
				
				# DON'T set active card/part until attack is actually performed
				
				# For debugging
				print("Attack action selected: Range = ", attack_range, ", Damage = ", damage)
				print("Selected cryptid position: ", local_to_map(selected_cryptid.position))
				
				# Store the current card for reference
				current_card = card_dialog
				
				# Add this to ensure the attack action is active
				print("Attack action bool set to: ", attack_action_bool)
				break
	elif card_dialog.bottom_half_container.modulate == Color(1, 1, 0, 1):
		for action in card_dialog.card_resource.bottom_move.actions:
			if action.action_types == [1]:  # Attack action type
				attack_range = action.range
				damage = action.amount
				attack_action_bool = true
				
				# DON'T set active card/part until attack is actually performed
				
				# For debugging
				print("Attack action selected: Range = ", attack_range, ", Damage = ", damage)
				print("Selected cryptid position: ", local_to_map(selected_cryptid.position))
				
				# Store the current card for reference
				current_card = card_dialog
				
				# Add this to ensure the attack action is active
				print("Attack action bool set to: ", attack_action_bool)
				break
				
	# If we failed to set attack_action_bool, print an error
	if not attack_action_bool:
		print("ERROR: Failed to activate attack action - no attack action found in selected card")
		# Check what actions are in the card
		if card_dialog.top_half_container.modulate == Color(1, 1, 0, 1):
			print("Top half actions:")
			for action in card_dialog.card_resource.top_move.actions:
				print("Action type: ", action.action_types)
		elif card_dialog.bottom_half_container.modulate == Color(1, 1, 0, 1):
			print("Bottom half actions:")
			for action in card_dialog.card_resource.bottom_move.actions:
				print("Action type: ", action.action_types)

func handle_attack_action(pos_clicked):
	print("In handle_attack_action...")
	
	var target_cryptid = get_cryptid_at_position(pos_clicked)
	print("Target position:", pos_clicked)
	print("Target cryptid:", target_cryptid)
	
	var attack_performed = false
	
	# Check if the target is valid - player cryptids can attack enemy cryptids, and enemy cryptids can attack player cryptids
	var valid_target = false
	
	# Get the attacking cryptid
	selected_cryptid = currently_selected_cryptid()
	
	# Determine if this is a valid target based on attacker type
	if target_cryptid != null:
		if selected_cryptid in player_cryptids_in_play and target_cryptid in enemy_cryptids_in_play:
			# Player attacking enemy - valid
			valid_target = true
			print("Valid target: Player attacking enemy")
		elif selected_cryptid in enemy_cryptids_in_play and target_cryptid in player_cryptids_in_play:
			# Enemy attacking player - valid
			valid_target = true
			print("Valid target: Enemy attacking player")
		else:
			# Same team attack - invalid
			valid_target = false
			print("Invalid target: Cannot attack your own team")
	
	# Only proceed if targeting a valid cryptid
	if target_cryptid != null and valid_target:
		print("Valid target found")
		
		# Calculate attack distance directly instead of relying on stored path
		var current_pos = local_to_map(selected_cryptid.position)
		var target_pos = local_to_map(target_cryptid.position)
		var attack_path = a_star_hex_attack_grid.get_id_path(
			a_star_hex_attack_grid.get_closest_point(current_pos),
			a_star_hex_attack_grid.get_closest_point(target_pos)
		)
		var attack_distance = attack_path.size() - 1
		
		print("Attack distance:", attack_distance)
		print("Attack range:", attack_range)
		
		if attack_distance <= attack_range:
			print("Target is within range")
			
			print("Attacker:", selected_cryptid)
			
			# Safely check card_dialog state - avoid accessing properties that might be freed
			var using_top_half = false
			var using_bottom_half = false
			
			if is_instance_valid(card_dialog) and card_dialog.has_method("display"):  # Check if card_dialog is valid
				if card_dialog.has_node("TopHalfContainer"):  # Check if the node exists
					var top_container = card_dialog.get_node("TopHalfContainer")
					using_top_half = top_container.modulate == Color(1, 1, 0, 1)
				
				if card_dialog.has_node("BottomHalfContainer"):  # Check if the node exists
					var bottom_container = card_dialog.get_node("BottomHalfContainer")
					using_bottom_half = bottom_container.modulate == Color(1, 1, 0, 1)
			else:
				# If card_dialog is invalid, we must be in an AI-controlled attack
				# In this case, we need to determine top/bottom from other context
				print("AI attack detected - card_dialog is not valid")
				# Use the current action type to determine which half is being used
				# Check if there's an active movement card part set
				if active_movement_card_part == "top":
					using_top_half = true
				elif active_movement_card_part == "bottom":
					using_bottom_half = true
				else:
					# Default to top if we can't determine
					print("Warning: Unable to determine card half, defaulting to top")
					using_top_half = true
			
			# Set active card part ONLY when an attack is actually performed
			if using_top_half:
				active_movement_card_part = "top"
				print("Using top half for attack")
			elif using_bottom_half:
				active_movement_card_part = "bottom"
				print("Using bottom half for attack")
			
			# Play the attack animation
			print("Starting attack animation")
			animate_attack(selected_cryptid, target_cryptid)
			
			attack_performed = true
			print("Attack performed successfully")
		else:
			print("Target out of range")
	else:
		print("Invalid attack: No valid target at the selected position")
	
	# Reset action state if no attack was performed
	if not attack_performed:
		print("No attack performed - resetting action state")
		attack_action_bool = false
		active_movement_card_part = ""  # Reset active card part
		active_movement_card = null     # Reset active card
		delete_all_lines()
		delete_all_indicators()


func _input(event):
	if movement_in_progress:
		return
	
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_RIGHT and event.is_pressed():
			handle_right_click()
		if event is InputEventMouseMotion and (move_action_bool or attack_action_bool):
			if event is InputEventMouseMotion:
				handle_mouse_motion()
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed() and (move_action_bool or attack_action_bool):
			if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
				handle_left_click(event)

func move_action_selected(current_card):
	# If already in segmented movement, only allow continuing with the same card
	if move_leftover > 0 and active_movement_card != null:
		# Only allow the same card to continue movement
		if active_movement_card != current_card:
			print("Cannot use a different card during active movement")
			return
	
	card_dialog = current_card
	move_action_bool = false
	# Make sure we have the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	
	var current_pos = local_to_map(selected_cryptid.position)
	var point = a_star_hex_grid.get_closest_point(current_pos, true)
	a_star_hex_grid.set_point_disabled(point, false)
	
	if selected_cryptid == null:
		print("ERROR: No selected cryptid found when selecting move action")
		return
		
	delete_all_lines()
	
	# If already in a segmented movement, only allow continuing with the same card part
	if move_leftover > 0 and active_movement_card_part != "":
		print("Already in segmented movement with " + active_movement_card_part + " part")
		
		# Only allow continuing with the same part
		if (active_movement_card_part == "top" and 
			card_dialog.top_half_container.modulate != Color(1, 1, 0, 1)):
			print("Cannot use bottom part during active top movement")
			return
		elif (active_movement_card_part == "bottom" and 
			card_dialog.bottom_half_container.modulate != Color(1, 1, 0, 1)):
			print("Cannot use top part during active bottom movement")
			return
	
	# Check for move action in the top half
	if card_dialog.top_half_container.modulate == Color(1, 1, 0, 1):
		for action in card_dialog.card_resource.top_move.actions:
			if action.action_types == [0] and action.amount > 0:
				# Only set move_leftover if we're not already in a segmented move
				if active_movement_card == null:
					original_move_amount = action.amount
					move_leftover = action.amount
				move_action_bool = true
				
				# For debugging
				print("Move action selected: Distance = ", move_leftover)
				print("Selected cryptid position: ", current_pos)
				break
	
	# Check for move action in the bottom half
	if card_dialog.bottom_half_container.modulate == Color(1, 1, 0, 1):
		for action in card_dialog.card_resource.bottom_move.actions:
			if action.action_types == [0] and action.amount > 0:
				# Only set move_leftover if we're not already in a segmented move
				if active_movement_card == null:
					original_move_amount = action.amount
					move_leftover = action.amount
				move_action_bool = true
				
				# For debugging
				print("Move action selected: Distance = ", move_leftover)
				print("Selected cryptid position: ", current_pos)
				break

func axial_to_cube(hex):
	var q = hex.y
	var r = hex.x
	return Vector3i(q, r, -q-r)

func cube_to_axial(cube):
	return Vector2i(cube.x, cube.y)

func cube_subtract(a, b):
	return Vector3i(a.x - b.x, a.y - b.y, a.z - b.z)

func cube_distance(a, b):
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

func create_hex_map_a_star(start_pos):
	var toSearch = [start_pos]
	walkable_hexes.append(start_pos)
	var processed = {}
	var id_counter = 0
	a_star_hex_grid.clear()
	a_star_hex_attack_grid.clear()
	
	while toSearch.size() > 0:
		var current_node = toSearch.pop_front()
		if current_node in processed:
			continue

		a_star_hex_grid.add_point(id_counter, Vector2(current_node.x, current_node.y))
		a_star_hex_attack_grid.add_point(id_counter, Vector2(current_node.x, current_node.y))
		processed[current_node] = id_counter
		for neighbor in get_surrounding_cells(current_node):
			show_coordinates_label(neighbor)
			if neighbor not in processed and neighbor not in toSearch and get_cell_atlas_coords(neighbor) != Vector2i(-1, -1):
				toSearch.append(neighbor)
				walkable_hexes.append(neighbor)
		id_counter += 1

	for current_node in processed.keys():
		for neighbor in get_surrounding_cells(current_node):
			if neighbor in processed:
				a_star_hex_grid.connect_points(processed[current_node], processed[neighbor])
				a_star_hex_attack_grid.connect_points(processed[current_node], processed[neighbor])
				draw_line_between_points(map_to_local(current_node), map_to_local(neighbor))

func draw_line_between_points(point_a, point_b):
	var line = Line2D.new()
	line.width = 2
	line.default_color = Color(0, 0, 0)
	line.add_point(Vector2(point_a.x, point_a.y))
	line.add_point(Vector2(point_b.x, point_b.y))
	line_container.add_child(line)

func draw_lines_between_points(points, num_points, color):
	if points.size() < 2:
		return
	num_points += 1
	var line = Line2D.new()
	line.width = 4
	line.default_color = color

	for i in range(min(points.size(), num_points)):
		line.add_point(Vector2(points[i].x, points[i].y))
	line_container.add_child(line)

func convert_vector2_array_to_vector2i_array(vector2_array):
	var vector2i_array = []
	for vector2 in vector2_array:
		vector2i_array.append(Vector2i(round(vector2.x), round(vector2.y)))
	return vector2i_array

func delete_all_lines():
	for line in line_container.get_children():
		line.queue_free()

func show_coordinates_label(hex_coords):
	var coordinates = Label.new()
	coordinates.show()
	var label_pos = map_to_local(hex_coords)
	label_pos.x -= 20
	label_pos.y += 10
	coordinates.position = label_pos
	coordinates.text = str(local_to_map(label_pos))
	add_child(coordinates)
	
func any_cryptid_not_completed():
	for cryptid_in_play in all_cryptids_in_play:
		if cryptid_in_play.cryptid.completed_turn == false:
			return true 
	return false

func currently_selected_cryptid():
	# Debug which cryptids are in play
	
	# First check if any cryptid is marked as currently_selected
	for player_cryptid in all_cryptids_in_play:
		if player_cryptid.cryptid.currently_selected == true:
			return player_cryptid
	
	# If no cryptid is marked as currently_selected, check hand reference
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.selected_cryptid:
		print("No cryptid marked as selected, using hand.selected_cryptid: ", hand_node.selected_cryptid.name)
		
		# Find the cryptid in player_cryptids_in_play that matches hand.selected_cryptid
		for player_cryptid in all_cryptids_in_play:
			if player_cryptid.cryptid == hand_node.selected_cryptid:
				print("Found matching cryptid in player_cryptids_in_play")
				return player_cryptid
		
		# If we didn't find a match, just return the first cryptid
		print("WARNING: No matching cryptid found, using first cryptid")
		if all_cryptids_in_play.size() > 0:
			return all_cryptids_in_play[0]
	
	# If all else fails, return the first cryptid if available
	if all_cryptids_in_play.size() > 0:
		print("No selected cryptid found, defaulting to first cryptid")
		return all_cryptids_in_play[0]
	
	# If we get here, something is seriously wrong
	print("CRITICAL ERROR: No cryptids in play!")
	return null

# Function to compare two cryptid objects based on their speed
func compare_cryptids(a, b):
	return a.cryptid.speed > b.cryptid.speed  # Use boolean comparison

# Function to sort the array
func sort_cryptids_by_speed(cryptid_array):
	cryptid_array.sort_custom(Callable(self, "compare_cryptids"))

func show_attackable_area(center_pos, max_range):
	var center_hex = local_to_map(center_pos)
	var center_cube = axial_to_cube(center_hex)
	
	# Get all hexes within range
	for x in range(-max_range, max_range + 1):
		for y in range(max(-max_range, -x - max_range), min(max_range, -x + max_range) + 1):
			var z = -x - y
			var cube = Vector3i(center_cube.x + x, center_cube.y + y, center_cube.z + z)
			var hex = cube_to_axial(cube)
			
			# Check if hex is valid
			if get_cell_atlas_coords(hex) != Vector2i(-1, -1):
				# Draw a small indicator at this hex
				var indicator = ColorRect.new()
				indicator.color = Color(1, 0, 0, 0.3)  # Semi-transparent red
				indicator.size = Vector2(10, 10)
				indicator.position = map_to_local(hex) - Vector2(5, 5)
				indicator.name = "attack_indicator"
				add_child(indicator)
# Find a cryptid at a given hex position
func get_cryptid_at_position(hex_pos):
	for cryptid in all_cryptids_in_play:
		if local_to_map(cryptid.position) == hex_pos:
			return cryptid
	return null

# Apply damage to a target cryptid
func apply_damage(target_cryptid, damage_amount):
	# Access the health value from the add_to_party.gd script
	var health_var = target_cryptid.get_node("HealthBar")
	if health_var:
		health_var.value -= damage_amount
		
		# If you have a health getter/setter in your cryptid class
		target_cryptid.set_health_values(health_var.value, health_var.max_value)
		target_cryptid.update_health_bar()
	
	# Check if the cryptid is defeated
	if health_var and health_var.value <= 0:
		handle_cryptid_defeat(target_cryptid)

# Handle a defeated cryptid
func handle_cryptid_defeat(defeated_cryptid):
	# Remove from play
	if defeated_cryptid in player_cryptids_in_play:
		player_cryptids_in_play.erase(defeated_cryptid)
	elif defeated_cryptid in enemy_cryptids_in_play:
		enemy_cryptids_in_play.erase(defeated_cryptid)
	
	all_cryptids_in_play.erase(defeated_cryptid)
	
	# Make hex walkable again
	walkable_hexes.append(local_to_map(defeated_cryptid.position))
	var point = a_star_hex_grid.get_closest_point(local_to_map(defeated_cryptid.position), true)
	a_star_hex_grid.set_point_disabled(point, false)
	# Visual effect for defeat
	defeated_cryptid.modulate = Color(1, 0, 0, 0.5)  # Red fade
	
	# Remove after a delay
	var tween = get_tree().create_tween()
	tween.tween_property(defeated_cryptid, "modulate", Color(1, 0, 0, 0), 1.0)
	tween.tween_callback(Callable(defeated_cryptid, "queue_free"))

# Clean up attack indicators
func delete_all_indicators():
	for child in get_children():
		if child.name == "attack_indicator":
			child.queue_free()

func reset_action_modes():
	move_action_bool = false
	attack_action_bool = false
	active_movement_card_part = ""
	active_movement_card = null
	move_leftover = 0
	delete_all_lines()
	delete_all_indicators()
	remove_movement_indicator()

# Function to create a tween with proper completion tracking
func create_movement_tween():
	# Cancel any existing tween
	if current_tween != null and current_tween.is_valid():
		current_tween.kill()
	
	# Create a new tween
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_QUAD)
	current_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Set flag to indicate movement is in progress
	movement_in_progress = true
	
	# Add a callback when tween finishes
	current_tween.finished.connect(Callable(self, "_on_movement_tween_finished"))
	
	return current_tween

# Callback for when tween completes
func _on_movement_tween_finished():
	movement_in_progress = false
	current_tween = null
	
	# Re-enable input that might have been disabled during animation
	set_process_input(true)
	
	# Reset any visual cues used during movement
	delete_all_lines()
	
	# If we still have movement points left, make sure the current position is usable
	if move_action_bool and move_leftover > 0:
		# Get the current position of the selected cryptid
		var current_pos = local_to_map(selected_cryptid.position)
		
		# Make the current position usable as a starting point for the next segment
		var point = a_star_hex_grid.get_closest_point(current_pos, true)
		a_star_hex_grid.set_point_disabled(point, false)
		
		# Update the movement indicator to show remaining movement
		update_movement_indicator(selected_cryptid, move_leftover)
	else:
		# Clean up indicators if movement is complete
		remove_movement_indicator()
	
func create_movement_trail(cryptid_node, path):
	# Create a new line to show the path being followed
	var trail = Line2D.new()
	trail.width = 5
	trail.default_color = Color(0.2, 0.8, 0.2, 0.7)  # Semi-transparent green
	trail.z_index = -1  # Make sure it appears below the cryptid
	trail.name = "movement_trail"
	
	# Add all points in the path
	for point in path:
		trail.add_point(point)
	
	# Add the trail to the scene
	add_child(trail)
	
	return trail

# Function to remove the movement trail
func remove_movement_trail():
	for child in get_children():
		if child.name == "movement_trail":
			child.queue_free()
			
func animate_movement_along_path(cryptid_node, start_pos, end_pos):
	# If movement is already in progress, don't start another one
	if movement_in_progress:
		print("Movement already in progress, ignoring new movement command")
		return
	
	# First, make the original hex walkable again
	walkable_hexes.append(start_pos)
	var point = a_star_hex_grid.get_closest_point(start_pos, true)
	a_star_hex_grid.set_point_disabled(point, false)
	# Remove walkability from the destination hex immediately
	# so no other cryptid can move there during animation
	walkable_hexes.erase(end_pos)
	point = a_star_hex_grid.get_closest_point(end_pos, true)
	a_star_hex_grid.set_point_disabled(point)
	# Create a temp variable to store the full path
	var movement_path = vector_path.duplicate()
	
	# Ensure we're only using the points we need
	var needed_path = []
	for i in range(movement_path.size()):
		if i == 0 or local_to_map(movement_path[i]) != start_pos:
			needed_path.append(movement_path[i])
			
		# Stop when we reach the destination
		if local_to_map(movement_path[i]) == end_pos:
			break
	
	# Create visual trail for the movement
	var trail = create_movement_trail(cryptid_node, needed_path)
	
	# Create a tween for smooth movement
	var tween = create_movement_tween()
	
	# Add starting position effect
	var start_circle = ColorRect.new()
	start_circle.color = Color(0.2, 0.8, 0.2, 0.5)
	start_circle.size = Vector2(30, 30)
	start_circle.position = map_to_local(start_pos) - Vector2(15, 15)
	start_circle.name = "movement_marker"
	add_child(start_circle)
	
	# Pulse effect for start position
	var pulse_tween = create_tween()
	pulse_tween.tween_property(start_circle, "scale", Vector2(1.5, 1.5), 0.5)
	pulse_tween.tween_property(start_circle, "scale", Vector2(1.0, 1.0), 0.5)
	pulse_tween.tween_property(start_circle, "modulate", Color(0.2, 0.8, 0.2, 0), 0.3)
	
	# Disable input during movement to prevent multiple actions
	set_process_input(false)
	
	# Set movement speed (adjust this value to control animation speed)
	var movement_speed = 0.2  # seconds per hex
	
	# Animate through each point in the path
	for i in range(1, needed_path.size()):
		var duration = movement_speed
		tween.tween_property(cryptid_node, "position", needed_path[i], duration)
	
	# Add a small bounce at the end for visual feedback
	tween.tween_property(cryptid_node, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(cryptid_node, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Fade out the trail when finished
	tween.tween_callback(Callable(self, "fade_out_movement_effects"))

# Fade out movement effects
func fade_out_movement_effects():
	# Find all movement visual elements
	var trail = null
	var markers = []
	
	for child in get_children():
		if child.name == "movement_trail":
			trail = child
		elif child.name == "movement_marker":
			markers.append(child)
	
	# Create a tween to fade them out
	var fade_tween = create_tween()
	
	if trail:
		fade_tween.tween_property(trail, "modulate", Color(1, 1, 1, 0), 0.5)
	
	for marker in markers:
		fade_tween.parallel().tween_property(marker, "modulate", Color(1, 1, 1, 0), 0.5)
	
	# Clean up after fading
	fade_tween.tween_callback(Callable(self, "clean_up_movement_effects"))

# Clean up movement effects
func clean_up_movement_effects():
	for child in get_children():
		if child.name == "movement_trail" or child.name == "movement_marker":
			child.queue_free()

func animate_attack(attacker, target):
	print("Starting attack animation from", attacker, "to", target)
	
	# If movement is already in progress, don't start another one
	if movement_in_progress:
		print("Movement already in progress, ignoring attack animation")
		return
		
	print("Animation will proceed - movement_in_progress is false")
	
	# Store original position
	var original_position = attacker.position
	print("Original position:", original_position)
	
	# Calculate direction vector from attacker to target
	var direction = (target.position - original_position).normalized()
	print("Direction vector:", direction)
	
	# Calculate how far to bump (40% of the way to the target, max 60 pixels)
	# Increased values to make animation more noticeable
	var bump_distance = min((target.position - original_position).length() * 0.4, 60.0)
	var bump_position = original_position + direction * bump_distance
	print("Bump distance:", bump_distance, "New position:", bump_position)
	
	# Set flag to indicate movement is in progress
	movement_in_progress = true
	print("Set movement_in_progress to true")
	
	# Create a tween for the animation - using direct create_tween() instead of helper function
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	print("Created new tween:", tween)
	
	# Connect finished signal
	tween.finished.connect(Callable(self, "_on_attack_tween_finished").bind([target, damage]))
	
	# Disable input during animation
	set_process_input(false)
	print("Disabled input processing")
	
	# Start with a quick forward movement
	print("Starting animation to bump position:", bump_position)
	tween.tween_property(attacker, "position", bump_position, 0.2)
	
	# Then return to the original position with a slight bounce
	print("Adding return animation to original position:", original_position)
	tween.tween_property(attacker, "position", original_position, 0.3)
	
	# Create attack visual effect - using more noticeable effects
	create_attack_effect(attacker.position, target.position)
	
	return tween


# Create a visual effect for the attack
func create_attack_effect(start_pos, end_pos):
	print("Creating attack visual effects")
	
	# Create a line for the attack - thicker line with brighter color
	var attack_line = Line2D.new()
	attack_line.width = 8
	attack_line.default_color = Color(1, 0, 0, 0.9)  # Bright red
	attack_line.add_point(start_pos)
	attack_line.add_point(end_pos)
	attack_line.name = "attack_effect"
	attack_line.z_index = 10  # Make sure it appears above other elements
	add_child(attack_line)
	print("Added attack line from", start_pos, "to", end_pos)
	
	# Create impact effect at target - larger impact
	var impact = ColorRect.new()
	impact.color = Color(1, 0, 0, 0.8)
	impact.size = Vector2(40, 40)
	impact.position = end_pos - Vector2(20, 20)
	impact.name = "attack_effect"
	impact.z_index = 10  # Make sure it appears above other elements
	add_child(impact)
	print("Added impact effect at", end_pos)
	
	# Animate the attack effects - longer duration
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	# Flash the line with more dramatic effect
	effect_tween.tween_property(attack_line, "width", 15, 0.15)
	effect_tween.tween_property(attack_line, "width", 3, 0.35)
	
	# Expand the impact and fade out
	effect_tween.tween_property(impact, "scale", Vector2(2.0, 2.0), 0.4)
	effect_tween.tween_property(impact, "modulate", Color(1, 0, 0, 0), 0.4)
	
	# Clean up after animation
	effect_tween.tween_callback(Callable(self, "clean_up_attack_effects"))

# Clean up attack effects
func clean_up_attack_effects():
	for child in get_children():
		if child.name == "attack_effect":
			child.queue_free()
			
# Helper function to apply damage after animation completes
func apply_delayed_damage(params):
	print("Applying delayed damage")
	var target_cryptid = params[0]
	var damage_amount = params[1]
	
	# Apply the actual damage
	print("Applying", damage_amount, "damage to", target_cryptid)
	apply_damage(target_cryptid, damage_amount)
	
	print("Updating game state after successful attack")
	# Update all cards to show availability
	hand.update_card_availability()
	
	# Now show the action menu again with updated button state
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.has_method("update_menu_visibility"):
		action_menu.update_menu_visibility(selected_cryptid.cryptid)
		action_menu.show()
	
	# Check if turn is complete
	if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
		selected_cryptid.cryptid.completed_turn = true
		hand.next_cryptid_turn()
	
	# Reset action state
	print("Resetting attack action state")
	attack_action_bool = false
	delete_all_lines()
	delete_all_indicators()

# Function called when attack tween completes
func _on_attack_tween_finished(params):
	print("Attack animation finished")
	
	# Reset movement flag
	movement_in_progress = false
	print("Reset movement_in_progress to false")
	
	# Re-enable input
	set_process_input(true)
	print("Re-enabled input processing")
	
	# Apply damage and continue with game logic
	apply_delayed_damage(params)

func update_movement_indicator(cryptid, movement_left):
	# Remove any existing movement indicators first
	remove_movement_indicator()
	
	# Create a new label to show remaining movement
	var movement_label = Label.new()
	movement_label.name = "movement_indicator"
	movement_label.add_to_group("movement_indicators")  # Add to group for easy finding
	movement_label.text = str(movement_left)
	
	# Style the label
	movement_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green color
	movement_label.add_theme_font_size_override("font_size", 32)  # Larger font
	
	# Position it above the cryptid
	movement_label.position = Vector2(cryptid.position.x, cryptid.position.y - 40)
	
	# Add a background for better visibility
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)  # Semi-transparent black
	bg.size = Vector2(30, 30)
	bg.position = Vector2(-10, -5)
	movement_label.add_child(bg)
	bg.z_index = -1  # Ensure it's behind the text
	
	# Add it to the scene
	add_child(movement_label)
	
	
func remove_movement_indicator():
	# Find and remove all nodes with our custom group
	var indicators = get_tree().get_nodes_in_group("movement_indicators")
	for indicator in indicators:
		indicator.queue_free()

func get_active_movement_card_part():
	return active_movement_card_part

func get_active_movement_card():
	return active_movement_card

func is_movement_in_progress():
	return move_leftover > 0 and active_movement_card != null

func enable_all_card_halves():
	# Get all cards in the hand
	var cards = hand.get_children()
	
	for card in cards:
		if card.get_script() and card.get_script().resource_path.ends_with("card_dialog.gd"):
			# Don't enable cards that should be disabled
			if not selected_cryptid.cryptid.top_card_played:
				card.top_half_container.modulate = Color(1, 1, 1, 1)
			if not selected_cryptid.cryptid.bottom_card_played:
				card.bottom_half_container.modulate = Color(1, 1, 1, 1)

func disable_other_card_halves(active_card_half):
	# Get all cards in the hand
	var cards = hand.get_children()
	
	print("Disabling other card halves, active half: ", active_card_half)
	
	for card in cards:
		if card.get_script() and card.get_script().resource_path.ends_with("card_dialog.gd"):
			# Skip the active card
			if card == card_dialog:
				print("Skipping active card")
				continue
				
			# Disable the appropriate half based on active_card_half
			if active_card_half == "top":
				print("Disabling top half of other card: ", card.card_resource.top_move.name_prefix)
				card.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				# Don't change mouse filter to allow viewing
			elif active_card_half == "bottom":
				print("Disabling bottom half of other card: ", card.card_resource.bottom_move.name_suffix)
				card.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				# Don't change mouse filter to allow viewing

func reset_for_new_cryptid():
	# Reset all action states for a new cryptid's turn
	reset_action_modes()
	
	# Make sure the hand is updated correctly
	hand.update_card_availability()

func finish_movement():
	# Only do something if there's movement in progress
	if move_action_bool and move_leftover > 0:
		print("Finishing movement early with " + str(move_leftover) + " movement left")
		
		# Mark the card part as used
		if active_movement_card_part == "top":
			selected_cryptid.cryptid.top_card_played = true
			
			# Mark the original card as discarded
			if card_dialog.card_resource.original_card != null:
				print("DEBUG: Marking original card as discarded from move action")
				card_dialog.card_resource.original_card.current_state = Card.CardState.IN_DISCARD
				
				# Reset the card display to its original amount
				if card_dialog.has_method("update_move_action_display"):
					card_dialog.update_move_action_display("top", original_move_amount)
		
		elif active_movement_card_part == "bottom":
			selected_cryptid.cryptid.bottom_card_played = true
			
			# Mark the original card as discarded
			if card_dialog.card_resource.original_card != null:
				print("DEBUG: Marking original card as discarded from move action")
				card_dialog.card_resource.original_card.current_state = Card.CardState.IN_DISCARD
				
				# Reset the card display to its original amount
				if card_dialog.has_method("update_move_action_display"):
					card_dialog.update_move_action_display("bottom", original_move_amount)
		
		# Reset movement state
		move_action_bool = false
		move_leftover = 0
		active_movement_card_part = ""
		active_movement_card = null
		
		# Clean up visuals
		remove_movement_indicator()
		delete_all_lines()
		
		# Re-enable cards
		enable_all_card_halves()
		
		# Update UI
		hand.update_card_availability()
		
		# Check if turn is complete
		if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
			selected_cryptid.cryptid.completed_turn = true
			hand.next_cryptid_turn()
	else:
		print("No movement in progress to finish")
