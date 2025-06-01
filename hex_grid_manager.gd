class_name HexGridManager
extends RefCounted

var movement_grid: AStar2D  # For pathfinding that respects obstacles
var attack_grid: AStar2D    # For line-of-sight checks, ranged attacks, etc.
var hex_map
var occupied_positions = {}  # Dictionary mapping Vector2i positions to occupying entities

func _init(tilemap = null, movement_astar = null, attack_astar = null):
	hex_map = tilemap
	movement_grid = movement_astar
	attack_grid = attack_astar
	
# Core occupation management functions

func is_occupied(hex_pos) -> bool:
	return occupied_positions.has(hex_pos)
	
func is_hex_occupied(hex_pos) -> bool:
	# Alias for is_occupied to match the expected method name
	return is_occupied(hex_pos)
	
func get_occupant(hex_pos):
	if occupied_positions.has(hex_pos):
		return occupied_positions[hex_pos]
	return null
	
# Movement grid management

func occupy_hex(hex_pos, entity) -> bool:
	print("GRID: Trying to occupy hex", hex_pos)
	
	if is_occupied(hex_pos):
		print("GRID: Position already occupied by", get_occupant(hex_pos))
		return false  # Already occupied
		
	# Mark as occupied in our tracking dictionary
	occupied_positions[hex_pos] = entity
	
	# Disable point in movement grid only
	var point = movement_grid.get_closest_point(hex_pos, true)
	if point != -1:  # Ensure point is valid
		movement_grid.set_point_disabled(point, true)
		print("GRID: Successfully occupied hex", hex_pos, "by entity:", entity)
		print("GRID: Point", point, "is now disabled in movement grid")
		return true
	else:
		print("GRID: Could not find point for position", hex_pos)
		# Remove from occupied positions since we couldn't disable the point
		occupied_positions.erase(hex_pos)
		return false
	
func vacate_hex(hex_pos, entity = null) -> bool:
	print("GRID: Trying to vacate hex", hex_pos)
	
	# If entity is provided, ensure it matches the occupant
	if entity != null:
		var occupant = get_occupant(hex_pos)
		if occupant != entity:
			print("GRID: Entity mismatch when vacating")
			print("GRID: Expected:", entity)
			print("GRID: Found:", occupant)
			return false
		
	# Remove from tracking
	if occupied_positions.has(hex_pos):
		occupied_positions.erase(hex_pos)
		
		# Enable point in movement grid
		var point = movement_grid.get_closest_point(hex_pos, true)
		if point != -1:  # Ensure point is valid
			movement_grid.set_point_disabled(point, false)
			print("GRID: Successfully vacated hex", hex_pos)
			return true
		else:
			print("GRID: Could not find point for position", hex_pos)
			# Re-add to occupied positions since we couldn't enable the point
			if entity != null:
				occupied_positions[hex_pos] = entity
			return false
	else:
		print("GRID: Position", hex_pos, "not marked as occupied")
		return false
	
func move_entity(from_pos, to_pos, entity) -> bool:
	print("GRID: Moving entity from", from_pos, "to", to_pos)
	
	# Check if the entity is at from_pos
	var occupant = get_occupant(from_pos)
	if occupant != entity:
		print("GRID: Entity not found at from_pos")
		print("GRID: Expected:", entity)
		print("GRID: Found:", occupant)
		return false
		
	# Ensure destination is not occupied
	if is_occupied(to_pos):
		print("GRID: Destination already occupied by", get_occupant(to_pos))
		return false
	
	print("GRID: Position checks passed, proceeding with move")
	
	# Vacate original position
	if not vacate_hex(from_pos, entity):
		print("GRID: Failed to vacate original position")
		return false
	
	# Occupy new position
	if not occupy_hex(to_pos, entity):
		print("GRID: Failed to occupy new position, trying to restore original")
		# Try to restore the entity to its original position
		occupy_hex(from_pos, entity)
		return false
	
	print("GRID: Successfully moved entity")
	return true
	
# Path finding helpers

func get_movement_path(from_pos, to_pos) -> Array:
	var from_id = movement_grid.get_closest_point(from_pos, true)
	var to_id = movement_grid.get_closest_point(to_pos, true)
	
	# If either point is invalid, return empty path
	if from_id == -1 or to_id == -1:
		return []
		
	# Get path through movement grid (respects obstacles)
	return movement_grid.get_id_path(from_id, to_id)
	
func get_attack_path(from_pos, to_pos) -> Array:
	var from_id = attack_grid.get_closest_point(from_pos, true)
	var to_id = attack_grid.get_closest_point(to_pos, true)
	
	# If either point is invalid, return empty path
	if from_id == -1 or to_id == -1:
		return []
		
	# Get path through attack grid (ignores obstacles)
	return attack_grid.get_id_path(from_id, to_id)
	
# Get entities within attack range
func get_attackable_entities(from_pos, range_limit: int) -> Array:
	var attackable = []
	
	# For each occupied position
	for hex_pos in occupied_positions:
		# Get attack path to this position
		var path = get_attack_path(from_pos, hex_pos)
		
		# Check if within range
		if path.size() > 0 and path.size() - 1 <= range_limit:
			attackable.append({
				"entity": occupied_positions[hex_pos],
				"position": hex_pos,
				"distance": path.size() - 1
			})
			
	return attackable
	
# Debugging and validation

func validate_grid_state() -> bool:
	var is_valid = true
	
	# Validate movement grid
	for hex_pos in occupied_positions.keys():
		var point = movement_grid.get_closest_point(hex_pos, true)
		
		if not movement_grid.is_point_disabled(point):
			print("ERROR: Position", hex_pos, "is marked as occupied but not disabled in movement grid")
			is_valid = false
	
	# Validate all disabled points in movement grid
	for point_id in movement_grid.get_point_ids():
		if movement_grid.is_point_disabled(point_id):
			var hex_pos = movement_grid.get_point_position(point_id)
			
			if not occupied_positions.has(hex_pos):
				print("ERROR: Point", hex_pos, "is disabled in movement grid but not marked as occupied")
				is_valid = false
	
	return is_valid
	
func debug_print_occupied_positions():
	print("\n=== GRID MANAGER OCCUPIED POSITIONS DEBUG ===")
	print("Total occupied positions:", occupied_positions.size())
	
	for pos in occupied_positions.keys():
		var entity = occupied_positions[pos]
		var entity_name = "Unknown"
		
		# Try to get a name if entity has a cryptid property
		if entity and entity.get("cryptid") and entity.cryptid.get("name"):
			entity_name = entity.cryptid.name
			
		print("Position:", pos, "- Occupied by:", entity_name)
	
	print("=== END OCCUPIED POSITIONS DEBUG ===\n")
