class_name StatusEffectManager
extends Node

signal status_effect_added(effect: StatusEffect)
signal status_effect_removed(effect_type: StatusEffect.EffectType)
signal status_effect_triggered(effect: StatusEffect)

var active_effects: Dictionary = {}  # Key: EffectType, Value: StatusEffect
var cryptid_node: Node  # Reference to the cryptid this manager belongs to

# Initialize the manager with a reference to the cryptid
func initialize(cryptid: Node) -> void:
	cryptid_node = cryptid
	name = "StatusEffectManager"

# Add or stack a status effect
func add_status_effect(effect_type: StatusEffect.EffectType, stacks: int = 1, custom_effect: StatusEffect = null) -> void:
	if effect_type in active_effects:
		# Effect already exists, add stacks
		active_effects[effect_type].add_stacks(stacks)
		print("Added", stacks, "stacks to", StatusEffect.EffectType.keys()[effect_type], 
			  "Total:", active_effects[effect_type].stack_count)
		
		# TRIGGER DISPLAY REFRESH HERE
		status_effect_added.emit(active_effects[effect_type])
	else:
		# Create new effect instance
		var new_effect: StatusEffect
		if custom_effect:
			new_effect = custom_effect.duplicate()
		else:
			new_effect = _create_default_effect(effect_type)
		
		new_effect.stack_count = stacks
		active_effects[effect_type] = new_effect
		print("Added new status effect:", StatusEffect.EffectType.keys()[effect_type], 
			  "with", stacks, "stacks")
		
		status_effect_added.emit(new_effect)

# Remove a status effect completely
func remove_status_effect(effect_type: StatusEffect.EffectType) -> void:
	if effect_type in active_effects:
		active_effects.erase(effect_type)
		status_effect_removed.emit(effect_type)
		print("Removed status effect:", StatusEffect.EffectType.keys()[effect_type])
		
		# Clean up visual effects based on effect type
		_cleanup_visual_effects(effect_type)

# Remove stacks from a status effect
func remove_stacks(effect_type: StatusEffect.EffectType, amount: int) -> void:
	if effect_type in active_effects:
		var should_remove = active_effects[effect_type].remove_stacks(amount)
		if should_remove:
			remove_status_effect(effect_type)
		else:
			print("Removed", amount, "stacks from", StatusEffect.EffectType.keys()[effect_type], 
				  "Remaining:", active_effects[effect_type].stack_count)

# Check if a status effect is active
func has_status_effect(effect_type: StatusEffect.EffectType) -> bool:
	return effect_type in active_effects

# Get a specific status effect
func get_status_effect(effect_type: StatusEffect.EffectType) -> StatusEffect:
	return active_effects.get(effect_type, null)

# Get all active effects
func get_all_effects() -> Array[StatusEffect]:
	var effects: Array[StatusEffect] = []
	for effect in active_effects.values():
		effects.append(effect)
	return effects

# Clear all status effects (for end of battle)
func clear_all_effects() -> void:
	active_effects.clear()
	print("Cleared all status effects")

# Create default status effects based on type
func _create_default_effect(effect_type: StatusEffect.EffectType) -> StatusEffect:
	var effect = StatusEffect.new()
	effect.effect_type = effect_type
	
	match effect_type:
		StatusEffect.EffectType.STUN:
			effect.effect_name = "Stun"
			effect.description = "Skip next turn"
			effect.max_stacks = 1  # Stun doesn't stack
			effect.trigger_time = StatusEffect.TriggerTime.TURN_START
			effect.prevents_actions = true
			
		StatusEffect.EffectType.VULNERABLE:
			effect.effect_name = "Vulnerable"
			effect.description = "Take additional damage"
			effect.trigger_time = StatusEffect.TriggerTime.ON_DAMAGE_TAKEN
			
		StatusEffect.EffectType.POISON:
			effect.effect_name = "Poison"
			effect.description = "Take damage at end of turn"
			effect.trigger_time = StatusEffect.TriggerTime.TURN_END
			
		StatusEffect.EffectType.SHIELDED:
			effect.effect_name = "Shielded"
			effect.description = "Block incoming damage"
			effect.trigger_time = StatusEffect.TriggerTime.ON_DAMAGE_TAKEN
			
		StatusEffect.EffectType.BURN:
			effect.effect_name = "Burn"
			effect.description = "Take damage at start of turn"
			effect.trigger_time = StatusEffect.TriggerTime.TURN_START
			
		StatusEffect.EffectType.DAZED:
			effect.effect_name = "Dazed"
			effect.description = "Move to end of turn order"
			effect.max_stacks = 1
			effect.trigger_time = StatusEffect.TriggerTime.TURN_START
			effect.modifies_turn_order = true
			
		StatusEffect.EffectType.PARALYZE:
			effect.effect_name = "Paralyze"
			effect.description = "Reduced movement"
			effect.trigger_time = StatusEffect.TriggerTime.ON_MOVE
			
		StatusEffect.EffectType.IMMOBILIZE:
			effect.effect_name = "Immobilize"
			effect.description = "Cannot move, expires at end of turn"
			effect.trigger_time = StatusEffect.TriggerTime.TURN_END
			effect.max_stacks = 1
	
	return effect


func process_turn_start_effects() -> void:
	print("Processing turn start effects for", cryptid_node.cryptid.name)
	
	for effect_type in active_effects:
		var effect = active_effects[effect_type]
		if effect.trigger_time == StatusEffect.TriggerTime.TURN_START:
			match effect_type:
				StatusEffect.EffectType.STUN:
					print("Cryptid is stunned - skipping turn")
					effect.consume()
					remove_status_effect(effect_type)
					status_effect_triggered.emit(effect)
					
				StatusEffect.EffectType.BURN:
					var damage = effect.stack_count * 2  # 2 damage per burn stack
					print("Burn damage:", damage)
					_apply_effect_damage(damage)
					remove_stacks(effect_type, 1)  # Remove 1 burn stack
					status_effect_triggered.emit(effect)
					
				StatusEffect.EffectType.DAZED:
					print("Cryptid is dazed - will move to end of turn order")
					effect.consume()
					remove_status_effect(effect_type)
					status_effect_triggered.emit(effect)

# Process effects that trigger at turn end
func process_turn_end_effects() -> void:
	print("Processing turn end effects for", cryptid_node.cryptid.name)
	
	for effect_type in active_effects:
		var effect = active_effects[effect_type]
		if effect.trigger_time == StatusEffect.TriggerTime.TURN_END:
			match effect_type:
				StatusEffect.EffectType.POISON:
					var damage = effect.stack_count  # 1 damage per poison stack
					print("Poison damage:", damage)
					_apply_effect_damage(damage)
					remove_stacks(effect_type, 1)  # Remove only 1 poison stack
					status_effect_triggered.emit(effect)
					
				StatusEffect.EffectType.IMMOBILIZE:
					print("Immobilize effect expires at end of turn")
					remove_status_effect(effect_type)  # Remove immobilize completely
					status_effect_triggered.emit(effect)

# Process effects when taking damage
func process_damage_taken_effects(incoming_damage: int) -> int:
	var modified_damage = incoming_damage
	
	for effect_type in active_effects:
		var effect = active_effects[effect_type]
		if effect.trigger_time == StatusEffect.TriggerTime.ON_DAMAGE_TAKEN:
			match effect_type:
				StatusEffect.EffectType.VULNERABLE:
					var extra_damage = effect.stack_count
					modified_damage += extra_damage
					print("Vulnerable - taking", extra_damage, "extra damage")
					remove_status_effect(effect_type)  # Remove all vulnerable
					status_effect_triggered.emit(effect)
					
				StatusEffect.EffectType.SHIELDED:
					var blocked = min(effect.stack_count, modified_damage)
					modified_damage -= blocked
					remove_stacks(effect_type, blocked)
					print("Shield blocked", blocked, "damage")
					status_effect_triggered.emit(effect)
	
	return modified_damage


func _apply_effect_damage(damage: int) -> void:
	if cryptid_node and damage > 0:
		# Get the tile map controller to use its damage application
		var tile_map = get_tree().get_nodes_in_group("map")[0]
		if tile_map and tile_map.has_method("apply_damage"):
			tile_map.apply_damage(cryptid_node, damage)
		else:
			# Fallback if we can't find the tile map
			var health_bar = cryptid_node.get_node("HealthBar")
			if health_bar:
				var new_health = max(0, health_bar.value - damage)
				health_bar.value = new_health
				cryptid_node.set_health_values(new_health, health_bar.max_value)
				cryptid_node.update_health_bar()
				print("Applied", damage, "damage from status effect")

# Check if the cryptid can take actions this turn
func can_take_actions() -> bool:
	if has_status_effect(StatusEffect.EffectType.STUN):
		return false
	return true

# Check if the cryptid can move this turn
func can_move() -> bool:
	if has_status_effect(StatusEffect.EffectType.IMMOBILIZE):
		return false
	return true

# Process the start of this cryptid's turn
func process_turn_start() -> void:
	print("\n=== Processing turn start for", cryptid_node.cryptid.name, "===")
	
	# Check for stun first
	if has_status_effect(StatusEffect.EffectType.STUN):
		print(cryptid_node.cryptid.name, "is STUNNED and cannot take actions this turn!")
	
	# Process all turn start effects
	process_turn_start_effects()
	
	# Update the status effect display
	if cryptid_node.has_node("StatusEffectDisplay"):
		var display = cryptid_node.get_node("StatusEffectDisplay")
		display.refresh_display()

# Process the end of this cryptid's turn
func process_turn_end() -> void:
	print("\n=== Processing turn end for", cryptid_node.cryptid.name, "===")
	
	# Process all turn end effects
	process_turn_end_effects()
	
	# Update the status effect display
	if cryptid_node.has_node("StatusEffectDisplay"):
		var display = cryptid_node.get_node("StatusEffectDisplay")
		display.refresh_display()

# Add this new function to clean up visual effects
func _cleanup_visual_effects(effect_type: StatusEffect.EffectType) -> void:
	# Get the tile map to access visual cleanup functions
	var tile_map = get_tree().get_nodes_in_group("map")[0] if get_tree().get_nodes_in_group("map").size() > 0 else null
	
	if not tile_map:
		print("WARNING: Could not find tile map for visual cleanup")
		return
	
	match effect_type:
		StatusEffect.EffectType.STUN:
			# Clean up stun visual effects
			if tile_map.has_method("clean_up_stun_effects"):
				tile_map.clean_up_stun_effects()
			# Also try to clean up any effects that might be children of the cryptid
			_cleanup_cryptid_visual_effects("stun_effect")
			
		StatusEffect.EffectType.POISON:
			_cleanup_cryptid_visual_effects("poison_effect")
			
		StatusEffect.EffectType.BURN:
			_cleanup_cryptid_visual_effects("burn_effect")
			
		StatusEffect.EffectType.IMMOBILIZE:
			_cleanup_cryptid_visual_effects("immobilize_effect")
			
		StatusEffect.EffectType.VULNERABLE:
			_cleanup_cryptid_visual_effects("vulnerable_effect")
			
		# Add other effect types as needed

# Helper to clean up effects that might be children of the cryptid node
func _cleanup_cryptid_visual_effects(effect_name: String) -> void:
	if cryptid_node:
		for child in cryptid_node.get_children():
			if child.name == effect_name:
				child.queue_free()
				print("Cleaned up", effect_name, "from cryptid")

# ========== STATUS EFFECT ACTION EXECUTION ==========

func execute_heal_action(source_cryptid, target_cryptid, heal_amount: int, visual_effects_manager):
	if not target_cryptid:
		print("No target for heal action")
		return
		
	# Heal the target using health bar system
	var health_bar = target_cryptid.get_node_or_null("HealthBar")
	if health_bar:
		var current_health = health_bar.value
		var max_health = health_bar.max_value
		var new_health = min(current_health + heal_amount, max_health)
		
		# Update health bar
		health_bar.value = new_health
		
		# Update cryptid's health values
		target_cryptid.set_health_values(new_health, max_health)
		target_cryptid.update_health_bar()
		
		# Store health metadata
		target_cryptid.cryptid.set_meta("current_health", new_health)
		
		var actual_heal = new_health - current_health
		
		# Show heal effect
		if visual_effects_manager:
			await visual_effects_manager.animate_heal(source_cryptid, target_cryptid)
			_show_heal_value_display(target_cryptid.position, actual_heal)
		
		print("Healed", target_cryptid.cryptid.name, "for", actual_heal)
		print("Health now: " + str(new_health) + "/" + str(max_health))
	else:
		print("ERROR: Could not find health bar on target cryptid!")

func execute_stun_action(source_cryptid, target_cryptid, stun_amount: int, visual_effects_manager):
	if not target_cryptid:
		print("No target for stun action")
		return
	
	# Apply stun
	var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
	if status_mgr:
		status_mgr.add_status_effect(StatusEffect.EffectType.STUN, stun_amount)
		print("Applied stun for", stun_amount, "turns to", target_cryptid.cryptid.name)
	
	# Show effect
	if visual_effects_manager:
		await visual_effects_manager.animate_stun(source_cryptid, target_cryptid)

func execute_poison_action(source_cryptid, target_cryptid, poison_amount: int, visual_effects_manager):
	if not target_cryptid:
		print("No target for poison action")
		return
	
	# Apply poison
	var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
	if status_mgr:
		status_mgr.add_status_effect(StatusEffect.EffectType.POISON, poison_amount)
		print("Applied poison for", poison_amount, "stacks to", target_cryptid.cryptid.name)
	
	# Show effect
	if visual_effects_manager:
		await visual_effects_manager.animate_poison(source_cryptid, target_cryptid)

func execute_immobilize_action(source_cryptid, target_cryptid, immobilize_amount: int, visual_effects_manager):
	if not target_cryptid:
		print("No target for immobilize action")
		return
	
	# Apply immobilize
	var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
	if status_mgr:
		status_mgr.add_status_effect(StatusEffect.EffectType.IMMOBILIZE, immobilize_amount)
		print("Applied immobilize for", immobilize_amount, "turns to", target_cryptid.cryptid.name)
	
	# Show effect
	if visual_effects_manager:
		await visual_effects_manager.animate_immobilize(source_cryptid, target_cryptid)

func execute_vulnerable_action(source_cryptid, target_cryptid, vulnerable_amount: int, visual_effects_manager):
	if not target_cryptid:
		print("No target for vulnerable action")
		return
	
	# Apply vulnerable
	var status_mgr = target_cryptid.get_node_or_null("StatusEffectManager")
	if status_mgr:
		status_mgr.add_status_effect(StatusEffect.EffectType.VULNERABLE, vulnerable_amount)
		print("Applied vulnerable for", vulnerable_amount, "stacks to", target_cryptid.cryptid.name)
	
	# Show effect
	if visual_effects_manager:
		await visual_effects_manager.animate_vulnerable(source_cryptid, target_cryptid)

# ========== VISUAL EFFECT CREATION ==========

func create_stun_effect(source_cryptid, target_cryptid, visual_effects_manager):
	# Create visual stun effect
	if visual_effects_manager and source_cryptid:
		visual_effects_manager.animate_stun(source_cryptid, target_cryptid)

func create_heal_effect(source_cryptid, target_cryptid, visual_effects_manager):
	# Create visual heal effect
	if visual_effects_manager and source_cryptid:
		visual_effects_manager.animate_heal(source_cryptid, target_cryptid)

func create_poison_effect(source_cryptid, target_cryptid, visual_effects_manager):
	# Create visual poison effect
	if visual_effects_manager and source_cryptid:
		visual_effects_manager.animate_poison(source_cryptid, target_cryptid)

func create_immobilize_effect(source_cryptid, target_cryptid, visual_effects_manager):
	# Create visual immobilize effect
	if visual_effects_manager and source_cryptid:
		visual_effects_manager.animate_immobilize(source_cryptid, target_cryptid)

func create_vulnerable_effect(source_cryptid, target_cryptid, visual_effects_manager):
	# Create visual vulnerable effect
	if visual_effects_manager and source_cryptid:
		visual_effects_manager.animate_vulnerable(source_cryptid, target_cryptid)

# ========== PREVIEW FUNCTIONS ==========

func show_heal_preview(target_cryptid, target_pos: Vector2i, tile_map_controller):
	# Show heal preview on target
	if target_cryptid and tile_map_controller:
		# Clear previous preview
		tile_map_controller.clear_heal_preview_hexes()
		
		# Store original tile state for restoration
		if not tile_map_controller.original_tile_states.has(target_pos):
			tile_map_controller.original_tile_states[target_pos] = tile_map_controller.get_cell_atlas_coords(target_pos)
		
		# Add to preview tracking and show with heal preview tile
		tile_map_controller.heal_preview_hexes.append(target_pos)
		tile_map_controller.set_cell(target_pos, 0, tile_map_controller.heal_preview_tile_id, 1)
		print("DEBUG: Added heal preview tile at", target_pos)

func show_stun_preview(target_cryptid, target_pos: Vector2i, tile_map_controller):
	# Show stun preview on target
	if target_cryptid and tile_map_controller:
		# Clear previous preview
		tile_map_controller.clear_stun_preview_hexes()
		
		# Store original tile state for restoration  
		if not tile_map_controller.original_tile_states.has(target_pos):
			tile_map_controller.original_tile_states[target_pos] = tile_map_controller.get_cell_atlas_coords(target_pos)
		
		# Add to preview tracking and show with stun preview tile
		tile_map_controller.stun_preview_hexes.append(target_pos)
		tile_map_controller.set_cell(target_pos, 0, tile_map_controller.stun_preview_tile_id, 1)
		print("DEBUG: Added stun preview tile at", target_pos)

func show_immobilize_preview(target_cryptid, target_pos: Vector2i, tile_map_controller):
	# Show immobilize preview on target
	if target_cryptid and tile_map_controller:
		# Clear previous preview
		tile_map_controller.clear_immobilize_preview_hexes()
		
		# Store original tile state for restoration  
		if not tile_map_controller.original_tile_states.has(target_pos):
			tile_map_controller.original_tile_states[target_pos] = tile_map_controller.get_cell_atlas_coords(target_pos)
		
		# Add to preview tracking and show with immobilize preview tile
		tile_map_controller.immobilize_preview_hexes.append(target_pos)
		tile_map_controller.set_cell(target_pos, 0, tile_map_controller.immobilize_preview_tile_id, 1)
		print("DEBUG: Added immobilize preview tile at", target_pos)

func show_vulnerable_preview(target_cryptid, target_pos: Vector2i, tile_map_controller):
	# Show vulnerable preview on target
	if target_cryptid and tile_map_controller:
		# Clear previous preview
		tile_map_controller.clear_vulnerable_preview_hexes()
		
		# Store original tile state for restoration  
		if not tile_map_controller.original_tile_states.has(target_pos):
			tile_map_controller.original_tile_states[target_pos] = tile_map_controller.get_cell_atlas_coords(target_pos)
		
		# Add to preview tracking and show with vulnerable preview tile
		tile_map_controller.vulnerable_preview_hexes.append(target_pos)
		tile_map_controller.set_cell(target_pos, 0, tile_map_controller.vulnerable_preview_tile_id, 1)
		print("DEBUG: Added vulnerable preview tile at", target_pos)

# ========== CLEANUP FUNCTIONS ==========

func clean_up_heal_effects(tile_map_controller):
	if tile_map_controller:
		tile_map_controller.clear_heal_preview_hexes()

func clean_up_stun_effects(tile_map_controller):
	if tile_map_controller:
		tile_map_controller.clear_stun_preview_hexes()
		
func clean_up_poison_effects(tile_map_controller):
	if tile_map_controller:
		tile_map_controller.clear_poison_preview_hexes()

func clean_up_immobilize_effects(tile_map_controller):
	if tile_map_controller:
		tile_map_controller.clear_immobilize_preview_hexes()

func clean_up_vulnerable_effects(tile_map_controller):
	if tile_map_controller:
		tile_map_controller.clear_vulnerable_preview_hexes()

func remove_stun_effect_from_cryptid(target_cryptid):
	# Remove visual stun effect from cryptid
	_cleanup_cryptid_visual_effects("stun_effect")

func clean_up_cryptid_status_visuals(target_cryptid):
	# Clean up all status effect visuals on a cryptid
	if target_cryptid:
		_cleanup_cryptid_visual_effects("stun_effect")
		_cleanup_cryptid_visual_effects("poison_effect")
		_cleanup_cryptid_visual_effects("burn_effect")
		_cleanup_cryptid_visual_effects("heal_effect")
		_cleanup_cryptid_visual_effects("immobilize_effect")
		_cleanup_cryptid_visual_effects("vulnerable_effect")

# ========== HELPER FUNCTIONS ==========

func _show_heal_value_display(position: Vector2, heal_amount: int):
	# Show floating heal number - this would need to be implemented
	# For now, just print the heal
	print("Heal value display: +", heal_amount, " at position ", position)
