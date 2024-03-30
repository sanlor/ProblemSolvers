extends CanvasLayer

@onready var world = $".."

@onready var data_update_timer = $data_update_timer

@onready var single_player = $connection/single_player
@onready var host_server = $connection/host_server
@onready var join_dev_server = $connection/join_dev_server

@onready var custom_server_address : LineEdit = $connection/custom_server_address
@onready var join_custom_server = $connection/join_custom_server

@onready var disconnect_button = $connection/disconnect
@onready var server_warning = $connection/server_warning

@onready var server_status = $server_status

@onready var team_list 		= $team_list

@onready var team_p : RichTextLabel = $team_list/VBoxContainer/teams/problem/team_p
@onready var team_s : RichTextLabel = $team_list/VBoxContainer/teams/solvers/team_s
@onready var lobby : Label = $team_list/VBoxContainer/lobby/lobby


@onready var player_custom = $player_custom

func _ready():
	multiplayer.multiplayer_peer = null
	Global.player_is_in_game = false
	
	#peer_list.text = 	"ID\n\n"
	#is_playing.text = 	"Is Playing\n\n"
	#latency.text = 		"Latency\n\n"
	
func _on_single_player_pressed():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world.begin_game()
	#world.request_add_player( multiplayer.get_unique_id() )
	#world.toggle_menu()

func _on_host_server_pressed():
	var error = MultiplayerLobby.create_server()
	if error:
		print( "cant connect to server. ",error )
	
	server_warning.visible = true
	data_update_timer.start()
	world.begin_game()

func _on_join_dev_server_pressed():
	var error = MultiplayerLobby.join_server()
	if error:
		print( "cant connect to server. ",error )
	server_warning.visible = false
	data_update_timer.start()

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
			
	var error = MultiplayerLobby.join_server( add )
	if error:
		print( "cant connect to server. ",error )
	server_warning.visible = false
	data_update_timer.start()
	
func _on_disconnect_pressed():
	data_update_timer.stop()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	world.stop_game()

# {MultiplayerLobby.NAME:p_name, MultiplayerLobby.TEAM:p_team, MultiplayerLobby.COLOR:color_picker.get_pick_color(), MultiplayerLobby.IS_PLAYING:false, MultiplayerLobby.LATENCY:0.0}
@rpc("authority","call_local","unreliable")
func set_peer_list( players_connected ):
	#await get_tree().process_frame
	lobby.text = 		""
	team_s.clear()#text = 		""
	team_p.clear()#text = 		""
	
	for peer : int in players_connected:
		if players_connected[peer][MultiplayerLobby.TEAM] == MultiplayerLobby.PROBLEM:
			team_p.push_color( players_connected[peer][MultiplayerLobby.COLOR] )
			team_p.append_text( players_connected[peer][MultiplayerLobby.NAME] )
			team_p.append_text( " - " + str(players_connected[peer][MultiplayerLobby.LATENCY]) + "ms")
			team_p.pop()
			team_p.newline()
		elif players_connected[peer][MultiplayerLobby.TEAM] == MultiplayerLobby.SOLVERS:
			team_s.push_color( players_connected[peer][MultiplayerLobby.COLOR] )
			team_s.append_text( players_connected[peer][MultiplayerLobby.NAME] )
			team_s.append_text( " - " + str(players_connected[peer][MultiplayerLobby.LATENCY]) + "ms")
			team_s.pop()
			team_s.newline()
			## PLayer in lobby
		elif players_connected[peer][MultiplayerLobby.TEAM] == MultiplayerLobby.NONE:
			lobby.text += str(players_connected[peer][MultiplayerLobby.NAME],"\n")
		else:
			# no team set
			breakpoint
	
	
func _set_connected():
	player_custom.visible = true
	single_player.disabled = true
	host_server.disabled = true
	join_custom_server.disabled = true
	join_dev_server.disabled = true
	disconnect_button.disabled = false
	
func _set_disconnected():
	player_custom.visible = false
	single_player.disabled = false
	host_server.disabled = false
	join_custom_server.disabled = false
	join_dev_server.disabled = false
	disconnect_button.disabled = true
	
func _process(_delta):
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer != OfflineMultiplayerPeer:
			match multiplayer.multiplayer_peer.get_connection_status():
				MultiplayerPeer.CONNECTION_CONNECTED:
					_set_connected()
					server_status.text = "Connected!" + "\n" + MultiplayerLobby.connected_server_name
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
		host_server.disabled = false
		join_custom_server.disabled = false
		join_dev_server.disabled = false
		disconnect_button.disabled = true
		server_warning.visible = false
		server_status.text = "Disconnected."


func _on_data_update_timer_timeout():
	if multiplayer.multiplayer_peer != null:
		if multiplayer.is_server():
			set_peer_list.rpc( MultiplayerLobby.players_connected )

func _on_join_pressed():
	MultiplayerLobby.player_data = player_custom.get_player_data()
	MultiplayerLobby.update_player_data.rpc_id( 1, MultiplayerLobby.player_data, multiplayer.get_unique_id() )
	
	world.request_add_player( multiplayer.get_unique_id() )
	world.toggle_menu()
