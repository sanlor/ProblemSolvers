extends CanvasLayer

@onready var game_notification = $game_notification

func _ready():
	Global.notification_level_generating.connect		( func(): _display_message("Generating level") )
	Global.notification_level_loading.connect			( func(): _display_message("Loading level") )
	Global.notification_level_loaded.connect			( func(): _display_message("") )

	Global.notification_receiving_server_data.connect	( func(): _display_message("Receiving Data") )
	Global.notification_received_server_data.connect	( func(): _display_message("") )
	_display_message("")
	
func _display_message(message : String):
	game_notification.set_text(message)
