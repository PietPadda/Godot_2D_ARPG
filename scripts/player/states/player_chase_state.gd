# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends PlayerState # Make sure it extends PlayerState

var target: Node2D

# Scene referenes needed for move state
@onready var attack_component: AttackComponent = player.get_node("AttackComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

func enter() -> void:
	# On entering, immediately start moving towards the target.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
		
	# Find a path to the target's current location.
	var start_pos = Grid.world_to_map(player.global_position)
	var end_pos = Grid.world_to_map(target.global_position)
	var path = Grid.find_path(start_pos, end_pos)
	
	# If a path exists, tell the component to start moving.
	if not path.is_empty():
		grid_movement_component.move_along_path(path)
		animation_component.play_animation("Move")
	else:
		# If no path, we might already be in range, or the target is unreachable.
		# Go idle and let the next input decide.
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE])

func process_physics(delta: float) -> void:
	# First, check if our target still exists.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit

	# Check distance using our new, correct stat calculator.
	var distance_to_target = player.global_position.distance_to(target.global_position) 
	var attack_range = stats_component.get_total_stat("range") # Correctly call the calculator

	if distance_to_target <= attack_range: # if we're in range
		# We are in range! Stop moving and transition to Attack.
		grid_movement_component.move_along_path([]) # Clear the path to stop movement.
		
		# Pass the target to the AttackState and transition.
		var attack_state = state_machine.states["attack"] # attackstate
		attack_state.target = target # pass the target to attack
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK]) # and attack
	else:
		# If we're not in range, we need to move! This was the missing piece.
		pass
