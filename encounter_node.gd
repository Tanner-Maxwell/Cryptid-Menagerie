extends Button
class_name EncounterNode

signal encounter_selected(node_data)

# Encounter properties
@export var encounter_type: String = "wild"  # "wild" or "trainer"
@export var biome: String = "Forest"
@export var trainer_id: String = ""  # Only used for trainer encounters
@export var node_id: String = "node_001"
@export var connected_nodes: Array[String] = []  # IDs of connected nodes

# Visual properties
@export var normal_color: Color = Color(1, 1, 1, 1)
@export var hover_color: Color = Color(1, 0.8, 0.2, 1)
@export var completed_color: Color = Color(0.5, 0.5, 0.5, 1)

# State
var is_accessible: bool = false
var is_completed: bool = false
var is_current: bool = false

# Called when the node enters the scene tree
func _ready():
	# Connect button signals
	connect("pressed", Callable(self, "_on_button_pressed"))
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	add_to_group("encounter_nodes")
	print("Added node " + name + " to encounter_nodes group")
	
	# If you have node_id defined, print it for debugging
	if "node_id" in self:
		print("Node ID: " + node_id)
	# Set up initial appearance
	update_appearance()

# Called when the button is pressed
func _on_button_pressed():
	if is_accessible and not is_completed:
		# Prepare node data to pass to the encounter system
		var node_data = {
			"node_id": node_id,
			"encounter_type": encounter_type,
			"biome": biome,
			"trainer_id": trainer_id
		}
		
		# Emit the encounter selected signal
		emit_signal("encounter_selected", node_data)

# Handle mouse hover
func _on_mouse_entered():
	if is_accessible and not is_completed:
		modulate = hover_color
		# You could show a tooltip here with encounter info

func _on_mouse_exited():
	update_appearance()  # Reset to normal appearance

# Set the node as accessible (can be selected by player)
func set_accessible(accessible: bool):
	is_accessible = accessible
	update_appearance()

# Mark the node as completed
func set_completed(completed: bool):
	is_completed = completed
	update_appearance()

# Mark this as the current node
func set_current(current: bool):
	is_current = current
	update_appearance()

# Update the visual appearance based on state
func update_appearance():
	if is_completed:
		modulate = completed_color
		disabled = true
	elif is_accessible:
		modulate = normal_color
		disabled = false
	else:
		modulate = Color(0.3, 0.3, 0.3, 0.5)  # Darkened and transparent
		disabled = true
	
	if is_current:
		# Add a highlight or border effect
		# This is just a placeholder - you might want to add a shader or sprite
		modulate = Color(0.2, 1, 0.2, 1)  # Greenish highlight
