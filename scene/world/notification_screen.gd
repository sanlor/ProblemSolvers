extends CanvasLayer

func _unhandled_input(event):
	if event is InputEventAction:
		if event.get_action() == "player_list":
			visible = event.is_pressed()
