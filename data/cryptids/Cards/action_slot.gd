extends HBoxContainer

@onready var texture_rect:TextureRect = %TextureRect
@onready var action_label:Label = $Action


func add_action(action:Action):
	action_label.text += enum_to_string(action.ActionType, action.action_types.front())
	action_label.text += " " + str(action.amount)
	if action.range > 0 and action.action_types.front() != 0:
		action_label.text += " Range: " + str(action.range)
	
func enum_to_string(enum_type: Dictionary, value: int) -> String:
	return enum_type.keys()[value]
