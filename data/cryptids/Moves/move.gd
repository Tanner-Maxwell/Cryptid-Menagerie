class_name Move
extends Resource

@export var actions:Array[Action]
@export var name_prefix:String
@export var name_suffix:String
@export var card_side: CARD_SIDE
@export var elemental_type: Array[ELEMENTAL_TYPE]

enum CARD_SIDE {
	TOP,
	BOTTOM
}

enum ELEMENTAL_TYPE {
	NEUTRAL,
	FIRE,
	WATER,
	GROVE,
	ELECTRIC,
	AETHER,
	ICE,
	GLOOM,
	GLIMMER,
	OOZE,
	ROCK,
	SPECTRE,
	AIR
}

func add_action(action:Action):
	actions.append(action.duplicate())

func remove_action(action:Action):
	actions.erase(action)

func get_actions() -> Array[Action]:
	return actions
