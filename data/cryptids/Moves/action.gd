class_name Action
extends Resource

@export_category("Action Settings")
@export var action_types: Array[ActionType] = []
@export var range: int
@export var amount: int
@export var area_of_effect: Array[Vector2i] = [Vector2i(0,0)]
@export var disabled = false


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
