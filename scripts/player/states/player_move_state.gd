# player_move_state.gd
# The state for when the player is actively moving towards a target.
class_name PlayerMoveState
extends PlayerState # Changed from 'State'

# References to the player's nodes we need to interact with.
@onready var targeting_component: PlayerTargetingComponent = player.get_node("PlayerTargetingComponent")

# This will hold the array of world positions we need to walk through.
var move_path: PackedVector2Array = []
var current_target_pos: Vector2
@export var stopping_distance: float = 5.0

func enter() -> void:
	# Play the move animation.
	player.get_node("AnimationComponent").play_animation("Move") # play Move anim
	# Start the process by getting the first tile from the path.
	_set_next_target()

func exit() -> void:
	# When we leave this state (e.g., finish moving or cast a skill),
	# ensure the player stops moving immediately.
	player.velocity = Vector2.ZERO

func _set_next_target() -> bool:
	# Check if the path is empty.
	if move_path.is_empty():
		return false # No more targets

	# Get the next waypoint from the path.
	self.current_target_pos = move_path[0]
	move_path.remove_at(0)
	return true # We have a new target

func process_input(event: InputEvent) -> void:
	# First, check if a skill was cast, which should interrupt the movement.
	if handle_skill_cast(event):
		# Clear the path so we don't resume moving after the cast.
		move_path.clear() # Clear the path so we don't resume moving
		return
		
	# Handle being interrupted by a new move command
	if event.is_action_pressed("move_click"):
		var new_path = Grid.find_path(
			Grid.world_to_map(player.global_position),
			Grid.world_to_map(player.get_global_mouse_position())
		)
		if not new_path.is_empty():
			self.move_path = new_path
			_set_next_target()
			
func process_physics(_delta: float) -> void:
	# If we don't have a target, something is wrong. Go idle.
	if current_target_pos == null:
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
		return

	# Check the distance to the center of the target tile.
	var distance_to_target = player.global_position.distance_to(current_target_pos)
	
	# If we are very close to the center, we've "arrived" at the tile.
	if distance_to_target < stopping_distance:
		# Try to get the next tile in our path.
		if not _set_next_target():
			# If there are no more tiles, our journey is over.
			state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])
			return
	
	# If we haven't arrived yet, calculate velocity and move.
	var direction = player.global_position.direction_to(current_target_pos) # dir
	var move_speed = stats_component.get_total_stat("move_speed") # vel
	player.velocity = direction * move_speed # dir * vel
	player.move_and_slide() # apply
