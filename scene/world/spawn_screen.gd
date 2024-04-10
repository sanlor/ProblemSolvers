extends CanvasLayer

@export var verbose_logs := false

@onready var problem_team = $player_spawn/HBoxContainer/problem_team
@onready var solver_team = $player_spawn/HBoxContainer/solver_team

@onready var join_button = $player_spawn/join_button

@onready var spawn_timer = $spawn_timer

@onready var player_custom_panel = $player_custom

func _ready():
	Global.game_state_changed.connect( _change_visibility )
	Global.show_spawn_screen.connect( can_player_spawn )
	
	

func _change_visibility(state : Global.GAME_STATE):
	if state == Global.GAME_STATE.SPAWN:
		visible = true
		can_player_spawn()
	else:
		visible = false

func can_player_spawn():
	# select random team
	var team = [problem_team, solver_team].pick_random()
	team.button_pressed = true
	team.pressed.emit()
	
	if not spawn_timer.is_stopped():
		spawn_timer.stop()
		
	spawn_timer.start( Global.game_time_to_spawn )
	join_button.disabled = true
	set_process(true)
	_force_update()

func _on_problem_team_pressed():
	Network.player_data[Network.TEAM] = Network.PROBLEM
	if verbose_logs:
		print("team changed to Problem")
	_force_update()

func _on_solver_team_pressed():
	Network.player_data[Network.TEAM] = Network.SOLVERS
	if verbose_logs:
		print("team changed to Solvers")
	_force_update()

# Player is connected to the server and wants to joing the game
func _on_join_pressed():
	Network.update_player_data.rpc_id(1, Network.player_data )
	Global.player_entered_world.emit( multiplayer.get_unique_id() )
	
	Global.curr_GAME_STATE = Global.GAME_STATE.IN_GAME

func _force_update():
	if multiplayer.multiplayer_peer != null:
		Network.update_player_data.rpc_id(1, Network.player_data ) ## Force on-the-fly update
		if verbose_logs:
			print("player_data updated")

func _process(_delta):
	join_button.text = "Can spawn in " + str( spawn_timer.time_left ).pad_decimals(1) + "s"

func _on_spawn_timer_timeout():
	join_button.disabled = false
	join_button.text = "Ready!"
	_force_update()
	set_process(false)
