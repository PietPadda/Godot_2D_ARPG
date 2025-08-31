# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# Scene referenes needed for move state
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

var move_path: PackedVector2Array = []
var final_destination_tile: Vector2i

func enter() -> void:
	if not move_path.is_empty():
		final_destination_tile = Grid.world_to_map(move_path[move_path.size() - 1])
	
	grid_movement_component.move_along_path(move_path)
	# When we enter, start listening for the component to finish a step.
	grid_movement_component.path_finished.connect(_on_path_finished)
	player.get_node("AnimationComponent").play_animation("Move")
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	if grid_movement_component.path_finished.is_connected(_on_path_finished):
		grid_movement_component.path_finished.disconnect(_on_path_finished)

func _on_path_finished() -> void:
	state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

# process_input handles discretse events like casting.
func process_input(event: InputEvent) -> void:
	if handle_skill_cast(event):
		# A skill was successfully cast. Stop all movement immediately.
		grid_movement_component.stop()
		return

# The physics process is now empty because the component handles it.
func process_physics(_delta: float) -> void:
	# If the move button is still held, find a new path to the mouse.
	if Input.is_action_pressed("move_click"):
		var current_mouse_tile = Grid.world_to_map(player.get_global_mouse_position())
		
		# ONLY recalculate the path if the mouse is pointing to a NEW tile.
		if current_mouse_tile != final_destination_tile:
			# --- DEBUG PRINT 2 ---
			# Announce that we are about to recalculate.
			print("MoveState: Recalculating path to new tile: ", current_mouse_tile)
			
			var start_pos = Grid.world_to_map(player.global_position)
			var new_path = Grid.find_path(start_pos, current_mouse_tile)
			
			# --- DEBUG PRINT 3 ---
			# Let's see what this new path is.
			print("MoveState: New path calculated: ", new_path)
			
			# Only update if a valid path was found.
			if not new_path.is_empty():
				self.final_destination_tile = current_mouse_tile
				grid_movement_component.move_along_path(new_path)
