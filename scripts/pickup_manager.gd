extends Node
class_name PickupManager

signal pickup_spawned(pickup: Pickup, position: Vector2i)
signal pickup_triggered(pickup: Pickup, position: Vector2i, cryptid: Node)
signal pickup_removed(pickup: Pickup, position: Vector2i)

# Dictionary to store pickups by position
var pickups: Dictionary = {}  # Vector2i -> Pickup

# Visual representation of pickups
var pickup_visuals: Dictionary = {}  # Vector2i -> Node2D

# Reference to hex grid manager
var hex_grid_manager: HexGridManager
var tile_map_controller: Node

func _ready():
	# Get references to required nodes - these will be set by parent
	pass
	
func initialize(parent_tile_map):
	tile_map_controller = parent_tile_map
	hex_grid_manager = parent_tile_map.grid_manager

func spawn_pickup(pickup_type: Pickup.PickupType, target_position: Vector2i, amount: int = 1) -> Array:
	print("PickupManager.spawn_pickup called - type:", pickup_type, "target:", target_position, "amount:", amount)
	var spawned_positions = []
	var available_positions = _get_available_neighbor_positions(target_position)
	print("Available positions:", available_positions)
	
	# Shuffle available positions for random placement
	available_positions.shuffle()
	
	# Spawn pickups up to the requested amount or available positions
	var spawn_count = min(amount, available_positions.size())
	for i in spawn_count:
		var pos = available_positions[i]
		var pickup = _create_pickup(pickup_type)
		_place_pickup(pickup, pos)
		spawned_positions.append(pos)
	
	return spawned_positions

func spawn_pickup_at_position(pickup_type: Pickup.PickupType, position: Vector2i) -> bool:
	if not _is_position_available(position):
		return false
		
	var pickup = _create_pickup(pickup_type)
	_place_pickup(pickup, position)
	return true

func _create_pickup(pickup_type: Pickup.PickupType) -> Pickup:
	var pickup = Pickup.new()
	pickup.pickup_type = pickup_type
	pickup._init()  # Initialize default properties
	
	return pickup

func _place_pickup(pickup: Pickup, position: Vector2i) -> void:
	print("Placing pickup at position:", position, "type:", pickup.pickup_type)
	
	# Replace existing pickup if any
	if pickups.has(position):
		_remove_pickup(position)
	
	# Add pickup to dictionary
	pickups[position] = pickup
	print("Pickup added to dictionary. Total pickups:", pickups.size())
	
	# Create visual representation
	_create_pickup_visual(pickup, position)
	
	# Update hex grid if walls block movement
	if pickup.blocks_movement():
		print("This pickup blocks movement:", pickup.pickup_type, "at", position)
		if hex_grid_manager:
			hex_grid_manager.occupy_hex(position, pickup)
			print("Wall placed - blocking movement at:", position)
	else:
		print("This pickup does NOT block movement:", pickup.pickup_type, "at", position)
	
	pickup_spawned.emit(pickup, position)

func _remove_pickup(position: Vector2i) -> void:
	if not pickups.has(position):
		return
		
	var pickup = pickups[position]
	
	# Remove from hex grid if it was blocking
	if pickup.blocks_movement() and hex_grid_manager:
		hex_grid_manager.vacate_hex(position, pickup)
	
	# Remove visual
	if pickup_visuals.has(position):
		pickup_visuals[position].queue_free()
		pickup_visuals.erase(position)
	
	# Remove from dictionary
	pickups.erase(position)
	
	pickup_removed.emit(pickup, position)

func trigger_pickup(position: Vector2i, cryptid: Node) -> void:
	if not pickups.has(position):
		return
		
	var pickup = pickups[position]
	
	# Skip walls - they don't trigger
	if pickup.pickup_type == Pickup.PickupType.WALL:
		return
	
	# Apply pickup effect
	pickup.trigger(cryptid)
	
	pickup_triggered.emit(pickup, position, cryptid)
	
	# Remove pickup if not persistent
	if pickup.should_remove_on_trigger():
		_remove_pickup(position)

func damage_pickup(position: Vector2i, damage: int) -> void:
	if not pickups.has(position):
		return
		
	var pickup = pickups[position]
	print("Damaging pickup at", position, "for", damage, "damage. Current health:", pickup.health)
	
	if pickup.take_damage(damage):
		print("Pickup destroyed at", position)
		_remove_pickup(position)
	else:
		print("Pickup damaged but still alive. New health:", pickup.health)
		# Update visual to show damage
		_update_pickup_visual(pickup, position)

func get_pickup_at_position(position: Vector2i) -> Pickup:
	return pickups.get(position, null)

func has_pickup_at_position(position: Vector2i) -> bool:
	return pickups.has(position)

func get_all_pickup_positions() -> Array:
	return pickups.keys()

func clear_all_pickups() -> void:
	var positions = pickups.keys()
	for pos in positions:
		_remove_pickup(pos)

func _get_available_neighbor_positions(center: Vector2i) -> Array:
	print("Getting available neighbors for center:", center)
	var neighbors = []
	
	# Use the tile map's built-in function to get proper hex neighbors
	if tile_map_controller:
		var surrounding = tile_map_controller.get_surrounding_cells(center)
		for neighbor_pos in surrounding:
			print("Checking neighbor:", neighbor_pos, "from center:", center)
			if _is_position_available(neighbor_pos):
				neighbors.append(neighbor_pos)
			else:
				print("Neighbor not available:", neighbor_pos)
	
	return neighbors

func _is_position_available(position: Vector2i) -> bool:
	# First check if this is a valid hex position on the map
	if tile_map_controller:
		var atlas_coords = tile_map_controller.get_cell_atlas_coords(position)
		if atlas_coords == Vector2i(-1, -1):
			print("Position", position, "is not a valid hex on the map")
			return false
	
	# Check if hex_grid_manager exists
	if not hex_grid_manager:
		print("WARNING: hex_grid_manager is null, assuming position is available")
		return true
		
	# Check if position is occupied by a cryptid
	if hex_grid_manager.is_hex_occupied(position):
		print("Position", position, "is occupied by a cryptid")
		return false
	
	# Check if there's already a pickup at this position
	if pickups.has(position):
		print("Position", position, "already has a pickup")
		return false
	
	# Position is available
	print("Position", position, "is available")
	return true

func _create_pickup_visual(pickup: Pickup, position: Vector2i) -> void:
	print("Creating visual for pickup at:", position)
	
	# Create visual node
	var visual = Node2D.new()
	visual.name = "Pickup_" + str(position)
	
	# Add icon
	var icon_rect = TextureRect.new()
	icon_rect.texture = pickup.icon
	icon_rect.modulate = pickup.icon_color
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	# Make icons much smaller - about 24x24 pixels for a hex that's probably 64x64
	var icon_size = 24.0 * pickup.icon_scale
	icon_rect.size = Vector2(icon_size, icon_size)
	# Center the icon - if the texture rect's origin is top-left, we need to offset by half the size
	icon_rect.position = Vector2(-icon_size/2, -icon_size/2)
	visual.add_child(icon_rect)
	
	# Add label for pickup name (for debugging)
	var label = Label.new()
	label.text = pickup.name
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-20, 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	visual.add_child(label)
	
	# Add to scene
	if tile_map_controller:
		tile_map_controller.add_child(visual)
		
		# Position on hex grid  
		var world_pos = tile_map_controller.map_to_local(position)
		visual.position = world_pos
		visual.z_index = 1  # Above tilemap but below cryptids
	
	pickup_visuals[position] = visual

func _update_pickup_visual(pickup: Pickup, position: Vector2i) -> void:
	if not pickup_visuals.has(position):
		return
		
	var visual = pickup_visuals[position]
	
	# Update health display for walls
	if pickup.pickup_type == Pickup.PickupType.WALL:
		# Add or update health label
		var health_label = visual.get_node_or_null("HealthLabel")
		if not health_label:
			health_label = Label.new()
			health_label.name = "HealthLabel"
			health_label.add_theme_font_size_override("font_size", 16)
			visual.add_child(health_label)
		
		health_label.text = str(pickup.health) + "/" + str(pickup.max_health)
		health_label.position = Vector2(-20, -40)
