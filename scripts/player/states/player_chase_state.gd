# player_chase_state.gd
# The state for moving towards a target to get within attack range.
class_name PlayerChaseState
extends PlayerState # Make sure it extends PlayerState

var target: Node2D
var move_path: PackedVector2Array = []
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
		
	# Connect to the signal that tells us when a single tile move is complete.
	grid_movement_component.move_finished.connect(_on_move_finished)
	
	# Calculate the initial path to start the chase.
	_recalculate_path()

func exit() -> void:
	# Disconnect the signal and stop all movement when leaving this state.
	grid_movement_component.move_finished.disconnect(_on_move_finished)
	grid_movement_component.stop()

func process_physics(delta: float) -> void:
	# First, check if our target still exists.
	if not is_instance_valid(target):
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.IDLE]) # just idle if invalid target
		return # early exit

	# First, always check if we've arrived in attack range.
	var distance_to_target = player.global_position.distance_to(target.global_position) 
	var attack_range = stats_component.get_total_stat("range")

	if distance_to_target <= attack_range:
		var attack_state: PlayerAttackState = state_machine.states["attack"]
		attack_state.target = target
		state_machine.change_state(States.PLAYER_STATE_NAMES[States.PLAYER.ATTACK])
		return
	
	# If not in range, check if we need to update our path.
	# Only recalculate if we're not busy moving AND the target has moved to a new tile.
	if not grid_movement_component.is_moving:
		var current_target_tile = Grid.world_to_map(target.global_position)
		if current_target_tile != last_target_tile:
			_recalculate_path()

# This function is called every time a single tile movement is finished.
func _on_move_finished() -> void:
	# When we arrive at a tile, simply try to move to the next one in our current path.
	_move_to_next_tile()

# Gets a new path and starts the movement process.
func _recalculate_path() -> void:
	var start_pos = Grid.world_to_map(player.global_position)
	var end_pos = Grid.world_to_map(target.global_position)
	
	self.last_target_tile = end_pos
	self.move_path = Grid.find_path(start_pos, end_pos)
	
	# Remove the first point, which is the player's current location.
	# This prevents trying to first walk to it's starting position
	if not move_path.is_empty():
		move_path.remove_at(0)
	
	player.get_node("AnimationComponent").play_animation("Move")
	_move_to_next_tile()
	
# Moves to the very next tile in the current path array.
func _move_to_next_tile() -> void:
	if move_path.is_empty():
		# Path is done, but we're not in range. Let the physics process recalculate.
		return 
	
	var next_pos = move_path[0]
	move_path.remove_at(0)
	grid_movement_component.move_to(next_pos)
