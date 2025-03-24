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
	# First check if we're in discard mode - if so, let the hand handle this event
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("switch_cryptid_deck") and parent_node.in_discard_mode:
		# Don't process card actions during discard mode
		return
	
	# Check if this card is disabled due to being the only card in hand
	if has_meta("disabled_for_action") and get_meta("disabled_for_action") == true:
		# Only one card in hand - show warning and prevent action
		var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
		if game_instructions and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			game_instructions.text = "Need at least 2 cards to play! Use Rest action instead."
			
			# Highlight the Rest button as a hint
			var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
			if action_menu and action_menu.rest_button:
				# Create a flash effect to draw attention to the Rest button
				var original_color = action_menu.rest_button.modulate
				action_menu.rest_button.modulate = Color(1, 0.5, 0.5, 1)  # Highlight in red
				
				# Create a timer to reset the color
				var timer = get_tree().create_timer(1.0)
				timer.timeout.connect(func(): action_menu.rest_button.modulate = original_color)
			
			# Prevent further processing
			get_viewport().set_input_as_handled()
			return
	
	# Normal card handling for 2+ cards
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if self.get_parent().is_in_group("hand"):
			var parent_hand = self.get_parent()
			var tile_map_layer = get_tree().get_nodes_in_group("map")[0]
			
			# Check if there's an active movement in progress
			if tile_map_layer.is_movement_in_progress():
				# If this is a different card than the active one, finish the current movement
				if tile_map_layer.get_active_movement_card() != self:
					tile_map_layer.finish_movement()
				# If this is the same card but different half, also finish movement
				elif (tile_map_layer.get_active_movement_card_part() == "top" and 
					  bottom_half_container.get_global_rect().has_point(event.global_position)) or (tile_map_layer.get_active_movement_card_part() == "bottom" and 
					  top_half_container.get_global_rect().has_point(event.global_position)):
					tile_map_layer.finish_movement()
			
			# Check if top half is clicked
			if top_half_container.get_global_rect().has_point(event.global_position):
				# Only check if disabled, not whether an action was used
				if top_half_container.disabled:
					return
				
				# Reset highlighting, but preserve grayed out state for disabled cards
				for card in parent_hand.get_children():
					if card is CardDialog:  # Make sure we're only affecting card dialogs
						# Only reset non-disabled cards to white
						if not card.top_half_container.disabled:
							card.top_half_container.modulate = Color(1, 1, 1, 1)
						if not card.bottom_half_container.disabled:
							card.bottom_half_container.modulate = Color(1, 1, 1, 1)
				
				# Highlight this top half only
				top_half_container.modulate = Color(1, 1, 0, 1)
				perform_action(card_resource.top_move.actions[0].action_types)
				
			# Check if bottom half is clicked
			elif bottom_half_container.get_global_rect().has_point(event.global_position):
				# Only check if disabled, not whether an action was used
				if bottom_half_container.disabled:
					return
				
				# Reset highlighting, but preserve grayed out state for disabled cards
				for card in parent_hand.get_children():
					if card is CardDialog:  # Make sure we're only affecting card dialogs
						# Only reset non-disabled cards to white
						if not card.top_half_container.disabled:
							card.top_half_container.modulate = Color(1, 1, 1, 1)
						if not card.bottom_half_container.disabled:
							card.bottom_half_container.modulate = Color(1, 1, 1, 1)
				
				# Highlight this bottom half only
				bottom_half_container.modulate = Color(1, 1, 0, 1)
				perform_action(card_resource.bottom_move.actions[0].action_types)


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
	# Get parent hand and selected cryptid
	var parent_hand = get_parent()
	if not parent_hand.has_method("switch_cryptid_deck"):
		return
	
	var selected_cryptid = parent_hand.selected_cryptid
	if not selected_cryptid:
		return
	
	# Check if the cryptid has already used a top/bottom action
	# We'll allow the highlighting and selection even if an action was used,
	# but the actual execution will be prevented in handle_move_action/handle_attack_action
	if top_half_container.modulate == Color(1, 1, 0, 1) and selected_cryptid.top_card_played:
		print("Warning: Top action already used this turn. Showing action but it won't be executed.")
	elif bottom_half_container.modulate == Color(1, 1, 0, 1) and selected_cryptid.bottom_card_played:
		print("Warning: Bottom action already used this turn. Showing action but it won't be executed.")
	
	action_types = actions
	
	# Reset any previous action states before starting a new one
	tile_map_layer.move_action_bool = false
	tile_map_layer.attack_action_bool = false
	tile_map_layer.delete_all_lines()
	tile_map_layer.delete_all_indicators()
	
	# Hide the action selection menu while performing the action
	var action_selection_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_selection_menu:
		action_selection_menu.hide()
	
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
	
	# Important update: If top or bottom half was used, update the menu to show only End Turn button
	if (top_half_container.modulate == Color(1, 1, 0, 1) and !selected_cryptid.top_card_played) or \
	   (bottom_half_container.modulate == Color(1, 1, 0, 1) and !selected_cryptid.bottom_card_played):
		# After action selection, a card action is about to be performed
		# This will cause an action to be used, so update the menu
		var menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
		if menu and menu.has_method("update_menu_visibility"):
			# Create a temporary version of the cryptid to check what the menu would look like after this action
			var temp_cryptid = selected_cryptid.duplicate()
			if top_half_container.modulate == Color(1, 1, 0, 1):
				temp_cryptid.top_card_played = true
			if bottom_half_container.modulate == Color(1, 1, 0, 1):
				temp_cryptid.bottom_card_played = true
				
			# Update menu based on what it will look like after action completes
			menu.update_menu_visibility(temp_cryptid)

func move_action():
	tile_map_layer.move_action_bool = true
	tile_map_layer.move_action_selected(self)
	pass

func attack_action():
	tile_map_layer.attack_action_bool = true
	tile_map_layer.attack_action_selected(self)
	# Store the current card for reference in the tile map controller
	tile_map_layer.current_card = self

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

func _on_mouse_entered():
	self.z_index += 2

func _on_mouse_exited():
	self.z_index -= 2

func update_move_action_display(card_half, remaining_amount):
	# Store the original amount so we can restore it later
	var move_actions = card_resource.top_move.actions if card_half == "top" else card_resource.bottom_move.actions
	
	for action in move_actions:
		if action.action_types == [0]:  # Move action
			# Update the amount in the action
			var original_amount = action.amount
			action.amount = remaining_amount
			
			# Clear and rebuild the card half
			var container = top_half_container if card_half == "top" else bottom_half_container
			
			# Remove all existing action slots
			for child in container.get_children():
				container.remove_child(child)
				child.queue_free()
			
			# Re-add the action slots with updated values
			for action_to_add in move_actions:
				var slot = action_slot.instantiate().duplicate()
				container.add_child(slot)
				slot.add_action(action_to_add)
			
			break
