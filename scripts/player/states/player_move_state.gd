# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# Scene referenes needed for move state
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

# This will hold the array of world positions we need to walk through.
var move_path: PackedVector2Array = []

func enter() -> void:
	# Remove the first point, which is the player's current location.
	# This prevents trying to first walk to it's starting position
	if not move_path.is_empty():
		move_path.remove_at(0)

	# When we enter, start listening for the component to finish a step.
	grid_movement_component.move_finished.connect(_on_move_finished)
	player.get_node("AnimationComponent").play_animation("Move")
	# Immediately try to move to the first tile in our path.
	_move_to_next_tile()
	
func exit() -> void:
	# IMPORTANT: Disconnect the signal when we leave this state to prevent bugs.
	grid_movement_component.move_finished.disconnect(_on_move_finished)

# This is the heart of our path-following loop.
func _move_to_next_tile() -> void:
	# stop moving if no path
	if move_path.is_empty():
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return
	
	# otherwise, get next path point and move
	var next_pos = move_path[0]
	move_path.remove_at(0)
	grid_movement_component.move_to(next_pos)

# Called by the component's signal when a single tile move is done.
func _on_move_finished() -> void:
	# When we arrive, simply try to move to the next one.
	_move_to_next_tile()

# process_input handles discretse events like casting.
func process_input(event: InputEvent) -> void:
	if handle_skill_cast(event):
		# A skill was successfully cast. Stop all movement immediately.
		grid_movement_component.stop()
		return

# The physics process is now empty because the component handles it.
func process_physics(_delta: float) -> void:
	# We check for new move commands ONLY if the component is NOT busy.
	if Input.is_action_pressed("move_click"):
		var end_pos = Grid.world_to_map(player.get_global_mouse_position())
		var start_pos = Grid.world_to_map(player.global_position)
		var new_path = Grid.find_path(start_pos, end_pos)
		
		# Only update if a valid path was found.
		if not new_path.is_empty():
			self.move_path = new_path
			_move_to_next_tile()
