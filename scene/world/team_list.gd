extends PanelContainer

@onready var team_p = $MarginContainer/VBoxContainer/teams/problem/team_p
@onready var team_s = $MarginContainer/VBoxContainer/teams/solvers/team_s
@onready var l_lobby = $MarginContainer/VBoxContainer/lobby/lobby

var curr_player_data_update_time := 0.0

func _ready():
	curr_player_data_update_time = Global.player_data_update_time

# {MultiplayerLobby.NAME:p_name, MultiplayerLobby.TEAM:p_team, MultiplayerLobby.COLOR:color_picker.get_pick_color(), MultiplayerLobby.IS_PLAYING:false, MultiplayerLobby.LATENCY:0.0}
#@rpc("authority","call_local","unreliable")
func set_peer_list( players_connected ):
	#await get_tree().process_frame
	l_lobby.text = 		""
	team_s.clear()#text = 		""
	team_p.clear()#text = 		""
	
	for peer : int in players_connected:
		if players_connected[peer][Network.TEAM] == Network.PROBLEM:
			team_p.push_color( players_connected[peer][Network.COLOR] )
			team_p.append_text( players_connected[peer][Network.NAME] )
			team_p.append_text( " - " + str(players_connected[peer][Network.LATENCY]) + "ms")
			team_p.pop()
			team_p.newline()
		elif players_connected[peer][Network.TEAM] == Network.SOLVERS:
			team_s.push_color( players_connected[peer][Network.COLOR] )
			team_s.append_text( players_connected[peer][Network.NAME] )
			team_s.append_text( " - " + str(players_connected[peer][Network.LATENCY]) + "ms")
			team_s.pop()
			team_s.newline()
			## PLayer in Network
		elif players_connected[peer][Network.TEAM] == Network.NONE:
			l_lobby.text += str(players_connected[peer][Network.NAME],"\n")
		else:
			# no team set
			breakpoint

func _process(delta):
	curr_player_data_update_time -= delta
	
	if curr_player_data_update_time <= 0.0:
		curr_player_data_update_time = Global.player_data_update_time
		set_peer_list( Network.players_connected )
		
