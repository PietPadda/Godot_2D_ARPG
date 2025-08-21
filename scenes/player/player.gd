# player.gd
# Handles player-specific logic, primarily input. Delegates tasks to components.
extends CharacterBody2D

# A reference to the MovementComponent node.
@onready var movement_component: MovementComponent = $MovementComponent

func _unhandled_input(event: InputEvent) -> void:
	# Check if the "move_click" action was just pressed.
	if event.is_action_pressed("move_click"):
		# Tell the MovementComponent where to go.
		movement_component.set_movement_target(get_global_mouse_position())
