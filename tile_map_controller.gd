extends TileMapLayer

const MAIN_ATLAS_ID = 0

@onready var cur_position = NodeBase.new()
@onready var tar_position = NodeBase.new()
@onready var enemy_position = NodeBase.new()
@onready var a_star_hex_grid = AStar2D.new()
@onready var line_container = $LineContainer
@onready var player_pos = map_to_local(Vector2i(-4, 1))
@onready var grove_starter = $"PlayerTeam/Grove Starter"
@onready var enemy_cryptid = $"EnemyTeam/Fire Starter"
@onready var walkable_hexes = []
@onready var card_dialog = $"../UIRoot/Hand/CardDialog"


var move_action_bool = false
var attack_action_bool = false
var current_atlas_coords
var cur_position_cube
var move_leftover = 20
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
	grove_starter.position = map_to_local(cur_position.Hex_Cords)
	enemy_cryptid.position = map_to_local(enemy_position.Hex_Cords)

func _input(event):
	if event is InputEventMouse:
		move_action_selected()
		attack_action_selected()
		if event.button_mask == MOUSE_BUTTON_RIGHT and event.is_pressed():
			handle_right_click()
		if event is InputEventMouseMotion:
			handle_mouse_motion()
		if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
			handle_left_click(event)

func handle_right_click():
	pass

func handle_mouse_motion():
	path = a_star_hex_grid.get_id_path(
		a_star_hex_grid.get_closest_point(local_to_map(player_pos)),
		a_star_hex_grid.get_closest_point(local_to_map(get_local_mouse_position()))
	)
	vector_path = []
	point_path = []
	for point in path:
		vector_path.append(map_to_local(a_star_hex_grid.get_point_position(point)))
		point_path.append(a_star_hex_grid.get_point_position(point))
	delete_all_lines()
	if move_action_bool:
		draw_lines_between_points(convert_vector2_array_to_vector2i_array(vector_path), move_leftover, Color(0, 1, 0))
	if attack_action_bool:
		draw_lines_between_points(convert_vector2_array_to_vector2i_array(vector_path), attack_range, Color(1, 0, 1))	

func handle_left_click(event):
	move_action_selected()
	attack_action_selected()
	var global_clicked = event.position
	var pos_clicked = local_to_map(to_local(global_clicked))
	if pos_clicked in walkable_hexes:
		if card_dialog.current_highlighted_container == card_dialog.top_half_container:
			for action in card_dialog.card_resource.top_move.actions:
				if action.action_types == [0] and action.amount >= point_path.size() - 1:
					action.amount -= point_path.size() - 1
					player_pos = map_to_local(pos_clicked)
					grove_starter.position = map_to_local(pos_clicked)
				
				if action.action_types == [1] and action.range > 0 and local_to_map(enemy_cryptid.position) == pos_clicked:
					print("testing")
		if card_dialog.current_highlighted_container == card_dialog.bottom_half_container:
			for action in card_dialog.card_resource.bottom_move.actions:
				if action.action_types == [0] and action.amount >= point_path.size() - 1:
					action.amount -= point_path.size() - 1
					player_pos = map_to_local(pos_clicked)
					grove_starter.position = map_to_local(pos_clicked)
				print(local_to_map(enemy_cryptid.position))
				print(pos_clicked)
				if action.action_types == [1] and attack_range >= point_path.size() - 1 and local_to_map(enemy_cryptid.position) == pos_clicked:
					print("attack")
					enemy_cryptid.health -= action.amount
					enemy_cryptid.update_health_bar()
		#print(move_leftover)
		#player_pos = map_to_local(pos_clicked)
		#cur_position_cube = axial_to_cube(pos_clicked)
		#grove_starter.position = map_to_local(pos_clicked)

func move_action_selected():
	move_action_bool = false
	delete_all_lines()
	if card_dialog.current_highlighted_container == card_dialog.top_half_container:
		for action in card_dialog.card_resource.top_move.actions:
			if action.action_types == [0] and action.amount > 0:
				move_leftover = action.amount
				move_action_bool = true
				break
	elif card_dialog.current_highlighted_container == card_dialog.bottom_half_container:
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
