class_name Action
extends Resource

@export_category("Action Settings")
@export var action_types: Array[ActionType] = []
@export var range: int
@export var amount: int
@export var area_of_effect: Array[Vector2i] = [Vector2i(0,0)]

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


# Function to perform the action
func perform_action(source, targets):
	for action_type in action_types:
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
func move_action(source, targets):
	# Implement move logic
	pass

func attack_action(source, targets):
	# Implement attack logic
	pass

func push_action(source, targets):
	# Implement push logic
	pass

func pull_action(source, targets):
	# Implement pull logic
	pass

func ranged_attack_action(source, targets):
	# Implement ranged attack logic
	pass

func heal_action(source, targets):
	# Implement heal logic
	pass

func stun_action(source, targets):
	# Implement stun logic
	pass

func apply_vulnerable_action(source, targets):
	# Implement apply vulnerable logic
	pass

func poison_action(source, targets):
	# Implement poison logic
	pass

func paralyze_action(source, targets):
	# Implement paralyze logic
	pass

func immobilize_action(source, targets):
	# Implement immobilize logic
	pass
