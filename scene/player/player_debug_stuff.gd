extends Node2D
@onready var player_node := get_parent()
@onready var player_debug = $player_DEBUG
@onready var debug_force = $debug_FORCE
@onready var debug_iframe = $debug_IFRAME

@export var enable_debug_state := false
@export var enable_debug_force := false
@export var enable_debug_iframe := false

func _physics_process(_delta):
	if enable_debug_state:
		player_debug.text = str(player_node.STATE.keys()[player_node.curr_state])
		
	if enable_debug_force:
		debug_force.points[1] = player_node.velocity / 2
		
	if debug_iframe:
		debug_iframe.text = str(player_node.curr_i_frame)
