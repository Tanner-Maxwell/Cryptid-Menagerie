extends Node2D
class_name PathDrawer

@export var line_color: Color = Color(1, 1, 1, 0.7)
@export var line_width: float = 3.0
@export var completed_color: Color = Color(0.5, 0.5, 0.5, 0.7)
@export var active_color: Color = Color(1, 0.8, 0.2, 1.0)

# Reference to encounter nodes
@onready var encounter_nodes = $"../EncounterNodes"

# Called when the node enters the scene tree
func _ready():
	# Wait a frame to ensure all encounter nodes are initialized
	await get_tree().process_frame
	draw_all_connections()

# Called whenever the node needs to be redrawn
func _draw():
	# This will be called after queue_redraw()
	# But we'll do our drawing in draw_all_connections instead
	pass

# Draw all connections between encounter nodes
func draw_all_connections():
	# Clear existing lines
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	var node_dict = {}
	
	# First create a dictionary of nodes by their ID
	for node in encounter_nodes.get_children():
		if node is EncounterNode:
			node_dict[node.node_id] = node
	
	# Then draw connections
	for node in encounter_nodes.get_children():
		if node is EncounterNode:
			for connected_id in node.connected_nodes:
				if node_dict.has(connected_id):
					draw_connection(node, node_dict[connected_id])
	
	# No need to call queue_redraw() as we're creating Line2D nodes

# Draw a connection between two nodes
func draw_connection(from_node, to_node):
	var line = Line2D.new()
	line.width = line_width
	
	# Calculate start and end positions
	var start_pos = from_node.position + from_node.size / 2
	var end_pos = to_node.position + to_node.size / 2
	
	# Add points to the line
	line.add_point(start_pos)
	line.add_point(end_pos)
	
	# Determine the color based on node states
	var line_completed = false
	
	# Check if both nodes are completed
	if from_node.is_completed and to_node.is_completed:
		line.default_color = completed_color
		line_completed = true
	# Check if one node is current and the other is accessible
	elif (from_node.is_current and to_node.is_accessible) or (to_node.is_current and from_node.is_accessible):
		line.default_color = active_color
	# Default color otherwise
	else:
		line.default_color = line_color
	
	# Add node to the scene
	add_child(line)
	
	# If the line is completed, send it to the back
	if line_completed:
		line.z_index = -1
	
	return line

# Update the connections (call this after node states change)
func update_connections():
	draw_all_connections()
