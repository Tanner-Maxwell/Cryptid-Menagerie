class_name CardDialog
extends PanelContainer

@export var action_slot:PackedScene
@export var card_resource:Card

@onready var team_dialog_grid_container:GridContainer = %TeamDialogGridContainer
@onready var card_name_container = %CardNameContainer
@onready var top_half_container = %TopHalfContainer
@onready var bottom_half_container = %BottomHalfContainer
@onready var top_element = %TopElement
@onready var bottom_element = %BottomElement
@onready var card_name = %CardName

@export var action_types: Array[Action.ActionType] = []

@onready var grove_starter = %"Grove Starter"
@onready var fire_starter = %"Fire Starter"

@onready var tile_map_layer = %TileMapLayer
@onready var hand_parent = %Hand
@onready var is_card_highlighted: bool = false  # Track if this card is highlighted

enum ActionType {
	MOVE,
	ATTACK,
	PUSH,
	PULL,
	RANGED_ATTACK,
	HEAL,
	STUN,
	APPLY_VULNERABLE,
	POISON,
	PARALYZE,
	IMMOBILIZE
}

func _ready():
	# Get the Hand parent node that manages the cards

	if card_resource != null and action_slot != null:
		display(card_resource)
	#perform_action(grove_starter, fire_starter, card_resource.top_move.actions[0].action_types)

# This function is called when the card is clicked (or any event that triggers the highlight)
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Notify the hand to highlight this card
		print(event)
		# Toggle highlight/unhighlight based on current state
		if get_global_rect().has_point(event.global_position):
			if hand_parent == self.get_parent():
				if is_card_highlighted:
					hand_parent.call("unhighlight_card", self)
				else:
					if hand_parent.call("can_highlight_more"):
						hand_parent.call("highlight_card", self)

func is_highlighted() -> bool:
	return is_card_highlighted

# Function to highlight this container
func highlight():
	is_card_highlighted = true  # Update the flag to indicate this card is highlighted
	modulate = Color(1, 1, 0, 1)  # Change to some highlight color or visual effect

# Function to unhighlight this container
func unhighlight():
	is_card_highlighted = false  # Update the flag to indicate this card is not highlighted
	modulate = Color(1, 1, 1, 1)  # Reset to normal or faded effect

func display(card: Card):
	show()
	card_name.text = card.top_move.name_prefix + " " + card.bottom_move.name_suffix
	for action in card.top_move.actions.size():
		var slot = action_slot.instantiate()
		top_half_container.add_child(slot)
		slot.add_action(card.top_move.actions[action])
	for action in card.bottom_move.actions.size():
		var slot = action_slot.instantiate()
		bottom_half_container.add_child(slot)
		slot.add_action(card.bottom_move.actions[action])

# Function to perform the action
func perform_action(source, targets, actions: Array[Action.ActionType]):
	action_types = actions
	for action_type in action_types:
		print(action_type)
		match action_type:
			ActionType.MOVE:
				move_action(source, targets)
			ActionType.ATTACK:
				attack_action(source, targets)
			ActionType.PUSH:
				push_action(source, targets)
			ActionType.PULL:
				pull_action(source, targets)
			ActionType.RANGED_ATTACK:
				ranged_attack_action(source, targets)
			ActionType.HEAL:
				heal_action(source, targets)
			ActionType.STUN:
				stun_action(source, targets)
			ActionType.APPLY_VULNERABLE:
				apply_vulnerable_action(source, targets)
			ActionType.POISON:
				poison_action(source, targets)
			ActionType.PARALYZE:
				paralyze_action(source, targets)
			ActionType.IMMOBILIZE:
				immobilize_action(source, targets)
			_:
				print("Unknown action type")

# Define action-specific functions
@warning_ignore("unused_parameter")
func move_action(source, targets):
	# Implement move logic
	print("move")
	pass

@warning_ignore("unused_parameter")
func attack_action(source, targets):
	# Implement attack logic
	print("attack")
	pass

@warning_ignore("unused_parameter")
func push_action(source, targets):
	# Implement push logic
	pass

@warning_ignore("unused_parameter")
func pull_action(source, targets):
	# Implement pull logic
	pass

@warning_ignore("unused_parameter")
func ranged_attack_action(source, targets):
	# Implement ranged attack logic
	pass

@warning_ignore("unused_parameter")
func heal_action(source, targets):
	# Implement heal logic
	pass

@warning_ignore("unused_parameter")
func stun_action(source, targets):
	# Implement stun logic
	pass

@warning_ignore("unused_parameter")
func apply_vulnerable_action(source, targets):
	# Implement apply vulnerable logic
	pass

@warning_ignore("unused_parameter")
func poison_action(source, targets):
	# Implement poison logic
	pass

@warning_ignore("unused_parameter")
func paralyze_action(source, targets):
	# Implement paralyze logic
	pass

@warning_ignore("unused_parameter")
func immobilize_action(source, targets):
	# Implement immobilize logic
	pass


func _on_mouse_entered():
	self.z_index += 2


func _on_mouse_exited():
	self.z_index -= 2
