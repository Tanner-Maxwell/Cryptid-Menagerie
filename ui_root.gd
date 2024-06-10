extends CanvasLayer

@onready var player:Player = %Player
@onready var team_dialog:TeamDialog = %TeamDialog

func _unhandled_input(event):
	if event.is_action_released("TeamDialog"):
		team_dialog.open(player.cryptidTeam)
