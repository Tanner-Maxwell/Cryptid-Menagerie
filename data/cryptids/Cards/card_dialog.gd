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

# NEW: Track current action index and active actions
var current_action_index: int = 0
var active_actions: Array[Action] = []
var active_card_half: String = ""  # "top" or "bottom"

enum ActionType {
	MOVE,
	ATTACK,
	PUSH,
	PULL,
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
			
			# Check if we're already in an action sequence
			if active_actions.size() > 0 and current_action_index < active_actions.size():
				print("Already in action sequence, action", current_action_index + 1, "of", active_actions.size())
				return
			
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
				
				# NEW: Initialize action sequence for top half
				active_card_half = "top"
				active_actions = card_resource.top_move.actions.duplicate()
				current_action_index = 0
				
				print("Starting top half actions, total actions:", active_actions.size())
				for i in range(active_actions.size()):
					print("  Action", i, ":", get_action_name(active_actions[i].action_types))
				
				# Start the first action
				if active_actions.size() > 0:
					execute_current_action()
				
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
				
				# NEW: Initialize action sequence for bottom half
				active_card_half = "bottom"
				active_actions = card_resource.bottom_move.actions.duplicate()
				current_action_index = 0
				
				print("Starting bottom half actions, total actions:", active_actions.size())
				for i in range(active_actions.size()):
					print("  Action", i, ":", get_action_name(active_actions[i].action_types))
				
				# Start the first action
				if active_actions.size() > 0:
					execute_current_action()

# NEW: Execute the current action in the sequence
func execute_current_action():
	if current_action_index >= active_actions.size():
		# All actions completed
		finish_card_usage()
		return
	
	var current_action = active_actions[current_action_index]
	
	print("Executing action index", current_action_index, ":", get_action_name(current_action.action_types))
	print("Current action details: range=", current_action.range, "amount=", current_action.amount)
	
	# Update UI to show current action
	update_action_indicator()
	
	# CRITICAL: Make sure tile_map_layer has a valid reference to this card
	tile_map_layer.card_dialog = self
	tile_map_layer.active_movement_card = self
	tile_map_layer.current_card = self  # Some functions use current_card
	
	# Set the action-specific parameters based on the current action
	if active_card_half == "top":
		tile_map_layer.active_movement_card_part = "top"
	else:
		tile_map_layer.active_movement_card_part = "bottom"
	
	# IMPORTANT: Keep the card highlighted while actions are active
	if active_card_half == "top":
		top_half_container.modulate = Color(1, 1, 0, 1)
		# Disable the other half
		bottom_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
		bottom_half_container.disabled = true
	else:
		bottom_half_container.modulate = Color(1, 1, 0, 1)
		# Disable the other half
		top_half_container.modulate = Color(0.5, 0.5, 0.5, 1)
		top_half_container.disabled = true
	
	# Disable other cards during action sequence
	disable_other_card_halves(active_card_half)
	
	# Set up the specific action parameters BEFORE calling perform_action
	for action_type in current_action.action_types:
		match action_type:
			ActionType.MOVE:
				print("Setting up MOVE action with amount:", current_action.amount)
				tile_map_layer.move_leftover = current_action.amount
				tile_map_layer.original_move_amount = current_action.amount
			ActionType.ATTACK:
				print("Setting up ATTACK action with range:", current_action.range, "damage:", current_action.amount)
				tile_map_layer.attack_range = current_action.range
				tile_map_layer.damage = current_action.amount
			ActionType.PUSH:
				print("Setting up PUSH action with range:", current_action.range, "amount:", current_action.amount)
				tile_map_layer.push_range = current_action.range
				tile_map_layer.push_amount = current_action.amount
			ActionType.PULL:
				print("Setting up PULL action with range:", current_action.range, "amount:", current_action.amount)
				tile_map_layer.pull_range = current_action.range
				tile_map_layer.pull_amount = current_action.amount
			ActionType.HEAL:
				print("Setting up HEAL action with range:", current_action.range, "amount:", current_action.amount)
				tile_map_layer.heal_range = current_action.range
				tile_map_layer.heal_amount = current_action.amount
			ActionType.STUN:
				print("Setting up STUN action with range:", current_action.range, "amount:", current_action.amount)
				tile_map_layer.stun_range = current_action.range
				tile_map_layer.stun_amount = current_action.amount
	
	# Perform the action based on its type
	perform_action(current_action.action_types)

# Helper function to disable other card halves
func disable_other_card_halves(active_half: String):
	var parent_hand = get_parent()
	if parent_hand:
		for card in parent_hand.get_children():
			if card != self and card is CardDialog:
				# Disable both halves of other cards
				if card.has_node("VBoxContainer/TopHalfContainer"):
					var top = card.get_node("VBoxContainer/TopHalfContainer")
					top.modulate = Color(0.5, 0.5, 0.5, 1)
					top.disabled = true
				if card.has_node("VBoxContainer/BottomHalfContainer"):
					var bottom = card.get_node("VBoxContainer/BottomHalfContainer")
					bottom.modulate = Color(0.5, 0.5, 0.5, 1)
					bottom.disabled = true

# NEW: Move to next action in sequence
func next_action():
	print("Moving to next action. Current index:", current_action_index)
	
	# Clean up the current action state first
	var tile_map = get_tree().get_nodes_in_group("map")[0]
	if tile_map:
		# Reset ALL action booleans
		tile_map.move_action_bool = false
		tile_map.attack_action_bool = false
		tile_map.push_action_bool = false
		tile_map.pull_action_bool = false
		tile_map.heal_action_bool = false
		tile_map.stun_action_bool = false
		tile_map.active_movement_card = null
		tile_map.active_movement_card_part = ""
		
		# Clear any visual indicators
		tile_map.delete_all_lines()
		tile_map.delete_all_indicators()
		tile_map.clear_movement_highlights()
		tile_map.remove_movement_indicator()
	
	current_action_index += 1
	print("New index:", current_action_index, "Total actions:", active_actions.size())
	
	if current_action_index >= active_actions.size():
		print("All actions completed")
		finish_card_usage()
	else:
		print("Executing action", current_action_index + 1, "of", active_actions.size())
		# Small delay to ensure cleanup is complete
		await get_tree().create_timer(0.1).timeout
		execute_current_action()

# NEW: Skip current action
func skip_current_action():
	# Clean up any active action state in tile map
	var tile_map = get_tree().get_nodes_in_group("map")[0]
	if tile_map:
		# Reset all action booleans
		tile_map.move_action_bool = false
		tile_map.attack_action_bool = false
		tile_map.push_action_bool = false
		tile_map.pull_action_bool = false
		tile_map.heal_action_bool = false
		tile_map.stun_action_bool = false
		
		# Clear any visual indicators
		tile_map.delete_all_lines()
		tile_map.delete_all_indicators()
		tile_map.clear_movement_highlights()
		tile_map.remove_movement_indicator()
	
	# If this is the first action being skipped, mark card as used
	if current_action_index == 0:
		mark_card_half_used()
	
	# Move to next action
	next_action()


# NEW: Mark the card half as used
func mark_card_half_used():
	var selected_cryptid = get_parent().selected_cryptid
	if active_card_half == "top" and not selected_cryptid.top_card_played:
		selected_cryptid.top_card_played = true
	elif active_card_half == "bottom" and not selected_cryptid.bottom_card_played:
		selected_cryptid.bottom_card_played = true

# NEW: Finish using this card
func finish_card_usage():
	print("Finishing card usage - all actions complete")
	
	# Mark the card half as used
	mark_card_half_used()
	
	# Reset action tracking
	current_action_index = 0
	active_actions.clear()
	active_card_half = ""
	
	# Clean up any remaining action state in tile map
	var tile_map = get_tree().get_nodes_in_group("map")[0]
	if tile_map:
		tile_map.move_action_bool = false
		tile_map.attack_action_bool = false
		tile_map.push_action_bool = false
		tile_map.pull_action_bool = false
		tile_map.heal_action_bool = false
		tile_map.stun_action_bool = false
		tile_map.delete_all_lines()
		tile_map.delete_all_indicators()
		tile_map.clear_movement_highlights()
	
	# Update UI
	var parent_hand = get_parent()
	if parent_hand and parent_hand.has_method("update_card_availability"):
		parent_hand.update_card_availability()
	
	# Update the action menu to show appropriate buttons
	var action_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_menu:
		# Force update the menu based on current cryptid state
		var selected_cryptid = parent_hand.selected_cryptid if parent_hand else null
		if selected_cryptid:
			action_menu.update_menu_visibility(selected_cryptid)
			action_menu.show()

# NEW: Update visual indicator for current action
func update_action_indicator():
	# This will be implemented to show which action is currently active
	var game_instructions = get_node("/root/VitaChrome/UIRoot/GameInstructions")
	if game_instructions and current_action_index < active_actions.size():
		var current_action = active_actions[current_action_index]
		var action_name = get_action_name(current_action.action_types)
		var action_number = current_action_index + 1
		var total_actions = active_actions.size()
		game_instructions.text = "Action " + str(action_number) + "/" + str(total_actions) + ": " + action_name

# NEW: Get human-readable action name
func get_action_name(action_types: Array) -> String:
	if action_types.size() == 0:
		return "Unknown"
	
	match action_types[0]:
		ActionType.MOVE:
			return "Move"
		ActionType.ATTACK:
			return "Attack"
		ActionType.PUSH:
			return "Push"
		ActionType.PULL:
			return "Pull"
		ActionType.HEAL:
			return "Heal"
		ActionType.STUN:
			return "Stun"
		ActionType.APPLY_VULNERABLE:
			return "Apply Vulnerable"
		ActionType.POISON:
			return "Poison"
		ActionType.PARALYZE:
			return "Paralyze"
		ActionType.IMMOBILIZE:
			return "Immobilize"
		_:
			return "Unknown"

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

# Modified perform_action to handle single action type
func perform_action(actions: Array[Action.ActionType]):
	# Get parent hand and selected cryptid
	var parent_hand = get_parent()
	if not parent_hand.has_method("switch_cryptid_deck"):
		return
	
	var selected_cryptid = parent_hand.selected_cryptid
	if not selected_cryptid:
		return
	
	# Reset any previous action states before starting a new one
	tile_map_layer.move_action_bool = false
	tile_map_layer.attack_action_bool = false
	tile_map_layer.push_action_bool = false
	tile_map_layer.pull_action_bool = false
	tile_map_layer.heal_action_bool = false
	tile_map_layer.stun_action_bool = false
	tile_map_layer.delete_all_lines()
	tile_map_layer.delete_all_indicators()
	
	# Hide the action selection menu while performing the action
	var action_selection_menu = get_node("/root/VitaChrome/UIRoot/ActionSelectMenu")
	if action_selection_menu:
		action_selection_menu.hide()
	
	# Execute only the first action type
	if actions.size() > 0:
		var action_type = actions[0]
		match action_type:
			ActionType.MOVE:
				move_action()
			ActionType.ATTACK:
				attack_action()
			ActionType.PUSH:
				push_action()
			ActionType.PULL:
				pull_action()
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
				# If unknown action, skip to next
				next_action()
	
	# Update the action menu to show skip button
	if action_selection_menu:
		action_selection_menu.update_menu_visibility(selected_cryptid)

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
	tile_map_layer.push_action_bool = true
	tile_map_layer.push_action_selected(self)
	# Store the current card for reference in the tile map controller
	tile_map_layer.current_card = self

func pull_action():
	tile_map_layer.pull_action_bool = true
	tile_map_layer.pull_action_selected(self)
	# Store the current card for reference in the tile map controller
	tile_map_layer.current_card = self

func heal_action():
	tile_map_layer.heal_action_bool = true
	tile_map_layer.heal_action_selected(self)
	# Store the current card for reference in the tile map controller
	tile_map_layer.current_card = self

func stun_action():
	print("Stun action activated in card_dialog")
	tile_map_layer.stun_action_bool = true
	tile_map_layer.current_card = self
	
	# Make sure we have the current action's parameters
	if current_action_index < active_actions.size():
		var current_action = active_actions[current_action_index]
		tile_map_layer.stun_range = current_action.range
		tile_map_layer.stun_amount = current_action.amount
		print("Stun parameters set - range:", current_action.range, "amount:", current_action.amount)
	
	tile_map_layer.stun_action_selected(self)

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
