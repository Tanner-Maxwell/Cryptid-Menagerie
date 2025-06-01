extends TileMapLayer

const MAIN_ATLAS_ID = 0
const HexGridManager = preload("res://Cryptid-Menagerie/hex_grid_manager.gd")
const PickupManager = preload("res://Cryptid-Menagerie/scripts/pickup_manager.gd")
const Pickup = preload("res://Cryptid-Menagerie/scripts/pickup.gd")

var grid_manager = null
var pickup_manager = null
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

@onready var visual_effects = VisualEffectsManager.new()

@onready var player_team = %PlayerTeam
@onready var enemy_team = %EnemyTeam
@onready var player_starting_positions = [Vector2i(1, -1), Vector2i(-2, 1), Vector2i(0, 1)]
@onready var enemy_starting_positions = [Vector2i(-4, -3), Vector2i(-2, -3), Vector2i(0, -3)]

var active_movement_card = null
var movement_in_progress = false
var current_tween = null

@onready var player_cryptids_in_play = []
@onready var enemy_cryptids_in_play = []

@onready var all_cryptids_in_play = []

@onready var blank_cryptid = preload("res://Cryptid-Menagerie/data/cryptids/blank_cryptid.tscn")
@onready var current_card

var enemies_defeated_count = 0
var battle_reward_screen = null

var defeated_cryptids = []
var original_move_amount = 0
var active_movement_card_part = ""
var move_action_bool = false
var attack_action_bool = false
var move_leftover = 0
var temporary_move_bonus = 0  # Temporary movement bonus from pickups
var attack_range = 2
var path
var vector_path = []
var point_path = []
var damage

var possible_move_hexes = []  # Stores hexes that can be moved to
var highlighted_path_hexes = [] # Stores the current movement path
var original_tile_states = {}  # Stores original tile states for restoration
var move_range_tile_id = Vector2i(2, 0)  # ID for possible movement tiles - adjust based on your tileset
var path_tile_id = Vector2i(2, 0)  # ID for path tiles - adjust based on your tileset
var is_showing_movement_range = false

var push_action_bool = false
var pull_action_bool = false
var push_range = 2
var pull_range = 6
var push_amount = 1
var pull_amount = 2
var push_pull_preview_hexes = []  # Add this with other variables at the top
var preview_tile_id = Vector2i(2, 0)  # Update this from (3, 0) to (2, 0)
var heal_preview_hexes = []
var stun_preview_hexes = []
var poison_preview_hexes = []
var immobilize_preview_hexes = []
var heal_preview_tile_id = Vector2i(3, 0)  # Green tile for heal preview
var stun_preview_tile_id = Vector2i(4, 0)  # Red tile for stun preview  
var poison_preview_tile_id = Vector2i(5, 0)  # Purple tile for poison preview
var immobilize_preview_tile_id = Vector2i(6, 0)  # Blue tile for immobilize preview
var vulnerable_preview_hexes = []
var vulnerable_preview_tile_id = Vector2i(7, 0)  # Yellow tile for vulnerable preview
var burn_preview_hexes = []
var burn_preview_tile_id = Vector2i(8, 0)  # Orange tile for burn preview
var shield_preview_hexes = []
var shield_preview_tile_id = Vector2i(9, 0)  # Blue tile for shield preview

var heal_action_bool = false
var heal_range = 2
var heal_amount = 0

var stun_action_bool = false
var stun_range = 2
var stun_amount = 1  # Usually 1 since stun doesn't stack
var active_stun_effects: Dictionary = {}  # Track stun effects by cryptid

var poison_action_bool = false
var immobilize_action_bool = false
var immobilize_range = 2
var immobilize_amount = 1  # Number of immobilize stacks to apply
var vulnerable_action_bool = false
var vulnerable_range = 2
var vulnerable_amount = 1  # Number of vulnerable stacks to apply
var poison_range = 2
var poison_amount = 1  # Number of poison stacks to apply

var burn_action_bool = false
var burn_range = 2
var burn_amount = 1  # Number of burn stacks to apply

var shield_action_bool = false
var shield_range = 2
var shield_amount = 1  # Number of shield stacks to apply

var pickup_spawn_action_bool = false
var pickup_spawn_range = 2
var pickup_spawn_amount = 1  # Number of pickups to spawn
var pickup_spawn_type = -1  # ActionType enum value for which pickup to spawn

var active_action = {
	"type": "",  # "move", "attack", "push", "pull", "heal", "stun", "poison", "immobilize", "vulnerable", "burn", "shield"
	"range": 0,
	"amount": 0,
	"card": null,
	"card_part": "",
	"in_progress": false
}

const ACTION_CONFIGS = {
	"move": {
		"range_key": "move_action_amount",
		"amount_key": "move_action_amount",
		"target_type": "position",
		"show_preview": false,
		"friendly_only": false
	},
	"attack": {
		"range_key": "move_action_amount",
		"amount_key": "attack_damage_amount",
		"target_type": "enemy",
		"show_preview": false,
		"friendly_only": false
	},
	"push": {
		"range_key": "push_range",
		"amount_key": "push_amount",
		"target_type": "any_cryptid",
		"show_preview": true,
		"friendly_only": false
	},
	"pull": {
		"range_key": "pull_range",
		"amount_key": "pull_amount",
		"target_type": "any_cryptid", 
		"show_preview": true,
		"friendly_only": false
	},
	"heal": {
		"range_key": "heal_range",
		"amount_key": "heal_amount",
		"target_type": "friendly",
		"show_preview": true,
		"friendly_only": true
	},
	"stun": {
		"range_key": "stun_range",
		"amount_key": "stun_amount",
		"target_type": "enemy",
		"show_preview": true,
		"friendly_only": false
	},
	"poison": {
		"range_key": "poison_range",
		"amount_key": "poison_amount",
		"target_type": "enemy",
		"show_preview": true,
		"friendly_only": false
	},
	"immobilize": {
		"range_key": "immobilize_range",
		"amount_key": "immobilize_amount",
		"target_type": "enemy",
		"show_preview": true,
		"friendly_only": false
	},
	"vulnerable": {
		"range_key": "vulnerable_range",
		"amount_key": "vulnerable_amount",
		"target_type": "enemy",
		"show_preview": true,
		"friendly_only": false
	},
	"burn": {
		"range_key": "burn_range",
		"amount_key": "burn_amount",
		"target_type": "enemy",
		"show_preview": true,
		"friendly_only": false
	},
	"shield": {
		"range_key": "shield_range",
		"amount_key": "shield_amount",
		"target_type": "friendly",
		"show_preview": true,
		"friendly_only": true
	},
	"spawn_pickup": {
		"range_key": "pickup_spawn_range",
		"amount_key": "pickup_spawn_amount",
		"target_type": "any_position",
		"show_preview": true,
		"friendly_only": false
	}
}

func _ready():
	var cur_position = Vector2i(-6, -1)
	create_hex_map_a_star(cur_position)
	show_coordinates_label(cur_position)
	
	visual_effects.name = "VisualEffectsManager"
	add_child(visual_effects)
	visual_effects.initialize(self)
	
	visual_effects.attack_animation_finished.connect(_on_attack_animation_finished)
	visual_effects.movement_animation_finished.connect(_on_movement_animation_finished)
	
	player_cryptids_in_play = initialize_starting_positions(player_starting_positions, player_team)
	
	all_cryptids_in_play.append_array(player_cryptids_in_play)
	all_cryptids_in_play.append_array(enemy_cryptids_in_play)
	print(all_cryptids_in_play)
	sort_cryptids_by_speed(all_cryptids_in_play)
	for cryptid in all_cryptids_in_play:
		print(cryptid.cryptid, cryptid.cryptid.speed)
		turn_order._add_picked_cards_to_turn_order(cryptid.cryptid.name)
	
	sort_cryptids_by_speed(player_cryptids_in_play)
	for cryptid in player_cryptids_in_play:
		print(cryptid, cryptid.cryptid.speed, cryptid.cryptid.currently_selected)
	print(player_cryptids_in_play)
	
	debug_container.name = "DebugContainer"
	debug_container.z_index = 100  # Make sure debug visuals appear above everything else
	add_child(debug_container)
	
	call_deferred("setup_debug_display")
	
	# Initialize the grid manager
	grid_manager = HexGridManager.new()
	grid_manager.hex_map = self
	grid_manager.movement_grid = a_star_hex_grid
	grid_manager.attack_grid = a_star_hex_attack_grid
	
	# Initialize pickup manager after grid_manager is ready
	pickup_manager = PickupManager.new()
	pickup_manager.name = "PickupManager"
	add_child(pickup_manager)
	pickup_manager.initialize(self)

	# Initialize the walkable_hexes array with all grid positions
	walkable_hexes.clear()
	for point_id in a_star_hex_grid.get_point_ids():
		var position = a_star_hex_grid.get_point_position(point_id)
		walkable_hexes.append(position)

	# Mark occupied positions as non-walkable
	for cryptid in player_cryptids_in_play:
		var pos = local_to_map(cryptid.position)
		var point = a_star_hex_grid.get_closest_point(pos, true)
		a_star_hex_grid.set_point_disabled(point, true)

	for cryptid in enemy_cryptids_in_play:
		var pos = local_to_map(cryptid.position)
		var point = a_star_hex_grid.get_closest_point(pos, true)
		a_star_hex_grid.set_point_disabled(point, true)

	print("Grid system initialized with", walkable_hexes.size(), "walkable hexes")
		
func _process(delta):
	# Only handle mouse motion during player turns, not during AI turns
	if move_action_bool or heal_action_bool:
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
func initialize_starting_positions(starting_positions: Array, team, specific_cryptids = null):
	var cryptids_in_play = []
	
	# Determine how many cryptids to place
	var cryptid_count = 0
	if specific_cryptids != null:
		# Use specific cryptids array if provided
		cryptid_count = specific_cryptids.size()
	elif team._content != null:
		# Otherwise use team content, but limit to available positions
		cryptid_count = min(team._content.size(), starting_positions.size())
	else:
		# No cryptids available
		return cryptids_in_play
	
	print("Initializing", cryptid_count, "cryptids")
	
	# Place each cryptid
	for i in range(cryptid_count):
		var cryptid = blank_cryptid.instantiate()
		
		# Use provided cryptids if available, otherwise use team content
		if specific_cryptids != null and i < specific_cryptids.size():
			cryptid.cryptid = specific_cryptids[i]
		elif team._content != null and i < team._content.size():
			cryptid.cryptid = team._content[i]
		else:
			print("Warning: Not enough cryptids available")
			break
			
		team.add_child(cryptid)
		
		# Set position
		if i < starting_positions.size():
			cryptid.position = map_to_local(starting_positions[i])
		else:
			print("Warning: Not enough starting positions")
			# Use first position as fallback
			cryptid.position = map_to_local(starting_positions[0])
			
		cryptid.hand = %Hand
		cryptids_in_play.append(cryptid)
		
		# Register with grid manager
		var hex_pos = starting_positions[i] if i < starting_positions.size() else starting_positions[0]
		if grid_manager.occupy_hex(hex_pos, cryptid):
			print("Registered cryptid at position", hex_pos)
		else:
			print("WARNING: Position", hex_pos, "already occupied, couldn't register cryptid")
	
	return cryptids_in_play

# Add a helper function to update all debug indicators
func refresh_debug_display():
	if not debug_enabled:
		return
		
	
	for point_id in a_star_hex_grid.get_points():
		update_debug_indicator(point_id)
		
# Update handle_right_click function to also finish movement
func handle_right_click():
	print("Right-click detected - cancelling current action")
	
	# Clear movement highlights
	clear_movement_highlights()
	hand.clear_card_selections()
	
	# If there's movement in progress, finish it
	if move_action_bool and move_leftover > 0:
		finish_movement()
		return
	
	# Otherwise clear action states
	move_action_bool = false
	attack_action_bool = false
	push_action_bool = false
	pull_action_bool = false
	heal_action_bool = false
	stun_action_bool = false
	poison_action_bool = false
	immobilize_action_bool = false
	vulnerable_action_bool = false
	active_movement_card_part = ""
	active_movement_card = null
	
	# Clean up visual elements
	delete_all_lines()
	delete_all_indicators()
	remove_movement_indicator()
	clear_movement_highlights()
	
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
	if not (move_action_bool or push_action_bool or pull_action_bool or heal_action_bool or stun_action_bool or poison_action_bool or immobilize_action_bool or vulnerable_action_bool):
		return
	
	# Clear previous preview
	for hex in push_pull_preview_hexes:
		if hex in original_tile_states:
			# Restore to range indicator or original tile
			if hex in possible_move_hexes or is_showing_movement_range:
				set_cell(hex, 0, move_range_tile_id, 2)
			else:
				set_cell(hex, 0, original_tile_states[hex], 0)
	
	# Get the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	
	if selected_cryptid == null:
		return
	
	# Get current position and mouse position
	var current_pos = local_to_map(selected_cryptid.position)
	var target_pos = local_to_map(get_local_mouse_position())
	
	if move_action_bool:
		# Show the movement path
		show_movement_path(current_pos, target_pos)
		
		# Also calculate path for visualization
		calculate_path(current_pos, target_pos)
	elif push_action_bool or pull_action_bool:
		print("DEBUG: Push/pull hover - push_action_bool:", push_action_bool, "pull_action_bool:", pull_action_bool)
		print("DEBUG: Target position:", target_pos)
		# Check if there's a cryptid at the target position
		var target_cryptid = get_cryptid_at_position(target_pos)
		print("DEBUG: Target cryptid found:", target_cryptid != null)
		if target_cryptid:
			print("DEBUG: Target cryptid name:", target_cryptid.cryptid.name if target_cryptid.cryptid else "no cryptid resource")
			print("DEBUG: Selected cryptid name:", selected_cryptid.cryptid.name if selected_cryptid.cryptid else "no cryptid resource")
		if target_cryptid and target_cryptid != selected_cryptid:
			print("DEBUG: Valid target found, showing preview")
			# Show the push/pull preview path
			var selected_pos = local_to_map(selected_cryptid.position)
			var direction
			if push_action_bool:
				print("DEBUG: Push mode - direction from", selected_pos, "to", target_pos)
				# Push: direction from pusher to target, then continue in that direction
				direction = get_hex_direction(selected_pos, target_pos)
			else:  # pull_action_bool
				print("DEBUG: Pull mode - direction from", target_pos, "to", selected_pos)
				# Pull: direction from target toward puller
				direction = get_hex_direction(target_pos, selected_pos)
			print("DEBUG: Calculated direction:", direction)
			var distance = active_action.amount
			print("DEBUG: Distance:", distance)
			print("DEBUG: Calling show_push_pull_preview")
			show_push_pull_preview(target_pos, direction, distance)
		else:
			print("DEBUG: No valid target or same as selected cryptid")
	elif heal_action_bool:
		# Show healable targets preview
		var target_cryptid = get_cryptid_at_position_simple(target_pos)
		if target_cryptid and is_friendly_target(selected_cryptid, target_cryptid):
			# Show heal preview effect
			# Use status effect manager for heal preview
			var status_mgr = get_tree().get_first_node_in_group("status_effect_managers")
			if status_mgr:
				status_mgr.show_heal_preview(target_cryptid, target_pos, self)
	elif stun_action_bool:
		# Show stun targets preview
		var target_cryptid = get_cryptid_at_position_simple(target_pos)
		if target_cryptid and not is_friendly_target(selected_cryptid, target_cryptid):
			# Show stun preview effect
			# Use status effect manager for stun preview
			var status_mgr = get_tree().get_first_node_in_group("status_effect_managers")
			if status_mgr:
				status_mgr.show_stun_preview(target_cryptid, target_pos, self)
	elif immobilize_action_bool:
		# Show immobilize targets preview
		var target_cryptid = get_cryptid_at_position_simple(target_pos)
		if target_cryptid and not is_friendly_target(selected_cryptid, target_cryptid):
			# Show immobilize preview effect
			# Use status effect manager for immobilize preview
			var status_mgr = get_tree().get_first_node_in_group("status_effect_managers")
			if status_mgr:
				status_mgr.show_immobilize_preview(target_cryptid, target_pos, self)
	elif vulnerable_action_bool:
		# Show vulnerable targets preview
		var target_cryptid = get_cryptid_at_position_simple(target_pos)
		if target_cryptid and not is_friendly_target(selected_cryptid, target_cryptid):
			# Show vulnerable preview effect
			# Use status effect manager for vulnerable preview
			var status_mgr = get_tree().get_first_node_in_group("status_effect_managers")
			if status_mgr:
				status_mgr.show_vulnerable_preview(target_cryptid, target_pos, self)
			
func handle_left_click(event):
	var global_clicked = to_local(event.global_position)
	selected_cryptid = currently_selected_cryptid()
	var pos_clicked = local_to_map(get_local_mouse_position())
	print(pos_clicked, "pos_clicked")
	# Check if we're in discard mode
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.in_discard_mode:
		print("In discard mode, ignoring card activation clicks")
		return
	
	# Debugging
	print("Left click detected!")
	print("move_action_bool = ", move_action_bool)
	print("attack_action_bool = ", attack_action_bool)
	print("push_action_bool = ", push_action_bool)
	print("pull_action_bool = ", pull_action_bool)
	print("heal_action_bool = ", heal_action_bool)
	
	if selected_cryptid == null:
		print("WARNING: No selected cryptid found, using first cryptid")
		if player_cryptids_in_play.size() > 0:
			selected_cryptid = player_cryptids_in_play[0]
		else:
			print("ERROR: No cryptids available!")
			return
	
	# Add debugging for the clicked position
	print("Clicked position:", pos_clicked)
	
	# Debug what cryptid might be at this position
	var target_cryptid = get_cryptid_at_position(pos_clicked)
	print("Pre-check - Cryptid at clicked position:", target_cryptid)
	
	# Handle action based on what is active using the generic system
	if active_action.type != "":
		# Mark actions as in_progress so handle_card_action will process them
		active_action.in_progress = true
		print("Handling action:", active_action.type)
		print("Active action details - range:", active_action.range, "amount:", active_action.amount)
		print("Vulnerable action bool:", vulnerable_action_bool)
		get_viewport().set_input_as_handled()
		handle_card_action(pos_clicked)
	else:
		print("No action type active")
		print("Active action type:", active_action.type)
		print("Active action in_progress:", active_action.in_progress)

func handle_move_action(pos_clicked):
	# Print basic debug info
	print("\n=== HANDLE MOVE ACTION ===")
	print("Target position:", pos_clicked)
	
	# Get the currently selected cryptid
	selected_cryptid = currently_selected_cryptid()
	if selected_cryptid == null:
		print("ERROR: No selected cryptid found")
		return false
	
	# Get the current position directly from the cryptid
	var current_pos = local_to_map(selected_cryptid.position)
	print("Current position:", current_pos)
	
	# Calculate movement path and distance
	var path = a_star_hex_grid.get_id_path(
		a_star_hex_grid.get_closest_point(current_pos, true),
		a_star_hex_grid.get_closest_point(pos_clicked, true)
	)
	
	if path.size() == 0:
		print("ERROR: No valid path found")
		return false
	
	var movement_distance = path.size() - 1
	print("Movement distance:", movement_distance)
	print("Available movement:", move_leftover)
	
	# Debug: Also calculate direct hex distance for comparison
	var direct_distance = calculate_distance(current_pos, pos_clicked)
	print("Direct hex distance:", direct_distance)
	print("Path length difference:", movement_distance - direct_distance)
	
	# Check if we have enough movement
	if movement_distance > move_leftover:
		print("Not enough movement points")
		return false
	
	# Check if destination is already occupied
	if a_star_hex_grid.is_point_disabled(a_star_hex_grid.get_closest_point(pos_clicked, true)):
		print("Destination already occupied")
		return false
	
	# At this point, the move is valid - let's execute it
	
	# 1. First, enable the current position (we're leaving it)
	var current_point = a_star_hex_grid.get_closest_point(current_pos, true)
	a_star_hex_grid.set_point_disabled(current_point, false)
	print("Enabled current position:", current_pos)
	
	# 2. Disable the destination (we're going there)
	var dest_point = a_star_hex_grid.get_closest_point(pos_clicked, true)
	a_star_hex_grid.set_point_disabled(dest_point, true)
	print("Disabled destination position:", pos_clicked)
	
	# 3. Calculate remaining movement
	var remaining_movement = move_leftover - movement_distance
	print("Remaining movement:", remaining_movement)
	
	# 4. IMPORTANT: Clear all existing movement highlights BEFORE moving
	clear_movement_highlights()
	
	# 5. Perform the actual position update for the cryptid
	var target_world_pos = map_to_local(pos_clicked)
	
	# 6. Animate the movement
	animate_movement(selected_cryptid, path)
	
	# 7. Handle card usage
	handle_card_usage(remaining_movement)
	
	# 8. Update UI
	update_action_menu()
	
	# 9. If we still have movement left, calculate new movement range from the NEW position
	if remaining_movement > 0:
		# Do this after a slight delay to ensure movement animation completes
		await get_tree().create_timer(movement_distance * .2).timeout
		# Get updated position
		var new_pos = local_to_map(selected_cryptid.position)
		# Recalculate movement range from the new position
		highlight_possible_movement_hexes(selected_cryptid.position, remaining_movement)
	else:
		# NEW: Movement exhausted, notify card to move to next action
		move_action_bool = false
		if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
			print("Movement complete, moving to next action")
			card_dialog.next_action()
	
	print("=== END HANDLE MOVE ACTION ===\n")
	return true

func animate_movement(cryptid_node, path_ids):
	print("Animating movement...")
	
	# If movement is already in progress, don't start another one
	if movement_in_progress:
		print("Movement already in progress, ignoring new movement command")
		return
	
	# Set flag to indicate movement is in progress
	movement_in_progress = true
	
	# Convert path IDs to world positions
	var world_positions = []
	for point_id in path_ids:
		var hex_pos = a_star_hex_grid.get_point_position(point_id)
		world_positions.append(map_to_local(hex_pos))
	
	# Create a tween for smooth movement
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Add a callback when tween finishes
	tween.finished.connect(Callable(self, "_on_movement_tween_finished"))
	
	# Disable input during movement to prevent multiple actions
	set_process_input(false)
	
	# Set movement speed
	var movement_speed = 0.2  # seconds per hex
	
	# Animate through each point in the path
	for i in range(1, world_positions.size()):
		tween.tween_property(cryptid_node, "position", world_positions[i], movement_speed)
		# Check for pickups at this hex position
		var hex_pos = Vector2i(a_star_hex_grid.get_point_position(path_ids[i]))
		tween.tween_callback(func(): _check_pickup_at_position(hex_pos, cryptid_node))
	
	# Add a small bounce at the end for visual feedback
	tween.tween_property(cryptid_node, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(cryptid_node, "scale", Vector2(1.0, 1.0), 0.1)

func _on_movement_tween_finished():
	print("Movement animation completed")
	movement_in_progress = false
	
	# Re-enable input
	set_process_input(true)
	
	# Show remaining movement indicator if we have movement left
	if move_action_bool and move_leftover > 0 and is_instance_valid(selected_cryptid):
		update_movement_indicator(selected_cryptid, move_leftover)
	else:
		remove_movement_indicator()

# Handle card usage for movement
func handle_card_usage(remaining_movement):
	# Simplified card usage handler
	use_card_part(active_action.card, active_action.card_part)
	reset_action_state()
	enable_all_cards()
func update_action_menu():
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu and action_menu.has_method("update_menu_visibility"):
		action_menu.update_menu_visibility(selected_cryptid.cryptid)
		action_menu.show()

func check_if_turn_complete():
	if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
		# Process turn end effects for THIS cryptid before marking turn complete
		if selected_cryptid.has_node("StatusEffectManager"):
			var status_manager = selected_cryptid.get_node("StatusEffectManager")
			print("Processing turn end effects for", selected_cryptid.cryptid.name)
			status_manager.process_turn_end()
			
			# Update the status effect display
			if selected_cryptid.has_node("StatusEffectDisplay"):
				var display = selected_cryptid.get_node("StatusEffectDisplay")
				display.refresh_display()
		
		# Mark the cryptid's turn as completed
		selected_cryptid.cryptid.completed_turn = true
		
		# Instead of directly going to next cryptid, update the UI to prompt
		# for the End Turn button
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu and action_menu.has_method("show_end_turn_only"):
			action_menu.show_end_turn_only()
			
		var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
		if game_instructions:
			game_instructions.text = "Turn complete. Press End Turn to continue."

# ============= GENERIC ACTION SYSTEM - NEW OPTIMIZATION =============

func card_action_selected(card_type: String, current_card):
	print("Action type:", card_type)
	print("Current card:", current_card)
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.in_discard_mode:
		print("In discard mode, ignoring", card_type, "action selection")
		return
	reset_action_state()
	card_dialog = current_card
	selected_cryptid = currently_selected_cryptid()
	print("Selected cryptid:", selected_cryptid)
	print("Cryptid name:", selected_cryptid.cryptid.name if selected_cryptid else "None")
	delete_all_indicators()
	delete_all_lines()
	update_all_debug_indicators()
	var v_box_container = current_card.get_node_or_null("VBoxContainer")
	if not v_box_container:
		return
	var top_half_container = v_box_container.get_node_or_null("TopHalfContainer")
	var bottom_half_container = v_box_container.get_node_or_null("BottomHalfContainer")
	if not top_half_container or not bottom_half_container:
		return
	var active_half = null
	var active_action_data = null
	var top_highlighted = is_yellow_highlighted(top_half_container.modulate)
	var bottom_highlighted = is_yellow_highlighted(bottom_half_container.modulate)
	if top_highlighted:
		active_half = top_half_container
	elif bottom_highlighted:
		active_half = bottom_half_container
	if not active_half:
		return
	var card_resource = current_card.get("card_resource")
	if not card_resource:
		return
	print("Card resource found:", card_resource.resource_path if card_resource else "None")
	var config = ACTION_CONFIGS.get(card_type, {})
	active_action.type = card_type
	active_action.card = v_box_container
	active_action.card_part = "top" if active_half == top_half_container else "bottom"
	var found_action = false
	var move_data = null
	if active_half == top_half_container:
		move_data = card_resource.get("top_move")
	else:
		move_data = card_resource.get("bottom_move")
	if move_data and move_data.get("actions") != null:
		for action in move_data.actions:
			var action_type_id = -1
			match card_type:
				"attack": action_type_id = 1
				"move": action_type_id = 0
				"push": action_type_id = 2
				"pull": action_type_id = 3
				"heal": action_type_id = 4
				"stun": action_type_id = 5
				"poison": action_type_id = 7
				"vulnerable": action_type_id = 6  # APPLY_VULNERABLE
				"immobilize": action_type_id = 9  # IMMOBILIZE
				"burn": action_type_id = 10  # BURN
				"shield": action_type_id = 11  # SHIELD
				"spawn_pickup": 
					# Handle pickup spawning actions - check which spawn action type is in the card
					for spawn_type in range(13, 22):  # 13-21 are spawn pickup actions
						if spawn_type in action.action_types:
							action_type_id = spawn_type
							pickup_spawn_type = spawn_type
							print("Found spawn action type:", spawn_type, "in card actions")
							break
			if action_type_id in action.action_types:
				active_action.range = action.range
				active_action.amount = action.amount
				found_action = true
				break
	if not found_action:
		return
	var selected_cryptid_hex_pos = local_to_map(selected_cryptid.position)
	if card_type == "move":
		highlight_possible_movement_hexes(selected_cryptid.position, active_action.range)
	elif card_type == "push" or card_type == "pull":
		show_push_pull_range(selected_cryptid_hex_pos, active_action.range, card_type)
	else:
		show_targetable_area(selected_cryptid_hex_pos, active_action.range, card_type)
	print("Setting up action booleans for card type:", card_type)
	match card_type:
		"move":
			# Check if cryptid is immobilized
			var status_mgr = selected_cryptid.get_node_or_null("StatusEffectManager")
			if status_mgr and status_mgr.has_status_effect(StatusEffect.EffectType.IMMOBILIZE):
				print("Cannot move - cryptid is immobilized!")
				return  # Prevent movement
			
			move_action_bool = true
			move_leftover = active_action.amount
			original_move_amount = active_action.amount
		"attack":
			attack_action_bool = true
			attack_range = active_action.range
			damage = active_action.amount
		"push":
			push_action_bool = true
			push_range = active_action.range
			push_amount = active_action.amount
		"pull":
			pull_action_bool = true
			pull_range = active_action.range
			pull_amount = active_action.amount
		"heal":
			heal_action_bool = true
			heal_range = active_action.range
			heal_amount = active_action.amount
		"stun":
			stun_action_bool = true
			stun_range = active_action.range
			stun_amount = active_action.amount
		"poison":
			poison_action_bool = true
			poison_range = active_action.range
			poison_amount = active_action.amount
		"immobilize":
			immobilize_action_bool = true
			immobilize_range = active_action.range
			immobilize_amount = active_action.amount
		"vulnerable":
			print("Setting vulnerable action - range:", active_action.range, "amount:", active_action.amount)
			vulnerable_action_bool = true
			vulnerable_range = active_action.range
			vulnerable_amount = active_action.amount
		"burn":
			burn_action_bool = true
			burn_range = active_action.range
			burn_amount = active_action.amount
		"shield":
			shield_action_bool = true
			shield_range = active_action.range
			shield_amount = active_action.amount
		"spawn_pickup":
			print("Setting up spawn_pickup action - type:", pickup_spawn_type, "range:", active_action.range, "amount:", active_action.amount)
			pickup_spawn_action_bool = true
			pickup_spawn_range = active_action.range
			pickup_spawn_amount = active_action.amount
	active_movement_card = v_box_container
	active_movement_card_part = active_action.card_part
	active_action.in_progress = true  # Important: Set this so handle_card_action works
	if active_half == top_half_container:
		disable_other_cards_exact("top")
	else:
		disable_other_cards_exact("bottom")
	print("card_action_selected complete - active_action.type:", active_action.type, "vulnerable_action_bool:", vulnerable_action_bool, "in_progress:", active_action.in_progress)
func reset_action_state():
	active_action.type = ""
	active_action.range = 0
	active_action.amount = 0
	active_action.card = null
	active_action.card_part = ""
	active_action.in_progress = false
	# Also reset old booleans for compatibility
	move_action_bool = false
	attack_action_bool = false
	push_action_bool = false
	pull_action_bool = false
	heal_action_bool = false
	stun_action_bool = false
	poison_action_bool = false
	immobilize_action_bool = false
	vulnerable_action_bool = false
	burn_action_bool = false
	shield_action_bool = false
	pickup_spawn_action_bool = false
	pickup_spawn_type = -1
	temporary_move_bonus = 0  # Reset temporary movement bonus
	# Clear all tile highlights and indicators
	clear_movement_highlights()
	# Clear push/pull preview
	for hex in push_pull_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	push_pull_preview_hexes.clear()
	# Clear other status effect previews
	clear_heal_preview_hexes()
	clear_stun_preview_hexes()
	clear_poison_preview_hexes()
	clear_immobilize_preview_hexes()
	clear_vulnerable_preview_hexes()
	clear_burn_preview_hexes()
	clear_shield_preview_hexes()
	active_movement_card_part = ""
	active_movement_card = null

func handle_card_action(pos_clicked: Vector2i):
	if not active_action.in_progress or active_action.type == "":
		return
		
	var target_hex_pos = pos_clicked  # pos_clicked is already hex coordinates
	var selected_cryptid_hex_pos = local_to_map(selected_cryptid.position)
	
	# Execute action based on type
	print("Executing action type:", active_action.type)
	match active_action.type:
		"move":
			# Movement has its own pathfinding and range checking
			handle_move_action(pos_clicked)
		"attack", "heal", "stun", "poison", "push", "pull", "immobilize", "vulnerable", "burn", "shield", "spawn_pickup":
			# For targeted actions, check if target is in range
			var distance = calculate_distance(selected_cryptid_hex_pos, target_hex_pos)
			print("Range check - Distance:", distance, "Max range:", active_action.range)
			if distance > active_action.range:
				print("Target out of range")
				# Show feedback to player
				var game_instructions = get_node_or_null("/root/VitaChrome/UIRoot/GameInstructions")
				if game_instructions:
					game_instructions.text = "Target out of range! Select a closer target or right-click to cancel."
				return
			
			# Find target at position if needed
			var target_cryptid = null
			for cryptid in all_cryptids_in_play:
				if local_to_map(cryptid.position) == target_hex_pos:
					target_cryptid = cryptid
					break
			
			# Execute the specific action
			match active_action.type:
				"attack":
					execute_attack_action(target_cryptid, target_hex_pos)
				"heal":
					# Use status effect manager for heal action
					var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager") 
					if status_mgr:
						await status_mgr.execute_heal_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"stun":
					# Use status effect manager for stun action
					var status_mgr_stun = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_stun:
						await status_mgr_stun.execute_stun_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"poison":
					# Use status effect manager for poison action
					var status_mgr_poison = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_poison:
						await status_mgr_poison.execute_poison_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"immobilize":
					# Use status effect manager for immobilize action
					var status_mgr_immobilize = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_immobilize:
						await status_mgr_immobilize.execute_immobilize_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"vulnerable":
					print("Executing vulnerable action")
					print("Target cryptid:", target_cryptid)
					print("Target position:", target_hex_pos)
					
					# Check if there's a target
					if not target_cryptid:
						print("No cryptid at target position")
						return
					
					# Validate target is enemy
					if not is_enemy_target(selected_cryptid, target_cryptid):
						print("Invalid target - must target enemy")
						print("Selected cryptid is player:", selected_cryptid in player_cryptids_in_play)
						print("Target cryptid is player:", target_cryptid in player_cryptids_in_play)
						return
					
					# Use status effect manager for vulnerable action
					var status_mgr_vulnerable = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_vulnerable:
						await status_mgr_vulnerable.execute_vulnerable_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"push":
					execute_push_action(target_cryptid, target_hex_pos)
				"pull":
					execute_pull_action(target_cryptid, target_hex_pos)
				"burn":
					# Check if there's a target
					if not target_cryptid:
						print("No cryptid at target position")
						return
					
					# Validate target is enemy
					if not is_enemy_target(selected_cryptid, target_cryptid):
						print("Invalid target - must target enemy")
						return
					
					# Use status effect manager for burn action
					var status_mgr_burn = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_burn:
						await status_mgr_burn.execute_burn_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"shield":
					# Check if there's a target
					if not target_cryptid:
						print("No cryptid at target position")
						return
					
					# Validate target is friendly
					var is_friendly = (selected_cryptid in player_cryptids_in_play and target_cryptid in player_cryptids_in_play) or \
									  (selected_cryptid in enemy_cryptids_in_play and target_cryptid in enemy_cryptids_in_play)
					if not is_friendly:
						print("Invalid target - must target friendly cryptid")
						return
					
					# Use status effect manager for shield action
					var status_mgr_shield = target_cryptid.get_node_or_null("StatusEffectManager")
					if status_mgr_shield:
						await status_mgr_shield.execute_shield_action(selected_cryptid, target_cryptid, active_action.amount, visual_effects)
						# Complete action
						use_card_part(active_action.card, active_action.card_part)
						delete_all_indicators()
						reset_action_state()
						enable_all_cards()
						# Move to next action if available
						if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
							card_dialog.next_action()
				"spawn_pickup":
					# Execute pickup spawn action
					execute_spawn_pickup_action(target_hex_pos)

func execute_spawn_pickup_action(target_hex_pos: Vector2i):
	print("Execute spawn pickup action - spawn type:", pickup_spawn_type, "at position:", target_hex_pos)
	
	# Debug: print what action types mean
	print("ActionType mapping:")
	print("13 = SPAWN_FIRE_TRAP")
	print("14 = SPAWN_HEAL_ORB")
	print("15 = SPAWN_IMMOBILIZE_TRAP")
	print("16 = SPAWN_DAMAGE_TRAP")
	print("17 = SPAWN_MOVEMENT_BOOST")
	print("18 = SPAWN_SHIELD_ORB")
	print("19 = SPAWN_POISON_CLOUD")
	print("20 = SPAWN_WALL")
	print("21 = SPAWN_STUN_TRAP")
	print("Current pickup_spawn_type is:", pickup_spawn_type)
	
	# Convert ActionType enum to PickupType enum
	var pickup_type = -1
	match pickup_spawn_type:
		12:  # SPAWN_FIRE_TRAP -> FIRE_TRAP (0)
			pickup_type = Pickup.PickupType.FIRE_TRAP
		13:  # SPAWN_HEAL_ORB -> HEAL_ORB (1)
			pickup_type = Pickup.PickupType.HEAL_ORB
		14:  # SPAWN_IMMOBILIZE_TRAP -> IMMOBILIZE_TRAP (2)
			pickup_type = Pickup.PickupType.IMMOBILIZE_TRAP
		15:  # SPAWN_DAMAGE_TRAP -> DAMAGE_TRAP (3)
			pickup_type = Pickup.PickupType.DAMAGE_TRAP
		16:  # SPAWN_MOVEMENT_BOOST -> MOVEMENT_BOOST (4)
			pickup_type = Pickup.PickupType.MOVEMENT_BOOST
		17:  # SPAWN_SHIELD_ORB -> SHIELD_ORB (5)
			pickup_type = Pickup.PickupType.SHIELD_ORB
		18:  # SPAWN_POISON_CLOUD -> POISON_CLOUD (6)
			pickup_type = Pickup.PickupType.POISON_CLOUD
		19:  # SPAWN_WALL -> WALL (7)
			pickup_type = Pickup.PickupType.WALL
		20:  # SPAWN_STUN_TRAP -> STUN_TRAP (8)
			pickup_type = Pickup.PickupType.STUN_TRAP
		_:
			print("Unknown pickup spawn type:", pickup_spawn_type)
			return
	
	# Check if pickup_manager exists
	if not pickup_manager:
		print("ERROR: pickup_manager is null!")
		return
		
	print("Attempting to spawn pickup type:", pickup_type, "amount:", active_action.amount)
	
	# Spawn pickups around the target position
	var spawned = pickup_manager.spawn_pickup(pickup_type, target_hex_pos, active_action.amount)
	print("Spawned", spawned.size(), "pickups of type", pickup_type, "around", target_hex_pos)
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		card_dialog.next_action()

func execute_attack_action(target_cryptid, target_hex_pos: Vector2i):
	# Check if there's a wall at the position
	if pickup_manager and pickup_manager.has_pickup_at_position(target_hex_pos):
		var pickup = pickup_manager.get_pickup_at_position(target_hex_pos)
		if pickup and pickup.pickup_type == Pickup.PickupType.WALL:
			print("Attacking wall at position:", target_hex_pos)
			# Damage the wall
			pickup_manager.damage_pickup(target_hex_pos, active_action.amount)
			
			# Complete action
			use_card_part(active_action.card, active_action.card_part)
			delete_all_indicators()
			reset_action_state()
			enable_all_cards()
			
			# Move to next action if available
			if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
				card_dialog.next_action()
			return
	
	if not target_cryptid:
		print("No target at position")
		return
		
	if not is_enemy_target(selected_cryptid, target_cryptid):
		print("Invalid target - must target enemy")
		return
	
	# Perform attack animation
	await visual_effects.animate_attack(selected_cryptid, target_cryptid)
	
	# Deal damage using health bar system
	var health_bar = target_cryptid.get_node_or_null("HealthBar")
	if health_bar:
		var current_health = health_bar.value
		var new_health = max(current_health - active_action.amount, 0)
		
		# Update health bar
		health_bar.value = new_health
		
		# Update cryptid's health values
		target_cryptid.set_health_values(new_health, health_bar.max_value)
		target_cryptid.update_health_bar()
		
		# Store health metadata
		target_cryptid.cryptid.set_meta("current_health", new_health)
		
		damage_value_display(target_cryptid.position, active_action.amount)
		print("Dealt", active_action.amount, "damage to", target_cryptid.cryptid.name)
		print("Health now: " + str(new_health) + "/" + str(health_bar.max_value))
		
		# Check if target is defeated
		if new_health <= 0:
			handle_cryptid_defeat(target_cryptid)
	else:
		print("ERROR: Could not find health bar on target cryptid!")
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		print("Action complete, moving to next action")
		card_dialog.next_action()

func execute_heal_action(target_cryptid, target_hex_pos: Vector2i):
	if not target_cryptid:
		print("No target at position")
		return
		
	if not is_friendly_target(selected_cryptid, target_cryptid):
		print("Invalid target - must target friendly")
		return
	
	# Heal the target using health bar system
	var health_bar = target_cryptid.get_node_or_null("HealthBar")
	if health_bar:
		var current_health = health_bar.value
		var max_health = health_bar.max_value
		var new_health = min(current_health + active_action.amount, max_health)
		
		# Update health bar
		health_bar.value = new_health
		
		# Update cryptid's health values
		target_cryptid.set_health_values(new_health, max_health)
		target_cryptid.update_health_bar()
		
		# Store health metadata
		target_cryptid.cryptid.set_meta("current_health", new_health)
		
		var actual_heal = new_health - current_health
		
		# Show heal effect
		await visual_effects.animate_heal(selected_cryptid, target_cryptid)
		heal_value_display(target_cryptid.position, actual_heal)
		
		print("Healed", target_cryptid.cryptid.name, "for", actual_heal)
		print("Health now: " + str(new_health) + "/" + str(max_health))
	else:
		print("ERROR: Could not find health bar on target cryptid!")
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		print("Action complete, moving to next action")
		card_dialog.next_action()

func execute_stun_action(target_cryptid, target_hex_pos: Vector2i):
	if not target_cryptid:
		print("No target at position")
		return
		
	if not is_enemy_target(selected_cryptid, target_cryptid):
		print("Invalid target - must target enemy")
		return
	
	# Apply stun
	var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
	if status_mgr:
		status_mgr.add_status_effect(StatusEffect.EffectType.STUN, active_action.amount)
		print("Applied stun for", active_action.amount, "turns to", target_cryptid.cryptid.name)
	
	# Show effect
	await visual_effects.animate_stun(selected_cryptid, target_cryptid)
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		print("Action complete, moving to next action")
		card_dialog.next_action()


func execute_push_action(target_cryptid, target_hex_pos: Vector2i):
	if not target_cryptid:
		print("No target at position")
		return
	
	# Calculate push direction
	var selected_cryptid_hex_pos = local_to_map(selected_cryptid.position)
	var push_direction = get_hex_direction(selected_cryptid_hex_pos, target_hex_pos)
	var push_distance = active_action.amount
	
	print("=== PUSH ACTION DEBUG ===")
	print("Target position:", target_hex_pos)
	print("Selected position:", selected_cryptid_hex_pos)
	print("Push direction:", push_direction)
	print("Push distance:", push_distance)
	
	# Find valid push destination and build path for preview
	var final_position = target_hex_pos
	var push_path = []
	for i in range(1, push_distance + 1):
		var test_pos = target_hex_pos + push_direction * i
		print("Testing push position", i, ":", test_pos)
		print("  Is walkable:", is_hex_walkable(test_pos))
		print("  Is occupied:", is_hex_occupied(test_pos))
		if is_hex_walkable(test_pos) and not is_hex_occupied(test_pos):
			final_position = test_pos
			push_path.append(test_pos)
			print("  -> Valid push destination")
		else:
			print("  -> Invalid, stopping search")
			break
	
	print("Final push position:", final_position)
	
	
	if final_position != target_hex_pos:
		print("Executing push animation...")
		# Animate push
		await visual_effects.animate_push(selected_cryptid, target_cryptid, target_hex_pos, final_position)
		
		# Update position
		update_cryptid_position(target_cryptid, final_position)
		print("Pushed", target_cryptid.cryptid.name, "to", final_position)
	else:
		print("No valid push destination found - target stays at", target_hex_pos)
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		print("Action complete, moving to next action")
		card_dialog.next_action()

func execute_pull_action(target_cryptid, target_hex_pos: Vector2i):
	if not target_cryptid:
		print("No target at position")
		return
	
	# Get puller position and pull distance
	var selected_cryptid_hex_pos = local_to_map(selected_cryptid.position)
	var pull_distance = active_action.amount
	
	print("=== PULL ACTION DEBUG ===")
	print("Target position:", target_hex_pos)
	print("Selected position:", selected_cryptid_hex_pos)
	print("Pull distance:", pull_distance)
	
	# Temporarily enable both target and puller positions for pathfinding
	var target_point = a_star_hex_grid.get_closest_point(target_hex_pos, true)
	var puller_point = a_star_hex_grid.get_closest_point(selected_cryptid_hex_pos, true)
	
	var was_target_disabled = a_star_hex_grid.is_point_disabled(target_point)
	var was_puller_disabled = a_star_hex_grid.is_point_disabled(puller_point)
	
	print("Target point disabled:", was_target_disabled, "Puller point disabled:", was_puller_disabled)
	
	# Enable both positions temporarily
	if was_target_disabled:
		a_star_hex_grid.set_point_disabled(target_point, false)
	if was_puller_disabled:
		a_star_hex_grid.set_point_disabled(puller_point, false)
	
	# Find path from target to puller using A*
	var path = a_star_hex_grid.get_id_path(target_point, puller_point)
	print("A* path found with", path.size(), "points:", path)
	
	# Restore both positions' states
	if was_target_disabled:
		a_star_hex_grid.set_point_disabled(target_point, true)
	if was_puller_disabled:
		a_star_hex_grid.set_point_disabled(puller_point, true)
	
	print("Pull path from target to puller:", path.size(), "steps")
	var final_position = target_hex_pos
	
	if path.size() > 1:  # Path includes start position, so we need at least 2 points
		# Convert path to positions and move target along the path
		var steps_to_move = min(pull_distance, path.size() - 1)  # -1 because path includes start
		print("Will attempt to move", steps_to_move, "steps")
		
		var pull_path = []
		for i in range(1, steps_to_move + 1):  # Start from 1 to skip current position
			var path_point_id = path[i]
			var path_pos = a_star_hex_grid.get_point_position(path_point_id)
			var hex_pos = Vector2i(path_pos.x, path_pos.y)
			
			print("Testing pull step", i, "to position:", hex_pos)
			
			# Don't pull into puller's position
			if hex_pos == selected_cryptid_hex_pos:
				print("  -> Cannot pull into puller's position, stopping")
				break
			
			# Check if position is available
			if not is_hex_occupied(hex_pos):
				final_position = hex_pos
				pull_path.append(hex_pos)
				print("  -> Valid pull destination")
			else:
				print("  -> Position occupied, stopping pull")
				break
		
	else:
		print("No valid path found for pull")
	
	print("Final pull position:", final_position)
	
	if final_position != target_hex_pos:
		print("Executing pull animation...")
		# Animate pull
		await visual_effects.animate_pull(selected_cryptid, target_cryptid, target_hex_pos, final_position)
		
		# Update position
		update_cryptid_position(target_cryptid, final_position)
		print("Pulled", target_cryptid.cryptid.name, "to", final_position)
	else:
		print("No valid pull destination found - target stays at", target_hex_pos)
	
	# Complete action
	use_card_part(active_action.card, active_action.card_part)
	delete_all_indicators()
	reset_action_state()
	enable_all_cards()
	
	# Move to next action if available
	if is_instance_valid(card_dialog) and card_dialog.has_method("next_action"):
		print("Action complete, moving to next action")
		card_dialog.next_action()

func is_enemy_target(caster, target) -> bool:
	if caster in player_cryptids_in_play and target in enemy_cryptids_in_play:
		return true
	elif caster in enemy_cryptids_in_play and target in player_cryptids_in_play:
		return true
	return false

func is_hex_walkable(hex_pos: Vector2i) -> bool:
	# Use A* grid to check if position is walkable (has a valid point)
	var point_id = a_star_hex_grid.get_closest_point(hex_pos, false)
	if point_id == -1:
		return false
	var point_pos = a_star_hex_grid.get_point_position(point_id)
	# Check if the closest point is actually at this position
	return Vector2i(point_pos.x, point_pos.y) == hex_pos

func is_hex_occupied(hex_pos: Vector2i) -> bool:
	# Check if any cryptid is at this position
	for cryptid in all_cryptids_in_play:
		if local_to_map(cryptid.position) == hex_pos:
			return true
	return false

func update_cryptid_position(cryptid, new_hex_pos: Vector2i):
	# Update A* grid
	var old_hex_pos = local_to_map(cryptid.position)
	var old_point = a_star_hex_grid.get_closest_point(old_hex_pos, true)
	var new_point = a_star_hex_grid.get_closest_point(new_hex_pos, true)
	
	# Enable old position, disable new position
	a_star_hex_grid.set_point_disabled(old_point, false)
	a_star_hex_grid.set_point_disabled(new_point, true)
	
	# Update cryptid position
	cryptid.position = map_to_local(new_hex_pos)
	
	# Check for pickups at the new position
	_check_pickup_at_position(new_hex_pos, cryptid)

func _check_pickup_at_position(hex_pos: Vector2i, cryptid: Node):
	if pickup_manager and pickup_manager.has_pickup_at_position(hex_pos):
		var pickup = pickup_manager.get_pickup_at_position(hex_pos)
		if pickup and pickup.pickup_type == Pickup.PickupType.MOVEMENT_BOOST:
			# Handle movement boost specially
			print("Movement boost pickup triggered!")
			temporary_move_bonus += 1
			move_leftover += 1
			# Update movement indicator if active
			if move_action_bool and is_instance_valid(selected_cryptid):
				update_movement_indicator(selected_cryptid, move_leftover)
		
		pickup_manager.trigger_pickup(hex_pos, cryptid)

func damage_value_display(position: Vector2, amount: int):
	# Display damage number (visual effect not implemented yet)
	print("Damage: ", amount)

func heal_value_display(position: Vector2, amount: int):
	# Display heal number (visual effect not implemented yet)
	print("Heal: ", amount)

func use_card_part(card_container, part: String):
	# Mark the card part as used
	if card_container:
		var half_container = null
		if part == "top":
			half_container = card_container.get_node_or_null("TopHalfContainer")
		else:
			half_container = card_container.get_node_or_null("BottomHalfContainer")
		
		if half_container:
			half_container.modulate = Color(0.5, 0.5, 0.5)  # Gray out used part

func enable_all_cards():
	# Re-enable all cards by restoring their normal modulation
	for card in get_tree().get_nodes_in_group("cards"):
		card.modulate = Color.WHITE

func calculate_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	# Calculate hex distance using cube coordinates
	var cube1 = axial_to_cube(pos1)
	var cube2 = axial_to_cube(pos2)
	return cube_distance(cube1, cube2)

func get_cells_within_range(center_pos: Vector2i, max_range: int) -> Array:
	# Get all hex positions within range
	var positions = []
	for q in range(-max_range, max_range + 1):
		for r in range(max(-max_range, -q - max_range), min(max_range, -q + max_range) + 1):
			var offset = Vector2i(q, r)
			positions.append(offset)
	return positions

func create_hex_indicator(hex_pos: Vector2i, color: Color):
	# Create a visual indicator at the hex position
	var indicator = ColorRect.new()
	indicator.color = color
	indicator.size = Vector2(50, 50)
	indicator.position = map_to_local(hex_pos) - indicator.size / 2
	debug_container.add_child(indicator)

func show_push_pull_preview(start_pos: Vector2i, direction: Vector2i, distance: int):
	print("DEBUG: show_push_pull_preview called - start_pos:", start_pos, "direction:", direction, "distance:", distance)
	
	# Clear previous preview
	print("DEBUG: Clearing", push_pull_preview_hexes.size(), "previous preview hexes")
	for hex in push_pull_preview_hexes:
		if hex in original_tile_states:
			if is_showing_movement_range:
				# Check if there's a cryptid at this position
				var has_cryptid = false
				for cryptid in all_cryptids_in_play:
					if local_to_map(cryptid.position) == hex:
						has_cryptid = true
						break
				set_cell(hex, 0, path_tile_id if has_cryptid else move_range_tile_id, 1 if has_cryptid else 2)
			else:
				set_cell(hex, 0, original_tile_states[hex], 0)
	push_pull_preview_hexes.clear()
	
	# Show preview of push/pull movement path
	print("DEBUG: Creating preview path...")
	var preview_count = 0
	var final_position = start_pos
	
	# Calculate the complete path and final destination
	for i in range(1, distance + 1):
		var preview_pos = start_pos + direction * i
		print("DEBUG: Testing preview position", i, ":", preview_pos)
		print("DEBUG: In walkable_hexes:", preview_pos in walkable_hexes)
		print("DEBUG: Is occupied:", is_hex_occupied(preview_pos))
		
		if preview_pos in walkable_hexes and not is_hex_occupied(preview_pos):
			final_position = preview_pos
		else:
			print("DEBUG: Hit obstacle at", preview_pos, "- final position will be", final_position)
			break
	
	# Show the complete path from start to final position
	var current_pos = start_pos
	while current_pos != final_position:
		current_pos = current_pos + direction
		if current_pos in walkable_hexes:
			# Store original tile state for restoration
			if not original_tile_states.has(current_pos):
				original_tile_states[current_pos] = get_cell_atlas_coords(current_pos)
			
			# Add to preview tracking and show with path tile
			push_pull_preview_hexes.append(current_pos)
			
			# Use different visual for final destination vs path
			if current_pos == final_position:
				set_cell(current_pos, 0, path_tile_id, 3)  # Different alt for final position
			else:
				set_cell(current_pos, 0, path_tile_id, 2)  # Path tiles
			
			preview_count += 1
			print("DEBUG: Added preview tile at", current_pos, "final?", current_pos == final_position)
		else:
			break
	
	print("DEBUG: Total preview tiles created:", preview_count, "Final position:", final_position)

func get_hex_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	# Calculate hex direction using simple unit steps
	var diff = to_pos - from_pos
	
	if diff.x == 0 and diff.y == 0:
		return Vector2i.ZERO
	
	# Clamp to unit steps (-1, 0, 1) for each axis
	var unit_x = 0
	var unit_y = 0
	
	if diff.x != 0:
		unit_x = 1 if diff.x > 0 else -1
	if diff.y != 0:
		unit_y = 1 if diff.y > 0 else -1
	
	return Vector2i(unit_x, unit_y)


func get_point_id_from_position(hex_pos: Vector2i) -> int:
	# Convert hex position to a unique point ID
	# This matches the ID generation in create_hex_map_a_star
	return (hex_pos.x + 1000) * 10000 + (hex_pos.y + 1000)

func create_hex_map_a_star_modified(start_pos, max_range):
	# Clear existing attack grid
	a_star_hex_attack_grid.clear()
	
	var id_counter = 0
	var queue = []
	var visited = {}
	
	# Add start position
	queue.append({"pos": start_pos, "distance": 0})
	visited[start_pos] = 0
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_pos = current.pos
		var current_distance = current.distance
		
		# Add point to A* grid
		a_star_hex_attack_grid.add_point(id_counter, Vector2(current_pos.x, current_pos.y))
		id_counter += 1
		
		# Don't expand beyond max range
		if current_distance >= max_range:
			continue
			
		# Check all neighbors
		var neighbors = get_hex_neighbors(current_pos)
		for neighbor in neighbors:
			if neighbor in visited:
				continue
				
			# Check if walkable
			if neighbor in walkable_hexes:
				visited[neighbor] = current_distance + 1
				queue.append({"pos": neighbor, "distance": current_distance + 1})
	
	return true

func attack_action_selected(current_card):
	# Use the new generic system
	card_action_selected("attack", current_card)
	return
func _is_color_close(color1, color2, tolerance = 0.1):
	return (
		abs(color1.r - color2.r) < tolerance and
		abs(color1.g - color2.g) < tolerance and
		abs(color1.b - color2.b) < tolerance and
		abs(color1.a - color2.a) < tolerance
	)

# Add this more verbose version of disable_other_card_halves for debugging
func disable_other_card_halves_debug(active_card_half):
	# Simplified debug function
	print("Disabling other card halves for:", active_card_half)
func _input(event):
	if movement_in_progress:
		return
	
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_RIGHT and event.is_pressed():
			handle_right_click()
		if event is InputEventMouseMotion and (move_action_bool or attack_action_bool or push_action_bool or pull_action_bool or heal_action_bool or stun_action_bool or poison_action_bool or immobilize_action_bool or vulnerable_action_bool or burn_action_bool or shield_action_bool or pickup_spawn_action_bool):
			if event is InputEventMouseMotion:
				handle_mouse_motion()
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed() and (move_action_bool or attack_action_bool or push_action_bool or pull_action_bool or heal_action_bool or stun_action_bool or poison_action_bool or immobilize_action_bool or vulnerable_action_bool or burn_action_bool or shield_action_bool or pickup_spawn_action_bool):
	# IMPORTANT: When we're in attack/push/pull/heal/stun/poison mode, handle clicks directly here
			if attack_action_bool or push_action_bool or pull_action_bool or heal_action_bool or stun_action_bool or poison_action_bool or immobilize_action_bool or vulnerable_action_bool or burn_action_bool or shield_action_bool or pickup_spawn_action_bool:
				# This ensures cryptids don't handle the click separately
				get_viewport().set_input_as_handled()
			handle_left_click(event)

func move_action_selected(current_card):
	# Use the new generic system
	card_action_selected("move", current_card)
	return
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
		
		# Find the cryptid in player_cryptids_in_play that matches hand.selected_cryptid
		for player_cryptid in all_cryptids_in_play:
			if player_cryptid.cryptid == hand_node.selected_cryptid:
				return player_cryptid
		
		# If we didn't find a match, just return the first cryptid
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

# Find a cryptid at a given hex position
func get_cryptid_at_position(hex_pos, for_attack = false):
	# Simplified cryptid position lookup
	for cryptid in all_cryptids_in_play:
		if local_to_map(cryptid.position) == hex_pos:
			return cryptid
	return null
func apply_damage(target_cryptid, damage_amount):
	# Simplified damage application using health bar system
	if target_cryptid and target_cryptid.cryptid:
		# Process status effects that modify damage
		var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
		var final_damage = damage_amount
		
		if status_mgr:
			final_damage = status_mgr.process_damage_taken_effects(damage_amount)
		
		var health_bar = target_cryptid.get_node_or_null("HealthBar")
		if health_bar:
			var current_health = health_bar.value
			var new_health = max(current_health - final_damage, 0)
			
			# Update health bar
			health_bar.value = new_health
			
			# Update cryptid's health values
			target_cryptid.set_health_values(new_health, health_bar.max_value)
			target_cryptid.update_health_bar()
			
			# Store health metadata
			target_cryptid.cryptid.set_meta("current_health", new_health)
			
			if final_damage > 0:
				damage_value_display(target_cryptid.position, final_damage)
			if new_health <= 0:
				handle_cryptid_defeat(target_cryptid)
func has_bench_cryptids():
	var game_controller = get_node_or_null("/root/VitaChrome/TileMapLayer/GameController")
	if game_controller and game_controller.has_method("has_bench_cryptids"):
		return game_controller.has_bench_cryptids()
	else:
		print("WARNING: game_controller not found or missing has_bench_cryptids method")
		return false

func handle_cryptid_defeat(defeated_cryptid):
	# Simplified defeat handling
	if defeated_cryptid:
		defeated_cryptid.queue_free()
		if defeated_cryptid in player_cryptids_in_play:
			player_cryptids_in_play.erase(defeated_cryptid)
		elif defeated_cryptid in enemy_cryptids_in_play:
			enemy_cryptids_in_play.erase(defeated_cryptid)
		all_cryptids_in_play.erase(defeated_cryptid)
		print("Cryptid defeated:", defeated_cryptid.cryptid.name)
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
		if child.name in ["attack_indicator", "heal_indicator", "stun_indicator", "poison_indicator"]:
			child.queue_free()

func reset_action_modes():
	move_action_bool = false
	attack_action_bool = false
	push_action_bool = false
	pull_action_bool = false
	heal_action_bool = false
	stun_action_bool = false
	poison_action_bool = false
	immobilize_action_bool = false
	vulnerable_action_bool = false
	burn_action_bool = false
	shield_action_bool = false
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

func finish_movement():
	# Simplified movement completion
	movement_in_progress = false
	delete_all_indicators()
	delete_all_lines()
	update_all_debug_indicators()
	use_card_part(active_action.card, active_action.card_part)
	reset_action_state()
	enable_all_cards()
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
func disable_other_cards_exact(active_card_half):
	# Simplified card disabling
	for card in get_tree().get_nodes_in_group("cards"):
		if card != active_action.card:
			card.modulate = Color(0.5, 0.5, 0.5)
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
	# Simplified card discard
	if card_dialog:
		card_dialog.queue_free()
		reset_action_state()
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
	# Reset all action values - simplified using generic system
	reset_action_state()
	delete_all_indicators()
	delete_all_lines()
func setup_debug_display():
	if not debug_enabled:
		return
		
	
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

func rebuild_grid_state():
	print("Rebuilding grid state...")
	
	# Clear the grid manager's occupied positions
	grid_manager.occupied_positions.clear()
	
	# Re-enable all points in the movement grid
	for point_id in a_star_hex_grid.get_point_ids():
		a_star_hex_grid.set_point_disabled(point_id, false)
	
	# Re-register all cryptids with their current positions
	for cryptid in player_cryptids_in_play:
		var hex_pos = local_to_map(cryptid.position)
		print("Re-registering player cryptid at position:", hex_pos)
		grid_manager.occupy_hex(hex_pos, cryptid)
	
	for cryptid in enemy_cryptids_in_play:
		var hex_pos = local_to_map(cryptid.position)
		print("Re-registering enemy cryptid at position:", hex_pos)
		grid_manager.occupy_hex(hex_pos, cryptid)
	
	print("Grid state rebuilt")
	
	# Update debug display
	if debug_enabled:
		update_all_debug_indicators()

# Ensure a cryptid's position is properly disabled
func ensure_cryptid_position_disabled(cryptid_node):
	if not cryptid_node:
		return
		
	# Get the current map posirebuild_grid_statetion
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

func debug_team_assignments():
	
	print("Player team cryptids:")
	for i in range(player_cryptids_in_play.size()):
		var cryptid = player_cryptids_in_play[i]
		print(str(i) + ": " + cryptid.cryptid.name + " at position " + str(local_to_map(cryptid.position)))
	
	print("\nEnemy team cryptids:")
	for i in range(enemy_cryptids_in_play.size()):
		var cryptid = enemy_cryptids_in_play[i]
		print(str(i) + ": " + cryptid.cryptid.name + " at position " + str(local_to_map(cryptid.position)))
	
	print("\nAll cryptids in play:")
	for i in range(all_cryptids_in_play.size()):
		var cryptid = all_cryptids_in_play[i]
		print(str(i) + ": " + cryptid.cryptid.name + " at position " + str(local_to_map(cryptid.position)))
		

func rebuild_walkable_hexes():
	print("Rebuilding walkable_hexes array...")
	
	# Clear the existing walkable_hexes array
	walkable_hexes.clear()
	
	# For each point in the A* grid, check if it's disabled
	for point_id in a_star_hex_grid.get_point_ids():
		if not a_star_hex_grid.is_point_disabled(point_id):
			var pos = a_star_hex_grid.get_point_position(point_id)
			walkable_hexes.append(pos)
	
	print("walkable_hexes rebuilt with", walkable_hexes.size(), "hexes")

func highlight_possible_movement_hexes(cryptid_position, movement_range):
	# Clear any existing highlights
	clear_movement_highlights()
	
	is_showing_movement_range = true
	var current_pos = local_to_map(cryptid_position)
	
	# Get all hexes within movement range
	possible_move_hexes = get_hexes_within_range(current_pos, movement_range)
	
	# Highlight each possible movement hex
	for hex_pos in possible_move_hexes:
		# Skip hexes that are occupied
		if a_star_hex_grid.is_point_disabled(a_star_hex_grid.get_closest_point(hex_pos, true)):
			continue
			
		# Store original tile
		original_tile_states[hex_pos] = get_cell_atlas_coords(hex_pos)
		
		# Set the alternate tile - corrected parameters
		set_cell(hex_pos, 0, move_range_tile_id, 2)

func get_hexes_within_range(center_pos, move_range):
	var result = []
	
	# For each walkable hex, check if it's within movement range
	for hex_pos in walkable_hexes:
		# Skip if the hex is occupied
		if a_star_hex_grid.is_point_disabled(a_star_hex_grid.get_closest_point(hex_pos, true)):
			continue
		
		# Calculate actual path distance
		var path = a_star_hex_grid.get_id_path(
			a_star_hex_grid.get_closest_point(center_pos, true),
			a_star_hex_grid.get_closest_point(hex_pos, true)
		)
		
		# If there's a valid path and it's within range
		if path.size() > 0 and path.size() - 1 <= move_range:
			result.append(hex_pos)
	
	return result

func show_movement_path(start_pos, target_pos):
	# First we need to properly reset ALL previously highlighted path hexes
	for hex_pos in highlighted_path_hexes:
		# Reset to movement range tile or original tile
		if hex_pos in possible_move_hexes:
			set_cell(hex_pos, 0, move_range_tile_id, 2)
		else:
			# In case this hex is no longer in possible movement range
			if hex_pos in original_tile_states:
				set_cell(hex_pos, 0, original_tile_states[hex_pos], 0)
	
	# Clear the tracking array
	highlighted_path_hexes.clear()
	
	# Calculate path using A* pathfinding
	var path = a_star_hex_grid.get_id_path(
		a_star_hex_grid.get_closest_point(start_pos, true),
		a_star_hex_grid.get_closest_point(target_pos, true)
	)
	
	# If no path or path beyond movement range, return
	if path.size() == 0 or path.size() - 1 > move_leftover:
		return
	
	# Highlight each hex in the path
	for i in range(1, path.size()):  # Skip the start position
		var path_pos = a_star_hex_grid.get_point_position(path[i])
		
		# Add to our tracking list
		highlighted_path_hexes.append(path_pos)
		
		# Set the path tile
		set_cell(path_pos, 0, path_tile_id, 1)

func clear_movement_highlights():
	# Restore original tiles
	for hex_pos in original_tile_states:
		set_cell(hex_pos, 0, original_tile_states[hex_pos], 0)
	
	# Clear tracking arrays
	possible_move_hexes.clear()
	original_tile_states.clear()
	is_showing_movement_range = false
	
	# Also clear path highlights
	for hex_pos in highlighted_path_hexes:
		if hex_pos in original_tile_states:
			set_cell(hex_pos, 0, original_tile_states[hex_pos], 0)
	
	highlighted_path_hexes.clear()

func clear_path_highlights():
	# Restore path hexes to movement range tiles
	for hex_pos in highlighted_path_hexes:
		if hex_pos in possible_move_hexes:
			set_cell(hex_pos, 0, move_range_tile_id, 0)
	
	highlighted_path_hexes.clear()

func clear_heal_preview_hexes():
	# Clear heal preview tiles
	for hex in heal_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	heal_preview_hexes.clear()

func clear_stun_preview_hexes():
	# Clear stun preview tiles
	for hex in stun_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	stun_preview_hexes.clear()

func clear_poison_preview_hexes():
	# Clear poison preview tiles
	for hex in poison_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	poison_preview_hexes.clear()

func clear_immobilize_preview_hexes():
	# Clear immobilize preview tiles
	for hex in immobilize_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	immobilize_preview_hexes.clear()

func clear_vulnerable_preview_hexes():
	# Clear vulnerable preview tiles
	for hex in vulnerable_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	vulnerable_preview_hexes.clear()

func clear_burn_preview_hexes():
	# Clear burn preview tiles
	for hex in burn_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	burn_preview_hexes.clear()

func clear_shield_preview_hexes():
	# Clear shield preview tiles
	for hex in shield_preview_hexes:
		if hex in original_tile_states:
			set_cell(hex, 0, original_tile_states[hex], 0)
	shield_preview_hexes.clear()

func push_action_selected(current_card):
	# Use the new generic system
	card_action_selected("push", current_card)
	return
func pull_action_selected(current_card):
	# Use the new generic system
	card_action_selected("pull", current_card)
	return
func show_targetable_area(center_pos, max_range, action_type = "attack"):
	# Simplified implementation - just show indicators at valid positions
	var positions = []
	for offset in get_cells_within_range(center_pos, max_range):
		var hex_pos = center_pos + offset
		if hex_pos in walkable_hexes:
			positions.append(hex_pos)
	
	for pos in positions:
		var indicator_color = Color.YELLOW if action_type == "friendly" else Color.RED
		create_hex_indicator(pos, indicator_color)

func show_push_pull_range(center_pos, max_range, action_type):
	# Clear any existing highlights first
	clear_movement_highlights()
	
	# Get all hexes within range using the working method
	var positions = get_hexes_within_range(center_pos, max_range)
	
	# Highlight each possible target hex
	for hex_pos in positions:
		# Store original tile state for restoration
		if not original_tile_states.has(hex_pos):
			original_tile_states[hex_pos] = get_cell_atlas_coords(hex_pos)
		
		# Use alt tile 2 for push/pull range indicator (same as move range)
		set_cell(hex_pos, 0, move_range_tile_id, 2)



func get_hex_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = []
	
	# Looking at your grid: odd rows appear shifted RIGHT compared to even rows
	if pos.y % 2 == 0:  # Even row
		directions = [
			Vector2i(-1, -1),  # Northwest
			Vector2i(0, -1),   # Northeast
			Vector2i(1, 0),    # East
			Vector2i(0, 1),    # Southeast
			Vector2i(-1, 1),   # Southwest
			Vector2i(-1, 0)    # West
		]
	else:  # Odd row (shifted right)
		directions = [
			Vector2i(0, -1),   # Northwest
			Vector2i(1, -1),   # Northeast
			Vector2i(1, 0),    # East
			Vector2i(1, 1),    # Southeast
			Vector2i(0, 1),    # Southwest
			Vector2i(-1, 0)    # West
		]
	
	for dir in directions:
		neighbors.append(pos + dir)
	
	return neighbors
	
func is_valid_push_position(pos: Vector2i) -> bool:
	# Check if position is on the map
	if get_cell_atlas_coords(pos) == Vector2i(-1, -1):
		print("Position", pos, "is off the map")
		return false
	
	# Check if position is occupied
	for cryptid in all_cryptids_in_play:
		if local_to_map(cryptid.position) == pos:
			print("Position", pos, "is occupied")
			return false
	
	return true

func create_push_effect(start_pos, end_pos):
	# Create a visual line for the push
	var push_line = Line2D.new()
	push_line.width = 6
	push_line.default_color = Color(1, 0.5, 0, 0.8)  # Orange for push
	push_line.add_point(start_pos)
	push_line.add_point(end_pos)
	push_line.name = "push_effect"
	push_line.z_index = 10
	add_child(push_line)
	
	# Create impact effect at target
	var impact = ColorRect.new()
	impact.color = Color(1, 0.5, 0, 0.6)  # Orange
	impact.size = Vector2(30, 30)
	impact.position = end_pos - Vector2(15, 15)
	impact.name = "push_effect"
	impact.z_index = 10
	add_child(impact)
	
	# Animate the effects
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	# Pulse the line
	effect_tween.tween_property(push_line, "width", 12, 0.2)
	effect_tween.tween_property(push_line, "width", 3, 0.3)
	
	# Expand and fade the impact
	effect_tween.tween_property(impact, "scale", Vector2(1.5, 1.5), 0.3)
	effect_tween.tween_property(impact, "modulate", Color(1, 0.5, 0, 0), 0.3)
	
	# Clean up after animation
	effect_tween.tween_callback(Callable(self, "clean_up_push_effects"))

func create_pull_effect(start_pos, end_pos):
	# Create a visual line for the pull
	var pull_line = Line2D.new()
	pull_line.width = 6
	pull_line.default_color = Color(0, 0.5, 1, 0.8)  # Blue for pull
	pull_line.add_point(start_pos)
	pull_line.add_point(end_pos)
	pull_line.name = "pull_effect"
	pull_line.z_index = 10
	add_child(pull_line)
	
	# Create swirl effect at puller
	var swirl = ColorRect.new()
	swirl.color = Color(0, 0.5, 1, 0.6)  # Blue
	swirl.size = Vector2(40, 40)
	swirl.position = start_pos - Vector2(20, 20)
	swirl.name = "pull_effect"
	swirl.z_index = 10
	add_child(swirl)
	
	# Animate the effects
	var effect_tween = create_tween()
	effect_tween.set_parallel(true)
	
	# Pulse the line
	effect_tween.tween_property(pull_line, "width", 12, 0.2)
	effect_tween.tween_property(pull_line, "width", 3, 0.3)
	
	# Rotate and fade the swirl
	effect_tween.tween_property(swirl, "rotation", TAU, 0.5)
	effect_tween.tween_property(swirl, "modulate", Color(0, 0.5, 1, 0), 0.5)
	
	# Clean up after animation
	effect_tween.tween_callback(Callable(self, "clean_up_pull_effects"))

func clean_up_push_effects():
	for child in get_children():
		if child.name == "push_effect":
			child.queue_free()

func clean_up_pull_effects():
	for child in get_children():
		if child.name == "pull_effect":
			child.queue_free()

func mark_action_used():
	# This should only be called by the card when ALL actions are complete
	# Mark the appropriate card half as used
	if active_movement_card_part == "top":
		selected_cryptid.cryptid.top_card_played = true
		print("Marked top card as played")
	elif active_movement_card_part == "bottom":
		selected_cryptid.cryptid.bottom_card_played = true
		print("Marked bottom card as played")
	
	# Disable the entire card visually
	if is_instance_valid(card_dialog):
		disable_entire_card(card_dialog)
		discard_card(card_dialog, selected_cryptid.cryptid)
		
		# Disable other cards with the selected half
		if active_movement_card_part == "top":
			disable_other_cards_exact("top")
		elif active_movement_card_part == "bottom":
			disable_other_cards_exact("bottom")

func update_ui_after_action():
	# REMOVED: mark_action_used() - this is now handled by the card
	
	# Update hand to reflect changes
	var hand_node = get_node("/root/VitaChrome/UIRoot/Hand")
	if hand_node and hand_node.has_method("update_card_availability"):
		hand_node.update_card_availability()
	
	# Check if turn is complete
	if selected_cryptid.cryptid.top_card_played and selected_cryptid.cryptid.bottom_card_played:
		selected_cryptid.cryptid.completed_turn = true
		print("Marked cryptid's turn as complete")
		
		# Update the UI to prompt for the End Turn button
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu and action_menu.has_method("show_end_turn_only"):
			action_menu.show_end_turn_only()
			
		var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
		if game_instructions:
			game_instructions.text = "Turn complete. Press End Turn to continue."
	else:
		# Show the action menu again with updated button state
		var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if action_menu and action_menu.has_method("update_menu_visibility"):
			action_menu.update_menu_visibility(selected_cryptid.cryptid)
			action_menu.show()

func heal_action_selected(current_card):
	# Use the new generic system
	card_action_selected("heal", current_card)
	return

func immobilize_action_selected(current_card):
	# Use the new generic system
	card_action_selected("immobilize", current_card)
	return

func vulnerable_action_selected(current_card):
	# Use the new generic system
	card_action_selected("vulnerable", current_card)
	return

func is_friendly_target(caster, target) -> bool:
	# Self-healing is allowed
	if caster == target:
		return true
	
	# Check if both are in player team
	if caster in player_cryptids_in_play and target in player_cryptids_in_play:
		return true
	
	# Check if both are in enemy team
	if caster in enemy_cryptids_in_play and target in enemy_cryptids_in_play:
		return true
	
	# Otherwise they're on different teams
	return false

# Add the apply_healing function:
func apply_healing(target_cryptid, heal_amount):
	print("Applying " + str(heal_amount) + " healing to " + target_cryptid.cryptid.name)
	
	# Access the health value from the cryptid
	var health_bar = target_cryptid.get_node("HealthBar")
	if health_bar:
		# Calculate new health value (capped at max)
		var current_health = health_bar.value
		var max_health = health_bar.max_value
		var new_health = min(current_health + heal_amount, max_health)
		
		# Update health bar
		health_bar.value = new_health
		
		# Update cryptid's health values
		target_cryptid.set_health_values(new_health, max_health)
		target_cryptid.update_health_bar()
		
		var actual_healing = new_health - current_health
		print("Health increased by:", actual_healing)
		print("Health now: " + str(new_health) + "/" + str(max_health))
		
		# Store health metadata
		target_cryptid.cryptid.set_meta("current_health", new_health)
	else:
		print("ERROR: Could not find health bar on target cryptid!")

func get_cryptid_at_position_simple(hex_pos) -> Node:
	print("Searching for cryptid at position:", hex_pos)
	
	# First try exact position match
	for cryptid in all_cryptids_in_play:
		if is_instance_valid(cryptid):
			var cryptid_pos = local_to_map(cryptid.position)
			if cryptid_pos == hex_pos:
				print("Found cryptid:", cryptid.cryptid.name, "at exact position:", cryptid_pos)
				return cryptid
	
	# If no exact match, check nearby positions (in case of click precision issues)
	var neighbors = get_hex_neighbors(hex_pos)
	neighbors.append(hex_pos)  # Include the center position
	
	var closest_cryptid = null
	var min_distance = 999999.0
	
	for cryptid in all_cryptids_in_play:
		if is_instance_valid(cryptid):
			var cryptid_pos = local_to_map(cryptid.position)
			var world_pos = map_to_local(cryptid_pos)
			var click_world_pos = map_to_local(hex_pos)
			var distance = world_pos.distance_to(click_world_pos)
			
			if distance < min_distance and distance < 50:  # Within 50 pixels
				min_distance = distance
				closest_cryptid = cryptid
				print("Found nearby cryptid:", cryptid.cryptid.name, "at position:", cryptid_pos, "distance:", distance)
	
	if closest_cryptid:
		return closest_cryptid
	
	print("No cryptid found at or near position:", hex_pos)
	return null

func stun_action_selected(current_card):
	# Use the new generic system
	card_action_selected("stun", current_card)
	return
	
func poison_action_selected(current_card):
	# Use the new generic system
	card_action_selected("poison", current_card)
	return

func _on_attack_animation_finished():
	# This replaces the old _on_attack_tween_finished
	print("Attack animation finished")
	movement_in_progress = false
	set_process_input(true)

	# Reset states
	attack_action_bool = false
	delete_all_lines()
	delete_all_indicators()

func _on_movement_animation_finished():
	print("Movement animation completed")
	movement_in_progress = false
	set_process_input(true)
	
	# Update movement indicator if needed
	if move_action_bool and move_leftover > 0 and is_instance_valid(selected_cryptid):
		update_movement_indicator(selected_cryptid, move_leftover)
	else:
		remove_movement_indicator()

