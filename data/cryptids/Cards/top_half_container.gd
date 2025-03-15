extends VBoxContainer


@export var highlighted = false
@onready var top_half_container = %TopHalfContainer
@onready var bottom_half_container = %BottomHalfContainer
@onready var hand = $"../../.."
@onready var card_dialog = $"../.."
@onready var disabled = false


## Signal handler for input events
func _on_HBoxContainer_input_event(event):
	if hand.has_method("highlight_card"):
		if event is InputEventMouseButton and event.pressed:
			hand.call("highlight_card", card_dialog)

func highlight():
	if disabled != false:
		update_style(true)

func unhighlight():
	if disabled != false:
		update_style(false)

func disable_top_half():
	top_half_container.modulate = Color(0.5, 0.5, 0.5) # Grey out the top half
	top_half_container.mouse_filter = Control.MOUSE_FILTER_IGNORE # Prevent interactions
	disabled = true

func enable_top_half():
	top_half_container.modulate = Color(1, 1, 1) # Restore default color
	top_half_container.mouse_filter = Control.MOUSE_FILTER_STOP # Allow interactions
	disabled = false

func update_style(is_highlighted: bool):
	if is_highlighted:
		modulate = Color(1, 1, 0) # Yellow color for highlight
	else:
		modulate = Color(1, 1, 1) # Default color (white)

