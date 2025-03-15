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
@onready var selected_cards = $UIRoot/SelectedCards

@export var action_types: Array[Action.ActionType] = []

@onready var grove_starter = %"Grove Starter"
@onready var fire_starter = %"Fire Starter"

@onready var tile_map_layer = %TileMapLayer
@onready var parent = $IRoot/Hand
@onready var is_card_highlighted: bool = false  # Track if this card is highlighted
@onready var is_top_highlighted: bool = false
@onready var is_bottom_highlighted: bool = false


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

signal moving

func _ready():
	if card_resource != null and action_slot != null:
		display(card_resource)
	parent = get_parent()
	tile_map_layer = get_tree().get_nodes_in_group("map")[0]

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if self.get_parent().is_in_group("hand"):
			if top_half_container.get_global_rect().has_point(event.global_position) and top_half_container.disabled == false:
				for card in self.get_parent().get_children():
					card.bottom_half_container.modulate = Color(1, 1, 1, 1)  # Default color for bottom
					card.top_half_container.modulate = Color(1, 1, 1, 1)  # Default color for bottom
				top_half_container.modulate = Color(1, 1, 0, 1)  # Highlight color for top
				perform_action(card_resource.top_move.actions[0].action_types)
			elif bottom_half_container.get_global_rect().has_point(event.global_position) and bottom_half_container.disabled == false:
				for card in self.get_parent().get_children():
					card.bottom_half_container.modulate = Color(1, 1, 1, 1)  # Default color for bottom
					card.top_half_container.modulate = Color(1, 1, 1, 1)  # Default color for bottom
				bottom_half_container.modulate = Color(1, 1, 0, 1)  # Highlight color for top
				perform_action(card_resource.bottom_move.actions[0].action_types)
				
		elif self.get_parent():
			if is_card_highlighted:
				parent.call("unhighlight_card", self)
			else:
				if parent.call("can_highlight_more"):
					parent.call("highlight_card", self)
					
		elif self.get_parent().is_in_group("selected_card"):
			if is_card_highlighted:
				parent.call("unhighlight_card", self)
			else:
				if parent.call("can_highlight_more"):
					parent.call("highlight_card", self)

func is_in_selected_cards() -> bool:
	return self.get_parent().is_in_group("selected_card")

func highlight():
	is_card_highlighted = true  # Update the flag to indicate this card is highlighted
	if parent.is_in_group("hand"):
		modulate = Color(1, 1, 0, 1)  # Change to highlight color or visual effect

func unhighlight():
	is_card_highlighted = false  # Update the flag to indicate this card is not highlighted
	if parent.is_in_group("hand"):
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


func perform_action(actions: Array[Action.ActionType]):
	action_types = actions
	for action_type in action_types:
		match action_type:
			ActionType.MOVE:
				move_action()
			ActionType.ATTACK:
				attack_action()
			ActionType.PUSH:
				push_action()
			ActionType.PULL:
				pull_action()
			ActionType.RANGED_ATTACK:
				ranged_attack_action()
			ActionType.HEAL:
				heal_action()
			ActionType.STUN:
				stun_action()
			ActionType.APPLY_VULNERABLE:
				apply_vulnerable_action()
			ActionType.POISON:
				poison_action()
			ActionType.PARALYZE:
				paralyze_action()
			ActionType.IMMOBILIZE:
				immobilize_action()
			_:
				print("Unknown action type")

func move_action():
	tile_map_layer.move_action_bool = true
	tile_map_layer.move_action_selected(self)
	pass

func attack_action():
	pass

func push_action():
	pass

func pull_action():
	pass

func ranged_attack_action():
	pass

func heal_action():
	pass

func stun_action():
	pass

func apply_vulnerable_action():
	pass

func poison_action():
	pass

func paralyze_action():
	pass

func immobilize_action():
	pass

#func move_action_selected():
	#var move_action_bool = false
	#delete_all_lines()
	#if card_dialog.current_highlighted_container == card_dialog.top_half_container:
		#for action in card_dialog.card_resource.top_move.actions:
			#if action.action_types == [0] and action.amount > 0:
				#move_leftover = action.amount
				#move_action_bool = true
				#break
	#elif card_dialog.current_highlighted_container == card_dialog.bottom_half_container:
		#for action in card_dialog.card_resource.bottom_move.actions:
			#if action.action_types == [0] and action.amount > 0:
				#move_leftover = action.amount
				#move_action_bool = true
				#break

func _on_mouse_entered():
	self.z_index += 2

func _on_mouse_exited():
	self.z_index -= 2
