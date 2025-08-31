# player_movement_component.gd
# A component that moves its parent CharacterBody2D towards a target position.
class_name PlayerMovementComponent
extends Node

# Export vars
@export var stopping_distance: float = 6.0

# The target position for the character to move towards.
var target_position: Vector2

# Public function that allows other nodes to set a new movement target.
func set_movement_target(new_target: Vector2) -> void:
	target_position = new_target
