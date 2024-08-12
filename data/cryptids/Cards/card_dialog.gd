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


var current_highlighted_container: VBoxContainer = null

func _ready():
	if card_resource and action_slot != null:
		display(card_resource)

func display(card:Card):
	show()
	#implement for action slots if we have duplication bug
	#for children in team_dialog_grid_container.get_children():
		#team_dialog_grid_container.remove_child(children)
	card_name.text = card.top_move.name_prefix + " " + card.bottom_move.name_suffix
	for action in card.top_move.actions.size():
		var slot = action_slot.instantiate()
		top_half_container.add_child(slot)
		slot.add_action(card.top_move.actions[action])
	for action in card.bottom_move.actions.size():
		var slot = action_slot.instantiate()
		bottom_half_container.add_child(slot)
		slot.add_action(card.bottom_move.actions[action])

func highlight_container(container: VBoxContainer):
	if current_highlighted_container == container:
		# If the clicked container is already highlighted, unhighlight it
		current_highlighted_container.unhighlight()
		current_highlighted_container = null
	else:
		# Unhighlight the previously highlighted container if it exists
		if current_highlighted_container != null:
			current_highlighted_container.unhighlight()
		# Highlight the new container
		current_highlighted_container = container
		current_highlighted_container.highlight()
