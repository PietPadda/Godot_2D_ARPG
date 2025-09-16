# ai_movement_component.gd
class_name AIMovementComponent
extends Node

# Note: This component does not need a stopping_distance,
# as that is handled by the AI's ChaseState.

# scene node
@onready var character_body: CharacterBody2D = get_parent()
@onready var stats_component: StatsComponent = get_parent().get_node("StatsComponent")
@onready var navigation_agent: NavigationAgent2D = get_parent().get_node("NavigationAgent2D")

# We'll use this to track the character's current position on the grid.
var _current_tile: Vector2i

func _physics_process(delta: float) -> void:
	# stop ai if reached target in mesh
	if navigation_agent.is_navigation_finished():
		character_body.velocity = Vector2.ZERO
		return

	# get next mesh target
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = character_body.global_position.direction_to(next_path_position)
	character_body.velocity = direction * stats_component.stats_data.move_speed

	character_body.move_and_slide()

func set_movement_target(new_target: Vector2) -> void:
	navigation_agent.target_position = new_target
