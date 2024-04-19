extends Button
# https://gamedevartisan.com/tutorials/godot-fundamentals/input-remapping
class_name RemapButton

@export var action: String

func _init():
	toggle_mode = true
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	theme_type_variation = "RemapButton"


func _ready():
	set_process_input(false)
	update_key_text()
	Global.update_inputs.connect( update_key_text )


func _toggled(_button_pressed):
	set_process_input(_button_pressed)
	if _button_pressed:
		text = "..."
		disabled = true
		release_focus()
	else:
		update_key_text()
		disabled = false
		#grab_focus()


func _input(event):
	if event is InputEventKey or event is InputEventMouseButton:
		#print(event)
		if event.pressed:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
			button_pressed = false


func update_key_text():
	var event := InputMap.action_get_events(action)
	if event.is_empty():
		text = "???"
	else:
		text = str( event.front().as_text().rstrip(" (Physical)") )

