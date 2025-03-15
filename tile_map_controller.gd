extends TileMapLayer

const MAIN_ATLAS_ID = 0

@onready var cur_position = NodeBase.new()
@onready var tar_position = NodeBase.new()
@onready var enemy_position = NodeBase.new()
@onready var a_star_hex_grid = AStar2D.new()
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


@onready var player_cryptids_in_play = []
@onready var enemy_cryptids_in_play = []

@onready var all_cryptids_in_play = []

@onready var blank_cryptid = preload("res://Cryptid-Menagerie/data/cryptids/blank_cryptid.tscn")
@onready var current_card


var move_action_bool = false
var attack_action_bool = false
var current_atlas_coords
var cur_position_cube
var move_leftover = 0
var attack_range = 2
var path
var vector_path = []
var point_path = []
var damage

func _ready():
	cur_position_cube = axial_to_cube(local_to_map(player_pos))
	cur_position.Hex_Cords = Vector2i(-4, 1)
	enemy_position.Hex_Cords = Vector2i(0, -3)
	create_hex_map_a_star(cur_position.Hex_Cords)
	show_coordinates_label(cur_position.Hex_Cords)
	walkable_hexes.erase(cur_position.Hex_Cords)
	walkable_hexes.erase(enemy_position.Hex_Cords)
	
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
		walkable_hexes.erase(local_to_map(cryptid.position))
		cryptids_in_play.append(cryptid)
	return cryptids_in_play

func handle_right_click():
	pass

func handle_mouse_motion():
	if selected_cryptid == null:
		selected_cryptid = player_cryptids_in_play[0]
	path = a_star_hex_grid.get_id_path(
		a_star_hex_grid.get_closest_point(local_to_map(selected_cryptid.position)),
		a_star_hex_grid.get_closest_point(local_to_map(get_local_mouse_position()))
	)
	vector_path = []
	point_path = []
	for point in path:
		vector_path.append(map_to_local(a_star_hex_grid.get_point_position(point)))
		point_path.append(a_star_hex_grid.get_point_position(point))
	delete_all_lines()
	if move_action_bool and walkable_hexes.find(local_to_map(get_local_mouse_position())) != -1:
		draw_lines_between_points(convert_vector2_array_to_vector2i_array(vector_path), move_leftover, Color(0, 1, 0))
	if attack_action_bool:
		draw_lines_between_points(convert_vector2_array_to_vector2i_array(vector_path), attack_range, Color(1, 0, 1))	

func handle_left_click(event):
	#attack_action_selected()
	var global_clicked = event.position
	selected_cryptid = currently_selected_cryptid()
	var pos_clicked = local_to_map(to_local(global_clicked))
	
	if selected_cryptid == null:
		selected_cryptid = player_cryptids_in_play[0]
	
	if pos_clicked in walkable_hexes:
		#if card_dialog.current_highlighted_container == card_dialog.top_half_container:
		if true:
			print(card_dialog.card_resource.top_move.actions)
			for action in card_dialog.card_resource.top_move.actions:
				if action.action_types == [0] and action.amount >= point_path.size() - 1 and selected_cryptid.cryptid.top_card_played == false:
					#and local_to_map(enemy_cryptid.position) != pos_clicked
					walkable_hexes.append(local_to_map(player_pos))
					action.amount -= point_path.size() - 1
					move_leftover -= point_path.size() - 1
					player_pos = map_to_local(pos_clicked)
					selected_cryptid.position = map_to_local(pos_clicked)
					walkable_hexes.erase(local_to_map(pos_clicked))
					print("testing", player_cryptids_in_play[0].position)
					#need to change this so it disables all other cards. The problem with this is you cannot do partial moves
					for card in hand.get_children():
						if card != card_dialog:
							card.top_half_container.disable_top_half()
						
				
				if action.action_types == [1] and action.range > 0 and local_to_map(enemy_cryptids_in_play[0].position) == pos_clicked:
					pass
		#if card_dialog.current_highlighted_container == card_dialog.bottom_half_container:
		if true:
			for action in card_dialog.card_resource.bottom_move.actions:
				if action.action_types == [0] and action.amount >= point_path.size() - 1 and selected_cryptid.cryptid.bottom_card_played == false:
					action.amount -= point_path.size() - 1
					player_pos = map_to_local(pos_clicked)
					selected_cryptid = currently_selected_cryptid()
					selected_cryptid.position = map_to_local(pos_clicked)
					selected_cryptid.cryptid.bottom_card_played = true
				if action.action_types == [1] and attack_range >= point_path.size() - 1 and local_to_map(enemy_cryptids_in_play[0].position) == pos_clicked:
					enemy_cryptid.health -= action.amount
					enemy_cryptid.update_health_bar()
		#print(move_leftover)
		player_pos = map_to_local(pos_clicked)
		#cur_position_cube = axial_to_cube(pos_clicked)
		#grove_starter.position = map_to_local(pos_clicked)
	selected_cryptid = currently_selected_cryptid()

func _input(event):
	if event is InputEventMouse:
		#attack_action_selected()
		if event.button_mask == MOUSE_BUTTON_RIGHT and event.is_pressed():
			handle_right_click()
		if event is InputEventMouseMotion and move_action_bool:
			if event is InputEventMouseMotion:
				handle_mouse_motion()
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed() and move_action_bool:
			if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
				handle_left_click(event)

func move_action_selected(current_card):
	card_dialog = current_card
	move_action_bool = false
	selected_cryptid = currently_selected_cryptid()
	delete_all_lines()
	#if current_card.current_highlighted_container == current_card.top_half_container:
	if current_card != null:
		for action in card_dialog.card_resource.top_move.actions:
			if action.action_types == [0] and action.amount > 0:
				move_leftover = action.amount
				move_action_bool = true
				break
	#elif current_card.current_highlighted_container == current_card.bottom_half_container:
	if current_card != null:
		for action in card_dialog.card_resource.bottom_move.actions:
			if action.action_types == [0] and action.amount > 0:
				move_leftover = action.amount
				move_action_bool = true
				break

func attack_action_selected():
	attack_action_bool = false
	delete_all_lines()
	if card_dialog.current_highlighted_container == card_dialog.top_half_container:
		for action in card_dialog.card_resource.top_move.actions:
			if action.action_types == [1]:
				damage = action.amount
				attack_range = action.range
				attack_action_bool = true
				break
	elif card_dialog.current_highlighted_container == card_dialog.bottom_half_container:
		for action in card_dialog.card_resource.bottom_move.actions:
			if action.action_types == [1]:
				damage = action.amount
				attack_range = action.range
				attack_action_bool = true
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

	while toSearch.size() > 0:
		var current_node = toSearch.pop_front()
		if current_node in processed:
			continue

		a_star_hex_grid.add_point(id_counter, Vector2(current_node.x, current_node.y))
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
	var turn_completed
	for cryptid_in_play in player_cryptids_in_play:
		if cryptid_in_play.cryptid.completed_turn == false:
			return false 
	return true 

func currently_selected_cryptid():
	for player_cryptids in player_cryptids_in_play:
		if player_cryptids.cryptid.currently_selected == true:
			return player_cryptids

# Function to compare two cryptid objects based on their speed
func compare_cryptids(a, b):
	return a.cryptid.speed > b.cryptid.speed  # Use boolean comparison

# Function to sort the array
func sort_cryptids_by_speed(cryptid_array):
	cryptid_array.sort_custom(Callable(self, "compare_cryptids"))

