# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# Scene referenes needed for move state
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

# This will hold the array of world positions we need to walk through.
var move_path: PackedVector2Array = []

func enter() -> void:
	# Immediately tell the component to start following the path.
	grid_movement_component.move_along_path(move_path)
	
	# Listen for the component to tell us when the path is finished.
	grid_movement_component.path_finished.connect(_on_path_finished)
	# Play the move animation.
	player.get_node("AnimationComponent").play_animation("Move") # play Move anim
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	grid_movement_component.path_finished.disconnect(_on_path_finished)

# When the component signals it's done, we transition back to Idle.
func _on_path_finished() -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

# We keep the input logic to handle interrupting a move with a new one or a skill cast.
func process_input(event: InputEvent) -> void:
	# First, check if a skill was cast, which should interrupt the movement.
	if handle_skill_cast(event):
		# Clear the path so we don't resume moving after the cast.
		grid_movement_component.move_along_path([]) # Clear the path so we don't resume moving
		return
		
	# Handle being interrupted by a new move command
	if event.is_action_pressed("move_click"):
		var new_path = Grid.find_path(
			Grid.world_to_map(player.global_position),
			Grid.world_to_map(player.get_global_mouse_position())
		)
		if not new_path.is_empty():
			# Tell the component to start following the new path immediately.
			grid_movement_component.move_along_path(new_path)
			
# The physics process is now empty because the component handles it.
func process_physics(_delta: float) -> void:
	pass
