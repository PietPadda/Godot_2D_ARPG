# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# This state now receives a single destination tile, not a pre-calculated path.
var destination_tile: Vector2i

func enter() -> void:
	print("[%s] PlayerMoveState: Successfully entered state." % player.name)
	player.get_node("AnimationComponent").play_animation("Move")
	# When we enter, start listening for the component to finish a step.
	grid_movement_component.path_finished.connect(_on_path_finished)
	# NEW: Listen for the stuck signal
	grid_movement_component.path_stuck.connect(_on_path_stuck)
	
	# Connect to input component signals to allow interruption
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)
	
	# Calculate and start the initial path
	var start_pos = Grid.world_to_map(player.global_position)
	var path  = Grid.find_path(start_pos, destination_tile)

	if not path.is_empty():
		grid_movement_component.move_along_path(path)
	else:
		# If for some reason no path is found, just go back to idle.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	if grid_movement_component.path_finished.is_connected(_on_path_finished):
		grid_movement_component.path_finished.disconnect(_on_path_finished)
	# Disconnect from the stuck signal
	if grid_movement_component.path_stuck.is_connected(_on_path_stuck):
		grid_movement_component.path_stuck.disconnect(_on_path_stuck)
	
	# Disconnect input signals
	input_component.move_to_requested.disconnect(_on_move_to_requested)
	input_component.target_requested.disconnect(_on_target_requested)
	input_component.cast_requested.disconnect(_on_cast_requested)

# ---Signal Handlers---
func _on_path_finished() -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

#  This function handles getting stuck during a normal move.
func _on_path_stuck() -> void:
	# Our path is blocked. Let's try to find a new one to the same destination.
	var start_pos = Grid.world_to_map(player.global_position)
	var new_path = Grid.find_path(start_pos, destination_tile)
	if not new_path.is_empty():
		grid_movement_component.move_along_path(new_path)
	else:
		# If no new path can be found, give up and go idle.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

func _on_move_to_requested(target_position: Vector2) -> void:
	var new_tile = Grid.world_to_map(target_position)
	
	# ONLY recalculate path if the mouse is on a new tile. This is an important optimization.
	if new_tile != destination_tile:
		destination_tile = new_tile
		var start_pos = Grid.world_to_map(player.global_position)
		var new_path = Grid.find_path(start_pos, destination_tile)
		
		if not new_path.is_empty():
			grid_movement_component.move_along_path(new_path)

func _on_target_requested(target: Node2D) -> void:
	grid_movement_component.stop()
	var chase_state: PlayerChaseState = state_machine.get_state(States.PLAYER.CHASE)
	chase_state.target = target
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE])
