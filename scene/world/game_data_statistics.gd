extends PanelContainer

@onready var user_list : Label = $margin/VBoxContainer/data/users/user_list
@onready var nodes_list : Label = $margin/VBoxContainer/data/nodes/nodes_list

var world_node : Node2D
var playground_node : Node2D
var update_data := false
func _ready():
	world_node 			= Global.world_node
	playground_node		= Global.playground_node

func _input(event):
	if event is InputEvent:
		if event.is_action_pressed("game_data"):
			visible = not visible

func _on_visibility_changed():
	if visible == true and is_node_ready():
		update_data = true
	else:
		update_data = false
				
func _physics_process(_delta):
	if update_data:
		user_list.text = ""
		nodes_list.text = ""
		
		for node in playground_node.get_children():
			if node is Player:
				nodes_list.text += str(node,"\n")
				user_list.text += str(node.get_multiplayer_authority(),"\n")

		
		
