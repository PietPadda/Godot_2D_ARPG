# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# This state now receives a single destination tile, not a pre-calculated path.
var destination_tile: Vector2i

func enter() -> void:
	player.get_node("AnimationComponent").play_animation("Move")
	# When we enter, start listening for the component to finish a step.
	grid_movement_component.path_finished.connect(_on_path_finished)
	# THIS IS THE KEY: We now listen for waypoints to recalculate our path.
	grid_movement_component.waypoint_reached.connect(_recalculate_path)
	
	# Connect to input component signals to allow interruption
	input_component.move_to_requested.connect(_on_move_to_requested)
	input_component.target_requested.connect(_on_target_requested)
	input_component.cast_requested.connect(_on_cast_requested)
	
	_recalculate_path() # Calculate and start the initial path.
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	if grid_movement_component.path_finished.is_connected(_on_path_finished):
		grid_movement_component.path_finished.disconnect(_on_path_finished)
	if grid_movement_component.waypoint_reached.is_connected(_recalculate_path):
		grid_movement_component.waypoint_reached.disconnect(_recalculate_path)
	
	# Disconnect input signals
	input_component.move_to_requested.disconnect(_on_move_to_requested)
	input_component.target_requested.disconnect(_on_target_requested)
	input_component.cast_requested.disconnect(_on_cast_requested)
	
func _physics_process(delta: float) -> void:
	pass
	
# We've moved the pathfinding logic into its own function for reuse.
func _recalculate_path() -> void:
	var start_pos = Grid.world_to_map(player.global_position)
	# THE FIX: We no longer call find_path directly.
	# We call our new high-level request function.
	Grid.request_path(start_pos, destination_tile, player)

# ---Signal Handlers---
func _on_path_finished() -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

func _on_move_to_requested(target_position: Vector2) -> void:
	var new_tile = Grid.world_to_map(target_position)
	
	# ONLY recalculate path if the mouse is on a new tile. This is an important optimization.
	if new_tile != destination_tile:
		destination_tile = new_tile
		var start_pos = Grid.world_to_map(player.global_position)
		var new_path = Grid.find_path(start_pos, destination_tile, owner)
		
		if not new_path.is_empty():
			grid_movement_component.move_along_path(new_path)

func _on_target_requested(target: Node2D) -> void:
	grid_movement_component.stop()
	var chase_state: PlayerChaseState = state_machine.get_state(States.PLAYER.CHASE)
	chase_state.target = target
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.CHASE])
