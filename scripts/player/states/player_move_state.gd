# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# References to the player's nodes we need to interact with.
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")

# This will hold the array of world positions we need to walk through.
var move_path: PackedVector2Array = []

func enter() -> void:
	# When we enter this state, start listening for the movement component to finish a step.
	grid_movement_component.move_finished.connect(_on_move_finished)
	# Immediately try to move to the first tile in our path.
	_move_to_next_tile()
	# Play the move animation.
	animation_component.play_animation("Move") # play Move anim

func exit() -> void:
	# IMPORTANT: When we exit this state, stop listening to the signal to prevent bugs.
	grid_movement_component.move_finished.disconnect(_on_move_finished)

# This function is the heart of our path-following loop.
func _move_to_next_tile():
	# If the path is empty, our journey is over.
	if move_path.is_empty():
		# Transition back to the Idle state.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return

	# Use the methods for a PackedVector2Array.
	# Get the next waypoint from the front of the array.
	var next_position = move_path[0]
	# Remove that waypoint from the array so we don't process it again.
	move_path.remove_at(0)
	# Tell our "motor" component to move there.
	grid_movement_component.move_to(next_position)

# This function is called automatically every time the GridMovementComponent finishes a single tile move.
func _on_move_finished():
	# When we arrive at a tile, simply try to move to the next one.
	_move_to_next_tile()

# We'll add logic here later to handle interrupting a move with a new one.
func process_input(event: InputEvent) -> void:
	# First, check if a skill was cast, which should interrupt the movement.
	if handle_skill_cast(event):
		# Clear the path so we don't resume moving after the cast.
		move_path.clear()
		return
