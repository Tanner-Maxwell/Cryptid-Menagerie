extends TileMapLayer

const main_atlas_id = 0
@onready var cur_position : NodeBase = NodeBase.new()
@onready var tar_position : NodeBase = NodeBase.new()
@onready var a_star_hex_grid : AStar2D = AStar2D.new()
@onready var line_container: Node2D = $LineContainer
var player_pos = map_to_local(Vector2i(-3, 1))

func _input(event):
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_RIGHT and event.is_pressed():
			cur_position.Hex_Cords = Vector2i(-3, 1)
			var atlas_coords = get_cell_atlas_coords(Vector2i(-3, 3))
			create_hex_map_a_star(cur_position.Hex_Cords)
			var neighbors: Array[Vector2i] = get_surrounding_cells(cur_position.Hex_Cords)
			var coordiantes = Label.new()
			coordiantes.show()
			var label_pos = map_to_local(cur_position.Hex_Cords)
			label_pos.x = label_pos.x - 20
			label_pos.y = label_pos.y + 10
			coordiantes.position = label_pos
			coordiantes.text = str(local_to_map(label_pos))
			add_child(coordiantes)
	
	if event is InputEventMouseMotion:
		delete_all_lines()
		var path = a_star_hex_grid.get_id_path(a_star_hex_grid.get_closest_point(player_pos), a_star_hex_grid.get_closest_point(local_to_map(get_local_mouse_position())))
		var vector_path : Array[Vector2] = []
		for point in path:
			var position = a_star_hex_grid.get_point_position(point)
			position = map_to_local(position)
			vector_path.append(position)
		var vector_path_i: Array[Vector2i] = convert_vector2_array_to_vector2i_array(vector_path)
		for point in vector_path_i:
			point = map_to_local(point)
		draw_lines_between_points(vector_path_i)
	if event.button_mask == MOUSE_BUTTON_LEFT and event.is_pressed():
		var global_clicked = event.position
		var pos_clicked = local_to_map(to_local(global_clicked))
		var tar_position = Vector2i(1, -3)
		var current_atlas_coords = get_cell_atlas_coords(pos_clicked)
		
		var pos_clicked_cube = axial_to_cube(pos_clicked)
		var cur_position_cube = axial_to_cube(cur_position.Hex_Cords)
		var tar_position_cube = axial_to_cube(tar_position)
		var gcost = cube_distance(cur_position_cube, tar_position_cube)
		var current_tile_alt = get_cell_alternative_tile(pos_clicked)
		var number_of_alts_for_clicked = tile_set.get_source(main_atlas_id).get_alternative_tiles_count(current_atlas_coords)
		#set_cell(pos_clicked, main_atlas_id, current_atlas_coords, (cube_distance(cur_position_cube,axial_to_cube(pos_clicked))))
		var surrounding_cells = get_surrounding_cells(pos_clicked)
		player_pos = pos_clicked
		print("position updated")
		#for cell in surrounding_cells:
		#	set_cell(cell, main_atlas_id, get_cell_atlas_coords(cell), (cube_distance(cur_position_cube,axial_to_cube(cell))))
		#print(a_star_hex_grid.get_point_path(pos_clicked))
		#var path = a_star_hex_grid.get_id_path(a_star_hex_grid.get_closest_point(player_pos), a_star_hex_grid.get_closest_point(pos_clicked))
		#print(path)
		#var vector_path : Array[Vector2] = []
		#for point in path:
			#var position = a_star_hex_grid.get_point_position(point)
			#position = map_to_local(position)
			#vector_path.append(position)
		#var vector_path_i: Array[Vector2i] = convert_vector2_array_to_vector2i_array(vector_path)
		#for point in vector_path_i:
			#point = map_to_local(point)
		#print(vector_path_i)
		#draw_lines_between_points(vector_path_i)
		#player_pos = pos_clicked
			
	
func findPath(start_node, target_node):
	var toSearch: Array[NodeBase] = []
	toSearch.append(start_node)
	var processed: Array[NodeBase] = []
	
	while (!toSearch.is_empty()):
		var current = toSearch[0]
		for t in toSearch:		
			if (f_cost(start_node, target_node, t) < f_cost(start_node, target_node, current) or \
			f_cost(start_node, target_node, t) == f_cost(start_node, target_node, current) and \
			cube_distance(target_node, t) < cube_distance(target_node, current)):
				current = t;
				
		processed.append(current)
		toSearch.remove_at(0)
		
		var neighbors = get_surrounding_cells(cube_to_axial(current))
		for neighbor in neighbors:
			if !processed.has(axial_to_cube(neighbor)):
				var inSearch = toSearch.has(axial_to_cube(neighbor))
				var costToNeighbor = cube_distance(start_node, current) + cube_distance(current, axial_to_cube(neighbor))
				if !inSearch or costToNeighbor < cube_distance(axial_to_cube(neighbor), current):
					if !inSearch:
						toSearch.append(axial_to_cube(neighbor))
				#if(!inSearch or costToNeighbor < cube_distance(neighbor, start_node)):
					#neighbor
			

func axial_to_cube(hex):
	var q = hex.x
	var r = hex.y - (hex.x - (hex.x&1)) / 2
	return Vector3i(q, r, -q-r)

func cube_to_axial(cube):
	var q = cube.x
	var r = cube.y
	return Vector2i(q, r)

func cube_subtract(a, b):
	return Vector3i((a.x - b.x), (a.y - b.y), (a.z - b.z))

func cube_distance(a, b):
	var vec: Vector3i = cube_subtract(a, b)
	return (abs(vec.x) + abs(vec.y) + abs(vec.z)) / 2
	
func f_cost(start_pos, target_pos, cur_pos):
	return (cube_distance(start_pos, cur_pos) + cube_distance(cur_pos, target_pos))

func create_hex_map_a_star(start_pos: Vector2i):
	var toSearch: Array[Vector2i] = [start_pos]
	var processed: Dictionary = {}
	var id_counter: int = 0
	
	while toSearch.size() > 0:
		var current_node: Vector2i = toSearch.pop_front()
		if current_node in processed:
			continue
		
		# Add the current node to the Astar grid with a unique ID
		a_star_hex_grid.add_point(id_counter, Vector2(current_node.x, current_node.y))
		processed[current_node] = id_counter
		
		# Get surrounding cells
		var neighbors: Array[Vector2i] = get_surrounding_cells(current_node)
		for neighbor in neighbors:
			if neighbor not in processed and neighbor not in toSearch and get_cell_atlas_coords(neighbor) != Vector2i(-1, -1):
				toSearch.append(neighbor)
		
		id_counter += 1
	# Connect all points in the processed dictionary
	for current_node in processed.keys():
		var current_id: int = processed[current_node]
		var neighbors: Array[Vector2i] = get_surrounding_cells(current_node)
		for neighbor in neighbors:
			if neighbor in processed:
				var neighbor_id: int = processed[neighbor]
				a_star_hex_grid.connect_points(current_id, neighbor_id)
				
				var coordiantes = Label.new()
				coordiantes.show()
				var label_pos = map_to_local(neighbor)
				label_pos.x = label_pos.x - 20
				label_pos.y = label_pos.y + 10
				coordiantes.position = label_pos
				coordiantes.text = str(local_to_map(label_pos))
				add_child(coordiantes)
				
				draw_line_between_points(map_to_local(current_node), map_to_local(neighbor))
				
func draw_line_between_points(point_a: Vector2i, point_b: Vector2i):
	var line = Line2D.new()
	line.width = 2
	line.default_color = Color(0, 0, 0)  # Set the line color to black
	line.add_point(Vector2(point_a.x, point_a.y))
	line.add_point(Vector2(point_b.x, point_b.y))
	line_container.add_child(line)

func draw_lines_between_points(points: Array[Vector2i]):
	if points.size() < 2:
		return
	var line = Line2D.new()
	line.width = 4
	line.default_color = Color(0, 1, 0)  # Set the line color to green
	for point in points:
		line.add_point(Vector2(point.x, point.y))
	line_container.add_child(line)

func convert_vector2_array_to_vector2i_array(vector2_array: Array) -> Array:
	var vector2i_array: Array[Vector2i] = []
	for vector2 in vector2_array:
		var vector2i = Vector2i(round(vector2.x), round(vector2.y))
		vector2i_array.append(vector2i)
	return vector2i_array

func delete_all_lines():
	var lines = line_container.get_children()
	for line in lines:
		line.queue_free()
