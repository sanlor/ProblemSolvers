extends CanvasLayer

@onready var about = $settings/about/right_panel/About
@onready var controls = $settings/about/right_panel/Controls
@onready var visual = $settings/about/right_panel/Visual


func _on_control_toggled(toggled_on):
	controls.visible = toggled_on

func _on_visual_toggled(toggled_on):
	visual.visible = toggled_on

func _on_about_toggled(toggled_on):
	about.visible = toggled_on

func _on_close_pressed():
	visible = not visible # toggle visibility


func _on_restore_pressed():
	Global.load_settings(true)

func _on_save_pressed():
	Global.save_settings()
