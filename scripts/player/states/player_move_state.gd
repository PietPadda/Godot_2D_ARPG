# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# Scene referenes needed for move state
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

# CHANGED: This state now works with a Vector2 world position, not a Vector2i tile.
var destination_world_pos: Vector2

func enter() -> void:
	player.get_node("AnimationComponent").play_animation("Move")
	# When we enter, start listening for the component to finish a step.
	grid_movement_component.path_finished.connect(_on_path_finished)
	# NEW: Listen for the stuck signal
	grid_movement_component.path_stuck.connect(_on_path_stuck)
	
	# CHANGED: We now calculate the path using world positions directly.
	var initial_path = Grid.find_path(player.global_position, destination_world_pos)

	if not initial_path.is_empty():
		grid_movement_component.move_along_path(initial_path)
	else:
		# If for some reason no path is found, just go back to idle.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	if grid_movement_component.path_finished.is_connected(_on_path_finished):
		grid_movement_component.path_finished.disconnect(_on_path_finished)
	# NEW: Disconnect from the stuck signal
	if grid_movement_component.path_stuck.is_connected(_on_path_stuck):
		grid_movement_component.path_stuck.disconnect(_on_path_stuck)

func _on_path_finished() -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

# process_input handles discretse events like casting.
func process_input(event: InputEvent) -> void:
	if handle_skill_cast(event):
		# A skill was successfully cast. Stop all movement immediately.
		grid_movement_component.stop()
		return

# _physics_process now handles hold-to-move without any race conditions.
func process_physics(_delta: float) -> void:
	# If the move button is still held, find a new path to the mouse.
	if Input.is_action_pressed("move_click"):
		var current_mouse_pos = player.get_global_mouse_position()
		
		# We compare distance to avoid spamming the pathfinder for tiny mouse movements.
		if current_mouse_pos.distance_to(destination_world_pos) > 10.0:
			self.destination_world_pos = current_mouse_pos
			
			# CHANGED: Recalculate the path using world positions directly.
			var new_path = Grid.find_path(player.global_position, destination_world_pos)
			
			if not new_path.is_empty():
				grid_movement_component.move_along_path(new_path)
				
# NEW: This function handles getting stuck during a normal move.
func _on_path_stuck() -> void:
	# CHANGED: Recalculate the path using world positions directly.
	var new_path = Grid.find_path(player.global_position, destination_world_pos)
	if not new_path.is_empty():
		grid_movement_component.move_along_path(new_path)
	else:
		# If no new path can be found, give up and go idle.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
