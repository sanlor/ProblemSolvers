extends Sprite2D

@onready var problem_team = $"../HBoxContainer/problem_team"
@onready var solver_team = $"../HBoxContainer/solver_team"

var lerp_speed := 0.5
var target := Vector2.ZERO

func _on_problem_team_pressed():
	target = problem_team.global_position

func _on_solver_team_pressed():
	target = solver_team.global_position
	
func _process(delta):
	if not position.is_equal_approx(target):
		position = position.lerp(target, lerp_speed)
