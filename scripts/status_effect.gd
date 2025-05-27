# Updated StatusEffect resource with icon support
class_name StatusEffect
extends Resource

enum EffectType {
	STUN,
	VULNERABLE,
	SHIELDED,
	POISON,
	PARALYZE,
	IMMOBILIZE,
	BURN,
	DAZED
}

enum TriggerTime {
	TURN_START,
	TURN_END,
	ON_DAMAGE_TAKEN,
	ON_DAMAGE_DEALT,
	ON_MOVE,
	MANUAL
}

@export var effect_type: EffectType
@export var stack_count: int = 1
@export var max_stacks: int = 99  # Set to 1 for non-stackable effects like stun
@export var icon: Texture2D  # This is already here, we'll use it
@export var effect_name: String
@export var description: String
@export var trigger_time: TriggerTime = TriggerTime.MANUAL
@export var prevents_actions: bool = false  # For stun
@export var modifies_turn_order: bool = false  # For dazed

# Function to add stacks
func add_stacks(amount: int) -> void:
	stack_count = min(stack_count + amount, max_stacks)

# Function to remove stacks
func remove_stacks(amount: int) -> bool:
	stack_count -= amount
	return stack_count <= 0  # Returns true if effect should be removed

# Function to consume all stacks (for effects like stun)
func consume() -> void:
	stack_count = 0
