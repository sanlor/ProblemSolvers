extends Node
## @tutorial https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#initializing-the-network
## IMPORTANT https://www.youtube.com/watch?v=d8QpnamQq1A
## https://github.com/finepointcgi/WebRTC-with-Godot-Tutorial/blob/Finished-Product/Server.gd

signal got_server_player_data

const PORT := 6969
#const DEFAULT_SERVER_IP 		:= "127.0.0.1" # IPv4 localhost
const DEFAULT_SERVER_IP 		:= "ws://127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS 			:= 8
const SERVER_NAME 				:= "DEV_main_server"

var custom_dev_server 			:= DEFAULT_SERVER_IP
var custom_port 				:= PORT
var custom_max_connections 		:= MAX_CONNECTIONS
var custom_server_name 			:= SERVER_NAME

var connected_server_name := ""


enum {NAME,TEAM,COLOR,IS_PLAYING,LATENCY}
enum {NONE, PROBLEM, SOLVERS}

## Websocket
enum MESSAGE{PING,PONG}

# Update timer
var curr_player_data_update_time := 0.0


# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players_connected = {} # players logged but not in the play area
#var players_in_game = []
## player data: ID:95563218,NAME:"XxXMiNaMExXx",TEAM:PROBLEM COLOR:Color.(fffffff),IS_PLAYING:false,LATENCY:0.0
var player_data := {NAME:"UNDEFINED", TEAM:NONE, COLOR:Color.WHITE, IS_PLAYING:false, LATENCY:0.0}
var peer_list := {}

func _ready():
	curr_player_data_update_time = Global.player_data_update_time
	
	## Every peer get this signal when a player connect or disconnect from the server
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	multiplayer.connection_failed.connect(_on_connected_fail)
	
	multiplayer.connected_to_server.connect( _connected_to_server )
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_check_arguments()

func _on_player_connected(id):
	# Update "players_connected" with the default player data
	players_connected[id] = player_data
	if id != 1:
		peer_list[id] = multiplayer.multiplayer_peer.get_peer( id )
	print("Player ",id," joined the server")
	
func _on_player_disconnected(id):
	players_connected.erase(id)
	peer_list.erase(id)
	
## peer only
func _connected_to_server():
	set_server_name.rpc_id(1)
		
## peer only
func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	print("Disconnected from server ",custom_dev_server)
	
func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	print("Cant connect to server ",custom_dev_server)
	
func _check_arguments():
	
	for argument in OS.get_cmdline_args():
		# Parse valid command-line arguments into a dictionary
		if argument.find("=") > -1:
			Global.server_only = true
			var key_value = argument.split("=")
			if key_value[0].lstrip("--") == "PORT" or key_value[0].lstrip("--") == "port":
				custom_port = int(key_value[1])
				print("Port set to ",custom_port)
			elif key_value[0].lstrip("--") == "MAX" or key_value[0].lstrip("--") == "max":
				custom_max_connections = int(key_value[1])
				print("Max connections set to ",custom_max_connections)
			elif key_value[0].lstrip("--") == "NAME" or key_value[0].lstrip("--") == "name":
				custom_server_name = str(key_value[1])
				print("Server name set to ",custom_server_name )
			else:
				print("invalid argument: ", key_value[0])
				print("-PORT=6969:  Set server port to 6969")
				print("-MAX=8: set the max ammount of players to 8")
				print("-NAME=my_server: set the server name to 'my_server'.")
				get_tree().quit()
				
	if Global.server_only:
		await get_tree().process_frame
		print(Time.get_datetime_string_from_system(),": starting server ",custom_server_name," with port ", custom_port, " and ", custom_max_connections, " max clients.")
		start_server_only()
		Global.begin_game.emit()

func start_server_only():
	#multiplayer.multiplayer_peer.close()
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(custom_port)
	if error:
		return error
		
	print("server started")
	multiplayer.multiplayer_peer = peer
	#multiplayer.multiplayer_peer.outbound_buffer_size = 1000000
	#multiplayer.multiplayer_peer.inbound_buffer_size = 1000000
	
	multiplayer.multiplayer_peer.set_target_peer( MultiplayerPeer.TARGET_PEER_BROADCAST ) ## DEPRECATED since Websocket implementation
	print("Begining game... NOW ")

func create_server():
	start_server_only()
	# Register the server
	_on_player_connected( multiplayer.get_unique_id() )
	
func join_server(add := ""):
	var peer := WebSocketMultiplayerPeer.new()
	var server = custom_dev_server
	var port = custom_port ## TODO 
	if add != "":
		server = add
		
	var error := peer.create_client( server + ":" + str(port) )
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer
	multiplayer.multiplayer_peer.set_target_peer( MultiplayerPeer.TARGET_PEER_SERVER ) ## DEPRECATED since Websocket implementation
	
func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

@rpc("any_peer","call_local")
func set_server_name():
	_set_server_name.rpc_id( multiplayer.get_remote_sender_id(), custom_server_name )

@rpc("authority","call_remote")
func _set_server_name( n : String):
	connected_server_name = n

@rpc("any_peer")
func get_server_name() -> String:
	return custom_server_name

@rpc("any_peer","call_local")
func update_player_data ( data : Dictionary ):
	players_connected[ multiplayer.get_remote_sender_id() ] = data
	_update_player_data.rpc( players_connected )
	
@rpc("authority","call_remote")
func _update_player_data ( serverside_players_connected : Dictionary = players_connected ):
	players_connected = serverside_players_connected
	emit_signal("got_server_player_data") # let nodes know that the player data was updated
	
# This functions only works on the server and it pushes to the clients.
func _process(_delta):
	if multiplayer.multiplayer_peer != null:
		if multiplayer.is_server():
			await get_tree().create_timer( Global.player_data_update_time ).timeout
			_latency_check() ## FIXME
			_update_player_data.rpc( players_connected ) # push update to clients

# only the server should run this func
func _latency_check():
	_ping.rpc( Time.get_ticks_msec() )

# broadcast the timestamp to all connected clients
@rpc("authority")
func _ping( timestamp : float ):
	_pong.rpc_id(1, timestamp)

# client respond the same timestamp. now we can calculate the timestamp
@rpc("any_peer")
func _pong( timestamp : float ):
	players_connected[ multiplayer.get_remote_sender_id() ][LATENCY] = Time.get_ticks_msec() - timestamp
	
