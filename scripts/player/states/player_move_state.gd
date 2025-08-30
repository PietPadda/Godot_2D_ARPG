# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# Scene referenes needed for move state
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

# This will hold the array of world positions we need to walk through.
var move_path: PackedVector2Array = []
# We'll add a new variable to track the final tile of our current path.
var final_destination_tile: Vector2i

func enter() -> void:
	# When we start moving, we need to know where our path ends.
	if not move_path.is_empty():
		var last_world_pos = move_path[move_path.size() - 1]
		final_destination_tile = Grid.world_to_map(last_world_pos)
	
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

# The input logic is now moved to the physics process for continuous checks.
func process_input(event: InputEvent) -> void:
	# First, check if a skill was cast, which should interrupt the movement.
	if handle_skill_cast(event):
		# Clear the path so we don't resume moving after the cast.
		grid_movement_component.move_along_path([]) # Clear the path so we don't resume moving
		return

# The physics process is now empty because the component handles it.
func process_physics(_delta: float) -> void:
	# If the move button is still held, find a new path to the mouse.
	if Input.is_action_pressed("move_click"):
		var current_mouse_tile = Grid.world_to_map(player.get_global_mouse_position())
		
		# ONLY recalculate the path if the mouse is pointing to a NEW tile.
		if current_mouse_tile != final_destination_tile:
			var start_pos = Grid.world_to_map(player.global_position)
			var new_path = Grid.find_path(start_pos, current_mouse_tile)
			
			# Only update if a valid path was found.
			if not new_path.is_empty():
				# Update the destination we are tracking.
				self.final_destination_tile = current_mouse_tile
				# Tell the component to start following the new path immediately.
				grid_movement_component.move_along_path(new_path)
