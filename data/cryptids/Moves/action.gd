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
	IMMOBILIZE,
	BURN,
	SHIELD,
	# Pickup spawning actions
	SPAWN_FIRE_TRAP,
	SPAWN_HEAL_ORB,
	SPAWN_IMMOBILIZE_TRAP,
	SPAWN_DAMAGE_TRAP,
	SPAWN_MOVEMENT_BOOST,
	SPAWN_SHIELD_ORB,
	SPAWN_POISON_CLOUD,
	SPAWN_WALL,
	SPAWN_STUN_TRAP
}
