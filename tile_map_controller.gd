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
@onready var debug_container = Node2D.new()
var debug_indicators = {}  # Dictionary to track all debug indicators by point ID
var debug_enabled = true   # Toggle for the debug display


@onready var player_team = %PlayerTeam
@onready var enemy_team = %EnemyTeam
@onready var player_starting_positions = [Vector2i(-4, -1), Vector2i(-2, 1), Vector2i(0, 1)]
@onready var enemy_starting_positions = [Vector2i(-4, -3), Vector2i(-2, -3), Vector2i(0, -3)]

var active_movement_card = null
var movement_in_progress = false
var current_tween = null

@onready var player_cryptids_in_play = []
@onready var enemy_cryptids_in_play = []

@onready var all_cryptids_in_play = []

@onready var blank_cryptid = preload("res://Cryptid-Menagerie/data/cryptids/blank_cryptid.tscn")
@onready var current_card

var defeated_cryptids = []
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
	
	debug_container.name = "DebugContainer"
	debug_container.z_index = 100  # Make sure debug visuals appear above everything else
	add_child(debug_container)
	
	# Call this at the end of _ready() to set up initial debug display
	call_deferred("setup_debug_display")
	
	var grid_check_timer = Timer.new()
	grid_check_timer.name = "GridStateVerifier"
	grid_check_timer.wait_time = 5.0  # Check every 5 seconds
	grid_check_timer.autostart = true
	grid_check_timer.one_shot = false
	grid_check_timer.timeout.connect(verify_grid_state)
	add_child(grid_check_timer)
	

func _process(delta):
	# Only handle mouse motion during player turns, not during AI turns
	if move_action_bool:
		# Check if the current cryptid is an enemy (AI controlled)
		var current_cryptid = currently_selected_cryptid()
		var is_enemy_turn = false
		
		if current_cryptid:
			is_enemy_turn = current_cryptid in enemy_cryptids_in_play
		
		# Only process mouse motion if it's not an enemy's turn
		if not is_enemy_turn:
			handle_mouse_motion()
	if debug_enabled and Engine.get_frames_drawn() % 30 == 0:  # Update every 30 frames
		update_all_debug_indicators()

#Place player and enemy teams on map
func initialize_starting_positions(starting_positions : Array, team):
	var cryptids_in_play = []
	for positions in starting_positions:
		var cryptid
		cryptid = blank_cryptid.instantiate()
		cryptid.cryptid = team._content[cryptids_in_play.size()]
		team.add_child(cryptid)
		
		cryptid.position = map_to_local(starting_positions[cryptids_in_play.size()])
		cryptid.hand = %Hand
		cryptids_in_play.append(cryptid)
		
		# Use our debug-enabled function instead of directly calling A*
		var point = a_star_hex_grid.get_closest_point(positions, true)
		a_star_hex_grid.set_point_disabled(point, true)  # Use our wrapper function
	return cryptids_in_play

# Add a helper function to update all debug indicators
func refresh_debug_display():
	if not debug_enabled:
		return
		
	print("Refreshing all A* hex grid debug indicators")
	
	for point_id in a_star_hex_grid.get_points():
		update_debug_indicator(point_id)
# Update handle_right_click function to also finish movement
func handle_right_click():
	print("Right-click detected - cancelling current action")
	
	# If there's movement in progress, finish it
	if move_action_bool and move_leftover > 0:
		finish_movement()
		return
	
	# Otherwise clear action states
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
		action_menu.prompt_player_for_action()

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
			
# Update the handle_left_click function to prevent actions during discard mode
func handle_left_click(event):
	var global_clicked = event.position
	selected_cryptid = currently_selected_cryptid()
	var pos_clicked = local_to_map(to_local(global_clicked))
	
	# Check if we're in discard mode
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.in_discard_mode:
		print("In discard mode, ignoring card activation clicks")
		return
	
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
	# Update debug display at the start of the move action
	update_all_debug_indicators()
	
	# Calculate the movement distance required for this move
	var movement_distance = point_path.size() - 1
	
	# Flag to track if move was successful
	var move_success = false
	
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
							
							# Handle based on whether we've used all movement
							if move_leftover <= 0:
								# Mark only the top half as used for action economy
								selected_cryptid.cryptid.top_card_played = true
								
								# Set the movement amount to zero in this card instance
								for move_action in card_dialog.card_resource.top_move.actions:
									if move_action.action_types == [0]:  # Move action
										# Update to zero to make it clear this action is used up
										move_action.amount = 0
										break
								
								# Update the display to show zero movement left
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("top", 0)
								
								# But visually disable both halves
								disable_entire_card(card_dialog)
								
								# Discard the card
								discard_card(card_dialog, selected_cryptid.cryptid)
								
								# Make sure to update the hand's UI
								if hand and hand.has_method("update_card_availability"):
									hand.update_card_availability()
							else:
								# We have more movement left, disable other cards
								# Disable bottom half of this card 
								card_dialog.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								card_dialog.bottom_half_container.disabled = true
								
								# Disable top half of all other cards
								disable_other_card_halves("top")
								
								# Store original move amount in the card instance's data
								if not card_dialog.has_meta("original_move_amount"):
									card_dialog.set_meta("original_move_amount", original_move_amount)
								
								# Update card display to show remaining movement
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("top", move_leftover)
									
								# Important: Also update the actual action value in this card instance
								for move_action in card_dialog.card_resource.top_move.actions:
									if move_action.action_types == [0]:  # Move action
										# Only update this specific card instance's action amount
										move_action.amount = move_leftover
										break
								
								# IMPORTANT: Do NOT mark the card as discarded or used yet
								# since we still have movement left
			
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
							
							# Handle based on whether we've used all movement
							if move_leftover <= 0:
								# Mark only the bottom half as used for action economy
								selected_cryptid.cryptid.bottom_card_played = true
								
								# Set the movement amount to zero in this card instance
								for move_action in card_dialog.card_resource.bottom_move.actions:
									if move_action.action_types == [0]:  # Move action
										# Update to zero to make it clear this action is used up
										move_action.amount = 0
										break
								
								# Update the display to show zero movement left
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("bottom", 0)
								
								# But visually disable both halves
								disable_entire_card(card_dialog)
								
								# Discard the card
								discard_card(card_dialog, selected_cryptid.cryptid)
								
								# Make sure to update the hand's UI
								if hand and hand.has_method("update_card_availability"):
									hand.update_card_availability()
							else:
								# We have more movement left, disable other cards
								# Disable top half of this card
								card_dialog.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
								card_dialog.top_half_container.disabled = true
								
								# Disable bottom half of all other cards
								disable_other_card_halves("bottom")
								
								# Store original move amount in the card instance's data
								if not card_dialog.has_meta("original_move_amount"):
									card_dialog.set_meta("original_move_amount", original_move_amount)
								
								# Update card display to show remaining movement
								if card_dialog.has_method("update_move_action_display"):
									card_dialog.update_move_action_display("bottom", move_leftover)
								
								# Important: Also update the actual action value in this card instance
								for move_action in card_dialog.card_resource.bottom_move.actions:
									if move_action.action_types == [0]:  # Move action
										# Only update this specific card instance's action amount
										move_action.amount = move_leftover
										break
								
								# IMPORTANT: Do NOT mark the card as discarded or used yet
								# since we still have movement left
		
		# Handle the case where card_dialog is not valid - AI controlled cryptids
		else:
			print("Card dialog not valid - likely AI controlled move")
			
			# For AI moves, we still need to perform the movement
			var new_position = pos_clicked
			move_performed = (original_position != new_position)
			
			if move_performed:
				# Update return flag
				move_success = true
				
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
				
				# Instead of directly going to next cryptid, update the UI to prompt
				# for the End Turn button
				if action_menu and action_menu.has_method("show_end_turn_only"):
					action_menu.show_end_turn_only()
					
				var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
				if game_instructions:
					game_instructions.text = "Turn complete. Press End Turn to continue."
			
			# After a successful move, update the menu
			if action_menu and action_menu.has_method("update_menu_visibility") and selected_cryptid:
				# This will update menu to show only End Turn if a card action was used
				action_menu.update_menu_visibility(selected_cryptid.cryptid)
				action_menu.show()
			update_all_debug_indicators()
	else:
		print("Invalid move: Clicked on a non-walkable hex or insufficient movement points")
		print("Required movement: ", movement_distance, ", Available movement: ", move_leftover)
		
		# IMPORTANT: If the move failed, make sure the target hex is not disabled
		# This is key to fixing the bug
		var point = a_star_hex_grid.get_closest_point(pos_clicked, true)
		if a_star_hex_grid.is_point_disabled(point):
			print("CLEANUP: Re-enabling hex that was incorrectly disabled due to failed move")
			set_point_disabled(point, false)
	
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
	update_all_debug_indicators()
	delete_all_lines()
	return move_success

func attack_action_selected(current_card):
	# Check if we're in discard mode
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.in_discard_mode:
		print("In discard mode, ignoring attack action selection")
		return
	
	print("\n---------- ATTACK ACTION SELECTED DEBUG ----------")
	card_dialog = current_card
	
	# Reset action states
	move_action_bool = false
	attack_action_bool = false
	
	# Debug info
	print("Selected card:", card_dialog)
	
	# Make sure we have the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	if selected_cryptid == null:
		print("ERROR: No selected cryptid found")
		return
	
	print("Selected cryptid:", selected_cryptid.cryptid.name)
	print("Top card played:", selected_cryptid.cryptid.top_card_played)
	print("Bottom card played:", selected_cryptid.cryptid.bottom_card_played)
	
	# Clear visual indicators
	delete_all_lines()
	
	# Get the VBoxContainer first
	var vbox = card_dialog.get_node_or_null("VBoxContainer")
	if not vbox:
		print("ERROR: VBoxContainer not found")
		return
	
	# Now get the correct container nodes using the exact path
	var top_half_container = vbox.get_node_or_null("TopHalfContainer")
	var bottom_half_container = vbox.get_node_or_null("BottomHalfContainer")
	
	print("Top half container found:", top_half_container != null)
	print("Bottom half container found:", bottom_half_container != null)
	
	if not top_half_container or not bottom_half_container:
		print("ERROR: Container nodes not found")
		return
	
	# Check which half is currently highlighted
	var top_highlighted = is_yellow_highlighted(top_half_container.modulate)
	var bottom_highlighted = is_yellow_highlighted(bottom_half_container.modulate)
	
	print("Top half highlighted:", top_highlighted)
	print("Bottom half highlighted:", bottom_highlighted)
	
	# Check for attack action based on our findings
	var found_attack = false
	
	# Debug the card resource
	print("\n--- CARD RESOURCE ANALYSIS ---")
	if card_dialog.get("card_resource") != null:
		var card_resource = card_dialog.card_resource
		print("Card resource found")
		
		# Check top move actions
		if top_highlighted and not selected_cryptid.cryptid.top_card_played:
			print("Checking top move actions")
			if card_resource.get("top_move") != null and card_resource.top_move.get("actions") != null:
				for action in card_resource.top_move.actions:
					print("Action type:", action.action_types)
					if 1 in action.action_types:  # Attack action type (1)
						print("Found attack action in top half")
						attack_range = action.range
						damage = action.amount
						attack_action_bool = true
						active_movement_card_part = "top"
						found_attack = true
						break
		
		# Check bottom move actions
		if not found_attack and bottom_highlighted and not selected_cryptid.cryptid.bottom_card_played:
			print("Checking bottom move actions")
			if card_resource.get("bottom_move") != null and card_resource.bottom_move.get("actions") != null:
				for action in card_resource.bottom_move.actions:
					print("Action type:", action.action_types)
					if 1 in action.action_types:  # Attack action type (1)
						print("Found attack action in bottom half")
						attack_range = action.range
						damage = action.amount
						attack_action_bool = true
						active_movement_card_part = "bottom"
						found_attack = true
						break
	else:
		print("ERROR: card_resource not found")
	print("--- END CARD RESOURCE ANALYSIS ---\n")
	
	# Provide detailed feedback
	if not attack_action_bool:
		print("ERROR: Failed to activate attack action")
		
		if selected_cryptid.cryptid.top_card_played and top_highlighted:
			print("Top action already used this turn")
		elif selected_cryptid.cryptid.bottom_card_played and bottom_highlighted:
			print("Bottom action already used this turn")
		else:
			print("No valid attack action found in the selected card half")
	else:
		print("Successfully activated attack action with range:", attack_range)
		
		# Store references for handle_attack_action
		if active_movement_card_part == "top":
			card_dialog.top_half_container = top_half_container
			disable_other_cards_exact("top")
		elif active_movement_card_part == "bottom":
			card_dialog.bottom_half_container = bottom_half_container
			disable_other_cards_exact("bottom")
	
	print("---------- END ATTACK ACTION SELECTED DEBUG ----------\n")

# Add this helper function for more reliable color comparison
func _is_color_close(color1, color2, tolerance = 0.1):
	return (
		abs(color1.r - color2.r) < tolerance and
		abs(color1.g - color2.g) < tolerance and
		abs(color1.b - color2.b) < tolerance and
		abs(color1.a - color2.a) < tolerance
	)

func handle_attack_action(pos_clicked):
	print("\n---------- HANDLE ATTACK ACTION DEBUG ----------")
	
	var target_cryptid = get_cryptid_at_position(pos_clicked)
	print("Target position:", pos_clicked)
	print("Target cryptid:", target_cryptid)
	
	var attack_performed = false
	var valid_target = false
	
	# Early exit if no target found
	if target_cryptid == null:
		print("Invalid attack: No valid target at the selected position")
		print("---------- END HANDLE ATTACK ACTION DEBUG ----------\n")
		
		# Reset action state
		attack_action_bool = false
		active_movement_card_part = ""
		active_movement_card = null
		delete_all_lines()
		delete_all_indicators()
		
		force_update_discard_display()
		return false
	
	# Get the attacking cryptid
	selected_cryptid = currently_selected_cryptid()
	
	# Determine if this is a valid target based on attacker type
	if selected_cryptid in player_cryptids_in_play and target_cryptid in enemy_cryptids_in_play:
		valid_target = true
		print("Valid target: Player attacking enemy")
	elif selected_cryptid in enemy_cryptids_in_play and target_cryptid in player_cryptids_in_play:
		valid_target = true
		print("Valid target: Enemy attacking player")
	else:
		valid_target = false
		print("Invalid target: Cannot attack your own team")
	
	# Only proceed if targeting a valid cryptid
	if valid_target:
		print("Valid target found")
		
		# Calculate attack distance
		var current_pos = local_to_map(selected_cryptid.position)
		var target_pos = local_to_map(target_cryptid.position)
		var attack_path = a_star_hex_attack_grid.get_id_path(
			a_star_hex_attack_grid.get_closest_point(current_pos),
			a_star_hex_attack_grid.get_closest_point(target_pos)
		)
		
		# Extra safety check for valid path
		if attack_path.size() == 0:
			print("ERROR: No valid attack path found")
			print("---------- END HANDLE ATTACK ACTION DEBUG ----------\n")
			return false
			
		var attack_distance = attack_path.size() - 1
		
		print("Attack distance:", attack_distance, "Attack range:", attack_range)
		
		if attack_distance <= attack_range:
			print("Target is within range")
			
			# Get the top and bottom containers from the card dialog
			var top_half_container = null
			var bottom_half_container = null
			
			if is_instance_valid(card_dialog):
				var vbox = card_dialog.get_node_or_null("VBoxContainer")
				if vbox:
					top_half_container = vbox.get_node_or_null("TopHalfContainer")
					bottom_half_container = vbox.get_node_or_null("BottomHalfContainer")
			
			# Determine which half is being used
			var using_top_half = false
			var using_bottom_half = false
			
			if top_half_container and is_yellow_highlighted(top_half_container.modulate):
				using_top_half = true
				print("Using top half for attack")
			elif bottom_half_container and is_yellow_highlighted(bottom_half_container.modulate):
				using_bottom_half = true
				print("Using bottom half for attack")
			else:
				# If we can't determine from color, use active_movement_card_part
				print("Cannot determine from color, using active_movement_card_part:", active_movement_card_part)
				using_top_half = active_movement_card_part == "top"
				using_bottom_half = active_movement_card_part == "bottom"
			
			# Play the attack animation
			print("Starting attack animation")
			animate_attack(selected_cryptid, target_cryptid)
			
			attack_performed = true
			print("Attack performed successfully")
			
			# Process card state changes immediately
			if attack_performed:
				# Mark only the appropriate half as "played" for action economy
				if using_top_half:
					selected_cryptid.cryptid.top_card_played = true
					print("Marked top half as played for action economy")
				elif using_bottom_half:
					selected_cryptid.cryptid.bottom_card_played = true
					print("Marked bottom half as played for action economy")
				
				# But visually disable the entire card
				disable_entire_card(card_dialog)
				
				# Discard the card
				discard_card(card_dialog, selected_cryptid.cryptid)
				
				# Disable other cards with the selected half
				if using_top_half:
					disable_other_cards_exact("top")
				elif using_bottom_half:
					disable_other_cards_exact("bottom")
				
				# Update hand to reflect changes
				var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
				if hand_node and hand_node.has_method("update_card_availability"):
					hand_node.update_card_availability()
				
				# Check if turn is complete
				if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
					selected_cryptid.cryptid.completed_turn = true
					print("Marked cryptid's turn as complete")
					
					# Instead of directly going to next cryptid, update the UI to prompt
					# for the End Turn button
					var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
					if action_menu and action_menu.has_method("show_end_turn_only"):
						action_menu.show_end_turn_only()
						
					var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
					if game_instructions:
						game_instructions.text = "Turn complete. Press End Turn to continue."
				
				# Show the action menu again with updated button state
				var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
				if action_menu and action_menu.has_method("update_menu_visibility"):
					action_menu.update_menu_visibility(selected_cryptid.cryptid)
					action_menu.show()
		else:
			print("Target out of range")
	else:
		print("Invalid attack: No valid target at the selected position")
	
	# Reset action state if no attack was performed
	if not attack_performed:
		print("No attack performed - resetting action state")
		attack_action_bool = false
		active_movement_card_part = ""
		active_movement_card = null
		delete_all_lines()
		delete_all_indicators()
	
	# Always update the menu if an attack was performed
	if attack_performed:
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu and action_menu.has_method("update_menu_visibility") and selected_cryptid:
			# This will update menu to show only End Turn after attack
			action_menu.update_menu_visibility(selected_cryptid.cryptid)
			action_menu.show()
		
	force_update_discard_display()
	print("---------- END HANDLE ATTACK ACTION DEBUG ----------\n")
	return attack_performed


# Add this more verbose version of disable_other_card_halves for debugging
func disable_other_card_halves_debug(active_card_half):
	print("\n---------- DISABLE OTHER CARD HALVES DEBUG ----------")
	print("Active card half:", active_card_half)
	
	# Get all cards in the hand
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if not hand_node:
		print("ERROR: Hand node not found!")
		# Try alternate methods
		hand_node = hand
		if not hand_node:
			print("ERROR: Hand reference also not valid!")
			return
	
	print("Found hand node:", hand_node)
	var cards = hand_node.get_children()
	print("Found", cards.size(), "children in hand")
	
	var valid_card_count = 0
	
	for card in cards:
		if not is_instance_valid(card):
			print("WARNING: Invalid card instance, skipping")
			continue
			
		print("Processing card:", card)
		
		# Check if this is a card dialog by script path
		var is_card_dialog = false
		if card.get_script():
			var script_path = card.get_script().resource_path
			print("Card script path:", script_path)
			is_card_dialog = script_path.ends_with("card_dialog.gd")
		else:
			print("WARNING: Card has no script")
		
		if is_card_dialog:
			valid_card_count += 1
			print("Found valid card dialog")
			
			# Skip the active card
			if card == card_dialog:
				print("Skipping active card")
				continue
			
			# Check if the card has the required containers
			var has_top_container = card.has_node("TopHalfContainer")
			var has_bottom_container = card.has_node("BottomHalfContainer")
			
			print("Has top container:", has_top_container)
			print("Has bottom container:", has_bottom_container)
			
			# Disable the appropriate half
			if active_card_half == "top" and has_top_container:
				var top_container = card.get_node("TopHalfContainer")
				print("Disabling top half of other card")
				top_container.modulate = Color(0.5, 0.5, 0.5, 1)
				top_container.disabled = true
			elif active_card_half == "bottom" and has_bottom_container:
				var bottom_container = card.get_node("BottomHalfContainer")
				print("Disabling bottom half of other card")
				bottom_container.modulate = Color(0.5, 0.5, 0.5, 1)
				bottom_container.disabled = true
	
	print("Processed", valid_card_count, "valid card dialogs")
	print("---------- END DISABLE OTHER CARD HALVES DEBUG ----------\n")

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

# Update the move_action_selected function to prevent activating during discard
func move_action_selected(current_card):
	# Check if we're in discard mode
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.in_discard_mode:
		print("In discard mode, ignoring move action selection")
		return
	
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
func sort_cryptids_by_speed(cryptids_list):
	print("Sorting cryptids list by speed...")
	
	# Make sure we're not trying to sort an empty list
	if cryptids_list.size() <= 1:
		print("List has 0 or 1 cryptids - no sorting needed")
		return
	
	# Sort the list in-place using a bubble sort for clarity
	# We use bubble sort here instead of sort_custom because we want to modify the original list
	var n = cryptids_list.size()
	for i in range(n):
		for j in range(0, n - i - 1):
			# Get speed values from cryptids, default to 0 if not set
			var speed_j = cryptids_list[j].cryptid.get("speed") if cryptids_list[j].cryptid.get("speed") != null else 0
			var speed_j_plus_1 = cryptids_list[j + 1].cryptid.get("speed") if cryptids_list[j + 1].cryptid.get("speed") != null else 0
			
			# Compare speeds (higher speed acts first, so we want descending order)
			if speed_j < speed_j_plus_1:
				# Swap elements
				var temp = cryptids_list[j]
				cryptids_list[j] = cryptids_list[j + 1]
				cryptids_list[j + 1] = temp
	
	# Print the sorted list for debugging
	print("Sorted cryptids by speed (higher speed first):")
	for i in range(cryptids_list.size()):
		var speed = cryptids_list[i].cryptid.get("speed") if cryptids_list[i].cryptid.get("speed") != null else 0
		print("  " + str(i+1) + ". " + cryptids_list[i].cryptid.name + " - Speed: " + str(speed))

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
# Apply damage to a target cryptid - updated to directly trigger emergency swap
func apply_damage(target_cryptid, damage_amount):
	print("Applying " + str(damage_amount) + " damage to " + target_cryptid.cryptid.name)
	
	# Access the health value from the add_to_party.gd script
	var health_bar = target_cryptid.get_node("HealthBar")
	if health_bar:
		# Calculate new health value
		var new_health = health_bar.value - damage_amount
		
		# Update health bar
		health_bar.value = new_health
		
		# If you have a health getter/setter in your cryptid class
		target_cryptid.set_health_values(new_health, health_bar.max_value)
		target_cryptid.update_health_bar()
		
		print("Health reduced to: " + str(new_health) + "/" + str(health_bar.max_value))
		
		# Check if the cryptid is defeated
		if new_health <= 0:
			print("Cryptid " + target_cryptid.cryptid.name + " has been defeated!")
			
			# Store health metadata before handling defeat
			target_cryptid.cryptid.set_meta("current_health", 0)
			print("Set current_health metadata to 0 for defeated cryptid")
			
			# Check if this is a player cryptid
			var is_player_cryptid = target_cryptid in player_cryptids_in_play
			print("Is player cryptid: " + str(is_player_cryptid))
			
			if is_player_cryptid:
				# Get game controller for defeat tracking
				var game_controller = get_node("/root/VitaChrome/TileMapLayer/GameController")
				if game_controller and game_controller.has_method("mark_cryptid_defeated"):
					game_controller.mark_cryptid_defeated(target_cryptid.cryptid.name)
					print("Marked as defeated:", target_cryptid.cryptid.name)
				
				# Check if there are any bench cryptids available for swap
				if has_bench_cryptids():
					print("Player cryptid defeated! Triggering emergency swap!")
					
					# Store position data for the swap
					var defeated_position = target_cryptid.position
					var map_pos = local_to_map(defeated_position)
					
					# Mark the hex as walkable
					walkable_hexes.append(map_pos)
					var point = a_star_hex_grid.get_closest_point(map_pos, true)
					a_star_hex_grid.set_point_disabled(point, false)
					
					# Visual effect for defeat
					target_cryptid.modulate = Color(1, 0, 0, 0.5)  # Red fade
					
					# Store position metadata
					target_cryptid.set_meta("defeated_position", defeated_position)
					target_cryptid.set_meta("defeated_map_pos", map_pos)
					
					# Trigger emergency swap
					if game_controller and game_controller.has_method("prompt_emergency_swap"):
						game_controller.prompt_emergency_swap(target_cryptid)
					else:
						print("ERROR: Could not find prompt_emergency_swap method!")
						handle_cryptid_defeat(target_cryptid)
				else:
					print("No bench cryptids available for emergency swap!")
					# FIXED: Properly get the game_instructions reference
					var game_instructions = get_node_or_null("/root/VitaChrome/UIRoot/GameInstructions")
					if game_instructions:
						game_instructions.text = "No cryptids available for swap. Battle lost!"
					handle_cryptid_defeat(target_cryptid)
			else:
				# For enemy cryptids, handle defeat normally
				handle_cryptid_defeat(target_cryptid)
	else:
		print("ERROR: Could not find health bar on target cryptid!")

# Helper function to check if bench cryptids are available
func has_bench_cryptids():
	# Get the player team
	var player_team_node = get_node_or_null("/root/VitaChrome/TileMapLayer/PlayerTeam")
	if player_team_node:
		# Count valid cryptids (not defeated)
		var valid_cryptids = 0
		var cryptids = []
		
		if player_team_node.has_method("get_cryptids"):
			cryptids = player_team_node.get_cryptids()
		elif player_team_node.get("_content") != null:
			cryptids = player_team_node._content
		elif player_team_node.get("cryptidTeam") != null:
			var team = player_team_node.cryptidTeam
			if team.has_method("get_cryptids"):
				cryptids = team.get_cryptids()
			elif team.get("_content") != null:
				cryptids = team._content
		
		# Check for valid cryptids (not on battlefield and not defeated)
		for cryptid in cryptids:
			if cryptid == null:
				continue
			
			# Skip if defeated
			var is_defeated = false
			var game_controller = get_node_or_null("/root/VitaChrome/TileMapLayer/GameController")
			if game_controller and game_controller.get("defeated_cryptids") != null:
				if game_controller.defeated_cryptids.has(cryptid.name):
					is_defeated = true
			
			if !is_defeated:
				# Check if this cryptid is already on the battlefield
				var on_battlefield = false
				for cryptid_node in player_cryptids_in_play:
					if cryptid_node.cryptid.name == cryptid.name:
						on_battlefield = true
						break
				
				if !on_battlefield:
					valid_cryptids += 1
		
		print("Found", valid_cryptids, "valid bench cryptids")
		return valid_cryptids > 0
	
	# Default to false if we couldn't determine
	return false

func handle_cryptid_defeat(defeated_cryptid):
	# CRITICAL: Make sure we get the GameController first, before anything else
	var game_controller = get_node_or_null("/root/VitaChrome/TileMapLayer/GameController")
	
	# Record this cryptid as permanently defeated in all lists
	if game_controller and game_controller.has_method("mark_cryptid_defeated"):
		game_controller.mark_cryptid_defeated(defeated_cryptid.cryptid.name)
		print("Marked cryptid as permanently defeated:", defeated_cryptid.cryptid.name)
	else:
		print("ERROR: Could not find GameController or mark_cryptid_defeated method")
		
		# Fallback: Add to direct trackers
		if Engine.has_singleton("DefeatedCryptidsTracker"):
			var tracker = Engine.get_singleton("DefeatedCryptidsTracker")
			tracker.add_defeated(defeated_cryptid.cryptid.name)
			print("Added to global tracker:", defeated_cryptid.cryptid.name)
	
	# IMPORTANT: Always remove the cryptid from the appropriate lists
	if defeated_cryptid in player_cryptids_in_play:
		print("Removing defeated player cryptid from player_cryptids_in_play:", defeated_cryptid.cryptid.name)
		player_cryptids_in_play.erase(defeated_cryptid)
	elif defeated_cryptid in enemy_cryptids_in_play:
		print("Removing defeated enemy cryptid from enemy_cryptids_in_play:", defeated_cryptid.cryptid.name)
		enemy_cryptids_in_play.erase(defeated_cryptid)
	
	# Also remove from all_cryptids_in_play
	if defeated_cryptid in all_cryptids_in_play:
		print("Removing defeated cryptid from all_cryptids_in_play:", defeated_cryptid.cryptid.name)
		all_cryptids_in_play.erase(defeated_cryptid)
	else:
		print("WARNING: Defeated cryptid not found in all_cryptids_in_play:", defeated_cryptid.cryptid.name)
		# Try to find by name as fallback
		for i in range(all_cryptids_in_play.size() - 1, -1, -1):
			if all_cryptids_in_play[i].cryptid.name == defeated_cryptid.cryptid.name:
				print("Found by name and removing from all_cryptids_in_play:", defeated_cryptid.cryptid.name)
				all_cryptids_in_play.remove_at(i)
				break
	
	# Make hex walkable again
	var map_pos = local_to_map(defeated_cryptid.position)
	walkable_hexes.append(map_pos)
	var point = a_star_hex_grid.get_closest_point(map_pos, true)
	a_star_hex_grid.set_point_disabled(point, false)
	
	# Update turn order to reflect the removal
	var turn_order = get_node_or_null("/root/VitaChrome/UIRoot/Turn Order")
	if turn_order and turn_order.has_method("initialize_cryptid_labels"):
		turn_order.initialize_cryptid_labels()
		print("Updated turn order after cryptid defeat")
	
	# Visual effect for defeat
	defeated_cryptid.modulate = Color(1, 0, 0, 0.5)  # Red fade
	
	# Remove after a delay (just visually - we've already removed from the lists)
	var tween = get_tree().create_tween()
	tween.tween_property(defeated_cryptid, "modulate", Color(1, 0, 0, 0), 1.0)
	tween.tween_callback(Callable(defeated_cryptid, "queue_free"))
	
	# Also remove the defeated cryptid's parent from the tree if it exists
	var parent = defeated_cryptid.get_parent()
	if parent and parent.get_child_count() <= 1:
		# If this was the only child, schedule the parent for removal too
		tween.tween_callback(Callable(parent, "queue_free"))

# Add a fallback emergency swap function - for redundancy
# Add a fallback emergency swap function - for redundancy
func _create_emergency_swap_team(defeated_cryptid):
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
			if child.cryptid.name == defeated_cryptid.cryptid.name:
				print("EXCLUDING defeated cryptid from options:", child.cryptid.name)
				continue
				
			# Also skip any cryptid in the global defeated list
			if GameController.globally_defeated_cryptids.has(child.cryptid.name):
				print("EXCLUDING globally defeated cryptid:", child.cryptid.name)
				continue
				
			# Add to swap options
			temp_team.add_cryptid(child.cryptid)
			print("Adding cryptid to filtered team:", child.cryptid.name)
	
	# Add a few extra cryptids for dev/testing (if needed)
	if player_cryptids_in_play.size() > 0 && temp_team.get_cryptids().size() < 2:
		var first_cryptid = null
		for cryptid in player_cryptids_in_play:
			if cryptid.cryptid.name != defeated_cryptid.cryptid.name and !GameController.globally_defeated_cryptids.has(cryptid.cryptid.name):
				first_cryptid = cryptid.cryptid
				break
		
		if first_cryptid:
			for i in range(1, 4):
				var new_name = first_cryptid.name + " " + str(400 + i)
				
				# Skip if already in globally defeated list
				if GameController.globally_defeated_cryptids.has(new_name):
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
	
	# Find the swap dialog
	var swap_dialog = get_node_or_null("/root/VitaChrome/UIRoot/SwapCryptidDialog")
	if swap_dialog:
		# Open the dialog with the filtered team
		swap_dialog.open(temp_team, defeated_cryptid.cryptid, player_cryptids_in_play)
	else:
		print("ERROR: Could not find SwapCryptidDialog!")

func remove_defeated_cryptid(defeated_cryptid):
	# Remove from appropriate lists
	if defeated_cryptid in player_cryptids_in_play:
		player_cryptids_in_play.erase(defeated_cryptid)
	elif defeated_cryptid in enemy_cryptids_in_play:
		enemy_cryptids_in_play.erase(defeated_cryptid)
	
	all_cryptids_in_play.erase(defeated_cryptid)
	
	# Remove with fade animation
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
	
	# IMPORTANT: Check if selected_cryptid is still valid before accessing it
	if !is_instance_valid(selected_cryptid):
		print("WARNING: selected_cryptid is no longer valid in _on_movement_tween_finished")
		# Clean up any movement indicators just to be safe
		remove_movement_indicator()
		# Update debug display after movement completes
		update_all_debug_indicators()
		return
	
	# Get the current position of the selected cryptid
	var current_pos = local_to_map(selected_cryptid.position)
	
	# If we still have movement points left, make sure the current position is usable
	if move_action_bool and move_leftover > 0:
		# Make the current position usable as a starting point for the next segment
		var point = a_star_hex_grid.get_closest_point(current_pos, true)
		set_point_disabled(point, false)
		
		# Update the movement indicator to show remaining movement
		update_movement_indicator(selected_cryptid, move_leftover)
	else:
		# Clean up indicators if movement is complete
		remove_movement_indicator()
	
	# Update debug display after movement completes
	update_all_debug_indicators()
	
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
	
	# Ensure cryptid_node is still valid
	if !is_instance_valid(cryptid_node):
		print("ERROR: cryptid_node is no longer valid in animate_movement_along_path")
		return
	
	# First, make the original hex walkable again
	walkable_hexes.append(start_pos)
	var point = a_star_hex_grid.get_closest_point(start_pos, true)
	
	# Use our debug-aware function instead of direct call
	a_star_hex_grid.set_point_disabled(point, false)
	
	# Remove walkability from the destination hex immediately
	# so no other cryptid can move there during animation
	walkable_hexes.erase(end_pos)
	point = a_star_hex_grid.get_closest_point(end_pos, true)
	
	# Use our debug-aware function instead of direct call
	a_star_hex_grid.set_point_disabled(point, true)
	
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
	
	# Save reference to the cryptid node to access in the tween completion
	var safe_cryptid_reference = cryptid_node
	
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
	
	# Check if attacker and target are still valid
	if !is_instance_valid(attacker) or !is_instance_valid(target):
		print("ERROR: attacker or target is no longer valid in animate_attack")
		# Reset movement flag
		movement_in_progress = false
		return null
	
	# If movement is already in progress, don't start another one
	if movement_in_progress:
		print("Movement already in progress, ignoring attack animation")
		return null
		
	print("Animation will proceed - movement_in_progress is false")
	
	# Store original position
	var original_position = attacker.position
	print("Original position:", original_position)
	
	# Calculate direction vector from attacker to target
	var direction = (target.position - original_position).normalized()
	print("Direction vector:", direction)
	
	# Calculate how far to bump
	var bump_distance = min((target.position - original_position).length() * 0.4, 60.0)
	var bump_position = original_position + direction * bump_distance
	print("Bump distance:", bump_distance, "New position:", bump_position)
	
	# Set flag to indicate movement is in progress
	movement_in_progress = true
	print("Set movement_in_progress to true")
	
	# Store the attacker, target, and damage for the callback
	var attack_data = [target, damage]
	
	# Create a tween for the animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	print("Created new tween:", tween)
	
	# Connect finished signal with attack data
	tween.finished.connect(Callable(self, "_on_attack_tween_finished").bind(attack_data))
	
	# Disable input during animation
	set_process_input(false)
	print("Disabled input processing")
	
	# Start with a quick forward movement
	print("Starting animation to bump position:", bump_position)
	tween.tween_property(attacker, "position", bump_position, 0.2)
	
	# Then return to the original position with a slight bounce
	print("Adding return animation to original position:", original_position)
	tween.tween_property(attacker, "position", original_position, 0.3)
	
	# Create attack visual effect
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

func _on_attack_tween_finished(params):
	print("Attack animation finished")
	
	# Reset movement flag
	movement_in_progress = false
	
	# Re-enable input
	set_process_input(true)
	
	# Get the target and damage from params
	var target_cryptid = params[0]
	var damage_amount = params[1]
	
	# Check if target_cryptid is still valid
	if !is_instance_valid(target_cryptid):
		print("WARNING: target_cryptid is no longer valid in _on_attack_tween_finished")
		# Still clean up
		attack_action_bool = false
		delete_all_lines()
		delete_all_indicators()
		return
	
	print("Applying", damage_amount, "damage to", target_cryptid)
	apply_damage(target_cryptid, damage_amount)
	
	# IMPORTANT: Reset attack_action_bool here
	attack_action_bool = false
	
	# Clean up visuals
	delete_all_lines()
	delete_all_indicators()

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

# Also add this enhanced disable_other_card_halves function
func disable_other_card_halves(active_card_half):
	# Get all cards in the hand
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if not hand_node:
		print("ERROR: Hand node not found")
		return
		
	var cards = hand_node.get_children()
	
	print("Disabling other card halves, active half: ", active_card_half)
	
	for card in cards:
		if card.get_script() and card.get_script().resource_path.ends_with("card_dialog.gd"):
			# Skip the active card
			if card == card_dialog:
				print("Skipping active card")
				continue
				
			# Disable the appropriate half based on active_card_half
			if active_card_half == "top":
				print("Disabling top half of other card")
				card.top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				card.top_half_container.disabled = true
			elif active_card_half == "bottom":
				print("Disabling bottom half of other card")
				card.bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
				card.bottom_half_container.disabled = true

func reset_for_new_cryptid():
	# Reset all action states for a new cryptid's turn
	reset_action_modes()
	
	# Make sure the hand is updated correctly
	hand.update_card_availability()


# Update finish_movement to not auto-advance turns
func finish_movement():
	# Only do something if there's movement in progress
	if move_action_bool and move_leftover > 0:
		print("Finishing movement early with " + str(move_leftover) + " movement left")
		
		# Now we should mark the card as used and discard it
		if active_movement_card_part == "top":
			selected_cryptid.cryptid.top_card_played = true
			
			# Discard the card now that we're done with it
			if is_instance_valid(active_movement_card):
				disable_entire_card(active_movement_card)
				discard_card(active_movement_card, selected_cryptid.cryptid)
				
		elif active_movement_card_part == "bottom":
			selected_cryptid.cryptid.bottom_card_played = true
			
			# Discard the card now that we're done with it
			if is_instance_valid(active_movement_card):
				disable_entire_card(active_movement_card)
				discard_card(active_movement_card, selected_cryptid.cryptid)
		
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
		
		# Update debug display after finishing movement
		update_all_debug_indicators()
		
		# Update UI
		var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
		if hand_node and hand_node.has_method("update_card_availability"):
			hand_node.update_card_availability()
		
		# Check if turn is complete
		if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
			selected_cryptid.cryptid.completed_turn = true
			
			# Show only the End Turn button instead of auto-advancing
			var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
			if action_menu and action_menu.has_method("show_end_turn_only"):
				action_menu.show_end_turn_only()
				
			var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
			if game_instructions:
				game_instructions.text = "Turn complete. Press End Turn to continue."
	else:
		print("No movement in progress to finish")

# Helper function to check if a color is yellowish (highlighted)
func is_yellow_highlighted(color):
	# Check if the color is predominantly yellow (high red and green, low blue)
	return color.r > 0.7 and color.g > 0.7 and color.b < 0.5

# Helper function to print the node tree - simple implementation
func print_node_tree(node, indent = 0):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	# Print properties for containers that might be relevant
	if node is Control:
		print(indent_str + "  modulate: " + str(node.modulate))
		# Check for disabled property without using has_variable
		if node.get("disabled") != null:
			print(indent_str + "  disabled: " + str(node.disabled))
	
	# Recursively print children
	for child in node.get_children():
		print_node_tree(child, indent + 1)

# A simplified version that doesn't rely on specific container names
func disable_other_cards_simplified(active_card_half):
	print("\n---------- DISABLE OTHER CARDS ----------")
	print("Active card half: " + active_card_half)
	
	# Get all cards in the hand
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if not hand_node:
		print("ERROR: Hand node not found!")
		hand_node = hand  # Try the direct reference
		if not hand_node:
			print("ERROR: Hand reference also not valid!")
			return
	
	print("Found hand node: " + str(hand_node))
	var cards = hand_node.get_children()
	print("Found " + str(cards.size()) + " children in hand")
	
	# Process each card
	for card in cards:
		if not is_instance_valid(card):
			continue
			
		# Skip the active card
		if card == card_dialog:
			print("Skipping active card")
			continue
		
		print("Processing card: " + str(card))
		
		# Disable the appropriate halves based on position
		var top_containers = []
		var bottom_containers = []
		
		for child in card.get_children():
			if child is Control:
				if "top" in child.name.to_lower() or child.position.y < card.size.y / 2:
					top_containers.append(child)
				else:
					bottom_containers.append(child)
		
		# Disable the appropriate containers
		if active_card_half == "top" and top_containers.size() > 0:
			for container in top_containers:
				print("Disabling top container: " + container.name)
				container.modulate = Color(0.5, 0.5, 0.5, 1)
				if container.get("disabled") != null:
					container.disabled = true
				
		elif active_card_half == "bottom" and bottom_containers.size() > 0:
			for container in bottom_containers:
				print("Disabling bottom container: " + container.name)
				container.modulate = Color(0.5, 0.5, 0.5, 1)
				if container.get("disabled") != null:
					container.disabled = true
	
	print("---------- END DISABLE OTHER CARDS ----------\n")

# Function to disable other cards based on the exact node structure
func disable_other_cards_exact(active_card_half):
	print("\n---------- DISABLE OTHER CARDS (EXACT) ----------")
	print("Active card half:", active_card_half)
	
	# Get all cards in the hand
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if not hand_node:
		print("ERROR: Hand node not found!")
		hand_node = hand  # Try the direct reference
		if not hand_node:
			print("ERROR: Hand reference also not valid!")
			return
	
	print("Found hand node:", hand_node)
	var cards = hand_node.get_children()
	print("Found", cards.size(), "children in hand")
	
	# First handle the active card's unused half
	if is_instance_valid(card_dialog):
		print("Handling active card:", card_dialog)
		
		var vbox = card_dialog.get_node_or_null("VBoxContainer")
		if vbox:
			var top_container = vbox.get_node_or_null("TopHalfContainer")
			var bottom_container = vbox.get_node_or_null("BottomHalfContainer")
			
			if active_card_half == "top" and bottom_container:
				print("Disabling bottom container of active card")
				bottom_container.modulate = Color(0.5, 0.5, 0.5, 1)
				if bottom_container.get("disabled") != null:
					bottom_container.disabled = true
			elif active_card_half == "bottom" and top_container:
				print("Disabling top container of active card")
				top_container.modulate = Color(0.5, 0.5, 0.5, 1)
				if top_container.get("disabled") != null:
					top_container.disabled = true
	
	# Then process the other cards
	for card in cards:
		if not is_instance_valid(card):
			continue
			
		# Skip the active card since we already handled it
		if card == card_dialog:
			print("Skipping active card for other processing")
			continue
		
		print("Processing card:", card)
		
		# Get the VBoxContainer
		var vbox = card.get_node_or_null("VBoxContainer")
		if not vbox:
			print("WARNING: VBoxContainer not found in card, skipping")
			continue
		
		# Get the top and bottom containers
		var top_container = vbox.get_node_or_null("TopHalfContainer")
		var bottom_container = vbox.get_node_or_null("BottomHalfContainer")
		
		# Check if we found them
		if not top_container or not bottom_container:
			print("WARNING: Half containers not found in card, skipping")
			continue
		
		# Disable the appropriate half
		if active_card_half == "top" and top_container:
			print("Disabling top container of other card:", top_container.name)
			top_container.modulate = Color(0.5, 0.5, 0.5, 1)
			if top_container.get("disabled") != null:
				top_container.disabled = true
		elif active_card_half == "bottom" and bottom_container:
			print("Disabling bottom container of other card:", bottom_container.name)
			bottom_container.modulate = Color(0.5, 0.5, 0.5, 1)
			if bottom_container.get("disabled") != null:
				bottom_container.disabled = true
	
	print("---------- END DISABLE OTHER CARDS (EXACT) ----------\n")

# Function to disable the entire card visually while preserving action economy
func disable_entire_card(card_dialog):
	if not is_instance_valid(card_dialog):
		print("ERROR: Invalid card dialog")
		return
	
	print("Disabling entire card visually")
	
	# Get the top and bottom containers
	var vbox = card_dialog.get_node_or_null("VBoxContainer")
	if not vbox:
		print("ERROR: VBoxContainer not found")
		return
	
	var top_half_container = vbox.get_node_or_null("TopHalfContainer")
	var bottom_half_container = vbox.get_node_or_null("BottomHalfContainer")
	
	# Disable both halves visually
	if top_half_container:
		top_half_container.disabled = true
		top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
		print("Visually disabled top half of card")
	
	if bottom_half_container:
		bottom_half_container.disabled = true
		bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
		print("Visually disabled bottom half of card")
	
	# Mark card as fully disabled with metadata
	if not card_dialog.has_meta("fully_disabled"):
		card_dialog.set_meta("fully_disabled", true)

func discard_card(card_dialog, cryptid):
	if not is_instance_valid(card_dialog) or not card_dialog.card_resource:
		print("ERROR: Invalid card dialog or card resource")
		return
	
	# Print current state before any changes
	print("BEFORE DISCARD - Deck size: " + str(cryptid.deck.size()) + ", Discard size: " + str(cryptid.discard.size()))
	
	# Get the original card resource
	var original_card = null
	if card_dialog.card_resource.original_card != null:
		original_card = card_dialog.card_resource.original_card
		print("Using original card reference for discard: " + str(original_card))
	else:
		original_card = card_dialog.card_resource
		print("Using direct card resource for discard: " + str(original_card))
	
	# Mark the card as discarded without removing from hand
	original_card.current_state = Card.CardState.IN_DISCARD
	print("Marked card state as IN_DISCARD: " + str(original_card.current_state))
	
	# Check if card is already in discard pile to avoid duplicates
	var already_in_discard = false
	for card in cryptid.discard:
		if card == original_card:
			already_in_discard = true
			print("Card already in discard pile")
			break
	
	# Only add if not already in discard
	if not already_in_discard:
		cryptid.discard.push_back(original_card)
		print("Added card to discard pile")
	
	# Do NOT remove the card from the deck array - it stays in both places
	# but with the state marked as IN_DISCARD
	
	# Print current state after changes
	print("AFTER DISCARD - Deck size: " + str(cryptid.deck.size()) + ", Discard size: " + str(cryptid.discard.size()))
	
	# List all cards in discard pile for debugging
	print("Cards in discard pile:")
	for i in range(cryptid.discard.size()):
		print("  Discard card " + str(i) + ": " + str(cryptid.discard[i]))
	
	# Force refresh the discard UI to reflect changes
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.has_method("switch_cryptid_discard_cards"):
		print("Refreshing discard display")
		hand_node.switch_cryptid_discard_cards(cryptid)

# Also add this function to force update the discard pile at the end of a turn
func force_update_discard_display():
	print("Forcing discard pile update")
	
	# Get the selected cryptid
	var cryptid = selected_cryptid.cryptid
	if not cryptid:
		print("ERROR: No selected cryptid")
		return
	
	# Force refresh the discard display
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand") 
	if hand_node and hand_node.has_method("switch_cryptid_discard_cards"):
		print("Forcing discard display refresh")
		hand_node.switch_cryptid_discard_cards(cryptid)
		
		# Also try to refresh the UI more generally
		if hand_node.has_method("update_card_availability"):
			hand_node.update_card_availability()

func reset_card_action_values(cryptid):
	print("Resetting card action values for " + cryptid.name)
	
	# Go through all cards in the cryptid's deck and discard
	var all_cards = []
	all_cards.append_array(cryptid.deck)
	all_cards.append_array(cryptid.discard)
	
	for card in all_cards:
		# Debug info - print current values before reset
		print("Card before reset:")
		if card.top_move:
			for action in card.top_move.actions:
				if action.action_types == [0]:  # Move action
					print("  Top move amount: " + str(action.amount))
		if card.bottom_move:
			for action in card.bottom_move.actions:
				if action.action_types == [0]:  # Move action
					print("  Bottom move amount: " + str(action.amount))
		
		# Use EXACTLY ONE method to reset values - prioritize metadata
		var reset_applied = false
		
		# First check if we have stored metadata
		if card.has_meta("original_move_amount"):
			var original_amount = card.get_meta("original_move_amount")
			print("Using stored original amount: " + str(original_amount))
			
			# Apply to both top and bottom if they have move actions
			if card.top_move:
				for action in card.top_move.actions:
					if action.action_types == [0]:  # Move action
						action.amount = original_amount
						print("Reset top move to " + str(original_amount))
			
			if card.bottom_move:
				for action in card.bottom_move.actions:
					if action.action_types == [0]:  # Move action
						action.amount = original_amount
						print("Reset bottom move to " + str(original_amount))
			
			reset_applied = true
		elif card.has_meta("original_top_move_amount") or card.has_meta("original_bottom_move_amount"):
			# Use specific top/bottom metadata if available
			if card.has_meta("original_top_move_amount") and card.top_move:
				var original_top_amount = card.get_meta("original_top_move_amount")
				for action in card.top_move.actions:
					if action.action_types == [0]:  # Move action
						action.amount = original_top_amount
						print("Reset top move to " + str(original_top_amount))
			
			if card.has_meta("original_bottom_move_amount") and card.bottom_move:
				var original_bottom_amount = card.get_meta("original_bottom_move_amount")
				for action in card.bottom_move.actions:
					if action.action_types == [0]:  # Move action
						action.amount = original_bottom_amount
						print("Reset bottom move to " + str(original_bottom_amount))
			
			reset_applied = true
		
		# Only use base values if metadata wasn't found
		if not reset_applied:
			# Try to use base values
			if card.get("base_move_bottom") != null and card.bottom_move:
				for action in card.bottom_move.actions:
					if action.action_types == [0]:
						action.amount = card.base_move_bottom.amount
						print("Reset bottom move to hardcoded base value: " + str(card.base_move_bottom.amount))
			
			if card.get("base_attack_top") != null and card.top_move:
				for action in card.top_move.actions:
					if action.action_types == [0]:
						action.amount = card.base_attack_top.amount
						print("Reset top move to hardcoded base value: " + str(card.base_attack_top.amount))
			
			# If no other method worked, use hardcoded defaults
			if not card.get("base_move_bottom") and not card.get("base_attack_top"):
				if card.top_move:
					for action in card.top_move.actions:
						if action.action_types == [0]:
							action.amount = 3  # Default move value
							print("Reset top move to default value: 3")
				
				if card.bottom_move:
					for action in card.bottom_move.actions:
						if action.action_types == [0]:
							action.amount = 3  # Default move value
							print("Reset bottom move to default value: 3")
		
		# Debug info - print values after reset
		print("Card after reset:")
		if card.top_move:
			for action in card.top_move.actions:
				if action.action_types == [0]:  # Move action
					print("  Top move amount: " + str(action.amount))
		if card.bottom_move:
			for action in card.bottom_move.actions:
				if action.action_types == [0]:  # Move action
					print("  Bottom move amount: " + str(action.amount))

# Function to initialize the debug display
func setup_debug_display():
	if not debug_enabled:
		return
		
	print("Setting up A* hex grid debug display")
	
	# Clear any existing debug indicators
	for child in debug_container.get_children():
		debug_container.remove_child(child)
		child.queue_free()
	
	debug_indicators.clear()
	
	# Iterate through all points in the A* grid and create indicators
	for point_id in a_star_hex_grid.get_point_ids():
		var point_pos = a_star_hex_grid.get_point_position(point_id)
		var map_pos = map_to_local(point_pos)
		
		# Create indicator for this point
		var indicator = create_debug_indicator(point_id, map_pos)
		debug_container.add_child(indicator)
		debug_indicators[point_id] = indicator
		
		# Set initial color based on disabled state
		update_debug_indicator(point_id)

# Create a visual indicator for a grid point
func create_debug_indicator(point_id, position):
	var indicator = Node2D.new()
	indicator.position = position
	
	# Add a ColorRect as a visible marker
	var rect = ColorRect.new()
	rect.size = Vector2(20, 20)  # Size of the indicator
	rect.position = Vector2(-10, -10)  # Center the rect on the point
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept mouse events
	indicator.add_child(rect)
	
	# Add a Label for the point ID
	var label = Label.new()
	label.text = str(point_id)
	label.position = Vector2(-15, -25)  # Position above the rect
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 12)
	# Add a ColorRect background for better visibility
	var bg = ColorRect.new()
	bg.size = Vector2(30, 20)
	bg.position = Vector2(-15, -25)
	bg.color = Color(1, 1, 1, 0.7)  # Semi-transparent white
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_child(bg)
	indicator.add_child(label)
	
	return indicator

# Update a debug indicator's color based on its disabled state
func update_debug_indicator(point_id):
	if not debug_enabled or not debug_indicators.has(point_id):
		return
		
	var indicator = debug_indicators[point_id]
	var is_disabled = a_star_hex_grid.is_point_disabled(point_id)
	
	# Get the ColorRect
	var rect = indicator.get_child(0)
	
	# Set color based on disabled state
	if is_disabled:
		rect.color = Color(1, 0, 0, 0.5)  # Semi-transparent red for disabled
	else:
		rect.color = Color(0, 1, 0, 0.5)  # Semi-transparent green for enabled

# Improved debug-aware wrapper for set_point_disabled
func set_point_disabled(point_id, disabled):
	# Call the original A* function
	a_star_hex_grid.set_point_disabled(point_id, disabled)
	
	# Update the debug display
	update_debug_indicator(point_id)
	
	# Add debug output
	print("Set point " + str(point_id) + " disabled=" + str(disabled) + 
		  " at position " + str(a_star_hex_grid.get_point_position(point_id)))

# Add this function to force update all debug indicators
func update_all_debug_indicators():
	if not debug_enabled:
		return
	
	# Clear existing indicators
	for child in debug_container.get_children():
		debug_container.remove_child(child)
		child.queue_free()
	
	debug_indicators.clear()
	
	# Create indicators for all points
	for point_id in a_star_hex_grid.get_point_ids():
		var point_pos = a_star_hex_grid.get_point_position(point_id)
		var map_pos = map_to_local(point_pos)
		
		# Create indicator for this point
		var indicator = create_debug_indicator(point_id, map_pos)
		debug_container.add_child(indicator)
		debug_indicators[point_id] = indicator
		
		# Set color based on disabled state
		update_debug_indicator(point_id)
		
# Function to clean up target position if a move fails
func cleanup_failed_move_target(target_pos):
	print("Cleaning up failed move target at:", target_pos)
	
	# Get the point ID for the target position
	var point = a_star_hex_grid.get_closest_point(target_pos, true)
	
	# Check if this point is disabled
	if a_star_hex_grid.is_point_disabled(point):
		print("Re-enabling point that was incorrectly disabled by failed move")
		
		# Re-enable the point
		set_point_disabled(point, false)
		
		# Add the position back to walkable hexes if it's not already there
		if not target_pos in walkable_hexes:
			walkable_hexes.append(target_pos)
		
		# Update debug display
		update_all_debug_indicators()
	else:
		print("Target point was not disabled, no cleanup needed")

# Function to verify and fix A* grid state
func verify_grid_state():
	print("Verifying A* grid state...")
	var fixed_count = 0
	
	# Verify each hex corresponds to the correct state
	for i in range(walkable_hexes.size()):
		var hex_pos = walkable_hexes[i]
		var point = a_star_hex_grid.get_closest_point(hex_pos, true)
		
		# Check if the point is disabled
		if a_star_hex_grid.is_point_disabled(point):
			# Check if there's a cryptid occupying this position
			var is_occupied = false
			for cryptid in all_cryptids_in_play:
				if local_to_map(cryptid.position) == hex_pos:
					is_occupied = true
					break
			
			# If not occupied, this should be enabled
			if not is_occupied:
				print("Found incorrectly disabled point at", hex_pos, "- fixing")
				set_point_disabled(point, false)
				fixed_count += 1
	
	# Report results
	if fixed_count > 0:
		print("Fixed", fixed_count, "incorrectly disabled grid points")
	else:
		print("Grid state verified - no issues found")
	
	# Update debug display
	update_all_debug_indicators()

# Ensure a cryptid's position is properly disabled
func ensure_cryptid_position_disabled(cryptid_node):
	if not cryptid_node:
		return
		
	# Get the current map position
	var map_pos = local_to_map(selected_cryptid.position)
	
	# Get the point ID for this position
	var point = a_star_hex_grid.get_closest_point(map_pos, true)
	
	# Check if it's already disabled
	if not a_star_hex_grid.is_point_disabled(point):
		# Disable the point
		set_point_disabled(point, true)
		
		# Also remove from walkable hexes if present
		if map_pos in walkable_hexes:
			walkable_hexes.erase(map_pos)
