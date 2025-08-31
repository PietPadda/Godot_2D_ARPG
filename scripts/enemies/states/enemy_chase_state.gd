# enemy_chase_state.gd
class_name EnemyChaseState
extends EnemyState # Corrected from PlayerState

var target: Node2D
var move_path: PackedVector2Array = []
var last_target_tile: Vector2i

# We now get the GridMovementComponent instead of the old AI one.
@onready var grid_movement_component: GridMovementComponent = owner_node.get_node("GridMovementComponent")

func enter() -> void:
	if not is_instance_valid(target):
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE])
		return
		
	animation_component.play_animation("Move") # Assuming enemy has a "Move" animation
	# NEW: Listen for the stuck signal
	grid_movement_component.path_stuck.connect(_recalculate_path)
	_recalculate_path()

func exit() -> void:
	# NEW: Disconnect from the stuck signal
	if grid_movement_component.path_stuck.is_connected(_recalculate_path):
		grid_movement_component.path_stuck.disconnect(_recalculate_path)
	grid_movement_component.stop()
	
func process_physics(delta: float) -> void:
	# First, check if our target is still valid (hasn't been defeated, etc.).
	if not is_instance_valid(target): # Use the shared function from the base class
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.IDLE]) # change state
		return

	# First, check if we are in range to attack.
	var distance = owner_node.global_position.distance_to(target.global_position)
	if distance <= stats_component.get_total_stat("range"):
		var attack_state: EnemyAttackState = state_machine.states["attack"]
		attack_state.target = target
		state_machine.change_state(States.ENEMY_STATE_NAMES[States.ENEMY.ATTACK])
		return

	# If not in range, check if we need to find a new path.
	if not grid_movement_component.is_moving:
		var current_target_tile = Grid.world_to_map(target.global_position)
		if current_target_tile != last_target_tile:
			_recalculate_path()

# Calculates a new path and tells the component to start moving.
func _recalculate_path() -> void:
	var start = Grid.world_to_map(owner_node.global_position)
	var end = Grid.world_to_map(target.global_position)
	last_target_tile = end
	var path = Grid.find_path(start, end)
	
	# The state simply tells the component what path to follow.
	grid_movement_component.move_along_path(path)
