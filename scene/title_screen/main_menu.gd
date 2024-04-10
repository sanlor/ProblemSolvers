extends CanvasLayer

@onready var world = $".."

@onready var single_player = $connection/single_player
@onready var host_server = $connection/host_server
@onready var join_dev_server = $connection/join_dev_server

@onready var custom_server_address : LineEdit = $connection/custom_server_address
@onready var join_custom_server = $connection/join_custom_server

@onready var disconnect_button = $connection/disconnect
@onready var server_warning = $connection/server_warning

@onready var server_status = $server_status

@onready var spawn_screen = $"../spawn_screen"

var curr_network_state

func _ready():
	visible = true
	multiplayer.multiplayer_peer = null
	Global.player_is_in_game = false
	
	_set_disconnected()
	
	if OS.has_feature("web"): # HTML5 doesnt support multiplayer
		host_server.disabled = true
		join_custom_server.disabled = true
		join_dev_server.disabled = true
		server_warning.visible = true
		server_warning.text = "Multiplayer functionality is disabled for the HTML5 build."
		
	Global.game_state_changed.connect( _change_visibility )
	Global.show_connection_screen.connect( func(): visible = not visible ) # toggle visibility
	
	#curr_network_state = multiplayer.multiplayer_peer.get_connection_status()

func _change_visibility(state : Global.GAME_STATE):
	if state == Global.GAME_STATE.CONNECTION:
		visible = true
	else:
		visible = false

func _on_single_player_pressed():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Global.begin_game.emit()
	#world.begin_game()
	#world.request_add_player( multiplayer.get_unique_id() )
	#world.toggle_menu()

func _on_host_server_pressed():
	var error = Network.create_server()
	if error:
		print( "cant connect to server. ",error )
	
	server_warning.visible = true
	Global.begin_game.emit()
	#world.begin_game()

func _on_join_dev_server_pressed():
	var error = Network.join_server()
	if error:
		push_warning( "cant connect to server. ",error )
	else:
		server_warning.visible = false
		await get_tree().process_frame
		Global.begin_game.emit()

func _on_join_custom_server_pressed():
	var add : String = custom_server_address.placeholder_text
	if not custom_server_address.text.is_empty():
		if custom_server_address.text.is_valid_ip_address():
			add = custom_server_address.text
			
		elif custom_server_address.text.is_valid_filename():
			## Do some adition checking for invalid URL, REGEX STUFF!
			add = custom_server_address.text
		else:
			print("Invalid Address")
			
			custom_server_address.text = ""
	
	print("Trying to connect to ",add)
	var error = Network.join_server( add )
	if error:
		push_warning( "cant connect to server. ",error )
	else:
		server_warning.visible = false
		await get_tree().process_frame
		Global.begin_game.emit()
	
func _on_disconnect_pressed():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	world.stop_game()
	get_tree().reload_current_scene()

func _set_connected():
	single_player.disabled = true
	if not OS.has_feature("web"):
		host_server.disabled = true
		join_custom_server.disabled = true
		join_dev_server.disabled = true
	disconnect_button.disabled = false
	Global.curr_GAME_STATE = Global.GAME_STATE.SPAWN
	
func _set_disconnected():
	single_player.disabled = false
	if not OS.has_feature("web"):
		host_server.disabled = false
		join_custom_server.disabled = false
		join_dev_server.disabled = false
	disconnect_button.disabled = true
	Global.curr_GAME_STATE = Global.GAME_STATE.CONNECTION
	
func _process(_delta):
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer != OfflineMultiplayerPeer:
			var state = multiplayer.multiplayer_peer.get_connection_status()
			if state != curr_network_state:
				curr_network_state = state
				
				match state:
					MultiplayerPeer.CONNECTION_CONNECTED:
						_set_connected()
						server_status.text = "Connected!" + "\n" + Network.connected_server_name
					MultiplayerPeer.CONNECTION_CONNECTING:
						_set_connected()
						server_status.text = "Connecting..."
					MultiplayerPeer.CONNECTION_DISCONNECTED:
						_set_disconnected()
						server_status.text = "Disconnected."
		else:
			server_status.text = "Single Player."
	else:
		single_player.disabled = false
		if not OS.has_feature("web"):
			host_server.disabled = false
			join_custom_server.disabled = false
			join_dev_server.disabled = false
			server_warning.visible = false
		disconnect_button.disabled = true
		server_status.text = "Disconnected."
