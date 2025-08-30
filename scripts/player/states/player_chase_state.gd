# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends PlayerState # Make sure it extends PlayerState

var target: Node2D
# We need to track the target's last known tile to avoid spamming the pathfinder.
var last_target_tile: Vector2i

# Scene referenes needed for move state
@onready var attack_component: AttackComponent = player.get_node("AttackComponent")
@onready var animation_component: AnimationComponent = player.get_node("AnimationComponent")
@onready var grid_movement_component: GridMovementComponent = player.get_node("GridMovementComponent")

func enter() -> void:
	# On entering, immediately start moving towards the target.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit
		
	player.get_node("AnimationComponent").play_animation("Move")
		# Calculate the initial path to start the chase.
	_recalculate_path()

func exit() -> void:
	# Crucial cleanup: stop movement.
	grid_movement_component.stop()

func process_physics(delta: float) -> void:
	# First, check if our target still exists.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit

	# First, always check if we've arrived in attack range.
	var distance = player.global_position.distance_to(target.global_position) 
	var attack_range = stats_component.get_total_stat("range")

	if distance <= attack_range:
		var attack_state: PlayerAttackState = state_machine.states["attack"]
		attack_state.target = target
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK])
		return
	
	# Only recalculate if the target has moved to a new tile.
	var current_target_tile = Grid.world_to_map(target.global_position)
	if current_target_tile != last_target_tile:
		_recalculate_path()

# Gets a new path and starts the movement process.
func _recalculate_path() -> void:
	var start_pos = Grid.world_to_map(player.global_position)
	var end_pos = Grid.world_to_map(target.global_position)
	
	last_target_tile = end_pos
	var path = Grid.find_path(start_pos, end_pos)
	
	# The state simply tells the component what path to follow.
	grid_movement_component.move_along_path(path)
