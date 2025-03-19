extends VBoxContainer


@export var highlighted = false
@onready var top_half_container = %TopHalfContainer
@onready var bottom_half_container = %BottomHalfContainer
@onready var hand = $"../../.."
@onready var card_dialog = $"../.."
@onready var disabled = false


### Signal handler for input events
#func _on_HBoxContainer_input_event(event):
	#if hand.has_method("highlight_card"):
		#if event is InputEventMouseButton and event.pressed:
			#hand.call("highlight_card", card_dialog)

func update_style(is_highlighted: bool):
	if is_highlighted:
		modulate = Color(1, 1, 0) # Yellow color for highlight
	else:
		modulate = Color(1, 1, 1) # Default color (white)
