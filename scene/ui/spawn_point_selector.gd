extends TextureButton

@onready var target = $target

var rotation_speed := 100.0

func _process(delta):
	target.rotation = rotation_speed * delta
	
	if button_pressed:
		position = get_global_mouse_position()

func _on_visibility_changed():
	#set_process( visible )
	pass
