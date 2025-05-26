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
			effect.description = "Cannot move"
			effect.trigger_time = StatusEffect.TriggerTime.ON_MOVE
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
