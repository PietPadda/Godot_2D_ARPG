# player_idle_state.gd
# The state for when the player is standing still.
class_name PlayerIdleState
extends State

# References to the player's nodes we need to interact with.
@onready var player: CharacterBody2D = get_owner()
@onready var movement_component: MovementComponent = player.get_node("MovementComponent")


func process_input(event: InputEvent) -> void:
	# When the move action is pressed, we want to start moving.
	if event.is_action_pressed("move_click"):
		# We tell the MovementComponent where to go...
		var target_position = player.get_global_mouse_position()
		movement_component.set_movement_target(target_position)
		
		# ...and then we tell the state machine to switch to the "Move" state.
		state_machine.change_state("Move")
