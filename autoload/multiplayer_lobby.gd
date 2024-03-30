extends Node
## @tutorial https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#initializing-the-network
## IMPORTANT https://www.youtube.com/watch?v=d8QpnamQq1A

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 6969
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 8

const SERVER_NAME := "DEV_main_server"
var connected_server_name := ""

enum {ID}
enum {NAME,TEAM,COLOR,IS_PLAYING,LATENCY}
enum {NONE, PROBLEM, SOLVERS}

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players_connected = {} # players logged but not in the play area
#var players_in_game = []
## player data: ID:95563218,NAME:"XxXMiNaMExXx",TEAM:PROBLEM COLOR:Color.(fffffff),IS_PLAYING:false,LATENCY:0.0
var player_data := {}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)
	
	multiplayer.connected_to_server.connect( set_server_name )
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_server_only():
	#multiplayer.multiplayer_peer.close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
		
	print("server started")
	multiplayer.multiplayer_peer = peer
	multiplayer.multiplayer_peer.set_target_peer( MultiplayerPeer.TARGET_PEER_BROADCAST )

func create_server():
	start_server_only()
	# Register the server
	_on_player_connected( multiplayer.get_unique_id() )
	
func join_server(add := ""):
	var peer = ENetMultiplayerPeer.new()
	var server = DEFAULT_SERVER_IP
	if add != "":
		server = add
	var error = peer.create_client(server, PORT)
	if error:
		return error
		
	multiplayer.multiplayer_peer = peer
	multiplayer.multiplayer_peer.set_target_peer( MultiplayerPeer.TARGET_PEER_SERVER )
	
func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

@rpc("any_peer","call_remote")
func set_server_name():
	connected_server_name = SERVER_NAME

@rpc("any_peer")
func get_server_name() -> String:
	return SERVER_NAME

@rpc("any_peer", "reliable")
func _on_player_connected(id):
	#players_connected.append( id )
	if multiplayer.is_server():
		player_data = {NAME:"SERVER", TEAM:NONE, COLOR:Color.WHITE, IS_PLAYING:false, LATENCY:0.0}
	else:
		player_data = {NAME:str(id), TEAM:NONE, COLOR:Color.WHITE, IS_PLAYING:false, LATENCY:0.0}
	players_connected[id] = player_data
	set_server_name()
	print("player connected ",id)

@rpc("authority", "reliable")
func update_latency():
	print("Latency update")
	for id : int in multiplayer.get_peers():
		if MultiplayerLobby.players_connected.has(id):
			var peer : ENetPacketPeer = multiplayer.multiplayer_peer.get_peer( id )
			MultiplayerLobby.players_connected[id][MultiplayerLobby.LATENCY] = peer.get_statistic( ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME )
		else:
			push_warning("player ID mismatch")
	pass

func _on_player_disconnected(id):
	players_connected.erase(id)
	#players_in_game.erase(id)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	print("Cant connect to server.")

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players_connected.clear()
	#players_in_game.clear()

@rpc("any_peer","call_local")
func update_player_data (data : Dictionary, id : int):
	players_connected[ id ] = data
	_update_player_data.rpc( players_connected )
	
@rpc("authority","call_remote")
func _update_player_data ( data : Dictionary ):
	players_connected = data
	print(data)
